import Foundation
import SwiftUI
import Combine
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Registro de clase reservada (esquema Android: model/ModelBookedClass.java)
//
// Réplica de BookClassActivity.prepareBookingData() / finalizeBooking() (Android):
//   BookedClasses/{teacherId}/{bookingId} y StudentClasses/{studentUid}/{bookingId}
//   { bookingId, roomId, studentId, teacherId, teacherName, date ("YYYY-MM-DD"),
//     time ("HH:mm"), modality ("Virtual"/"Presencial"), musicLevel, instrumentLevel,
//     notes, type (paquete), price (Double), method, timestamp (String), status ("pending"),
//     studentName, studentPhoto, teacherPhoto (opcionales del modelo) }
public struct BookedClassRecord: Identifiable, Codable, Hashable {
    public var bookingId: String
    public var studentId: String?
    public var teacherId: String?
    public var date: String?
    public var time: String?
    public var modality: String?
    public var musicLevel: String?
    public var instrumentLevel: String?
    public var type: String?
    public var method: String?
    public var timestamp: String?
    public var status: String?
    public var teacherName: String?
    public var studentName: String?
    public var paymentHash: String?
    public var notes: String?
    public var price: Double
    public var roomId: String?
    public var studentPhoto: String?
    public var teacherPhoto: String?
    public var rating: Double
    public var reviewText: String?

    /// Enriquecimiento local (patrón authorCache de FirebaseService): `Users/{teacherId}/instrument|specialty`.
    public var teacherInstrument: String?

    public var id: String { bookingId }

    public init(
        bookingId: String,
        studentId: String? = nil,
        teacherId: String? = nil,
        date: String? = nil,
        time: String? = nil,
        modality: String? = nil,
        musicLevel: String? = nil,
        instrumentLevel: String? = nil,
        type: String? = nil,
        method: String? = nil,
        timestamp: String? = nil,
        status: String? = nil,
        teacherName: String? = nil,
        studentName: String? = nil,
        paymentHash: String? = nil,
        notes: String? = nil,
        price: Double = 0,
        roomId: String? = nil,
        studentPhoto: String? = nil,
        teacherPhoto: String? = nil,
        rating: Double = 0,
        reviewText: String? = nil,
        teacherInstrument: String? = nil
    ) {
        self.bookingId = bookingId
        self.studentId = studentId
        self.teacherId = teacherId
        self.date = date
        self.time = time
        self.modality = modality
        self.musicLevel = musicLevel
        self.instrumentLevel = instrumentLevel
        self.type = type
        self.method = method
        self.timestamp = timestamp
        self.status = status
        self.teacherName = teacherName
        self.studentName = studentName
        self.paymentHash = paymentHash
        self.notes = notes
        self.price = price
        self.roomId = roomId
        self.studentPhoto = studentPhoto
        self.teacherPhoto = teacherPhoto
        self.rating = rating
        self.reviewText = reviewText
        self.teacherInstrument = teacherInstrument
    }

    public init(key: String, dict: [String: Any]) {
        self.bookingId = BookedClassRecord.string(dict["bookingId"]) ?? key
        self.studentId = BookedClassRecord.string(dict["studentId"])
        self.teacherId = BookedClassRecord.string(dict["teacherId"])
        self.date = BookedClassRecord.string(dict["date"])
        self.time = BookedClassRecord.string(dict["time"])
        self.modality = BookedClassRecord.string(dict["modality"])
        self.musicLevel = BookedClassRecord.string(dict["musicLevel"])
        self.instrumentLevel = BookedClassRecord.string(dict["instrumentLevel"])
        self.type = BookedClassRecord.string(dict["type"])
        self.method = BookedClassRecord.string(dict["method"])
        self.timestamp = BookedClassRecord.string(dict["timestamp"])
        self.status = BookedClassRecord.string(dict["status"])
        self.teacherName = BookedClassRecord.string(dict["teacherName"])
        self.studentName = BookedClassRecord.string(dict["studentName"])
        self.paymentHash = BookedClassRecord.string(dict["paymentHash"])
        self.notes = BookedClassRecord.string(dict["notes"])
        self.price = BookedClassRecord.double(dict["price"]) ?? 0
        self.roomId = BookedClassRecord.string(dict["roomId"])
        self.studentPhoto = BookedClassRecord.string(dict["studentPhoto"])
        self.teacherPhoto = BookedClassRecord.string(dict["teacherPhoto"])
        self.rating = BookedClassRecord.double(dict["rating"]) ?? 0
        self.reviewText = BookedClassRecord.string(dict["reviewText"])
        self.teacherInstrument = nil
    }

