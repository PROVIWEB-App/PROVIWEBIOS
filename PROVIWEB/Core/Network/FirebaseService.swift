import Foundation
import Combine
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Auth & Session Errors
public enum FirebaseServiceError: LocalizedError {
    case invalidEmail
    case weakPassword
    case missingCredentials
    case firebaseNotAvailable
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "El correo electrónico no es válido."
        case .weakPassword:
            return "La contraseña debe tener al menos 6 caracteres."
        case .missingCredentials:
            return "Ingresa tu correo y contraseña para continuar."
        case .firebaseNotAvailable:
            return "Firebase no está disponible en esta compilación."
        case .network(let message):
            return message
        }
    }
}

// MARK: - Firebase Service Wrapper: Auth + Live Realtime Database (esquema Android)
@MainActor
public class FirebaseService: ObservableObject {
    public static let shared = FirebaseService()

    /// UID del usuario de demostración (modo offline / QA)
    public static let demoUserId = "user_demo_violin_001"

    // MARK: Session State
    @Published public var currentUserId: String = "user_demo_violin_001"
    @Published public var isAuthenticated: Bool = false {
        didSet {
            if isAuthenticated && !oldValue {
                activateSession()
            } else if !isAuthenticated && oldValue {
                deactivateSession()
            }
        }
    }
    /// `true` cuando ya se conoce el estado de sesión (evita parpadeos de arranque)
    @Published public var isSessionReady: Bool = false
    /// `true` cuando el usuario entró sin credenciales (revisión / QA / sin red)
    @Published public var isDemoMode: Bool = false
    /// `true` cuando `Users/{uid}` marca `isMinor = "yes"` y `minorApprovalStatus != "approved"`
    /// (mismo esquema que WaitApprovalActivity.java / SignUpActivity.java en Android).
    @Published public var isPendingApproval: Bool = false {
        didSet {
            if isPendingApproval {
                if let uid = realUid {
                    UserDefaults.standard.set(uid, forKey: FirebaseService.pendingApprovalUidKey)
                }
            } else {
                UserDefaults.standard.removeObject(forKey: FirebaseService.pendingApprovalUidKey)
            }
        }
    }
    private static let pendingApprovalUidKey = "proviweb.pendingApproval.uid"
    /// Bloquea botones de login/registro mientras se procesa una operación
    @Published public var isAuthBusy: Bool = false
    /// Último error de autenticación listo para mostrar en la UI
    @Published public var authError: String?
    @Published public var currentUser: UserModel?

    // MARK: In-memory database nodes (seed local / respaldo offline)
    @Published public var posts: [PostModel] = []
    @Published public var reels: [ReelModel] = []
    @Published public var songs: [SongModel] = []
    @Published public var playlists: [PlaylistModel] = []
    @Published public var books: [BookModel] = []
    @Published public var verifiedEntities: [UserModel] = []
    @Published public var liveSessions: [LiveSessionModel] = []
    /// Contadores reales del panel ADMIN (lecturas puntuales, ver `refreshAdminCounters()`).
    /// En modo demo conservan sus valores locales de ejemplo.
    @Published public var adminReportedPostsCount: Int = 4
    @Published public var adminPendingVerificationsCount: Int = 7
    @Published public var walletBalance: WalletBalanceModel = WalletBalanceModel(
        balanceUSD: 145.50,
        diamonds: 820,
        referralCount: 14,
        walletAddress: "0x71C...4982aF"
    )

    // MARK: Internos de sincronización
    private var cancellables = Set<AnyCancellable>()
    private var didBootstrap: Bool = false
    private var authorCache: [String: UserModel] = [:]
    private var aplausosCount: [String: Int] = [:]
    private var aplausosLiked: [String: Bool] = [:]
    private var pendingAuthorFetches: Set<String> = []

    #if canImport(FirebaseAuth)
    private var authHandle: AuthStateDidChangeListenerHandle?
    #endif
    #if canImport(FirebaseDatabase)
    /// Observadores con su ruta de baja exacta (la baja debe hacerse sobre el MISMO
    /// reference/query donde se registró, o Firebase deja el listener vivo).
    private var syncObservers: [(handle: DatabaseHandle, remove: () -> Void)] = []
    private var aplausosObservers: [String: (handle: DatabaseHandle, remove: () -> Void)] = [:]
    private var currentUserObserver: (handle: DatabaseHandle, remove: () -> Void)?
    /// Respaldo del observador de entidades verificadas: si la consulta
    /// `verified == "yes"` se cancela (falta índice), se cae a una lectura de los
    /// últimos usuarios con el MISMO filtro de MainFragment.java.
    private var verifiedEntitiesFallback: (handle: DatabaseHandle, remove: () -> Void)?
    #endif

    public init() {
        loadInitialMockData()
    }

