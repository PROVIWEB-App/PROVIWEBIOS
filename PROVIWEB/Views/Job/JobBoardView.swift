import Foundation
import SwiftUI
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Jobs Service (RTDB esquema exacto de Android: nodo `JobOffers`)
//
// Réplica de CreateJobOfferActivity.executePublish (línea 560+) / ModelJobOffer.java:
//   JobOffers/{id} = { id, publisherId, publisherName, publisherPhoto, verifiedEntity,
//                      title, category, instrumentOrRole, workType, locationType, city, country,
//                      salary: String, salaryCurrency, payFrequency, description,
//                      auditionRepertoire, sheetMusicPdfUrl, imageUrl, urgentSos,
//                      createdTimestamp: long, deadlineTimestamp: long, status: "active",
//                      applicationsCount: Int, internationalConditions, acceptsInternational }
//   JobApplications/{jobId}/{applicantUid} = ModelJobApplication (JobDetailsActivity.java:1683)
//     -> child key = UID del postulante (NO push key), status "pending", timestamp: long millis.
//   HomeFragment.java:2132 lee `JobOffers` completo y filtra `status == "active"` en cliente.
@MainActor
public final class JobsService: ObservableObject {
    public static let shared = JobsService()

    @Published public private(set) var jobs: [JobOfferModel] = []
    /// Vacantes a las que ya se postuló la sesión actual (evita re-incrementar applicationsCount).
    @Published public private(set) var appliedJobIds: Set<String> = []

    private var rawJobs: [String: [String: Any]] = [:]
    private var isStarted = false
    #if canImport(FirebaseDatabase)
    private var jobsObserver: (handle: DatabaseHandle, remove: () -> Void)?
    #endif

    private init() {}

    private var myName: String {
        let name = FirebaseService.shared.currentUser?.name ?? ""
        return name.trimmingCharacters(in: .whitespaces).isEmpty ? "Artista PROVIWEB" : name
    }

    private var myPhoto: String { FirebaseService.shared.currentUser?.image ?? "" }

    public func ensureStarted() {
        guard !isStarted, FirebaseService.shared.canWriteToCloud else { return }
        isStarted = true
        #if canImport(FirebaseDatabase)
        observeJobs()
        #endif
    }

