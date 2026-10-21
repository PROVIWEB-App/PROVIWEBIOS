import Foundation
import SwiftUI
import Combine
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Verification Service (nodos RTDB reales de Android)
//
// Réplica de los mapas de `menu/*.java`:
//   VerifiUserActivity.java:166        → Verification/{uid}
//   ProfesorVerificationActivity.java:431 → VerificationProfesor/{uid}
//   StudentVerifiActivity.java:242     → VerificationStudents/{uid}
//   EntidadVerifActivity.java:387      → VerificationEntidad/{uid}
// Escritura en cada tier: `{ name, username, email, vId (String), uID, status: "pending",
// timestamp (Long de System.currentTimeMillis()), ...campos propios del tier }`.
@MainActor
public final class VerificationService: ObservableObject {
    public static let shared = VerificationService()

    /// `status` del nodo de verificación del tier seleccionado (pending/approved/rejected).
    @Published public private(set) var currentStatus: String? = nil
    /// `Users/{uid}/verified == "yes"` (VerifiUserActivity.isAlreadyVerified).
    @Published public private(set) var isAlreadyVerified: Bool = false

    /// `true` con sesión real (no demo).
    public var usesLiveVerification: Bool { FirebaseService.shared.canWriteToCloud }

    private var lastTier: VerificationRequestView.VerificationTier? = nil

    private init() {}

    /// Nodo RTDB que corresponde a cada tipo de insignia.
    public static func nodePath(for tier: VerificationRequestView.VerificationTier) -> String {
        switch tier {
        case .musician: return "Verification"
        case .teacher: return "VerificationProfesor"
        case .student: return "VerificationStudents"
        case .entity: return "VerificationEntidad"
        }
    }

    /// Etiqueta en español del estado actual (nil si no hay solicitud registrada).
    public var statusLabel: String? {
        if isAlreadyVerified { return "Perfil verificado ✓" }
        switch (currentStatus ?? "").lowercased() {
        case "pending": return "Solicitud en revisión ⏳"
        case "approved": return "Solicitud aprobada ✓"
        case "rejected": return "Solicitud rechazada ✗"
        default: return nil
        }
    }

    public var statusIsRejected: Bool {
        !isAlreadyVerified && (currentStatus ?? "").lowercased() == "rejected"
    }

    public var statusIsApproved: Bool {
        isAlreadyVerified || (currentStatus ?? "").lowercased() == "approved"
    }

    /// Lectura del estado actual (nodo de verificación + `Users/{uid}/verified`).
    public func refreshStatus(for tier: VerificationRequestView.VerificationTier) {
        currentStatus = nil
        isAlreadyVerified = false
        lastTier = tier
        guard let uid = FirebaseService.shared.authenticatedUid else { return }
        #if canImport(FirebaseDatabase)
        Database.database().reference().child("Users").child(uid).child("verified")
            .observeSingleEvent(of: .value) { [weak self] snapshot in
                Task { @MainActor in
                    guard let self = self, self.lastTier == tier else { return }
                    self.isAlreadyVerified = VerificationService.string(snapshot.value) == "yes"
                }
            }

        let node = VerificationService.nodePath(for: tier)
        Database.database().reference().child(node).child(uid)
            .observeSingleEvent(of: .value) { [weak self] snapshot in
                Task { @MainActor in
                    guard let self = self, self.lastTier == tier else { return }
                    guard snapshot.exists() else { return }
                    let dict = snapshot.value as? [String: Any] ?? [:]
                    let status = VerificationService.string(dict["status"]) ?? "pending"
                    self.currentStatus = status
                }
            }
        #endif
    }