    // MARK: - Bootstrap (llamar desde AppDelegate tras FirebaseApp.configure())
    /// Idempotente: activa el listener de sesión y la sincronización en vivo.
    public func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        #if canImport(FirebaseAuth)
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.handleAuthStateChange(user)
            }
        }
        #else
        isSessionReady = true
        #endif

        // Semilla en vivo (mejor esfuerzo): si las reglas lo permiten, pinta datos reales.
        startLiveDatabaseSync()
    }

    // MARK: - Sesión
    private func activateSession() {
        guard !isDemoMode else { return }
        startLiveDatabaseSync()
    }

    private func deactivateSession() {
        stopLiveDatabaseSync()
        if !isDemoMode {
            #if canImport(FirebaseAuth)
            if Auth.auth().currentUser != nil {
                try? Auth.auth().signOut()
            }
            #endif
        }
        isDemoMode = false
        isPendingApproval = false
        currentUserId = FirebaseService.demoUserId
        currentUser = nil
        #if canImport(FirebaseDatabase)
        currentUserObserver?.remove()
        currentUserObserver = nil
        #endif
    }

    #if canImport(FirebaseAuth)
    private func handleAuthStateChange(_ user: User?) {
        defer { isSessionReady = true }

        if let user = user {
            currentUserId = user.uid
            isDemoMode = false
            // Restaura la bandera de "menor pendiente" para no abrir MainTabView
            // antes de que RTDB responda (o cuando no hay red).
            if UserDefaults.standard.string(forKey: FirebaseService.pendingApprovalUidKey) == user.uid {
                isPendingApproval = true
            }
            // Durante signIn/signUp está isAuthBusy: en ese caso la sesión la activa el
            // propio flujo DESPUÉS de resolver la aprobación (un menor nunca ve MainTabView).
            if !isAuthenticated, !isAuthBusy { isAuthenticated = true }
            fetchCurrentUser(uid: user.uid)
            resolvePendingApproval(uid: user.uid) { _ in }
            startLiveDatabaseSync()
        } else {
            // Sesión demo activa: no la tumbamos por un callback nulo inicial.
            if isDemoMode { return }
            currentUserId = FirebaseService.demoUserId
            currentUser = nil
            if isAuthenticated { isAuthenticated = false } else { stopLiveDatabaseSync() }
        }
    }
    #endif

    // MARK: - Login
    public func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(trimmedEmail) else {
            completion(.failure(FirebaseServiceError.invalidEmail))
            return
        }
        guard !password.isEmpty else {
            completion(.failure(FirebaseServiceError.missingCredentials))
            return
        }

        #if canImport(FirebaseAuth)
        isAuthBusy = true
        authError = nil
        Auth.auth().signIn(withEmail: trimmedEmail, password: password) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                if let error = error {
                    self.isAuthBusy = false
                    self.authError = self.friendlyMessage(for: error)
                    completion(.failure(error))
                    return
                }
                if let user = result?.user {
                    self.currentUserId = user.uid
                    self.isDemoMode = false
                    self.fetchCurrentUser(uid: user.uid)
                    self.markOnline(uid: user.uid)
                    AnalyticsService.shared.logEvent("login_success", parameters: ["method": "email"])
                    // La sesión se activa DESPUÉS de resolver la aprobación de menores:
                    // así la raíz muestra WaitApprovalView y nunca MainTabView.
                    self.resolvePendingApproval(uid: user.uid) { _ in
                        if !self.isAuthenticated { self.isAuthenticated = true }
                        self.isAuthBusy = false
                        completion(.success(()))
                    }
                } else {
                    self.isAuthBusy = false
                    completion(.success(()))
                }
            }
        }
        #else
        completion(.failure(FirebaseServiceError.firebaseNotAvailable))
        #endif
    }

    // MARK: - Registro
    public func signUp(
        name: String,
        email: String,
        password: String,
        instrument: String,
        username: String? = nil,
        phone: String? = nil,
        isMinor: Bool = false,
        completion: @escaping (Result<UserModel, Error>) -> Void
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard isValidEmail(trimmedEmail) else {
            completion(.failure(FirebaseServiceError.invalidEmail))
            return
        }
        guard password.count >= 6 else {
            completion(.failure(FirebaseServiceError.weakPassword))
            return
        }
        guard !trimmedName.isEmpty else {
            completion(.failure(FirebaseServiceError.missingCredentials))
            return
        }

        #if canImport(FirebaseAuth)
        isAuthBusy = true
        authError = nil
        Auth.auth().createUser(withEmail: trimmedEmail, password: password) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                if let error = error {
                    self.isAuthBusy = false
                    self.authError = self.friendlyMessage(for: error)
                    completion(.failure(error))
                    return
                }
                guard let user = result?.user else {
                    self.isAuthBusy = false
                    completion(.failure(FirebaseServiceError.network("No se pudo crear la cuenta.")))
                    return
                }

                let handle = username?.isEmpty == false
                    ? (username ?? "").lowercased()
                    : trimmedEmail.split(separator: "@").first.map(String.init)?.lowercased() ?? "proviweb"

                let profile = UserModel(
                    id: user.uid,
                    uid: user.uid,
                    name: trimmedName,
                    email: trimmedEmail,
                    username: handle,
                    bio: "¡Soy nuevo en PROVIWEB! 🎶",
                    phone: phone,
                    instrument: instrument,
                    referralCode: String(UUID().uuidString.prefix(8)).uppercased()
                )

                self.writeUserNode(uid: user.uid, profile: profile, isMinor: isMinor) { result in
                    Task { @MainActor in
                        self.isAuthBusy = false
                        // Si el perfil no se guardó (sin red / permisos), no activamos sesión:
                        // el usuario reintenta y evitamos quedar un menor "colgado" en espera.
                        guard case .success = result else {
                            let message = "No se pudo guardar el perfil. Revisa tu conexión e inténtalo de nuevo."
                            self.authError = message
                            completion(.failure(FirebaseServiceError.network(message)))
                            return
                        }
                        self.currentUserId = user.uid
                        self.isDemoMode = false
                        self.currentUser = profile
                        // Menores: la raíz mostrará WaitApprovalView hasta la aprobación.
                        // Sin RTDB la aprobación es imposible: no se activa la barrera.
                        self.isPendingApproval = isMinor && FirebaseService.isDatabaseAvailable
                        self.isAuthenticated = true
                        user.sendEmailVerification(completion: nil)
                        AnalyticsService.shared.logEvent("sign_up_success", parameters: ["instrument": instrument])
                        AnalyticsService.shared.setUserId(user.uid)
                        completion(.success(profile))
                    }
                }
            }
        }
        #else
        completion(.failure(FirebaseServiceError.firebaseNotAvailable))
        #endif
    }

    // MARK: - Recuperación de contraseña
    public func sendPasswordReset(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(trimmedEmail) else {
            completion(.failure(FirebaseServiceError.invalidEmail))
            return
        }
        #if canImport(FirebaseAuth)
        isAuthBusy = true
        Auth.auth().sendPasswordReset(withEmail: trimmedEmail) { [weak self] error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isAuthBusy = false
                if let error = error {
                    self.authError = self.friendlyMessage(for: error)
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
        #else
        completion(.failure(FirebaseServiceError.firebaseNotAvailable))
        #endif
    }

    // MARK: - Verificación de teléfono (SMS OTP)
    #if canImport(FirebaseAuth)
    public func startPhoneVerification(phoneNumber: String, completion: @escaping (Result<String, Error>) -> Void) {
        isAuthBusy = true
        authError = nil
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uidDelegate: nil) { [weak self] verificationID, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isAuthBusy = false
                if let error = error {
                    self.authError = self.friendlyMessage(for: error)
                    completion(.failure(error))
                    return
                }
                guard let verificationID = verificationID else {
                    let err = FirebaseServiceError.network("No se recibió el código de verificación.")
                    self.authError = err.errorDescription
                    completion(.failure(err))
                    return
                }
                completion(.success(verificationID))
            }
        }
    }

    /// Confirma el código SMS. Si ya hay sesión de email se **vincula** el teléfono
    /// al usuario actual (`link(with:)`) para no romper la cuenta de correo;
    /// solo se usa `signIn` como último recurso cuando no existe sesión previa.
    public func confirmPhoneVerification(verificationID: String, code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: code)
        isAuthBusy = true
        authError = nil

        let finish: (Error?) -> Void = { [weak self] error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isAuthBusy = false
                if let error = error {
                    // Si el fallo es que el teléfono ya estaba vinculado, lo tratamos como éxito.
                    let phoneProvider = PhoneAuthProvider.provider().providerID
                    let alreadyLinked = Auth.auth().currentUser?.providerData.contains {
                        $0.providerID == phoneProvider
                    } ?? false
                    if alreadyLinked {
                        completion(.success(()))
                        return
                    }
                    self.authError = self.friendlyMessage(for: error)
                    completion(.failure(error))
                } else {
                    self.persistLinkedPhoneIfNeeded()
                    completion(.success(()))
                }
            }
        }

        if let user = Auth.auth().currentUser {
            user.link(with: credential) { _, error in
                finish(error)
            }
        } else {
            Auth.auth().signIn(with: credential) { _, error in
                finish(error)
            }
        }
    }

    /// Refleja el teléfono recién vinculado en el perfil local y en `Users/{uid}` de RTDB
    /// para que Android lo vea con el mismo dato.
    private func persistLinkedPhoneIfNeeded() {
        guard !isDemoMode else { return }
        guard let linkedPhone = Auth.auth().currentUser?.phoneNumber, !linkedPhone.isEmpty else { return }
        if currentUser?.phone != linkedPhone {
            var updated = currentUser
            updated?.phone = linkedPhone
            if let updated = updated {
                currentUser = updated
            }
            saveCurrentUserProfile()
        }
    }
    #else
    public func startPhoneVerification(phoneNumber: String, completion: @escaping (Result<String, Error>) -> Void) {
        completion(.failure(FirebaseServiceError.firebaseNotAvailable))
    }

    public func confirmPhoneVerification(verificationID: String, code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.failure(FirebaseServiceError.firebaseNotAvailable))
    }
    #endif

    // MARK: - Salir / Modo demostración
    public func signOut() {
        isDemoMode = false
        if isAuthenticated {
            isAuthenticated = false
        } else {
            deactivateSession()
        }
    }

    public func enterDemoMode() {
        authError = nil
        // El usuario demo nunca espera aprobación: desarma la barrera de menores.
        isPendingApproval = false
        isDemoMode = true
        currentUserId = FirebaseService.demoUserId
        currentUser = demoUser()
        isSessionReady = true
        isAuthenticated = true
        startLiveDatabaseSync()
    }

    private func demoUser() -> UserModel {
        UserModel(
            id: FirebaseService.demoUserId,
            uid: FirebaseService.demoUserId,
            name: "Israel Violín Maestro",
            email: "israel@proviweb.com",
            username: "israviolink",
            image: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
            bio: "Violinista profesional & Fundador de PROVIWEB. Compartiendo el arte de la música clásica y el mariachi 🎻🎶",
            phone: "+52 55 1234 5678",
            location: "Ciudad de México",
            verified: "musician",
            onlineStatus: "Online",
            instrument: "Violín",
            experienceYears: 15,
            referralCode: "ISRA2026"
        )
    }

    // MARK: - Perfil
    public func saveCurrentUserProfile() {
        guard !isDemoMode, let user = currentUser, isRealAuthActive else { return }
        #if canImport(FirebaseDatabase)
        let dict: [String: Any] = [
            "name": user.name,
            "username": (user.username ?? "").lowercased(),
            "bio": user.bio ?? "",
            "instrument": user.instrument ?? "",
            "experienceYears": user.experienceYears ?? 0,
            "phone": user.phone ?? "",
            "location": user.location ?? "",
            "photo": user.image ?? "",
            "image": user.image ?? ""
        ]
        Database.database().reference().child("Users").child(user.id).updateChildValues(dict)
        #endif
    }

    /// Sube la nueva URL de la foto de perfil y la persiste en el nodo `Users/{uid}/photo`
    /// (mismo campo que usa `EditProfileActivity.uploadDp()` en Android).
    /// Se escriben `photo` e `image` porque `userModel` prioriza `image` sobre `photo`.
    public func updateProfilePhotoURL(_ url: String) {
        guard !isDemoMode, let uid = realUid, isRealAuthActive else { return }
        currentUser?.image = url
        #if canImport(FirebaseDatabase)
        Database.database().reference().child("Users").child(uid)
            .updateChildValues(["photo": url, "image": url])
        #endif
    }

    #if canImport(FirebaseDatabase)
    private func fetchCurrentUser(uid: String) {
        let ref = Database.database().reference().child("Users").child(uid)
        let previous = currentUserObserver
        previous?.remove()
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self, let dict = snapshot.value as? [String: Any] else { return }
                self.currentUser = self.userModel(uid: uid, dict: dict, fallback: self.currentUser)
                self.applyApprovalState(uid: uid, dict: dict)
                self.authorCache[uid] = self.currentUser
                self.applyAuthors()
            }
        }
        currentUserObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }

    private func userModel(uid: String, dict: [String: Any], fallback: UserModel? = nil) -> UserModel {
        UserModel(
            id: uid,
            uid: uid,
            name: FirebaseService.nonEmpty(dict["name"]) ?? fallback?.name ?? "Músico PROVIWEB",
            email: FirebaseService.nonEmpty(dict["email"]) ?? fallback?.email ?? "",
            username: FirebaseService.nonEmpty(dict["username"]) ?? fallback?.username,
            image: FirebaseService.nonEmpty(dict["image"]) ?? FirebaseService.nonEmpty(dict["photo"]) ?? fallback?.image,
            cover: FirebaseService.nonEmpty(dict["cover"]) ?? fallback?.cover,
            bio: FirebaseService.nonEmpty(dict["bio"]) ?? fallback?.bio,
            phone: FirebaseService.nonEmpty(dict["phone"]) ?? fallback?.phone,
            location: FirebaseService.nonEmpty(dict["location"]) ?? fallback?.location,
            verified: FirebaseService.nonEmpty(dict["verified"]) ?? fallback?.verified,
            onlineStatus: FirebaseService.nonEmpty(dict["onlineStatus"]) ?? fallback?.onlineStatus ?? "Online",
            instrument: FirebaseService.nonEmpty(dict["instrument"]) ?? fallback?.instrument,
            experienceYears: FirebaseService.intValue(dict["experienceYears"]) ?? fallback?.experienceYears,
            referralCode: FirebaseService.nonEmpty(dict["referralCode"]) ?? fallback?.referralCode
        )
    }

    private func markOnline(uid: String) {
        let values: [String: Any] = [
            "isOnline": true,
            "onlineStatus": "Online",
            "lastSeen": Date().timeIntervalSince1970 * 1000
        ]
        Database.database().reference().child("Users").child(uid).updateChildValues(values)
    }

    private func writeUserNode(uid: String, profile: UserModel, isMinor: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        // Esquema idéntico al de SignUpActivity.java (Android) para interoperabilidad total.
        var dict: [String: Any] = [
            "id": uid,
            "name": profile.name,
            "email": profile.email,
            "username": profile.username ?? "",
            "bio": profile.bio ?? "¡Soy nuevo en PROVIWEB! 🎶",
            "verified": "",
            "verifiedprofesor": "",
            "verifiedstudent": "",
            "verifiedentidad": "",
            "verifiedprofesorart": "",
            "musicservice": "",
            "location": profile.location ?? "",
            "phone": profile.phone ?? "",
            "status": "\(Int(Date().timeIntervalSince1970 * 1000))",
            "typingTo": "noOne",
            "link": "",
            "photo": profile.image ?? "",
            "verifyEmail": false,
            "instrument": profile.instrument ?? "",
            "generoMusic": "",
            "organizaton": "User",
            "organizationName": "",
            "organizationRole": "",
            "referralCount": 0,
            "referralCode": profile.referralCode ?? "",
            "userType": "USER",
            "role": "USER",
            "isOnline": true,
            "onlineStatus": "Online",
            "isMinor": isMinor ? "yes" : "no",
            "registrationTimestamp": Int(Date().timeIntervalSince1970 * 1000),
            "createdWith": "iOS"
        ]
        if isMinor {
            dict["minorApprovalStatus"] = "pending"
        }

        let root = Database.database().reference()
        root.child("Users").child(uid).updateChildValues(dict) { error, _ in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            root.child("Balance").child(uid).updateChildValues(["balance": "0.00"]) { _, _ in
                if isMinor {
                    // Panel de menores de Android: MinorApprovalRequests/{uid}
                    // (mismos campos que SignUpActivity.java).
                    let minorRequest: [String: Any] = [
                        "userId": uid,
                        "name": profile.name,
                        "username": (profile.username ?? "").lowercased(),
                        "email": profile.email,
                        "instrument": profile.instrument ?? "",
                        "generoMusic": "",
                        "tutorName": "",
                        "tutorEmail": "",
                        "tutorPhone": "",
                        "consentDoc": "",
                        "timestamp": "\(Int(Date().timeIntervalSince1970 * 1000))",
                        "status": "pending"
                    ]
                    root.child("MinorApprovalRequests").child(uid).setValue(minorRequest)
                }
                DispatchQueue.main.async { completion(.success(())) }
            }
        }
    }
    #else
    private func fetchCurrentUser(uid: String) {}
    private func markOnline(uid: String) {}
    private func writeUserNode(uid: String, profile: UserModel, isMinor: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
    #endif

    // MARK: - Aprobación de menores (isMinor / minorApprovalStatus)
    /// Actualiza `isPendingApproval` a partir del nodo `Users/{uid}` (esquema Android).
    private func applyApprovalState(uid: String, dict: [String: Any]) {
        guard uid == currentUserId || uid == realUid else { return }
        let rawMinor = FirebaseService.nonEmpty(dict["isMinor"])?.lowercased()
        let isMinor = rawMinor == "yes" || (dict["isMinor"] as? Bool) == true
        guard isMinor else {
            if isPendingApproval { isPendingApproval = false }
            return
        }
        let status = (FirebaseService.nonEmpty(dict["minorApprovalStatus"]) ?? "").lowercased()
        // Android (WaitApprovalActivity) solo deja pasar con "approved".
        let approved = status == "approved"
        if isPendingApproval != !approved {
            isPendingApproval = !approved
        }
    }

    /// Consulta única del estado de aprobación; invoca `completion(resolved)` en MainActor
    /// (tope de 4 s para no dejar colgado el login sin red). `resolved == false` significa
    /// que NO se pudo leer RTDB (sin conexión / permisos), no que la solicitud siga pendiente.
    private func resolvePendingApproval(uid: String, completion: @escaping (Bool) -> Void) {
        #if canImport(FirebaseDatabase)
        var finished = false
        let finishOnce: (Bool) -> Void = { resolved in
            guard !finished else { return }
            finished = true
            completion(resolved)
        }
        Database.database().reference().child("Users").child(uid).observeSingleEvent(of: .value) { [weak self] snapshot in
            Task { @MainActor in
                if let self = self, let dict = snapshot.value as? [String: Any] {
                    self.applyApprovalState(uid: uid, dict: dict)
                    finishOnce(true)
                } else {
                    finishOnce(false)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            Task { @MainActor in finishOnce(false) }
        }
        #else
        completion(false)
        #endif
    }

    /// Resultado de la comprobación manual del estado (botón "Comprobar estado").
    public enum MinorApprovalCheck {
        case approved
        case pending
        /// No se pudo consultar RTDB (sin conexión o permisos): no es "pendiente".
        case unresolved
    }

    /// Botón "Comprobar estado" (equivalente a btnCheckStatus en WaitApprovalActivity.java).
    public func checkMinorApprovalStatus(completion: @escaping (MinorApprovalCheck) -> Void) {
        let uid = realUid ?? currentUserId
        guard !uid.isEmpty else {
            completion(.unresolved)
            return
        }
        resolvePendingApproval(uid: uid) { [weak self] resolved in
            guard resolved else {
                completion(.unresolved)
                return
            }
            completion(self?.isPendingApproval ?? false ? .pending : .approved)
        }
    }

    /// `true` cuando el target compila con FirebaseDatabase (los productos SPM son independientes).
    private static var isDatabaseAvailable: Bool {
        #if canImport(FirebaseDatabase)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Utilidades de sesión
    /// `true` cuando existe una sesión real de Firebase Auth (no modo demo).
    private var isRealAuthActive: Bool {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser != nil
        #else
        return false
        #endif
    }

    /// `true` cuando una sesión real (no demo) puede escribir en la nube.
    /// Exuesto para los servicios hermanos (ChatService, MarketplaceService, LocationService).
    public var canWriteToCloud: Bool {
        !isDemoMode && isRealAuthActive
    }

    /// UID real de Firebase Auth con sesión activa, o `nil` en modo demo sin cuenta.
    public var authenticatedUid: String? {
        canWriteToCloud ? realUid : nil
    }

    /// UID real de Firebase Auth, o `nil` si no hay sesión activa.
    private var realUid: String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == "FIRAuthErrorDomain" {
            switch nsError.code {
            case 17007: return "Ese correo ya está registrado. Inicia sesión."
            case 17004, 17009: return "El correo o la contraseña no son correctos."
            case 17011: return "No existe ninguna cuenta con ese correo."
            case 17008: return "El correo electrónico no tiene un formato válido."
            case 17010: return "Demasiados intentos. Inténtalo más tarde."
            case 17999: return "Error de conexión con Firebase. Revisa tu red."
            default: break
            }
        }
        return nsError.localizedDescription
    }

    public func addPracticeReward() {
        walletBalance.balanceUSD += 1.00
        walletBalance.diamonds += 5
    }

    // MARK: - Aplausos (likes) — nodo `Aplausos/{postId}/{uid}` (igual que Android)
    public func toggleLikePost(postId: String) {
        let wasLiked = aplausosLiked[postId] ?? false
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var post = posts[index]
            post.likedByCurrentUser = !wasLiked
            let currentLikes = Int(post.pLikes ?? "0") ?? 0
            post.pLikes = "\(wasLiked ? max(0, currentLikes - 1) : currentLikes + 1)"
            posts[index] = post
        }

        #if canImport(FirebaseDatabase)
        guard !isDemoMode, isRealAuthActive else { return }
        let ref = Database.database().reference().child("Aplausos").child(postId).child(currentUserId)
        if wasLiked {
            ref.removeValue()
        } else {
            ref.setValue(Int(Date().timeIntervalSince1970 * 1000))
        }
        #endif
    }

    public func addComment(postId: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var post = posts[index]
            let currentComments = Int(post.pComments ?? "0") ?? 0
            post.pComments = "\(currentComments + 1)"
            posts[index] = post
        }

        #if canImport(FirebaseDatabase)
        guard !isDemoMode, isRealAuthActive else { return }
        let root = Database.database().reference().child("Posts").child(postId)

        // Mismo esquema que CommentActivity.sendComment() en Android.
        let timestamp = "\(Int(Date().timeIntervalSince1970 * 1000))"
        let comment: [String: Any] = [
            "cId": timestamp,
            "comment": trimmed,
            "timestamp": timestamp,
            "id": currentUserId,
            "type": "text",
            "pId": postId
        ]
        root.child("Comments").child(timestamp).setValue(comment)

        // Contador visible en ambos sistemas operativos.
        root.child("commentCount").observeSingleEvent(of: .value) { snapshot in
            let current: Int
            if let number = snapshot.value as? NSNumber {
                current = number.intValue
            } else if let text = snapshot.value as? String, let parsed = Int(text) {
                current = parsed
            } else {
                current = 0
            }
            root.child("commentCount").setValue(current + 1)
        }
        #endif
    }

    // MARK: - Crear publicación
    public func createPost(title: String, description: String, feeling: String?, image: String?, video: String?, audio: String?) {
        guard let user = currentUser else { return }
        let newId = FirebaseService.pushKey() ?? UUID().uuidString
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText = description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Android solo persiste `text`: si hay título lo anteponemos para que
        // ambos sistemas muestren exactamente lo mismo.
        let composedText: String
        if cleanTitle.isEmpty {
            composedText = cleanText
        } else if cleanText.isEmpty {
            composedText = cleanTitle
        } else {
            composedText = "\(cleanTitle)\n\n\(cleanText)"
        }

        let newPost = PostModel(
            id: newId,
            pId: newId,
            uid: user.id,
            uName: user.name,
            uEmail: user.email,
            uDp: user.image,
            pTitle: nil,
            pDescr: composedText,
            pImage: image,
            pVideo: video,
            pAudio: audio,
            pTime: "\(Int(Date().timeIntervalSince1970 * 1000))",
            pLikes: "0",
            pComments: "0",
            pShare: "0",
            feeling: feeling,
            location: user.location,
            isPromoted: false
        )
        posts.insert(newPost, at: 0)
        publishPostToCloud(post: newPost)
        AnalyticsService.shared.logEvent("post_created", parameters: [
            "has_media": (image != nil || video != nil || audio != nil) ? "true" : "false"
        ])
    }

    // MARK: - Semilla local (contenido de demostración siempre disponible offline)
    public func loadInitialMockData() {
        if currentUser == nil {
            currentUser = demoUser()
        }

        guard posts.isEmpty else { return }

        // Mock Posts
        posts = [
            PostModel(
                id: "post_1",
                uid: "user_demo_violin_001",
                uName: "Israel Violín Maestro",
                uDp: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
                pTitle: "Práctica del Concierto de Mendelssohn en Mi Menor",
                pDescr: "Trabajando en el fraseo del primer movimiento y la afinación de las octavas. ¿Qué les parece el sonido de este violín artesanal? 🎻✨",
                pImage: "https://images.unsplash.com/photo-1612225330812-01a9c6b355ec?w=800&auto=format&fit=crop&q=60",
                pAudio: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
                pTime: "1725000000000",
                pLikes: "148",
                pComments: "24",
                pShare: "8",
                feeling: "Inspirado",
                location: "Sala Nezahualcóyotl"
            ),
            PostModel(
                id: "post_2",
                uid: "entity_mariachi_01",
                uName: "Mariachi Sinfónico Real",
                uDp: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
                pTitle: "¡Disponible para eventos y serenatas este fin de semana!",
                pDescr: "Contamos con repertorio clásico y tradicional mexicano. Solicita tu cotización directamente desde la app en el botón de Cotizar 🎺🎻🇲🇽",
                pImage: "https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=800&auto=format&fit=crop&q=60",
                pTime: "1724980000000",
                pLikes: "312",
                pComments: "45",
                pShare: "32",
                feeling: "Feliz",
                location: "Guadalajara, Jalisco"
            ),
            PostModel(
                id: "post_3",
                uid: "user_demo_violin_001",
                uName: "Israel Violín Maestro",
                uDp: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
                pDescr: "Nuevo arreglo del Huapango para cuarteto. ¡Escúchenlo y díganme qué les parece! 🎶🇲🇽 #Huapango #Cuarteto #Proviweb",
                pVideo: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
                pTime: "1724960000000",
                pLikes: "97",
                pComments: "12",
                pShare: "4",
                feeling: "Orgulloso",
                location: "Pátzcuaro, Michoacán"
            ),
            PostModel(
                id: "post_4",
                uid: "entity_conservatorio_01",
                uName: "Conservatorio Nacional de Música",
                uDp: "https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&auto=format&fit=crop&q=60",
                pTitle: "Auditorios abiertos esta semana",
                pDescr: "Entra a PROVIWEB y agenda tu clase de prueba con nuestros maestros verificados. 🎹🎼",
                pImage: "https://images.unsplash.com/photo-1514320291840-2e0a9bf2a9ae?w=800&auto=format&fit=crop&q=60",
                pTime: "1724940000000",
                pLikes: "203",
                pComments: "31",
                pShare: "9",
                feeling: "Feliz",
                location: "Ciudad de México"
            )
        ]

        // Mock Reels
        reels = [
            ReelModel(
                id: "reel_1",
                videoUri: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
                caption: "Técnica de Spiccato a tempo 140 BPM 🔥 #ViolinMastery #Spiccato #Proviweb",
                soundTitle: "Sonata No. 1 en Sol Menor - J.S. Bach",
                soundAuthor: "Israel Violín",
                authorId: "user_demo_violin_001",
                authorName: "Israel Violín",
                authorDp: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
                likesCount: 1420,
                commentsCount: 89
            ),
            ReelModel(
                id: "reel_2",
                videoUri: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyBlazes.mp4",
                caption: "Dueto de Mariachi en vivo en Bellas Artes 🎻🎺 #Mariachi #EnVivo",
                soundTitle: "El Son de la Negra (En Vivo)",
                soundAuthor: "Mariachi Sinfónico Real",
                authorId: "entity_mariachi_01",
                authorName: "Mariachi Real",
                authorDp: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
                likesCount: 3890,
                commentsCount: 230
            ),
            ReelModel(
                id: "reel_3",
                videoUri: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
                caption: "Afinación con el afinador inteligente de PROVIWEB 🎻🎯 #Afinación #Proviweb",
                soundTitle: "Ejercicio de Arpegios",
                soundAuthor: "Israel Violín",
                authorId: "user_demo_violin_001",
                authorName: "Israel Violín",
                authorDp: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
                likesCount: 764,
                commentsCount: 41
            )
        ]

        // Mock Songs
        songs = [
            SongModel(
                id: "song_1",
                title: "Czardas de Vittorio Monti",
                artist: "Israel Violín",
                audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
                coverUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=60",
                genre: "Clásica",
                duration: 215,
                plays: 18450
            ),
            SongModel(
                id: "song_2",
                title: "Huapango de Moncayo (Arreglo Violín Solo)",
                artist: "Orquesta de Cuerdas Proviweb",
                audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
                coverUrl: "https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&auto=format&fit=crop&q=60",
                genre: "Sinfónica",
                duration: 380,
                plays: 32900
            )
        ]

        // Mock Books
        books = [
            BookModel(
                id: "book_1",
                title: "Suzuki Violin School - Vol. 1",
                author: "Shinichi Suzuki",
                category: "Método Suzuki",
                coverUrl: "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=500&auto=format&fit=crop&q=60"
            ),
            BookModel(
                id: "book_2",
                title: "Kreutzer 42 Estudios o Caprichos para Violín",
                author: "Rodolphe Kreutzer",
                category: "Estudios Técnicos",
                coverUrl: "https://images.unsplash.com/photo-1512820790803-83ca734da794?w=500&auto=format&fit=crop&q=60"
            )
        ]

        // Mock Verified Entities
        verifiedEntities = [
            UserModel(
                id: "entity_1",
                name: "Conservatorio Nacional de Música",
                image: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
                location: "CDMX",
                verified: "entity"
            ),
            UserModel(
                id: "entity_2",
                name: "Orquesta Filarmónica de Cámara",
                image: "https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&auto=format&fit=crop&q=60",
                location: "Monterrey",
                verified: "entity"
            ),
            UserModel(
                id: "entity_3",
                name: "Academia de Violín Suzuki",
                image: "https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&auto=format&fit=crop&q=60",
                location: "Bogotá",
                verified: "entity"
            )
        ]

        // Mock Live Sessions
        liveSessions = [
            LiveSessionModel(
                id: "live_1",
                hostId: "user_demo_violin_001",
                hostName: "Israel Violín",
                hostDp: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
                title: "Masterclass: Golpes de Arco y Afinación",
                mode: .practice,
                listenersCount: 42
            ),
            LiveSessionModel(
                id: "live_2",
                hostId: "host_podcast_01",
                hostName: "Podcast: Hablemos de Música",
                hostDp: "https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=500&auto=format&fit=crop&q=60",
                title: "Episodio 18: La vida del músico profesional",
                mode: .podcast,
                listenersCount: 128
            )
        ]
    }

    // MARK: - Sincronización en vivo (Realtime Database, esquema Android)
    /// Lee `Posts`, `Reels` y `Users/{uid}` con el MISMO esquema que la app Android,
    /// de modo que ambas plataformas ven y escriben datos idénticos.
    public func startLiveDatabaseSync() {
        #if canImport(FirebaseDatabase)
        stopLiveDatabaseSync()

        let root = Database.database().reference()

        // 1) Feed de publicaciones (últimas 50, mismo orden por clave que HomeFragment.java)
        let postsQuery = root.child("Posts").queryOrderedByKey().queryLimited(toLast: 50)
        let postsHandle = postsQuery.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                self?.applyPostsSnapshot(snapshot)
            }
        }
        syncObservers.append((handle: postsHandle, remove: { postsQuery.removeObserver(withHandle: postsHandle) }))

        // 2) Reels (mismo nodo que PostUploadService.java / AdapterReel.java)
        let reelsQuery = root.child("Reels").queryOrderedByKey().queryLimited(toLast: 30)
        let reelsHandle = reelsQuery.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                self?.applyReelsSnapshot(snapshot)
            }
        }
        syncObservers.append((handle: reelsHandle, remove: { reelsQuery.removeObserver(withHandle: reelsHandle) }))

        // 3) Catálogo de canciones, biblioteca de partituras y entidades verificadas.
        //    Solo con sesión real (nunca en demo): sin sesión se conserva el seed local.
        if canWriteToCloud {
            // 3a) Canciones (nodo `Songs`, esquema de MusicUploadService.java en Android)
            let songsQuery = root.child("Songs").queryOrderedByKey().queryLimited(toLast: 100)
            let songsHandle = songsQuery.observe(.value) { [weak self] snapshot in
                Task { @MainActor in
                    self?.applySongsSnapshot(snapshot)
                }
            }
            syncObservers.append((handle: songsHandle, remove: { songsQuery.removeObserver(withHandle: songsHandle) }))

            // 3b) Libros / partituras (nodo `books`, igual que ArchiveActivity.java)
            let booksQuery = root.child("books").queryOrderedByKey().queryLimited(toLast: 60)
            let booksHandle = booksQuery.observe(.value) { [weak self] snapshot in
                Task { @MainActor in
                    self?.applyBooksSnapshot(snapshot)
                }
            }
            syncObservers.append((handle: booksHandle, remove: { booksQuery.removeObserver(withHandle: booksHandle) }))

            // 3c) Entidades verificadas (lista "Entidades" de MainFragment.java)
            observeVerifiedEntities(root: root)
        }

        // 4) Perfil del usuario actual
        if !isDemoMode, let uid = realUid {
            fetchCurrentUser(uid: uid)
        }
        #endif
    }

    public func stopLiveDatabaseSync() {
        #if canImport(FirebaseDatabase)
        for observer in syncObservers {
            observer.remove()
        }
        syncObservers.removeAll()
        for (_, observer) in aplausosObservers {
            observer.remove()
        }
        aplausosObservers.removeAll()
        currentUserObserver?.remove()
        currentUserObserver = nil
        verifiedEntitiesFallback?.remove()
        verifiedEntitiesFallback = nil
        #endif
    }

    // MARK: - Parsing de publicaciones
    private func applyPostsSnapshot(_ snapshot: Any?) {
        #if canImport(FirebaseDatabase)
        guard let snapshot = snapshot as? DataSnapshot else { return }
        guard let children = snapshot.children.allObjects as? [DataSnapshot] else { return }

        var remote: [PostModel] = []
        for child in children {
            guard let dict = child.value as? [String: Any] else { continue }
            let post = FirebaseService.postModel(key: child.key, dict: dict)
            remote.append(post)
            fetchAuthorIfNeeded(uid: post.uid)
        }

        // Conserva el seed local si la base está vacía o inaccesible (modo demo/offline).
        guard !remote.isEmpty else { return }

        remote.sort { (Double($0.pTime ?? "0") ?? 0) > (Double($1.pTime ?? "0") ?? 0) }
        posts = remote
        attachAplausosObservers(for: remote.map { $0.id })
        applyAuthors()
        #endif
    }

    private func applyReelsSnapshot(_ snapshot: Any?) {
        #if canImport(FirebaseDatabase)
        guard let snapshot = snapshot as? DataSnapshot else { return }
        guard let children = snapshot.children.allObjects as? [DataSnapshot] else { return }

        var remote: [ReelModel] = []
        for child in children {
            guard let dict = child.value as? [String: Any] else { continue }
            let uid = FirebaseService.nonEmpty(dict["id"]) ?? FirebaseService.nonEmpty(dict["userId"]) ?? ""
            fetchAuthorIfNeeded(uid: uid)
            let author = authorCache[uid]
            let reel = ReelModel(
                id: child.key,
                reelId: FirebaseService.nonEmpty(dict["pId"]) ?? child.key,
                videoUri: FirebaseService.nonEmpty(dict["video"]) ?? FirebaseService.nonEmpty(dict["vine"]) ?? "",
                thumbnail: FirebaseService.nonEmpty(dict["thumbnail"]) ?? FirebaseService.nonEmpty(dict["meme"]) ?? FirebaseService.nonEmpty(dict["cover"]),
                caption: FirebaseService.nonEmpty(dict["text"]),
                soundTitle: FirebaseService.nonEmpty(dict["audioTitle"]) ?? "Sonido original",
                soundAuthor: author?.name ?? FirebaseService.nonEmpty(dict["authorName"]),
                soundUri: FirebaseService.nonEmpty(dict["audio"]),
                authorId: uid,
                authorName: author?.name,
                authorDp: author?.image,
                likesCount: FirebaseService.intValue(dict["likes"]) ?? 0,
                commentsCount: FirebaseService.intValue(dict["commentCount"]) ?? 0,
                viewsCount: FirebaseService.intValue(dict["views"]),
                timestamp: FirebaseService.nonEmpty(dict["pTime"])
            )
            remote.append(reel)
        }

        guard !remote.isEmpty else { return }
        remote.sort { (Double($0.timestamp ?? "0") ?? 0) > (Double($1.timestamp ?? "0") ?? 0) }
        reels = remote
        #endif
    }

    // MARK: - Parsing de catálogos (canciones, partituras y entidades verificadas)
    /// Sustituye `songs` por el contenido real de `Songs/{songId}` (esquema Android).
    /// En vivo puro: el seed local solo vive mientras no hay sesión (ver `startLiveDatabaseSync`).
    private func applySongsSnapshot(_ snapshot: Any?) {
        #if canImport(FirebaseDatabase)
        guard let snapshot = snapshot as? DataSnapshot else { return }
        guard let children = snapshot.children.allObjects as? [DataSnapshot] else { return }

        var remote: [SongModel] = []
        for child in children {
            guard let dict = child.value as? [String: Any] else { continue }
            remote.append(FirebaseService.songModel(uid: child.key, dict: dict))
        }

        // Mismo criterio que MusicExploreActivity.java: promocionadas vigentes arriba,
        // después por número de reproducciones y, por último, las más recientes.
        let nowMs = Date().timeIntervalSince1970 * 1000
        remote.sort { lhs, rhs in
            let lhsPromoted = (lhs.isPromoted ?? false) && (lhs.adExpiry ?? 0) > nowMs
            let rhsPromoted = (rhs.isPromoted ?? false) && (rhs.adExpiry ?? 0) > nowMs
            if lhsPromoted != rhsPromoted { return lhsPromoted }
            if lhs.totalPlays != rhs.totalPlays { return lhs.totalPlays > rhs.totalPlays }
            return (Double(lhs.timestamp ?? "0") ?? 0) > (Double(rhs.timestamp ?? "0") ?? 0)
        }
        songs = remote
        #endif
    }

    /// Sustituye `books` por el contenido real del nodo `books` (ArchiveActivity.java).
    private func applyBooksSnapshot(_ snapshot: Any?) {
        #if canImport(FirebaseDatabase)
        guard let snapshot = snapshot as? DataSnapshot else { return }
        guard let children = snapshot.children.allObjects as? [DataSnapshot] else { return }

        var remote: [BookModel] = []
        for child in children {
            guard let dict = child.value as? [String: Any] else { continue }
            remote.append(FirebaseService.bookModel(key: child.key, dict: dict))
        }

        remote.sort { ($0.timestamp ?? 0) > ($1.timestamp ?? 0) }
        books = remote
        #endif
    }

    /// Observa `Users` con `verified == "yes"` (mismo filtro que MainFragment.java:98-108)
    /// para la lista "Entidades" del marketplace.
    /// Decisión: se usa una consulta dedicada `orderByChild("verified").equalTo("yes")`
    /// en lugar de reutilizar `currentUserObserver` (que solo mira `Users/{uid}` propio y
    /// no da la lista) y en lugar de leer `Users` completo (mucho más tráfico).
    #if canImport(FirebaseDatabase)
    private func observeVerifiedEntities(root: DatabaseReference) {
        let query = root.child("Users").queryOrdered(byChild: "verified").queryEqual(toValue: "yes")
        let handle = query.observe(.value, with: { [weak self] snapshot in
            Task { @MainActor in
                self?.applyVerifiedEntitiesSnapshot(snapshot)
            }
        }, withCancel: { [weak self] _ in
            // Sin índice sobre `verified` RTDB puede cancelar la consulta:
            // respaldo con los últimos 400 usuarios y el mismo filtro de Android.
            Task { @MainActor in
                self?.startVerifiedEntitiesFallback(root: root)
            }
        })
        syncObservers.append((handle: handle, remove: { query.removeObserver(withHandle: handle) }))
    }

    private func startVerifiedEntitiesFallback(root: DatabaseReference) {
        guard verifiedEntitiesFallback == nil else { return }
        let query = root.child("Users").queryOrderedByKey().queryLimited(toLast: 400)
        let handle = query.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                self?.applyVerifiedEntitiesSnapshot(snapshot)
            }
        }
        verifiedEntitiesFallback = (handle: handle, remove: { query.removeObserver(withHandle: handle) })
    }
    #endif

    private func applyVerifiedEntitiesSnapshot(_ snapshot: Any?) {
        #if canImport(FirebaseDatabase)
        guard let snapshot = snapshot as? DataSnapshot else { return }
        guard let children = snapshot.children.allObjects as? [DataSnapshot] else { return }

        var remote: [UserModel] = []
        for child in children {
            guard let dict = child.value as? [String: Any] else { continue }
            // Android exige `name` + `verified == "yes"` y excluye la cuenta propia.
            guard FirebaseService.nonEmpty(dict["name"]) != nil else { continue }
            guard FirebaseService.nonEmpty(dict["verified"])?.lowercased() == "yes" else { continue }
            if child.key == currentUserId || child.key == realUid { continue }
            remote.append(userModel(uid: child.key, dict: dict))
        }

        guard !remote.isEmpty else { return }
        remote.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        verifiedEntities = remote
        #endif
    }

    /// Convierte un nodo `Songs/{songId}` (esquema de MusicUploadService.java) al modelo iOS.
    static func songModel(uid: String, dict: [String: Any]) -> SongModel {
        // Android guarda `duration` como texto ("2:15") y `durationMs` en milisegundos.
        let durationMs = FirebaseService.intValue(dict["durationMs"])
        let durationText = FirebaseService.nonEmpty(dict["duration"])
        let seconds: Double
        if let ms = durationMs, ms > 0 {
            seconds = Double(ms) / 1000.0
        } else if let parsed = FirebaseService.seconds(fromTimeText: durationText) {
            seconds = parsed
        } else {
            seconds = 0
        }

        let playCount = FirebaseService.intValue(dict["playCount"]) ?? 0
        let status = (FirebaseService.nonEmpty(dict["verificationStatus"]) ?? "pending").lowercased()
        let downloadUrl = FirebaseService.nonEmpty(dict["downloadUrl"])

        return SongModel(
            id: uid,
            songId: FirebaseService.nonEmpty(dict["songId"]) ?? FirebaseService.nonEmpty(dict["id"]) ?? uid,
            title: FirebaseService.nonEmpty(dict["title"]) ?? "Sin título",
            artist: FirebaseService.nonEmpty(dict["artist"]) ?? "Artista PROVIWEB",
            artistId: FirebaseService.nonEmpty(dict["artistId"]) ?? FirebaseService.nonEmpty(dict["pId"]),
            audioUrl: FirebaseService.nonEmpty(dict["audioUrl"]) ?? "",
            coverUrl: FirebaseService.nonEmpty(dict["coverUrl"]),
            genre: FirebaseService.nonEmpty(dict["genre"]),
            duration: seconds,
            plays: playCount,
            isVerifiedAuthor: status == "approved",
            isPendingReview: status == "pending",
            timestamp: FirebaseService.nonEmpty(dict["timestamp"])
                ?? FirebaseService.nonEmpty(dict["submittedForReviewAt"]),
            ownerId: FirebaseService.nonEmpty(dict["pId"]),
            album: FirebaseService.nonEmpty(dict["album"]),
            durationText: durationText,
            durationMs: durationMs,
            playCount: playCount,
            likeCount: FirebaseService.intValue(dict["likeCount"]) ?? 0,
            commentCount: FirebaseService.intValue(dict["commentCount"]) ?? 0,
            verificationStatus: status,
            rejectionReason: FirebaseService.nonEmpty(dict["rejectionReason"]),
            privacy: FirebaseService.nonEmpty(dict["privacy"]),
            bpm: FirebaseService.intValue(dict["bpm"]),
            musicalKey: FirebaseService.nonEmpty(dict["key"]),
            instruments: FirebaseService.firstString(dict["instruments"]),
            isPromoted: FirebaseService.coerceBool(dict["isPromoted"]) ?? false,
            adExpiry: FirebaseService.doubleValue(dict["adExpiry"]),
            lyrics: FirebaseService.nonEmpty(dict["lyrics"]),
            isDownloadable: FirebaseService.coerceBool(dict["isDownloadable"])
                ?? (downloadUrl != nil),
            downloadUrl: downloadUrl,
            isPodcast: FirebaseService.coerceBool(dict["isPodcast"]) ?? false,
            podcastCategory: FirebaseService.nonEmpty(dict["podcastCategory"]),
            hostBio: FirebaseService.nonEmpty(dict["hostBio"]),
            hostPhoto: FirebaseService.nonEmpty(dict["hostPhoto"]),
            sheetMusicId: FirebaseService.nonEmpty(dict["sheetMusicId"]),
            sheetMusicTitle: FirebaseService.nonEmpty(dict["sheetMusicTitle"]),
            sheetMusicUrl: FirebaseService.nonEmpty(dict["sheetMusicUrl"]),
            sheetMusicCover: FirebaseService.nonEmpty(dict["sheetMusicCover"]),
            sheetMusicCategory: FirebaseService.nonEmpty(dict["sheetMusicCategory"])
        )
    }

    /// Convierte un nodo `books/{key}` (esquema de ArchiveActivity.java) al modelo iOS.
    static func bookModel(key: String, dict: [String: Any]) -> BookModel {
        BookModel(
            id: key,
            bookId: FirebaseService.nonEmpty(dict["bookId"]) ?? key,
            title: FirebaseService.nonEmpty(dict["title"]) ?? "Partitura sin título",
            // Los libros de Android no traen compositor: usamos `author` si existe
            // y, si no, el subidor (los títulos suelen traer "Obra (Compositor)").
            author: FirebaseService.nonEmpty(dict["author"])
                ?? FirebaseService.nonEmpty(dict["uploaderName"])
                ?? "Comunidad PROVIWEB",
            category: FirebaseService.nonEmpty(dict["category"]) ?? "Partituras",
            pdfUrl: FirebaseService.nonEmpty(dict["content"]) ?? FirebaseService.nonEmpty(dict["pdfUrl"]),
            coverUrl: FirebaseService.nonEmpty(dict["cover"]) ?? FirebaseService.nonEmpty(dict["coverUrl"]),
            views: FirebaseService.intValue(dict["views"]) ?? 0,
            bookType: FirebaseService.nonEmpty(dict["type"]),
            isPublic: FirebaseService.coerceBool(dict["isPublic"]) ?? true,
            uploaderId: FirebaseService.nonEmpty(dict["uploaderId"]),
            uploaderName: FirebaseService.nonEmpty(dict["uploaderName"]),
            uploaderPhoto: FirebaseService.nonEmpty(dict["uploaderPhoto"]),
            timestamp: FirebaseService.doubleValue(dict["timestamp"]),
            transcriptionXml: FirebaseService.nonEmpty(dict["transcriptionXml"]),
            transcriptionMidiCsv: FirebaseService.nonEmpty(dict["transcriptionMidiCsv"]),
            estimatedBpm: FirebaseService.intValue(dict["estimatedBpm"]),
            capturedNotes: FirebaseService.intValue(dict["capturedNotes"])
        )
    }

    /// Convierte un nodo `Posts/{key}` (esquema Android) al modelo iOS.
    static func postModel(key: String, dict: [String: Any]) -> PostModel {
        let type = (FirebaseService.nonEmpty(dict["type"]) ?? "").lowercased()
        let meme = FirebaseService.nonEmpty(dict["meme"])
        let vine = FirebaseService.nonEmpty(dict["vine"])
        let videoField = FirebaseService.nonEmpty(dict["video"])
        let audioField = FirebaseService.nonEmpty(dict["audio"])
        let authorUid = FirebaseService.nonEmpty(dict["id"])
            ?? FirebaseService.nonEmpty(dict["userId"])
            ?? FirebaseService.nonEmpty(dict["uid"])
            ?? ""

        var image: String? = FirebaseService.nonEmpty(dict["pImage"])
        var video: String? = FirebaseService.nonEmpty(dict["pVideo"])
        var audio: String? = FirebaseService.nonEmpty(dict["pAudio"])

        switch type {
        case "video":
            video = vine ?? videoField ?? video
            if let meme = meme { image = meme }
        case "audio":
            audio = audioField ?? meme ?? audio
        case "image":
            image = meme ?? FirebaseService.firstString(dict["memes"]) ?? image
        case "text":
            image = nil
            video = nil
            audio = nil
        case "sheet_music":
            image = meme ?? image
        case "serie":
            image = meme ?? image
            video = vine ?? video
        default:
            // Compatibilidad con nodos escritos por la propia app iOS / legado.
            if let vine = vine, vine != "noVideo", video == nil { video = vine }
            if let meme = meme, meme != "noImage", image == nil { image = meme }
        }

        let author = FirebaseService.cachedAuthorStatic(authorUid)

        return PostModel(
            id: key,
            pId: FirebaseService.nonEmpty(dict["pId"]) ?? key,
            uid: authorUid,
            uName: FirebaseService.nonEmpty(dict["uName"]) ?? author?.name,
            uEmail: FirebaseService.nonEmpty(dict["uEmail"]) ?? author?.email,
            uDp: FirebaseService.nonEmpty(dict["uDp"]) ?? author?.image,
            pTitle: FirebaseService.nonEmpty(dict["pTitle"]),
            pDescr: FirebaseService.nonEmpty(dict["pDescr"]) ?? FirebaseService.nonEmpty(dict["text"]),
            pImage: image,
            pVideo: video,
            pAudio: audio,
            pTime: FirebaseService.nonEmpty(dict["pTime"]),
            pLikes: FirebaseService.countString(dict["pLikes"]),
            pComments: FirebaseService.countString(dict["commentCount"]) ?? FirebaseService.countString(dict["pComments"]),
            pShare: FirebaseService.countString(dict["pShares"]) ?? FirebaseService.countString(dict["pShare"]),
            feeling: FirebaseService.nonEmpty(dict["feeling"]),
            location: FirebaseService.nonEmpty(dict["location"]),
            isPromoted: (dict["isPromoted"] as? Bool) ?? false,
            likedByCurrentUser: false,
            savedByCurrentUser: false
        )
    }

    // MARK: - Escritura compatible con Android
    public func publishPostToCloud(post: PostModel) {
        #if canImport(FirebaseDatabase)
        guard !isDemoMode, isRealAuthActive else { return }

        let root = Database.database().reference()
        let key = post.pId ?? post.id

        // Estructura idéntica a PostUploadService.java (Android)
        var dict: [String: Any] = [
            "id": post.uid.isEmpty ? currentUserId : post.uid,
            "pId": key,
            "text": post.pDescr ?? post.pTitle ?? "",
            "pTime": post.pTime ?? "\(Int(Date().timeIntervalSince1970 * 1000))",
            "pLikes": "0",
            "pComments": "0",
            "commentCount": 0,
            "privacy": "Everyone",
            "feeling": post.feeling ?? "",
            "location": post.location ?? ""
        ]

        if let audio = post.pAudio, !audio.isEmpty {
            dict["type"] = "audio"
            dict["meme"] = audio
            dict["audio"] = audio
            dict["vine"] = "noVideo"
        } else if let video = post.pVideo, !video.isEmpty {
            dict["type"] = "video"
            dict["vine"] = video
            dict["meme"] = post.pImage ?? "noImage"
        } else if let image = post.pImage, !image.isEmpty {
            dict["type"] = "image"
            dict["meme"] = image
            dict["memes"] = [image]
        } else {
            dict["type"] = "text"
            dict["meme"] = "noImage"
            dict["vine"] = "noVideo"
        }

        root.child("Posts").child(key).setValue(dict) { [weak self] error, _ in
            Task { @MainActor in
                guard let self = self, let error = error else { return }
                self.authError = self.friendlyMessage(for: error)
            }
        }
        #endif
    }

    // MARK: - Moderación de canciones (nodo `Songs`, esquema Android)
    /// Aprueba una canción: `Songs/{songId}/verificationStatus = "approved"`
    /// (mismo valor que ModelSong.java → `isVerified()`).
    public func approveSong(songId: String) {
        applySongModeration(songId: songId, values: ["verificationStatus": "approved"])
    }

    /// Rechaza una canción guardando también `rejectionReason`
    /// (lo leen AdapterSong.java / AdapterSongFeed.java / SongPlayerFullActivity.java).
    public func rejectSong(
        songId: String,
        reason: String = "Revisión manual de PROVIWEB: no se acreditaron los derechos de la grabación."
    ) {
        applySongModeration(songId: songId, values: [
            "verificationStatus": "rejected",
            "rejectionReason": reason
        ])
    }

    private func applySongModeration(songId: String, values: [String: Any]) {
        guard !songId.isEmpty else { return }

        // Actualización optimista local: la cola de revisión cambia al instante
        // (y en modo demo es el único efecto, sin red).
        if let index = songs.firstIndex(where: { $0.id == songId || $0.songId == songId }) {
            songs[index].verificationStatus = FirebaseService.stringValue(values["verificationStatus"])
            if let reason = FirebaseService.nonEmpty(values["rejectionReason"]) {
                songs[index].rejectionReason = reason
            }
            songs[index].isPendingReview = songs[index].normalizedVerificationStatus == "pending"
            songs[index].isVerifiedAuthor = songs[index].normalizedVerificationStatus == "approved"
        }

        #if canImport(FirebaseDatabase)
        guard canWriteToCloud else { return }
        Database.database().reference().child("Songs").child(songId).updateChildValues(values)
        #endif
    }

    // MARK: - Reproducciones (contador `playCount` de Android)
    /// Incrementa `playCount` al reproducir: optimista en local (también en demo)
    /// y, con sesión real, lectura + 1 con `setValue` (mismo patrón que `addComment`).
    /// Nunca se usa `runTransaction`.
    public func registerSongPlay(songId: String) {
        guard !songId.isEmpty else { return }

        if let index = songs.firstIndex(where: { $0.id == songId || $0.songId == songId }) {
            let current = songs[index].totalPlays
            songs[index].playCount = current + 1
            songs[index].plays = current + 1
        }

        #if canImport(FirebaseDatabase)
        guard canWriteToCloud else { return }
        let ref = Database.database().reference().child("Songs").child(songId).child("playCount")
        ref.observeSingleEvent(of: .value) { snapshot in
            let current: Int
            if let number = snapshot.value as? NSNumber {
                current = number.intValue
            } else if let text = snapshot.value as? String, let parsed = Int(text) {
                current = parsed
            } else {
                current = 0
            }
            ref.setValue(current + 1)
        }
        #endif
    }

    // MARK: - Contadores reales del panel ADMIN
    /// Dos lecturas puntuales (baratas): `ReportPost` (denuncias de AdapterPost.java)
    /// y `Verification` con `status == "pending"` (solicitudes de VerifiUserActivity.java).
    /// En modo demo no se leen y se conservan los valores locales de ejemplo.
    public func refreshAdminCounters() {
        #if canImport(FirebaseDatabase)
        guard canWriteToCloud else { return }
        let root = Database.database().reference()

        root.child("ReportPost").observeSingleEvent(of: .value) { [weak self] snapshot in
            Task { @MainActor in
                self?.adminReportedPostsCount = Int(snapshot.childrenCount)
            }
        }

        root.child("Verification").observeSingleEvent(of: .value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var pending = 0
                if let children = snapshot.children.allObjects as? [DataSnapshot] {
                    for child in children {
                        let status = (FirebaseService.nonEmpty(child.childSnapshot(forPath: "status").value) ?? "pending")
                            .lowercased()
                        if status == "pending" { pending += 1 }
                    }
                }
                self.adminPendingVerificationsCount = pending
            }
        }
        #endif
    }

    // MARK: - Autores (nombre / foto desde `Users/{uid}`)
    private func fetchAuthorIfNeeded(uid: String) {
        guard !uid.isEmpty, authorCache[uid] == nil, !pendingAuthorFetches.contains(uid) else { return }
        #if canImport(FirebaseDatabase)
        pendingAuthorFetches.insert(uid)
        Database.database().reference().child("Users").child(uid).observeSingleEvent(of: .value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                self.pendingAuthorFetches.remove(uid)
                if let dict = snapshot.value as? [String: Any] {
                    self.authorCache[uid] = self.userModel(uid: uid, dict: dict)
                    self.applyAuthors()
                }
            }
        }
        #endif
    }

    private func applyAuthors() {
        guard !authorCache.isEmpty else { return }
        var changed = false
        for index in posts.indices where posts[index].uName == nil || posts[index].uDp == nil {
            let uid = posts[index].uid
            guard let author = authorCache[uid] else { continue }
            if posts[index].uName == nil, !author.name.isEmpty {
                posts[index].uName = author.name
                changed = true
            }
            if posts[index].uDp == nil, let image = author.image {
                posts[index].uDp = image
                changed = true
            }
        }
        for index in reels.indices where reels[index].authorName == nil {
            let uid = reels[index].authorId
            guard let author = authorCache[uid] else { continue }
            reels[index].authorName = author.name
            reels[index].authorDp = author.image
            changed = true
        }
        if changed {
            objectWillChange.send()
        }
    }

    private static func cachedAuthorStatic(_ uid: String) -> UserModel? {
        guard !uid.isEmpty else { return nil }
        return FirebaseService.shared.authorCache[uid]
    }

    // MARK: - Observadores de aplausos por publicación
    private func attachAplausosObservers(for postIds: [String]) {
        #if canImport(FirebaseDatabase)
        let wanted = Set(postIds)
        for (postId, observer) in aplausosObservers where !wanted.contains(postId) {
            observer.remove()
            aplausosObservers.removeValue(forKey: postId)
            aplausosCount.removeValue(forKey: postId)
            aplausosLiked.removeValue(forKey: postId)
        }

        for postId in postIds where aplausosObservers[postId] == nil {
            let ref = Database.database().reference().child("Aplausos").child(postId)
            let handle = ref.observe(.value) { [weak self] snapshot in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.aplausosCount[postId] = Int(snapshot.childrenCount)
                    self.aplausosLiked[postId] = snapshot.hasChild(self.currentUserId)
                    self.refreshSocialCounters(postId: postId)
                }
            }
            aplausosObservers[postId] = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
        }
        #endif
    }

    private func refreshSocialCounters(postId: String) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        if let count = aplausosCount[postId] {
            posts[index].pLikes = "\(count)"
        }
        if let liked = aplausosLiked[postId] {
            posts[index].likedByCurrentUser = liked
        }
    }

    // MARK: - Helpers de conversión (Firebase entrega NSNumber / String / Bool mezclados)
    static func nonEmpty(_ value: Any?) -> String? {
        guard let text = stringValue(value) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "noImage" || trimmed == "noVideo" || trimmed == "null" {
            return nil
        }
        return trimmed
    }

    static func stringValue(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        if let bool = value as? Bool { return bool ? "1" : "0" }
        return nil
    }

    static func countString(_ value: Any?) -> String? {
        guard let text = stringValue(value) else { return nil }
        return text
    }

    static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) }
        if let integer = value as? Int { return integer }
        if let double = value as? Double { return Int(double) }
        return nil
    }

    static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text.trimmingCharacters(in: .whitespaces)) }
        if let integer = value as? Int { return Double(integer) }
        if let double = value as? Double { return double }
        return nil
    }

    /// Normaliza booleanos mezclados (Bool de Swift, NSNumber de RTDB, "yes"/"no" de Android).
    static func coerceBool(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let text = value as? String {
            switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1", "y": return true
            case "false", "no", "0", "n": return false
            default: return nil
            }
        }
        return nil
    }

    /// Convierte la duración que escribe Android ("2:15" / "1:02:03") a segundos.
    static func seconds(fromTimeText text: String?) -> Double? {
        guard let text = text else { return nil }
        let parts = text.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty, parts.count <= 3 else { return nil }
        var total: Double = 0
        for part in parts {
            guard let value = Double(part) else { return nil }
            total = total * 60 + value
        }
        return total
    }

    static func firstString(_ value: Any?) -> String? {
        if let list = value as? [Any] {
            for item in list {
                if let text = nonEmpty(item) { return text }
            }
            return nil
        }
        return nonEmpty(value)
    }

    static func pushKey() -> String? {
        #if canImport(FirebaseDatabase)
        return Database.database().reference().child("Posts").push().key
        #else
        return nil
        #endif
    }
}