    #if canImport(FirebaseDatabase)
    private func observeJobs() {
        let ref = Database.database().reference().child("JobOffers")
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var next: [String: [String: Any]] = [:]
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    next[snap.key] = dict
                }
                self.rawJobs = next
                self.rebuild()
            }
        }
        jobsObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }
    #endif

    private func rebuild() {
        let mapped: [JobOfferModel] = rawJobs.compactMap { key, dict in
            let status = JobsService.stringValue(dict["status"]) ?? "active"
            // Como HomeFragment.java: filtra activas en cliente.
            guard status == "active" else { return nil }
            return JobsService.parseJob(key: key, dict: dict)
        }
        jobs = mapped.sorted { $0.createdTimestamp > $1.createdTimestamp }
    }

    // MARK: - Parseo (ModelJobOffer.parseFromSnapshot)
    static func parseJob(key: String, dict: [String: Any]) -> JobOfferModel {
        let title = stringValue(dict["title"]) ?? "Vacante musical"
        let publisherName = stringValue(dict["publisherName"]) ?? "Artista PROVIWEB"
        let salary = stringValue(dict["salary"]) ?? ""
        let currency = stringValue(dict["salaryCurrency"]) ?? "USD"
        let payFrequency = stringValue(dict["payFrequency"]) ?? ""
        let created = numberValue(dict["createdTimestamp"]) ?? 0

        var date = ""
        if created > 0 {
            date = "Publicado " + JobsService.shortDate(created)
        } else if !payFrequency.isEmpty {
            date = payFrequency
        }

        return JobOfferModel(
            id: key,
            title: title,
            ensemble: publisherName,
            city: stringValue(dict["city"]) ?? "",
            paymentUSD: JobsService.parseAmount(salary) ?? 0,
            instrument: stringValue(dict["instrumentOrRole"]) ?? "Músico",
            date: date,
            isUrgent: JobsService.coerceBool(dict["urgentSos"]),
            publisherId: stringValue(dict["publisherId"]) ?? stringValue(dict["idUser"]) ?? "",
            publisherPhoto: stringValue(dict["publisherPhoto"]) ?? "",
            verifiedEntity: JobsService.coerceBool(dict["verifiedEntity"])
                || JobsService.coerceBool(dict["isVerifiedEntity"]),
            category: stringValue(dict["category"]) ?? "",
            workType: stringValue(dict["workType"]) ?? "",
            locationType: stringValue(dict["locationType"]) ?? "",
            country: stringValue(dict["country"]) ?? "",
            salary: salary,
            salaryCurrency: currency,
            payFrequency: payFrequency,
            descriptionText: stringValue(dict["description"]) ?? "",
            status: stringValue(dict["status"]) ?? "active",
            createdTimestamp: created,
            applicationsCount: JobsService.numberValue(dict["applicationsCount"]).map { Int($0) } ?? 0,
            acceptsInternational: JobsService.coerceBool(dict["acceptsInternational"]),
            internationalConditions: stringValue(dict["internationalConditions"]) ?? ""
        )
    }

    static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String { return value }
        if let value = raw as? NSNumber { return value.stringValue }
        return nil
    }

    static func numberValue(_ raw: Any?) -> Double? {
        if let value = raw as? NSNumber { return value.doubleValue }
        if let value = raw as? String { return Double(value) }
        return nil
    }

    static func coerceBool(_ raw: Any?) -> Bool {
        if let value = raw as? Bool { return value }
        if let value = raw as? String { return value == "true" || value == "1" }
        if let value = raw as? NSNumber { return value.boolValue }
        return false
    }

    /// Extrae el primer número de textos tipo "$1,200.50 MXN" o "A convenir".
    static func parseAmount(_ text: String) -> Double? {
        var current = ""
        var candidate: String?
        for character in text {
            if character.isNumber {
                current.append(character)
            } else if (character == "." || character == ","), !current.isEmpty {
                current.append(character)
            } else if !current.isEmpty {
                candidate = current
                break
            }
        }
        if candidate == nil, !current.isEmpty { candidate = current }
        guard let raw = candidate else { return nil }
        return Double(raw.replacingOccurrences(of: ",", with: "."))
    }

    static func shortDate(_ millis: Double) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: Date(timeIntervalSince1970: millis / 1000))
    }

    // MARK: - Publicar vacante (CreateJobOfferActivity.executePublish)
    public func postJob(title: String, ensemble: String, payment: String, instrument: String) {
        #if canImport(FirebaseDatabase)
        guard let uid = FirebaseService.shared.authenticatedUid else { return }
        let ref = Database.database().reference().child("JobOffers")
        let key = ref.push().key ?? "\(Int(Date().timeIntervalSince1970 * 1000))"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let user = FirebaseService.shared.currentUser

        // El formulario iOS solo tiene título/ensamble/pago/instrumento:
        // el resto va con defaults razonables (tal cual hace NewAdActivity2.java:153-168).
        let dict: [String: Any] = [
            "id": key,
            "publisherId": uid,
            "publisherName": myName,
            "publisherPhoto": myPhoto,
            "verifiedEntity": user?.isVerified ?? false,
            "title": title,
            "category": "",
            "instrumentOrRole": instrument,
            "workType": "Por Evento",
            "locationType": "Presencial",
            "city": ensemble,
            "country": "",
            "salary": payment,
            "salaryCurrency": "USD",
            "payFrequency": "A convenir",
            "description": "",
            "auditionRepertoire": "",
            "sheetMusicPdfUrl": "",
            "imageUrl": "",
            "urgentSos": false,
            "createdTimestamp": now,
            "deadlineTimestamp": 0,
            "status": "active",
            "applicationsCount": 0,
            "internationalConditions": "",
            "acceptsInternational": false,
            "availableVacancies": 1,
            "acceptedVacancies": 0,
            "vacancyScope": "nacional",
            "rating": 5.0,
            "reviewsCount": 0,
            "positivePercentage": 100
        ]
        ref.child(key).setValue(dict)
        #endif
    }

    // MARK: - Postularme (JobDetailsActivity.saveApplicationToDatabase:1683)
    public func apply(to job: JobOfferModel) {
        #if canImport(FirebaseDatabase)
        guard let uid = FirebaseService.shared.authenticatedUid else { return }
        let appRef = Database.database().reference()
            .child("JobApplications").child(job.id).child(uid)
        appRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                // Ya existe postulación previa → no se duplica ni se vuelve a incrementar el contador.
                if snapshot.exists() {
                    self.appliedJobIds.insert(job.id)
                    return
                }
                self.writeApplication(job: job, uid: uid)
            }
        }
        #endif
    }

    #if canImport(FirebaseDatabase)
    private func writeApplication(job: JobOfferModel, uid: String) {
        let root = Database.database().reference()
        let pushKey = root.child("JobApplications").child(job.id).push().key
        let applicationId = pushKey ?? "\(Int(Date().timeIntervalSince1970 * 1000))"
        let millis = Int64(Date().timeIntervalSince1970 * 1000)

        // Modelo idéntico a ModelJobApplication.java (timestamp como long, como Android).
        let application: [String: Any] = [
            "applicationId": applicationId,
            "jobId": job.id,
            "jobTitle": job.title,
            "publisherId": job.publisherId,
            "applicantId": uid,
            "applicantName": myName,
            "applicantUsername": "",
            "applicantPhoto": myPhoto,
            "applicantLocation": "",
            "applicantMusicalGenre": "",
            "applicantSocialNetworks": "",
            "applicantPerformancePercentage": 100,
            "applicantReputation": 40.0,
            "applicantInstrument": job.instrument,
            "ratingGiven": 5.0,
            "demoAudioUrl": "",
            "demoVideoUrl": "",
            "coverLetter": "",
            "curriculumUrl": "",
            "curriculumFileName": "",
            "videoUrls": [String](),
            "videoThumbnails": [String](),
            "status": "pending",
            "timestamp": millis
        ]
        root.child("JobApplications").child(job.id).child(uid).setValue(application)
        appliedJobIds.insert(job.id)

        // applicationsCount +1 (JobDetailsActivity.java:1708-1711): lectura + setValue, sin runTransaction.
        let countRef = root.child("JobOffers").child(job.id).child("applicationsCount")
        countRef.observeSingleEvent(of: .value) { snapshot in
            let current: Int
            if let number = snapshot.value as? NSNumber {
                current = number.intValue
            } else if let text = snapshot.value as? String, let parsed = Int(text) {
                current = parsed
            } else {
                current = 0
            }
            countRef.setValue(current + 1)
        }

        notifyPublisher(job: job, applicantUid: uid)
    }

    /// Notificación RTDB al publisher con el formato de AdapterPost.java:1554-1564
    /// (nota: Android sólo envía FCM para postulaciones — PushNotificationHelper.sendJobProposalNotification).
    private func notifyPublisher(job: JobOfferModel, applicantUid: String) {
        guard !job.publisherId.isEmpty else { return }
        let timestamp = "\(Int(Date().timeIntervalSince1970 * 1000))"
        let root = Database.database().reference()

        let notification: [String: Any] = [
            "pId": job.id,
            "timestamp": timestamp,
            "pText": "Se ha postulado a tu oferta: \(job.title)",
            "notification": "💼 Nueva postulación",
            "sId": applicantUid,
            "sName": myName,
            "type": "job_application"
        ]
        root.child("Users").child(job.publisherId).child("Notifications").child(timestamp).setValue(notification)
        root.child("Users").child(job.publisherId).child("Count").child(timestamp).setValue(true)
    }
    #endif
}