    // MARK: - Envío de la solicitud (lectura de `Users` + setValue del nodo del tier)
    public func submit(
        tier: VerificationRequestView.VerificationTier,
        institution: String,
        officialIdNumber: String,
        credentialsURL: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        #if canImport(FirebaseDatabase)
        guard let uid = FirebaseService.shared.authenticatedUid else {
            completion(.failure(ClassesServiceError.noSession))
            return
        }
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let stamp = "\(millis)"
        let user = FirebaseService.shared.currentUser
        var map: [String: Any] = [
            "name": user?.name ?? "",
            "username": user?.username ?? "",
            "email": user?.email ?? "",
            "vId": stamp,
            "uID": uid,
            // Android escribe `timestamp` como Long (System.currentTimeMillis()).
            "timestamp": millis,
            "status": "pending",
            // Campos propios de la vista iOS (Android no los pide; se conservan junto a los suyos).
            "institution": institution,
            "officialIdNumber": officialIdNumber,
            "credentialsUrl": credentialsURL
        ]

        // Campos exactos de cada Activity de Android (los documentos/selfies se suben allí;
        // aquí sólo se replican las claves con los datos disponibles en iOS).
        switch tier {
        case .musician:
            // VerifiUserActivity: linkTiktok, linkInstagram, linkFacebook
            map["linkTiktok"] = ""
            map["linkInstagram"] = ""
            map["linkFacebook"] = ""
        case .teacher:
            // ProfesorVerificationActivity
            map["frontIdUrl"] = ""
            map["backIdUrl"] = ""
            map["curriculumUrl"] = credentialsURL
            map["paypalEmail"] = ""
            map["specialty"] = institution
            map["experience"] = ""
            map["basePrice"] = ""
            map["bio"] = ""
            map["videoUrl"] = ""
        case .student:
            // StudentVerifiActivity
            map["prof"] = ""
            map["profName"] = institution
        case .entity:
            // EntidadVerifActivity
            map["frontIdUrl"] = ""
            map["backIdUrl"] = ""
            map["documentUrl"] = credentialsURL
            map["videoUrl"] = ""
            map["type"] = institution
        }

        let node = VerificationService.nodePath(for: tier)
        // Copia inmutable: evita referenciar una `var` capturada dentro de la tarea.
        let payload: [String: Any] = map
        Task { @MainActor in
            do {
                try await ClassesService.shared.writeValue(payload, path: [node, uid])

                // Profesor: Android replica `specialty` en Users/{uid}
                // (ProfesorVerificationActivity.java:438-443). El resto de campos de perfil
                // (paypalEmail/experience/basePrice/description) no se escriben aquí para no
                // sobrescribirlos con valores vacíos.
                if tier == .teacher, !institution.isEmpty {
                    try await ClassesService.shared.updateChildren(["specialty": institution], path: ["Users", uid])
                }

                self.refreshStatus(for: tier)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
        #else
        completion(.failure(ClassesServiceError.firebaseUnavailable))
        #endif
    }

    private static func string(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }
}

// MARK: - Multi-Tier Verification Request View (Student, Teacher, Entity)
public struct VerificationRequestView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @ObservedObject private var verification = VerificationService.shared
    @Environment(\.presentationMode) var presentationMode
    
    public enum VerificationTier: String, CaseIterable {
        case musician = "Músico Profesional"
        case teacher = "Profesor / Maestro"
        case student = "Estudiante de Música"
        case entity = "Entidad / Conservatorio / Mariachi"
    }
    
    @State private var selectedTier: VerificationTier = .musician
    @State private var institutionName: String = ""
    @State private var credentialsUrl: String = ""
    @State private var officialIdNumber: String = ""
    @State private var isSending: Bool = false
    @State private var isSentAlertPresented: Bool = false
    @State private var isErrorAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Tipo de Insignia de Verificación")) {
                        Picker("Categoría", selection: $selectedTier) {
                            ForEach(VerificationTier.allCases, id: \.self) { tier in
                                Text(tier.rawValue).tag(tier)
                            }
                        }
                    }
                    
                    if let statusLabel = verification.statusLabel {
                        Section(header: Text("Estado de tu Solicitud")) {
                            HStack(spacing: 8) {
                                Image(systemName: verification.statusIsApproved ? "checkmark.seal.fill" : (verification.statusIsRejected ? "xmark.seal.fill" : "clock.fill"))
                                    .foregroundColor(verification.statusIsApproved ? AppColors.success : (verification.statusIsRejected ? AppColors.errorRed : AppColors.primary))
                                Text(statusLabel)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.textPrimary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    
                    Section(header: Text("Datos de Respaldo")) {
                        TextField("Institución, Conservatorio o Agrupación", text: $institutionName)
                        TextField("Número de Cédula o Identificación Oficial", text: $officialIdNumber)
                        TextField("Enlace a Portafolio, Título o Credencial", text: $credentialsUrl)
                    }
                    
                    Section(footer: Text("Los perfiles verificados obtienen mayor visibilidad en el Marketplace, Hub Musical y en la recomendación del Profesor IA.")) {
                        EmptyView()
                    }
                    
                    Section {
                        Button(action: sendRequest) {
                            HStack(spacing: 8) {
                                if isSending {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isSending ? "Enviando…" : "Enviar Solicitud de Verificación")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .disabled(institutionName.isEmpty || officialIdNumber.isEmpty || isSending)
                        .listRowBackground(institutionName.isEmpty || officialIdNumber.isEmpty ? Color.gray : AppColors.primary)
                    }
                }
            }
            .navigationTitle("Verificación de Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
                verification.refreshStatus(for: selectedTier)
            }
            .onChange(of: selectedTier) { tier in
                verification.refreshStatus(for: tier)
            }
            .alert(alertTitle, isPresented: $isSentAlertPresented) {
                Button("Entendido") {
                    if !isErrorAlert {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func sendRequest() {
        guard verification.usesLiveVerification else {
            alertTitle = "Se requiere una cuenta"
            alertMessage = "Para enviar la solicitud de verificación necesitas iniciar sesión con una cuenta real de PROVIWEB. En modo demostración no se escribe en la nube."
            isErrorAlert = true
            isSentAlertPresented = true
            return
        }
        
        isSending = true
        verification.submit(
            tier: selectedTier,
            institution: institutionName.trimmingCharacters(in: .whitespacesAndNewlines),
            officialIdNumber: officialIdNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            credentialsURL: credentialsUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        ) { result in
            isSending = false
            switch result {
            case .success:
                alertTitle = "¡Solicitud Recibida!"
                alertMessage = "El equipo de moderación de PROVIWEB revisará tus credenciales dentro de las próximas 24 a 48 horas."
                isErrorAlert = false
            case .failure(let error):
                alertTitle = "No se pudo enviar la solicitud"
                alertMessage = error.localizedDescription
                isErrorAlert = true
            }
            isSentAlertPresented = true
        }
    }
}