    // MARK: Utilidades de parseo (RTDB devuelve String u NSNumber indistintamente)
    public static func string(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    public static func double(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// `timestamp` de Android es String de milisegundos; también acepta la key numérica.
    public var timestampMillis: Double {
        if let raw = timestamp, let value = Double(raw) { return value }
        return Double(bookingId) ?? 0
    }

    public var scheduledDate: Date {
        guard let raw = date else { return Date() }
        return BookedClassRecord.dateFormatter.date(from: raw) ?? Date()
    }

    public var startTimeText: String { time ?? "--:--" }

    /// Android guarda sólo la hora de inicio; iOS muestra "inicio - fin" (+1 h, igual que las franjas de 1 hora).
    public var endTimeText: String {
        guard let raw = time else { return "" }
        let parts = raw.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]) else { return "" }
        let minute = Int(parts[1]) ?? 0
        return String(format: "%02d:%02d", (hour + 1) % 24, minute)
    }

    public static func lessonModality(from raw: String?) -> TeacherModel.LessonModality {
        switch (raw ?? "").lowercased() {
        case "presencial":
            return .inPerson
        case "both", "híbrido", "hibrido", "hybrid":
            return .hybrid
        default:
            return .online
        }
    }

    /// Valores de estado que escribe Android (MyBookedClassesActivity: completed/confirmed/cancelled + resto "pending").
    public static func bookingStatus(from raw: String?) -> BookedClassModel.BookingStatus {
        switch (raw ?? "").lowercased() {
        case "confirmed":
            return .confirmed
        case "completed":
            return .completed
        case "cancelled", "canceled":
            return .cancelled
        case "ongoing", "in_progress":
            return .ongoing
        default:
            return .pending
        }
    }

    /// Puente hacia el modelo que ya consume la UI (`MyBookedClassesView`).
    public var uiModel: BookedClassModel {
        BookedClassModel(
            id: bookingId,
            teacherId: teacherId ?? "",
            teacherName: teacherName ?? "Profesor",
            teacherAvatar: teacherPhoto,
            studentId: studentId ?? "",
            studentName: studentName ?? "",
            studentAvatar: studentPhoto,
            instrument: teacherInstrument ?? "Música",
            scheduledDate: scheduledDate,
            startTime: startTimeText,
            endTime: endTimeText,
            modality: BookedClassRecord.lessonModality(from: modality),
            lessonTopic: notes ?? type ?? "Clase particular",
            priceUSD: price,
            status: BookedClassRecord.bookingStatus(from: status),
            videoRoomId: roomId,
            notes: notes
        )
    }
}

// MARK: - Classes Service (nodos RTDB reales de Android)
//
// Réplica de BookClassActivity / MyBookedClassesActivity / SearchClassesActivity /
// TeacherAvailabilityActivity:
//   StudentClasses/{uid}, BookedClasses/{teacherId}, ClassRequests/{pushKey},
//   Balance/{uid}/balance, PlatformCommission/balance, Users/{teacherId}/Notifications,
//   Users/{uid}/availability
@MainActor
public final class ClassesService: ObservableObject {
    public static let shared = ClassesService()

    @Published public private(set) var myClasses: [BookedClassRecord] = []
    @Published public private(set) var verifiedTeachers: [TeacherModel] = []
    @Published public private(set) var didLoadMyClasses: Bool = false
    @Published public private(set) var didLoadTeachers: Bool = false
    /// Saldo QAV (`Balance/{uid}/balance`) leído de la nube (FirebaseService no sincroniza ese nodo).
    @Published public private(set) var qavBalance: Double? = nil

    /// `true` con sesión real (no demo): las vistas conservan su seed local cuando es `false`.
    public var usesLiveClasses: Bool { FirebaseService.shared.canWriteToCloud }

    private var isMyClassesStarted = false
    private var observedUid: String? = nil
    private var teacherDetails: [String: TeacherDetails] = [:]
    private var pendingTeacherFetches: Set<String> = []

    #if canImport(FirebaseDatabase)
    private var myClassesObserver: (handle: DatabaseHandle, remove: () -> Void)?
    #endif

    private init() {}

    // MARK: - Días y modalidades (TeacherAvailabilityActivity.java)
    public static let dayNameToAbbr: [String: String] = [
        "Lunes": "LUN", "Martes": "MAR", "Miércoles": "MIÉ", "Jueves": "JUE",
        "Viernes": "VIE", "Sábado": "SÁB", "Domingo": "DOM"
    ]

    public static let dayAbbrToName: [String: String] = [
        "LUN": "Lunes", "MAR": "Martes", "MIÉ": "Miércoles", "JUE": "Jueves",
        "VIE": "Viernes", "SÁB": "Sábado", "DOM": "Domingo"
    ]

    /// Android usa valores "Virtual" / "Presencial" / "Both" en `Users/{uid}/availability/modality`.
    public static func androidModality(from modality: TeacherModel.LessonModality) -> String {
        switch modality {
        case .online: return "Virtual"
        case .inPerson: return "Presencial"
        case .hybrid: return "Both"
        }
    }

    public static func lessonModality(from raw: String?) -> TeacherModel.LessonModality {
        BookedClassRecord.lessonModality(from: raw)
    }