// MARK: - Musical Job Board & Gigs View (com.israviolink.app.job equivalent)
public struct JobBoardView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var service = JobsService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isPostJobPresented: Bool = false
    @State private var selectedFilter: String = "Todos"

    /// `true` cuando la lista proviene del nodo `JobOffers` en la nube (sesión real).
    private let usesLiveJobs: Bool = FirebaseService.shared.canWriteToCloud

    private static let seedJobs: [JobOfferModel] = [
        JobOfferModel(id: "j1", title: "Violinista para Cuarteto de Bodas", ensemble: "Ensamble Armonía", city: "Ciudad de México", paymentUSD: 120.0, instrument: "Violín", date: "Sábado 18 Octubre", isUrgent: true),
        JobOfferModel(id: "j2", title: "Trompeta Primera para Mariachi", ensemble: "Mariachi Sol de Oro", city: "Guadalajara, JAL", paymentUSD: 80.0, instrument: "Trompeta", date: "Fines de Semana", isUrgent: false),
        JobOfferModel(id: "j3", title: "Profesor de Iniciación Musical y Cuerdas", ensemble: "Academia Amadeus", city: "Monterrey, NL", paymentUSD: 450.0, instrument: "Cuerdas", date: "Mensual / Medio Tiempo", isUrgent: false)
    ]

    private var jobs: [JobOfferModel] {
        usesLiveJobs ? service.jobs : JobBoardView.seedJobs
    }

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Post Job Banner
                        Button(action: { isPostJobPresented = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "briefcase.fill")
                                    .font(.title3)
                                Text("Publicar Vacante o Búsqueda de Músico")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.primary)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Job Offers List
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Bolsa de Trabajo Musical")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 16)
                            
                            if jobs.isEmpty {
                                Text("No hay vacantes activas por ahora.")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
                            }

                            ForEach(jobs) { job in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(job.title)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(theme.textPrimary)
                                             
                                            Text(job.city.isEmpty ? job.ensemble : "\(job.ensemble) • \(job.city)")
                                                .font(.caption)
                                                .foregroundColor(theme.textSecondary)
                                        }
                                        Spacer()
                                        if job.isUrgent {
                                            Text("URGENTE")
                                                .font(.system(size: 9, weight: .black))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(AppColors.errorRed)
                                                .foregroundColor(.white)
                                                .cornerRadius(6)
                                        }
                                    }
                                     
                                    HStack {
                                        Label(job.instrument, systemImage: "music.note")
                                            .font(.caption2)
                                            .foregroundColor(AppColors.primary)
                                         
                                        Spacer()
                                         
                                        Text(job.paymentLabel)
                                            .font(.subheadline)
                                            .fontWeight(.black)
                                            .foregroundColor(AppColors.success)
                                    }
                                     
                                    HStack(spacing: 10) {
                                        Text(job.date.isEmpty ? job.payFrequency : "Fecha: \(job.date)")
                                            .font(.caption2)
                                            .foregroundColor(theme.textSecondary)
                                         
                                        Spacer()
                                         
                                        Button(action: {
                                            // Contact / apply → JobApplications/{jobId}/{myUid}
                                            if usesLiveJobs {
                                                service.apply(to: job)
                                            }
                                        }) {
                                            Text(isApplied(job) ? "Postulada ✅" : "Postularme")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 6)
                                                .background(AppColors.primary)
                                                .cornerRadius(10)
                                                .opacity(isApplied(job) && usesLiveJobs ? 0.65 : 1)
                                        }
                                        .disabled(usesLiveJobs && isApplied(job))
                                    }
                                }
                                .padding(16)
                                .background(theme.cardColor)
                                .cornerRadius(16)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Empleos y Vacantes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $isPostJobPresented) {
                PostJobSheet()
            }
            .onAppear {
                if usesLiveJobs { service.ensureStarted() }
            }
        }
    }

    private func isApplied(_ job: JobOfferModel) -> Bool {
        usesLiveJobs && service.appliedJobIds.contains(job.id)
    }
}

struct PostJobSheet: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var service = JobsService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var title: String = ""
    @State private var ensemble: String = ""
    @State private var payment: String = ""
    @State private var instrument: String = "Violín"

    private let usesLiveJobs: Bool = FirebaseService.shared.canWriteToCloud
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                Form {
                    Section(header: Text("Información del Empleo")) {
                        TextField("Título de la Vacante", text: $title)
                        TextField("Nombre del Ensamble / Empresa", text: $ensemble)
                        TextField("Honorarios (USD)", text: $payment)
                            .keyboardType(.decimalPad)
                        Picker("Instrumento Requerido", selection: $instrument) {
                            Text("Violín").tag("Violín")
                            Text("Viola / Cello").tag("Cuerdas")
                            Text("Trompeta").tag("Trompeta")
                            Text("Guitarra / Vihuela").tag("Guitarra")
                            Text("Vocalista").tag("Voz")
                        }
                    }
                    
                    Button(action: {
                        if usesLiveJobs {
                            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !cleanTitle.isEmpty else { return }
                            service.postJob(
                                title: cleanTitle,
                                ensemble: ensemble.trimmingCharacters(in: .whitespacesAndNewlines),
                                payment: payment.trimmingCharacters(in: .whitespacesAndNewlines),
                                instrument: instrument
                            )
                        }
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Publicar Oferta")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(AppColors.primary)
                }
            }
            .navigationTitle("Nueva Oferta de Trabajo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

public struct JobOfferModel: Identifiable {
    public let id: String
    let title: String
    let ensemble: String
    let city: String
    let paymentUSD: Double
    let instrument: String
    let date: String
    let isUrgent: Bool

    // Campos del nodo `JobOffers` (ModelJobOffer.java) con defaults
    // para no romper el seed local del modo demo.
    var publisherId: String = ""
    var publisherPhoto: String = ""
    var verifiedEntity: Bool = false
    var category: String = ""
    var workType: String = ""
    var locationType: String = ""
    var country: String = ""
    var salary: String = ""
    var salaryCurrency: String = "USD"
    var payFrequency: String = ""
    var descriptionText: String = ""
    var status: String = "active"
    var createdTimestamp: Double = 0
    var applicationsCount: Int = 0
    var acceptsInternational: Bool = false
    var internationalConditions: String = ""

    /// Texto mostrado en la tarjeta: Android pinta `salary` tal cual (String).
    var paymentLabel: String {
        let trimmed = salary.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "$\(Int(paymentUSD)) USD" }
        if trimmed.rangeOfCharacter(from: .decimalDigits) == nil { return trimmed }
        if salaryCurrency.isEmpty { return trimmed }
        if trimmed.uppercased().contains(salaryCurrency.uppercased()) { return trimmed }
        return "\(trimmed) \(salaryCurrency)"
    }
}