    // MARK: - Observador de mis clases
    /// Arranca el observador de `StudentClasses/{uid}` si hay sesión real.
    public func ensureStarted() {
        guard FirebaseService.shared.canWriteToCloud else {
            // Sin sesión real (demo): no se observa la nube y la vista conserva su seed.
            if isMyClassesStarted { stopObserving() }
            return
        }
        observeMyClasses()
    }

    public func observeMyClasses() {
        guard let uid = FirebaseService.shared.authenticatedUid else {
            // Sin sesión real (demo): limpia cualquier estado heredado.
            if isMyClassesStarted { stopObserving() }
            return
        }
        if isMyClassesStarted, observedUid == uid { return }
        if isMyClassesStarted { stopObserving() }

        #if canImport(FirebaseDatabase)
        isMyClassesStarted = true
        observedUid = uid
        let ref = Database.database().reference().child("StudentClasses").child(uid)
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var rows: [BookedClassRecord] = []
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    rows.append(BookedClassRecord(key: snap.key, dict: dict))
                }
                // Android: `Collections.reverse(classList)` sobre keys cronológicas → más reciente primero.
                self.myClasses = rows.sorted { $0.timestampMillis > $1.timestampMillis }
                self.didLoadMyClasses = true
                self.fetchMissingTeachers()
            }
        }
        myClassesObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
        #else
        // Sin módulo de base de datos: evita que la vista se quede en "cargando".
        isMyClassesStarted = true
        observedUid = uid
        didLoadMyClasses = true
        #endif
    }

    public func stopObserving() {
        #if canImport(FirebaseDatabase)
        myClassesObserver?.remove()
        myClassesObserver = nil
        #endif
        isMyClassesStarted = false
        observedUid = nil
        myClasses = []
        didLoadMyClasses = false
    }

    // MARK: - Foto / instrumento del profesor (MyBookedClassesActivity carga Users/{teacherId} por ítem)
    private struct TeacherDetails {
        let name: String?
        let photo: String?
        let instrument: String?
    }

    private func fetchMissingTeachers() {
        #if canImport(FirebaseDatabase)
        for record in myClasses {
            guard let teacherId = record.teacherId, !teacherId.isEmpty else { continue }
            if teacherDetails[teacherId] != nil || pendingTeacherFetches.contains(teacherId) { continue }
            pendingTeacherFetches.insert(teacherId)
            Database.database().reference().child("Users").child(teacherId)
                .observeSingleEvent(of: .value) { [weak self] snapshot in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.pendingTeacherFetches.remove(teacherId)
                        let dict = snapshot.value as? [String: Any] ?? [:]
                        let instrument = ClassesService.nonEmpty(ClassesService.string(dict["specialty"]))
                            ?? ClassesService.nonEmpty(ClassesService.string(dict["instrument"]))
                        self.teacherDetails[teacherId] = TeacherDetails(
                            name: ClassesService.nonEmpty(ClassesService.string(dict["name"])),
                            photo: ClassesService.nonEmpty(ClassesService.string(dict["photo"])),
                            instrument: instrument
                        )
                        self.applyTeacherDetails()
                    }
                }
        }
        #endif
    }

    private func applyTeacherDetails() {
        let details = teacherDetails
        myClasses = myClasses.map { record in
            var next = record
            guard let teacherId = record.teacherId, let info = details[teacherId] else { return next }
            if next.teacherPhoto == nil || next.teacherPhoto?.isEmpty == true { next.teacherPhoto = info.photo }
            if next.teacherName == nil || next.teacherName?.isEmpty == true, let name = info.name { next.teacherName = name }
            next.teacherInstrument = info.instrument
            return next
        }
    }

    // MARK: - Profesores verificados (SearchClassesActivity.loadTeachers)
    /// Android consulta `Users` con `orderByChild("verifiedprofesor").equalTo("yes")`.
    /// Aquí se lee `Users` con `limitToLast` razonable y se filtra en cliente: siguiendo la
    /// experiencia de FirebaseService.observeVerifiedEntities, una consulta `equalTo` sin índice
    /// RTDB puede cancelarse, y el patrón de respaldo del proyecto es "últimos N usuarios + filtro".
    public func searchTeachers(query: String = "") {
        guard FirebaseService.shared.canWriteToCloud else { return }
        #if canImport(FirebaseDatabase)
        let ref = Database.database().reference().child("Users")
            .queryOrderedByKey()
            .queryLimited(toLast: 400)
        ref.observeSingleEvent(of: .value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var rows: [TeacherModel] = []
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any],
                          ClassesService.string(dict["verifiedprofesor"]) == "yes",
                          let model = ClassesService.parseTeacher(uid: snap.key, dict: dict) else { continue }
                    rows.append(model)
                }
                let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if !needle.isEmpty {
                    rows = rows.filter {
                        $0.name.localizedCaseInsensitiveContains(needle) ||
                        $0.institution.localizedCaseInsensitiveContains(needle) ||
                        $0.instrument.localizedCaseInsensitiveContains(needle)
                    }
                }
                self.verifiedTeachers = rows
                self.didLoadTeachers = true
            }
        }
        #else
        // Sin módulo de base de datos: la vista no debe quedarse en "cargando".
        verifiedTeachers = []
        didLoadTeachers = true
        #endif
    }

    /// RTDB devuelve el valor como `String` u `NSNumber` según cómo se escribió.
    public static func string(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    public static func double(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }

    /// `nil` cuando el texto está vacío o sólo contiene espacios (evita etiquetas en blanco).
    public static func nonEmpty(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    /// Convierte un nodo `Users/{uid}` (profesor) al `TeacherModel` de la UI.
    public static func parseTeacher(uid: String, dict: [String: Any]) -> TeacherModel? {
        let name = nonEmpty(string(dict["name"])) ?? "Profesor"
        let username = nonEmpty(string(dict["username"])) ?? "usuario"
        let photo = nonEmpty(string(dict["photo"]))
        let instrument = nonEmpty(string(dict["specialty"])) ?? nonEmpty(string(dict["instrument"])) ?? "Música"
        let basePrice = double(dict["basePrice"]) ?? 20.0
        let experience = Int(string(dict["experience"]) ?? "0") ?? 0
        let bio = string(dict["bio"]) ?? ""
        let rating = double(dict["rating"]) ?? 0
        let ratingCount = Int(double(dict["ratingCount"]) ?? 0)

        var availableDays: [String] = []
        var startTime = "08:00"
        var endTime = "18:00"
        var modalityRaw = "Both"
        if let availability = dict["availability"] as? [String: Any] {
            if let days = availability["availableDays"] as? [String] {
                availableDays = days.map { dayAbbrToName[$0.uppercased()] ?? $0 }
            }
            if let value = string(availability["startTime"]), !value.isEmpty { startTime = value }
            if let value = string(availability["endTime"]), !value.isEmpty { endTime = value }
            if let value = string(availability["modality"]), !value.isEmpty { modalityRaw = value }
        }

        var slots: [ClassTimeSlot] = []
        for day in availableDays where !day.isEmpty {
            slots.append(ClassTimeSlot(dayOfWeek: day, startTime: startTime, endTime: endTime))
        }

        return TeacherModel(
            id: uid,
            name: name,
            username: username,
            avatarUrl: photo,
            instrument: instrument,
            bio: bio,
            hourlyRateUSD: basePrice,
            hourlyRateDiamonds: max(60, Int(basePrice * 6)),
            rating: rating,
            reviewCount: ratingCount,
            experienceYears: experience,
            institution: "Profesor Verificado",
            modality: lessonModality(from: modalityRaw),
            availableDays: availableDays,
            timeSlots: slots,
            isVerifiedTeacher: true
        )
    }

    // MARK: - Saldo QAV (`Balance/{uid}/balance`)
    public func fetchQavBalance(completion: @escaping (Double?) -> Void) {
        #if canImport(FirebaseDatabase)
        guard let uid = FirebaseService.shared.authenticatedUid else { completion(nil); return }
        Task { @MainActor in
            let raw = await self.readValue(path: ["Balance", uid, "balance"])
            let value = ClassesService.double(raw)
            self.qavBalance = value
            completion(value)
        }
        #else
        completion(nil)
        #endif
    }

    // MARK: - Reserva de clase con pago real (BookClassActivity.processInternalPayment + finalizeBooking)
    ///
    /// Réplica Android:
    ///  1. `Balance/{studentUid}/balance` -= price (String numérico)
    ///  2. `Balance/{teacherId}/balance` += price * 0.90
    ///  3. `PlatformCommission/balance` += price * 0.10 (EXISTE y se escribe en Android, líneas 483/520-529)
    ///  4. `BookedClasses/{teacherId}/{bookingId}` + `StudentClasses/{uid}/{bookingId}`
    ///  5. Notificación `Users/{teacherId}/Notifications/{ts}` + `Count/{ts}` + mensaje en `Chats`
    public func bookClass(
        teacher: TeacherModel,
        date: Date,
        timeSlot: String,
        level: String,
        modality: String,
        notes: String,
        packageType: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        #if canImport(FirebaseDatabase)
        guard let uid = FirebaseService.shared.authenticatedUid else {
            completion(.failure(ClassesServiceError.noSession))
            return
        }
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let bookingId = "\(millis)"
        let price = teacher.hourlyRateUSD
        let dateText = ClassesService.isoDateFormatter.string(from: date)
        let startHour = String(timeSlot.split(separator: "-").first ?? "")
            .trimmingCharacters(in: .whitespaces)
        let hourText = startHour.isEmpty ? timeSlot : startHour

        Task { @MainActor in
            do {
                // 1) Solo LECTURAS previas: saldos y perfiles (nada se debita todavía).
                let studentRaw = await self.readValue(path: ["Balance", uid, "balance"])
                let studentBalance = ClassesService.double(studentRaw) ?? 0
                guard studentBalance >= price else {
                    completion(.failure(ClassesServiceError.insufficientBalance(studentBalance)))
                    return
                }
                let commission = price * 0.10
                let teacherAmount = price - commission
                let teacherRaw = await self.readValue(path: ["Balance", teacher.id, "balance"])
                let teacherBalance = ClassesService.double(teacherRaw) ?? 0
                let platformRaw = await self.readValue(path: ["PlatformCommission", "balance"])
                let platformBalance = ClassesService.double(platformRaw) ?? 0

                // 2) Datos del alumno y del profesor (Users/{uid}: name, photo)
                let studentDict = (await self.readValue(path: ["Users", uid])) as? [String: Any] ?? [:]
                let teacherDict = (await self.readValue(path: ["Users", teacher.id])) as? [String: Any] ?? [:]
                let studentName = ClassesService.string(studentDict["name"]) ?? FirebaseService.shared.currentUser?.name ?? ""
                let studentPhoto = ClassesService.string(studentDict["photo"])
                let teacherPhoto = ClassesService.string(teacherDict["photo"]) ?? teacher.avatarUrl

                // 3) Mapa de reserva (prepareBookingData + bookingId/roomId de finalizeBooking)
                var map: [String: Any] = [
                    "bookingId": bookingId,
                    "roomId": bookingId,
                    "studentId": uid,
                    "teacherId": teacher.id,
                    "teacherName": teacher.name,
                    "date": dateText,
                    "time": hourText,
                    "modality": modality,
                    "musicLevel": level,
                    "instrumentLevel": level,
                    "notes": notes,
                    "type": packageType,
                    "price": price,
                    "method": "QAV Saldo",
                    "timestamp": "\(millis)",
                    "status": "pending"
                ]
                if !studentName.isEmpty { map["studentName"] = studentName }
                if let studentPhoto = studentPhoto, !studentPhoto.isEmpty { map["studentPhoto"] = studentPhoto }
                if let teacherPhoto = teacherPhoto, !teacherPhoto.isEmpty { map["teacherPhoto"] = teacherPhoto }

                // 4) Pago + reserva en UNA sola escritura multi-ruta ATÓMICA:
                //    débito, abono, comisión y ambos nodos de reserva se aplican juntos
                //    (aparecen a la vez o ninguno) — nunca se debita el saldo sin dejar la reserva.
                let updates: [String: Any] = [
                    "Balance/\(uid)/balance": String(studentBalance - price),
                    "Balance/\(teacher.id)/balance": String(teacherBalance + teacherAmount),
                    "PlatformCommission/balance": String(platformBalance + commission),
                    "BookedClasses/\(teacher.id)/\(bookingId)": map,
                    "StudentClasses/\(uid)/\(bookingId)": map
                ]
                try await self.updateRoot(updates)

                // 5) Automatizaciones (sendBookingAutomations): notificación + chat de cortesía.
                //    Son best-effort: si fallan, el pago y la reserva ya quedaron aplicados.
                do {
                    try await self.sendBookingAutomations(
                        studentUid: uid,
                        teacher: teacher,
                        amount: price,
                        packageType: packageType,
                        dateText: dateText,
                        hourText: hourText,
                        level: level,
                        modality: modality,
                        notes: notes,
                        timestamp: "\(millis)"
                    )
                } catch {
                    // Se ignora deliberadamente: no debe reportarse un fallo de la reserva.
                }

                // Wallet local en pantalla (FirebaseService no observa `Balance`)
                let newStudentBalance = studentBalance - price
                FirebaseService.shared.walletBalance.balanceQav = newStudentBalance
                self.qavBalance = newStudentBalance
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
        #else
        completion(.failure(ClassesServiceError.firebaseUnavailable))
        #endif
    }

    /// Notificación al profesor + chat + contador (BookClassActivity.sendBookingAutomations, líneas 585-617).
    private func sendBookingAutomations(
        studentUid: String,
        teacher: TeacherModel,
        amount: Double,
        packageType: String,
        dateText: String,
        hourText: String,
        level: String,
        modality: String,
        notes: String,
        timestamp: String
    ) async throws {
        #if canImport(FirebaseDatabase)
        let notesText = notes.isEmpty ? "" : "\n📝 Objetivo/Notas: \(notes)"
        let message = "¡Hola Profesor \(teacher.name)! 🎓 Acabo de reservar y pagar mi \(packageType) (QAV Saldo)." +
            "\n📅 Fecha: \(dateText) a las \(hourText)" +
            "\n🎻 Nivel: \(level)" +
            "\n📍 Modalidad: \(modality)" + notesText

        // Chats (esquema idéntico a ChatActivity/ChatViewModel)
        let chat: [String: Any] = [
            "sender": studentUid,
            "receiver": teacher.id,
            "msg": message,
            "timestamp": timestamp,
            "isSeen": false,
            "type": "text"
        ]
        try await pushWrite(chat, path: ["Chats"])
        try await updateChildren(
            ["id": teacher.id, "lastMsg": message, "timestamp": timestamp, "lastMsgType": "text", "lastSenderId": studentUid],
            path: ["Chatlist", studentUid, teacher.id]
        )
        try await updateChildren(
            ["id": studentUid, "lastMsg": message, "timestamp": timestamp, "lastMsgType": "text", "lastSenderId": studentUid],
            path: ["Chatlist", teacher.id, studentUid]
        )

        // Users/{teacherId}/Notifications/{ts} (replica literal de Android)
        let notif: [String: Any] = [
            "pId": "booking_\(timestamp)",
            "timestamp": timestamp,
            "pText": "Has recibido un pago de $\(String(format: "%.2f", amount)) USD por una nueva clase \(packageType).",
            "notification": "Nueva Clase Vendida 🎓",
            "sUid": studentUid,
            "type": "booking"
        ]
        try await writeValue(notif, path: ["Users", teacher.id, "Notifications", timestamp])
        try await writeValue(true, path: ["Users", teacher.id, "Count", timestamp])
        #endif
    }

    // MARK: - Solicitud pública de clase (SearchClassesActivity, líneas 524-566)
    public func createClassRequest(
        instrument: String,
        level: String,
        budget: String,
        description: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        #if canImport(FirebaseDatabase)
        guard let uid = FirebaseService.shared.authenticatedUid else {
            completion(.failure(ClassesServiceError.noSession))
            return
        }
        let ref = Database.database().reference().child("ClassRequests")
        guard let pushKey = ref.push().key else {
            completion(.failure(ClassesServiceError.missingPushKey))
            return
        }
        let now = "\(Int(Date().timeIntervalSince1970 * 1000))"
        let baseMap: [String: Any] = [
            "requestId": pushKey,
            "studentId": uid,
            "instrument": instrument,
            "level": level,
            "budget": budget,
            "description": description,
            "timestamp": now,
            "status": "open"
        ]
        Task { @MainActor in
            do {
                let userDict = (await self.readValue(path: ["Users", uid])) as? [String: Any] ?? [:]
                // Se copia dentro de la tarea para no mutar una variable capturada.
                var payload = baseMap
                if let name = ClassesService.string(userDict["name"]), !name.isEmpty { payload["studentName"] = name }
                if let photo = ClassesService.string(userDict["photo"]), !photo.isEmpty { payload["studentPhoto"] = photo }
                try await self.writeValue(payload, path: ["ClassRequests", pushKey])
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
        #else
        completion(.failure(ClassesServiceError.firebaseUnavailable))
        #endif
    }

    // MARK: - Disponibilidad del profesor (TeacherAvailabilityActivity.saveAvailabilityAndProfile)
    public struct TeacherAvailabilityData {
        public var days: [String]
        public var startTime: String
        public var endTime: String
        public var modality: String
        public var basePrice: String
    }

    /// Escribe `Users/{uid}` con `updateChildren` (NUNCA setValue: borraría el perfil).
    public func saveAvailability(
        days: [String],
        startHour: String,
        endHour: String,
        modality: String,
        basePrice: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        #if canImport(FirebaseDatabase)
        guard let uid = FirebaseService.shared.authenticatedUid else {
            completion(.failure(ClassesServiceError.noSession))
            return
        }
        let availability: [String: Any] = [
            "availableDays": days,
            "startTime": startHour.isEmpty ? "08:00" : startHour,
            "endTime": endHour.isEmpty ? "18:00" : endHour,
            "modality": modality
        ]
        let priceText = basePrice.trimmingCharacters(in: .whitespacesAndNewlines)
        let userUpdate: [String: Any] = [
            "availability": availability,
            "basePrice": priceText.isEmpty ? "20.00" : priceText
        ]

        Task { @MainActor in
            do {
                try await self.updateChildren(userUpdate, path: ["Users", uid])
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
        #else
        completion(.failure(ClassesServiceError.firebaseUnavailable))
        #endif
    }

    public func loadAvailability(completion: @escaping (TeacherAvailabilityData?) -> Void) {
        #if canImport(FirebaseDatabase)
        guard let uid = FirebaseService.shared.authenticatedUid else { completion(nil); return }
        Task { @MainActor in
            guard let dict = (await self.readValue(path: ["Users", uid])) as? [String: Any] else {
                completion(nil)
                return
            }
            guard let availability = dict["availability"] as? [String: Any] else {
                if let basePrice = ClassesService.string(dict["basePrice"]), !basePrice.isEmpty {
                    completion(TeacherAvailabilityData(
                        days: [],
                        startTime: "08:00",
                        endTime: "18:00",
                        modality: "Both",
                        basePrice: basePrice
                    ))
                } else {
                    completion(nil)
                }
                return
            }
            let rawDays = (availability["availableDays"] as? [String]) ?? []
            completion(TeacherAvailabilityData(
                days: rawDays,
                startTime: ClassesService.string(availability["startTime"]) ?? "08:00",
                endTime: ClassesService.string(availability["endTime"]) ?? "18:00",
                modality: ClassesService.string(availability["modality"]) ?? "Both",
                basePrice: ClassesService.string(dict["basePrice"]) ?? "20.00"
            ))
        }
        #else
        completion(nil)
        #endif
    }

    // MARK: - Utilidades RTDB (lectura + escritura; nunca runTransaction)
    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    #if canImport(FirebaseDatabase)
    private func reference(for path: [String]) -> DatabaseReference {
        var ref = Database.database().reference()
        for component in path { ref = ref.child(component) }
        return ref
    }

    private func readValue(path: [String]) async -> Any? {
        // Se construye la referencia antes del cierre para no invocar miembros aislados dentro.
        let ref = reference(for: path)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Any?, Never>) in
            ref.observeSingleEvent(of: .value) { snapshot in
                continuation.resume(returning: snapshot.value)
            }
        }
    }

    /// Escritura puntual de un nodo (`setValue`). Se expone a nivel de módulo para que
    /// `VerificationService` reutilice el mismo patrón lectura + escritura.
    func writeValue(_ value: Any, path: [String]) async throws {
        let ref = reference(for: path)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setValue(value) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// Fusión de campos (`updateChildValues`) — nunca `setValue` sobre nodos con más datos.
    func updateChildren(_ values: [String: Any], path: [String]) async throws {
        let ref = reference(for: path)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.updateChildValues(values) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// Escritura multi-ruta ATÓMICA en la raíz: las claves son rutas absolutas
    /// (`"Balance/{uid}/balance"`, `"StudentClasses/{uid}/{id}"`...). Firebase las aplica
    /// todas o ninguna — usado para que pago + reserva queden juntos sin riesgo de débito huérfano.
    func updateRoot(_ values: [String: Any]) async throws {
        let ref = Database.database().reference()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.updateChildValues(values) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func pushWrite(_ value: Any, path: [String]) async throws {
        let ref = reference(for: path).childByAutoId()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setValue(value) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    #endif
}

// MARK: - Errores de Clases / Verificación (textos en español)
public enum ClassesServiceError: LocalizedError {
    case firebaseUnavailable
    case noSession
    case insufficientBalance(Double)
    case missingPushKey
    case timeout

    public var errorDescription: String? {
        switch self {
        case .firebaseUnavailable:
            return "El módulo de base de datos no está disponible en esta compilación."
        case .noSession:
            return "Necesitas iniciar sesión con una cuenta real de PROVIWEB para realizar esta acción."
        case .insufficientBalance(let balance):
            return "Saldo insuficiente en QAV Saldo ($\(String(format: "%.2f", balance))). Recarga tu saldo para completar la reserva."
        case .missingPushKey:
            return "No se pudo generar el identificador de la operación. Inténtalo de nuevo."
        case .timeout:
            return "El servidor tardó demasiado en responder. Revisa \"Mis Clases\" por si la reserva ya se registró."
        }
    }
}

// MARK: - Book Private Masterclass View
public struct BookClassView: View {
    public let teacher: TeacherModel
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedDate: Date = Date().addingTimeInterval(86400 * 2)
    @State private var selectedTimeSlot: String = "16:00 - 17:00"
    @State private var selectedLevel: String = "Principiante"
    @State private var selectedModality: String = "Virtual"
    @State private var lessonTopic: String = ""
    @State private var studentNotes: String = ""
    @State private var availableBalance: Double? = nil
    @State private var isBookingInFlight: Bool = false
    @State private var isAlertPresented: Bool = false
    @State private var isErrorAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var isCalendarPresented: Bool = false
    
    /// Android reserva con las franjas publicadas en `Users/{teacherId}/availability`.
    private var availableTimes: [String] {
        let slots = Array(Set(teacher.timeSlots.map { "\($0.startTime) - \($0.endTime)" }))
            .sorted { lhs, rhs in
                lhs < rhs
            }
        if slots.isEmpty {
            return ["09:00 - 10:00", "11:00 - 12:00", "15:00 - 16:00", "16:00 - 17:00", "18:00 - 19:00"]
        }
        return slots
    }
    
    public init(teacher: TeacherModel) {
        self.teacher = teacher
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    // Teacher Summary Section
                    Section(header: Text("Profesor Seleccionado")) {
                        HStack(spacing: 12) {
                            AvatarView(urlString: teacher.avatarUrl, size: 48, isVerified: teacher.isVerifiedTeacher)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(teacher.name)
                                    .font(.headline)
                                    .foregroundColor(theme.textPrimary)
                                Text("\(teacher.instrument) • \(teacher.institution)")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                                Text("Tarifa: \(String(format: "$%.2f USD", teacher.hourlyRateUSD)) / hora")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Date & Slot Selection
                    Section(header: Text("Fecha y Horario")) {
                        DatePicker("Fecha de la Clase", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                        
                        Picker("Horario Disponible", selection: $selectedTimeSlot) {
                            ForEach(availableTimes, id: \.self) { slot in
                                Text(slot).tag(slot)
                            }
                        }
                        
                        Picker("Modalidad", selection: $selectedModality) {
                            Text("Virtual").tag("Virtual")
                            Text("Presencial").tag("Presencial")
                        }
                        
                        Picker("Nivel", selection: $selectedLevel) {
                            Text("Principiante").tag("Principiante")
                            Text("Intermedio").tag("Intermedio")
                            Text("Avanzado").tag("Avanzado")
                        }
                        
                        Button(action: { isCalendarPresented = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .foregroundColor(AppColors.primary)
                                Text("Seleccionar fecha en calendario")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                    
                    // Lesson Topic & Notes
                    Section(header: Text("Objetivo de Aprendizaje")) {
                        TextField("Tema (ej. Repertorio Bach, Golpes de Arco, Solfeo)", text: $lessonTopic)
                        
                        TextField("Notas o piezas que estás trabajando actualmente", text: $studentNotes)
                    }
                    
                    // Payment Method
                    // Android sólo ofrece: Saldo QAV interno, Crypto o Google Play (BookClassActivity
                    // rbInternalBalance/rbCrypto). NO existe pago de clases con diamantes, por lo que
                    // el toggle de diamantes se retiró: se paga con `Balance/{uid}/balance`.
                    Section(header: Text("Método de Pago"),
                            footer: Text("Pago con tu Saldo QAV (nodo Balance). El profesor recibe el 90% y PROVIWEB aplica una comisión del 10% (PlatformCommission).")) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.primary)
                            Text("Pagar con Saldo QAV (Balance)")
                                .font(.subheadline)
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Saldo disponible:")
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            Text(String(format: "$%.2f USD", availableBalance ?? firebase.walletBalance.balanceUSD))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textPrimary)
                        }
                        
                        HStack {
                            Text("Total a Pagar:")
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            Text(String(format: "$%.2f USD", teacher.hourlyRateUSD))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    
                    // Confirmation Action
                    Section {
                        Button(action: confirmBooking) {
                            HStack(spacing: 8) {
                                if isBookingInFlight {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isBookingInFlight ? "Procesando pago…" : "Confirmar y Reservar Clase")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .disabled(isBookingInFlight)
                        .listRowBackground(AppColors.primary)
                    }
                }
            }
            .navigationTitle("Reservar Clase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(alertTitle, isPresented: $isAlertPresented) {
                Button("Entendido") {
                    if !isErrorAlert {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $isCalendarPresented) {
                BookingCalendarView(onDateSelected: { date in
                    selectedDate = date
                })
            }
            .onAppear {
                if !availableTimes.contains(selectedTimeSlot) {
                    selectedTimeSlot = availableTimes.first ?? selectedTimeSlot
                }
                ClassesService.shared.fetchQavBalance { balance in
                    if let balance = balance {
                        availableBalance = balance
                    }
                }
            }
        }
    }
    
    private var composedNotes: String {
        [lessonTopic, studentNotes]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " — ")
    }
    
    @MainActor private func confirmBooking() {
        guard ClassesService.shared.usesLiveClasses else {
            // Modo demostración (sin cuenta real): se conserva el comportamiento local anterior.
            alertTitle = "¡Clase Reservada con Éxito!"
            alertMessage = "El profesor ha recibido tu solicitud. Se ha generado tu enlace de sala para la fecha acordada."
            isErrorAlert = false
            isAlertPresented = true
            return
        }
        
        isBookingInFlight = true
        // Envoltura "solo una vez": si el callback de RTDB no vuelve en 45 s, el timeout
        // de seguridad libera el botón y avisa (evita la UI bloqueada a mitad de pago).
        var didFinish = false
        let finish: (Result<Void, Error>) -> Void = { result in
            guard !didFinish else { return }
            didFinish = true
            isBookingInFlight = false
            switch result {
            case .success:
                alertTitle = "¡Clase Reservada con Éxito!"
                alertMessage = "El profesor ha recibido tu solicitud. Se ha generado tu enlace de sala para la fecha acordada."
                isErrorAlert = false
            case .failure(let error):
                alertTitle = "No se pudo reservar la clase"
                alertMessage = error.localizedDescription
                isErrorAlert = true
            }
            isAlertPresented = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) {
            finish(.failure(ClassesServiceError.timeout))
        }
        ClassesService.shared.bookClass(
            teacher: teacher,
            date: selectedDate,
            timeSlot: selectedTimeSlot,
            level: selectedLevel,
            modality: selectedModality,
            notes: composedNotes,
            packageType: "Clase Individual (1 clase)",
            completion: finish
        )
    }
}
