import Foundation
import SwiftUI
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// Los completions de este módulo devuelven mensajes de error legibles en `Result<T, String>`
// (mismo patrón que Android, que propaga Strings); `String` necesita conformar a `Error`.
extension String: Error {}

// MARK: - Eventos Artísticos en vivo (RTDB esquema exacto de Android: `ArtisticEvents`)
//
// Réplica de EventsHomeActivity / CreateEventActivity / EventTicketManager.java (Android):
//   ArtisticEvents/{eventId} = { id, creatorId, creatorName, creatorUsername, creatorPhoto,
//     title, description, category (String libre), coverUrl, mediaType, eventType, accessType,
//     eventDate ("dd 'de' MMMM, yyyy"), eventTime ("HH:mm"), eventTimestamp (long millis),
//     location, latitude, longitude, onlinePlatform, onlineStreamLink, collaborators, schedule,
//     paymentMethod ("qav"/"link"/"free"), priceQav, purchaseLink, maxCapacity,
//     registeredCount, createdAt (long), status ("active"/"cancelled"/"finished") }
//   EventTickets/{eventId}/{ticketId} y UserEventTickets/{userId}/{ticketId} = entrada (QR).
// La cartelera se ordena por `eventTimestamp` descendente; "Mis Boletos" lee
// `UserEventTickets/{uid}` (igual que Android).
@MainActor
public final class EventsService: ObservableObject {
    public static let shared = EventsService()

    /// Cartelera en vivo (nodo `ArtisticEvents`), ordenada por `eventTimestamp` desc.
    @Published public private(set) var events: [ArtisticEventModel] = []
    /// Entradas del usuario actual (nodo `UserEventTickets/{uid}`), ordenadas por `purchasedAt` desc.
    @Published public private(set) var myTickets: [UserEventTicketModel] = []
    /// `true` cuando la sesión permite escribir en la nube (no modo demo).
    public let usesLiveEvents: Bool

    private var rawEvents: [String: [String: Any]] = [:]
    private var rawTickets: [String: [String: Any]] = [:]
    private var isStarted = false
    private var isPurchasing = false
    private var isCreating = false

    #if canImport(FirebaseDatabase)
    private var eventsObserver: (handle: DatabaseHandle, remove: () -> Void)?
    private var ticketsObserver: (handle: DatabaseHandle, remove: () -> Void)?
    #endif

    private init() {
        usesLiveEvents = FirebaseService.shared.canWriteToCloud
    }

    // MARK: - Arranque de observadores
    public func ensureStarted() {
        guard FirebaseService.shared.canWriteToCloud else { return }
        #if canImport(FirebaseDatabase)
        if !isStarted {
            isStarted = true
            observeEvents()
        }
        // `observeMyTickets` necesita uid: si aún no está disponible no se registra
        // y se reintenta en la próxima llamada (onAppear), sin duplicar observers.
        observeMyTickets()
        #endif
    }

    #if canImport(FirebaseDatabase)
    private func observeEvents() {
        let ref = Database.database().reference().child("ArtisticEvents")
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var next: [String: [String: Any]] = [:]
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    next[snap.key] = dict
                }
                self.rawEvents = next
                self.rebuildEvents()
            }
        }
        eventsObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }

    private func observeMyTickets() {
        guard ticketsObserver == nil, let uid = FirebaseService.shared.authenticatedUid else { return }
        let ref = Database.database().reference().child("UserEventTickets").child(uid)
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var next: [String: [String: Any]] = [:]
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    next[snap.key] = dict
                }
                self.rawTickets = next
                self.rebuildTickets()
            }
        }
        ticketsObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }
    #endif

    // MARK: - Reconstrucción de listas
    private func rebuildEvents() {
        var mapped: [ArtisticEventModel] = []
        for (key, dict) in rawEvents {
            if let event = EventsService.parseEvent(key: key, dict: dict) {
                mapped.append(event)
            }
        }
        // Android ordena la cartelera por fecha del evento (eventTimestamp desc).
        events = mapped.sorted { lhs, rhs in
            let left = lhs.eventTimestamp > 0 ? lhs.eventTimestamp : lhs.createdAt
            let right = rhs.eventTimestamp > 0 ? rhs.eventTimestamp : rhs.createdAt
            if left != right { return left > right }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func rebuildTickets() {
        var mapped: [UserEventTicketModel] = []
        for (key, dict) in rawTickets {
            if let ticket = EventsService.parseTicket(key: key, dict: dict) {
                mapped.append(ticket)
            }
        }
        myTickets = mapped.sorted { $0.purchasedAtMs > $1.purchasedAtMs }
    }

    // MARK: - Lectura manual de valores RTDB
    static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String { return value }
        if let value = raw as? NSNumber { return value.stringValue }
        return nil
    }

    static func doubleValue(_ raw: Any?) -> Double {
        if let value = raw as? NSNumber { return value.doubleValue }
        if let text = raw as? String {
            let clean = text.replacingOccurrences(of: ",", with: ".")
            if let value = Double(clean) { return value }
        }
        return 0
    }

    static func intValue(_ raw: Any?) -> Int {
        if let value = raw as? NSNumber { return value.intValue }
        if let text = raw as? String, let value = Int(text) { return value }
        return 0
    }

    static func coerceBool(_ raw: Any?) -> Bool {
        if let value = raw as? Bool { return value }
        if let value = raw as? NSNumber { return value.boolValue }
        if let text = raw as? String { return text == "true" || text == "1" }
        return false
    }

    static func dictArray(_ raw: Any?) -> [[String: Any]] {
        if let list = raw as? [Any] {
            return list.compactMap { $0 as? [String: Any] }
        }
        if let map = raw as? [String: Any] {
            return map.values.compactMap { $0 as? [String: Any] }
        }
        return []
    }

    // MARK: - Formatos de fecha (idénticos a SimpleDateFormat de CreateEventActivity.java)
    static let readableDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd 'de' MMMM, yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }()

    /// `eventDate: Date` de iOS se resuelve desde `eventTimestamp` (long de Android);
    /// si no existe se parsea el texto legible `eventDate` + `eventTime`.
    static func dateFrom(timestampMillis: Double, dateText: String?, timeText: String?) -> Date {
        if timestampMillis > 0 {
            return Date(timeIntervalSince1970: timestampMillis / 1000)
        }
        if let dateText = dateText, !dateText.isEmpty {
            let base = readableDateFormatter.date(from: dateText)
                ?? (ISO8601DateFormatter().date(from: dateText) ?? Date())
            if let timeText = timeText, !timeText.isEmpty,
               let timeOnly = timeFormatter.date(from: timeText) {
                let calendar = Calendar.current
                let comps = calendar.dateComponents([.hour, .minute], from: timeOnly)
                if let adjusted = calendar.date(bySettingHour: comps.hour ?? 0,
                                                minute: comps.minute ?? 0,
                                                second: 0,
                                                of: base) {
                    return adjusted
                }
            }
            return base
        }
        return Date()
    }

    // MARK: - Parseo `ArtisticEvents/{eventId}` → ArtisticEventModel
    static func parseEvent(key: String, dict: [String: Any]) -> ArtisticEventModel? {
        let title = stringValue(dict["title"]) ?? ""
        guard !title.isEmpty else { return nil }

        let timestamp = doubleValue(dict["eventTimestamp"])
        let dateText = stringValue(dict["eventDate"]) ?? ""
        let timeText = stringValue(dict["eventTime"]) ?? ""
        let eventDate = dateFrom(timestampMillis: timestamp, dateText: dateText, timeText: timeText)

        let rawCategory = stringValue(dict["category"]) ?? ""
        let paymentMethod = stringValue(dict["paymentMethod"]) ?? "free"
        let priceQav = doubleValue(dict["priceQav"])
        let maxCapacity = intValue(dict["maxCapacity"])
        let registeredCount = intValue(dict["registeredCount"])
        let accessType = stringValue(dict["accessType"]) ?? "publico"
        let eventType = stringValue(dict["eventType"]) ?? "presencial"
        let onlinePlatform = stringValue(dict["onlinePlatform"]) ?? ""
        let streamLink = stringValue(dict["onlineStreamLink"]) ?? ""
        let location = stringValue(dict["location"]) ?? ""
        let isOnline = eventType.lowercased() == "online"
        let isLiveStreamed = isOnline || !streamLink.isEmpty

        var schedule: [EventScheduleItem] = []
        for raw in dictArray(dict["schedule"]) {
            let time = stringValue(raw["time"]) ?? ""
            let itemTitle = stringValue(raw["title"]) ?? ""
            guard !itemTitle.isEmpty || !time.isEmpty else { continue }
            schedule.append(EventScheduleItem(
                id: stringValue(raw["id"]) ?? UUID().uuidString,
                timeString: time,
                activityTitle: itemTitle,
                artistName: nil,
                date: stringValue(raw["date"]) ?? "",
                accessType: stringValue(raw["accessType"]) ?? "libre",
                timestamp: doubleValue(raw["timestamp"])
            ))
        }

        var collaborators: [EventCollaboratorItem] = []
        for raw in dictArray(dict["collaborators"]) {
            let name = stringValue(raw["name"]) ?? ""
            guard !name.isEmpty else { continue }
            let uid = stringValue(raw["uid"]) ?? ""
            collaborators.append(EventCollaboratorItem(
                id: uid.isEmpty ? UUID().uuidString : uid,
                name: name,
                role: stringValue(raw["role"]) ?? "Colaborador",
                avatarUrl: stringValue(raw["photo"]),
                verified: true,
                uid: uid,
                username: stringValue(raw["username"]) ?? "",
                isAppUser: coerceBool(raw["isAppUser"])
            ))
        }

        let rawStatus = (stringValue(dict["status"]) ?? "active").lowercased()
        let status: ArtisticEventModel.EventStatus
        switch rawStatus {
        case "cancelled":
            status = .cancelled
        case "finished":
            status = .completed
        default:
            status = (maxCapacity > 0 && registeredCount >= maxCapacity) ? .soldOut : .upcoming
        }

        // Para eventos "online" la sede es la plataforma de streaming (Android deja `location` vacío).
        let venue = isOnline ? (onlinePlatform.isEmpty ? "En línea" : onlinePlatform) : location
        let coverUrl = stringValue(dict["coverUrl"]) ?? ""
        let creatorPhoto = stringValue(dict["creatorPhoto"]) ?? ""

        return ArtisticEventModel(
            id: key,
            title: title,
            organizerId: stringValue(dict["creatorId"]) ?? "",
            organizerName: stringValue(dict["creatorName"]) ?? "Artista",
            organizerDp: creatorPhoto.isEmpty ? nil : creatorPhoto,
            description: stringValue(dict["description"]) ?? "",
            bannerUrl: coverUrl.isEmpty ? nil : coverUrl,
            venueName: venue,
            address: "",
            latitude: dict["latitude"] == nil ? nil : doubleValue(dict["latitude"]),
            longitude: dict["longitude"] == nil ? nil : doubleValue(dict["longitude"]),
            eventDate: eventDate,
            durationHours: 2.0,
            category: ArtisticEventModel.mapCategory(rawCategory),
            ticketPriceUSD: priceQav,
            ticketPriceDiamonds: Int(priceQav * 6),
            totalCapacity: maxCapacity,
            ticketsSold: registeredCount,
            isFree: priceQav <= 0,
            isLiveStreamed: isLiveStreamed,
            liveStreamUrl: streamLink.isEmpty ? nil : streamLink,
            status: status,
            schedule: schedule,
            collaborators: collaborators,
            creatorUsername: stringValue(dict["creatorUsername"]) ?? "",
            categoryRaw: rawCategory,
            mediaType: stringValue(dict["mediaType"]) ?? "image",
            eventType: eventType,
            accessType: accessType,
            eventDateText: dateText,
            eventTime: timeText,
            eventTimestamp: timestamp,
            onlinePlatform: onlinePlatform,
            paymentMethod: paymentMethod,
            priceQav: priceQav,
            purchaseLink: stringValue(dict["purchaseLink"]) ?? "",
            createdAt: doubleValue(dict["createdAt"]),
            rawStatus: rawStatus
        )
    }

    // MARK: - Parseo `UserEventTickets/{uid}/{ticketId}` → UserEventTicketModel
    static func parseTicket(key: String, dict: [String: Any]) -> UserEventTicketModel? {
        let eventId = stringValue(dict["eventId"]) ?? ""
        guard !eventId.isEmpty else { return nil }
        return UserEventTicketModel(
            ticketId: stringValue(dict["ticketId"]) ?? key,
            eventId: eventId,
            eventTitle: stringValue(dict["eventTitle"]) ?? "",
            eventCategory: stringValue(dict["eventCategory"]) ?? "",
            eventDateText: stringValue(dict["eventDate"]) ?? "",
            eventTime: stringValue(dict["eventTime"]) ?? "",
            eventTimestamp: doubleValue(dict["eventTimestamp"]),
            eventLocation: stringValue(dict["eventLocation"]) ?? "",
            eventCoverUrl: stringValue(dict["eventCoverUrl"]),
            eventType: stringValue(dict["eventType"]) ?? "presencial",
            userId: stringValue(dict["userId"]) ?? "",
            userName: stringValue(dict["userName"]) ?? "",
            userUsername: stringValue(dict["userUsername"]) ?? "",
            userPhoto: stringValue(dict["userPhoto"]),
            creatorId: stringValue(dict["creatorId"]) ?? "",
            pricePaidQav: doubleValue(dict["pricePaidQav"]),
            paymentMethod: stringValue(dict["paymentMethod"]) ?? "free",
            qrPayload: stringValue(dict["qrPayload"]) ?? "",
            purchasedAtMs: doubleValue(dict["purchasedAt"]),
            checkedIn: coerceBool(dict["checkedIn"]),
            checkedInAtMs: doubleValue(dict["checkedInAt"])
        )
    }

    // MARK: - Creación de evento (esquema completo de CreateEventActivity.java)
    /// Publica en `ArtisticEvents/{pushKey}` con el mismo esquema que Android.
    /// `eventDate` se escribe SIEMPRE en los tres formatos: legible, "HH:mm" y `eventTimestamp` (long).
    public func createEvent(
        title: String,
        description: String,
        categoryRaw: String,
        eventDate: Date,
        venueName: String,
        address: String = "",
        isFree: Bool,
        priceQav: Double,
        maxCapacity: Int,
        coverUrl: String = "",
        schedule: [EventScheduleItem] = [],
        collaborators: [EventCollaboratorItem] = [],
        completion: @escaping (Result<ArtisticEventModel, String>) -> Void
    ) {
        #if canImport(FirebaseDatabase)
        guard !isCreating else {
            completion(.failure("Ya se está publicando un evento, espera un momento."))
            return
        }
        guard let uid = FirebaseService.shared.authenticatedUid else {
            completion(.failure("Necesitas una sesión activa para publicar eventos."))
            return
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            completion(.failure("El título del evento no puede estar vacío."))
            return
        }

        isCreating = true
        let root = Database.database().reference()
        let eventsRef = root.child("ArtisticEvents")
        let eventId = eventsRef.push().key ?? "evt_\(Int(Date().timeIntervalSince1970 * 1000))"
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let location: String
        if address.isEmpty {
            location = venueName
        } else if venueName.isEmpty {
            location = address
        } else {
            location = "\(venueName), \(address)"
        }

        // Lee el perfil del creador, igual que saveEventToDatabase() en Android.
        root.child("Users").child(uid).observeSingleEvent(of: .value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                let dict = snapshot.value as? [String: Any] ?? [:]
                let cached = FirebaseService.shared.currentUser
                let creatorName = EventsService.stringValue(dict["name"]) ?? cached?.name ?? "Artista"
                let creatorUsername = EventsService.stringValue(dict["username"]) ?? cached?.username ?? ""
                let creatorPhoto = EventsService.stringValue(dict["photo"]) ?? cached?.image ?? ""

                let scheduleDicts: [[String: Any]] = schedule.map { item in
                    [
                        "id": item.id,
                        "date": item.date,
                        "time": item.timeString,
                        "timestamp": Int64(item.timestamp),
                        "accessType": item.accessType.isEmpty ? "libre" : item.accessType,
                        "title": item.activityTitle
                    ]
                }
                let collaboratorDicts: [[String: Any]] = collaborators.map { item in
                    [
                        "uid": item.uid,
                        "name": item.name,
                        "username": item.username,
                        "photo": item.avatarUrl ?? "",
                        "role": item.role,
                        "isAppUser": item.isAppUser
                    ]
                }

                let eventDict: [String: Any] = [
                    "id": eventId,
                    "creatorId": uid,
                    "creatorName": creatorName,
                    "creatorUsername": creatorUsername,
                    "creatorPhoto": creatorPhoto,
                    "title": cleanTitle,
                    "description": description,
                    "category": categoryRaw,
                    "coverUrl": coverUrl,
                    "mediaType": "image",
                    "eventType": "presencial",
                    "accessType": "publico",
                    "eventDate": EventsService.readableDateFormatter.string(from: eventDate),
                    "eventTime": EventsService.timeFormatter.string(from: eventDate),
                    "eventTimestamp": Int64(eventDate.timeIntervalSince1970 * 1000),
                    "location": location,
                    "latitude": 0.0,
                    "longitude": 0.0,
                    "onlinePlatform": "",
                    "onlineStreamLink": "",
                    "collaborators": collaboratorDicts,
                    "schedule": scheduleDicts,
                    "paymentMethod": isFree ? "free" : "qav",
                    "priceQav": isFree ? 0.0 : priceQav,
                    "purchaseLink": "",
                    "maxCapacity": maxCapacity,
                    "registeredCount": 0,
                    "createdAt": nowMillis,
                    "status": "active"
                ]

                eventsRef.child(eventId).setValue(eventDict) { [weak self] error, _ in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.isCreating = false
                        if let error = error {
                            completion(.failure("No se pudo publicar el evento: \(error.localizedDescription)"))
                            return
                        }
                        self.rawEvents[eventId] = eventDict
                        self.rebuildEvents()
                        if let model = EventsService.parseEvent(key: eventId, dict: eventDict) {
                            completion(.success(model))
                        } else {
                            completion(.failure("El evento se publicó pero no se pudo leer. Revisa la cartelera."))
                        }
                    }
                }
            }
        }
        #else
        completion(.failure("Firebase no disponible en esta compilación."))
        #endif
    }

    // MARK: - Compra / inscripción a una entrada (EventTicketManager.java)
    /// Flujo en vivo:
    ///  1. Relee el evento real (aforo, precio, estado) → "Evento agotado" / cancelado.
    ///  2. Relee `Balance/{uid}/balance` → saldo insuficiente en español si no alcanza.
    ///  3. Descuenta al comprador y abona al creador con `updateChildValues` (sin transacciones).
    ///  4. Escribe la entrada en AMBOS nodos (`EventTickets` + `UserEventTickets`).
    ///  5. `registeredCount` = lectura actual + 1 con `setValue`.
    ///  6. Notifica al creador (`Users/{creatorId}/Notifications`).
    public func purchaseTicket(
        _ event: ArtisticEventModel,
        completion: @escaping (Result<UserEventTicketModel, String>) -> Void
    ) {
        #if canImport(FirebaseDatabase)
        guard !isPurchasing else {
            completion(.failure("Ya hay una compra en proceso, espera un momento."))
            return
        }
        guard let uid = FirebaseService.shared.authenticatedUid else {
            completion(.failure("Necesitas una sesión activa para comprar entradas."))
            return
        }
        guard event.status != .cancelled else {
            completion(.failure("Este evento fue cancelado por el organizador."))
            return
        }

        isPurchasing = true
        // Envoltura "solo una vez": el callback real y el timeout de seguridad
        // compiten por completar; gana el primero y `isPurchasing` siempre se libera.
        var didFinish = false
        let finish: (Result<UserEventTicketModel, String>) -> Void = { result in
            guard !didFinish else { return }
            didFinish = true
            self.isPurchasing = false
            completion(result)
        }
        // Timeout de seguridad (W3): si el callback de RTDB no vuelve, no dejamos la UI bloqueada.
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            Task { @MainActor in
                finish(.failure("El servidor tardó demasiado en responder. Revisa \"Mis Boletos\" por si la entrada ya se generó."))
            }
        }
        let root = Database.database().reference()

        // 1) Estado real del evento en RTDB.
        root.child("ArtisticEvents").child(event.id).observeSingleEvent(of: .value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                guard let eventDict = snapshot.value as? [String: Any],
                      let freshEvent = EventsService.parseEvent(key: event.id, dict: eventDict) else {
                    self.isPurchasing = false
                    finish(.failure("No se pudo leer el evento en el servidor. Inténtalo de nuevo."))
                    return
                }
                if freshEvent.status == .cancelled {
                    self.isPurchasing = false
                    finish(.failure("Este evento fue cancelado por el organizador."))
                    return
                }
                if freshEvent.status == .completed {
                    self.isPurchasing = false
                    finish(.failure("Este evento ya finalizó."))
                    return
                }
                if freshEvent.isSoldOut {
                    self.isPurchasing = false
                    finish(.failure("Evento agotado: el aforo está completo (\(freshEvent.ticketsSold)/\(freshEvent.totalCapacity))."))
                    return
                }

                // 2) Saldo QAV del comprador (mismo nodo que usa Android).
                root.child("Balance").child(uid).child("balance").observeSingleEvent(of: .value) { [weak self] balanceSnap in
                    Task { @MainActor in
                        guard let self = self else { return }
                        let balance = EventsService.doubleValue(balanceSnap.value)
                        if freshEvent.needsQavPayment && balance < freshEvent.priceQav {
                            self.isPurchasing = false
                            finish(.failure(String(
                                format: "Saldo QAV insuficiente para adquirir esta entrada (%.2f QAV requeridos). Tu saldo actual es de %.2f QAV.",
                                freshEvent.priceQav,
                                balance
                            )))
                            return
                        }
                        // 3) Perfil del comprador (misma lectura que EventTicketManager.java).
                        self.purchaseWithProfile(
                            freshEvent: freshEvent,
                            eventDict: eventDict,
                            buyerUid: uid,
                            buyerBalance: balance,
                            completion: finish
                        )
                    }
                }
            }
        }
        #else
        completion(.failure("Firebase no disponible en esta compilación."))
        #endif
    }

    #if canImport(FirebaseDatabase)
    private func purchaseWithProfile(
        freshEvent: ArtisticEventModel,
        eventDict: [String: Any],
        buyerUid: String,
        buyerBalance: Double,
        completion: @escaping (Result<UserEventTicketModel, String>) -> Void
    ) {
        let root = Database.database().reference()
        root.child("Users").child(buyerUid).observeSingleEvent(of: .value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                let dict = snapshot.value as? [String: Any] ?? [:]
                let cached = FirebaseService.shared.currentUser
                let name = EventsService.stringValue(dict["name"]) ?? cached?.name ?? "Usuario"
                let username = EventsService.stringValue(dict["username"]) ?? cached?.username ?? ""
                let photo = EventsService.stringValue(dict["photo"]) ?? cached?.image ?? ""
                self.executePurchase(
                    freshEvent: freshEvent,
                    eventDict: eventDict,
                    buyerUid: buyerUid,
                    buyerName: name.isEmpty ? "Usuario" : name,
                    buyerUsername: username,
                    buyerPhoto: photo,
                    buyerBalance: buyerBalance,
                    completion: completion
                )
            }
        }
    }

    private func executePurchase(
        freshEvent: ArtisticEventModel,
        eventDict: [String: Any],
        buyerUid: String,
        buyerName: String,
        buyerUsername: String,
        buyerPhoto: String,
        buyerBalance: Double,
        completion: @escaping (Result<UserEventTicketModel, String>) -> Void
    ) {
        let root = Database.database().reference()
        let creatorId = freshEvent.organizerId
        let chargePrice: Double = freshEvent.needsQavPayment ? freshEvent.priceQav : 0
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let suffix = buyerUid.prefix(min(5, buyerUid.count))
        let ticketId = "tkt_\(nowMillis)_\(suffix)"

        // 1) Entrada con el mismo esquema que buildTicket() de EventTicketManager.java.
        let eventDateText = freshEvent.eventDateText.isEmpty
            ? EventsService.readableDateFormatter.string(from: freshEvent.eventDate)
            : freshEvent.eventDateText
        let eventTimeText = freshEvent.eventTime.isEmpty
            ? EventsService.timeFormatter.string(from: freshEvent.eventDate)
            : freshEvent.eventTime
        let eventLocation: String
        if freshEvent.isOnlineEvent {
            eventLocation = freshEvent.onlinePlatform.isEmpty ? "Online" : "Online: \(freshEvent.onlinePlatform)"
        } else {
            eventLocation = freshEvent.venueName
        }

        let ticket: [String: Any] = [
            "ticketId": ticketId,
            "eventId": freshEvent.id,
            "eventTitle": freshEvent.title,
            "eventCategory": freshEvent.categoryDisplayName,
            "eventDate": eventDateText,
            "eventTime": eventTimeText,
            "eventTimestamp": Int64(freshEvent.eventTimestamp),
            "eventLocation": eventLocation,
            "eventCoverUrl": freshEvent.bannerUrl ?? "",
            "eventType": freshEvent.eventType,
            "userId": buyerUid,
            "userName": buyerName,
            "userUsername": buyerUsername,
            "userPhoto": buyerPhoto,
            "creatorId": creatorId,
            "pricePaidQav": chargePrice,
            "paymentMethod": chargePrice > 0 ? "qav" : "free",
            "qrPayload": "PROVIWEB_TICKET:\(freshEvent.id):\(ticketId):\(buyerUid)",
            "purchasedAt": nowMillis,
            "checkedIn": false,
            "checkedInAt": Int64(0)
        ]

        // 2) Escritura ATÓMICA multi-ruta: entradas + registeredCount + pagos en UNA sola
        //    `updateChildValues` (aparecen a la vez o ninguna) — nunca se debita el
        //    saldo sin llegar a emitir la entrada).
        let newCount = freshEvent.ticketsSold + 1
        let commitPurchase: (Double) -> Void = { creatorBalance in
            var updates: [String: Any] = [
                "EventTickets/\(freshEvent.id)/\(ticketId)": ticket,
                "UserEventTickets/\(buyerUid)/\(ticketId)": ticket,
                "ArtisticEvents/\(freshEvent.id)/registeredCount": newCount
            ]
            if chargePrice > 0 {
                // Cargo al comprador y abono al creador (Balance/{uid}/balance, String con 2 decimales).
                updates["Balance/\(buyerUid)/balance"] = String(format: "%.2f", buyerBalance - chargePrice)
                if !creatorId.isEmpty && creatorId != buyerUid {
                    updates["Balance/\(creatorId)/balance"] = String(format: "%.2f", creatorBalance + chargePrice)
                }
            }
            root.updateChildValues(updates) { [weak self] error, _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    if let error = error {
                        self.isPurchasing = false
                        completion(.failure("No se pudo generar la entrada: \(error.localizedDescription)"))
                        return
                    }

                    if chargePrice > 0 {
                        // Refleja el nuevo saldo en la cartera visible de la app
                        // (`balanceQav` es el espejo local de `Balance/{uid}/balance`).
                        FirebaseService.shared.walletBalance.balanceQav = buyerBalance - chargePrice
                    }

                    var localDict = self.rawEvents[freshEvent.id] ?? eventDict
                    localDict["registeredCount"] = newCount
                    self.rawEvents[freshEvent.id] = localDict
                    self.rebuildEvents()

                    // 3) Notificación al creador (mismo formato que AdapterPost.java:1554).
                    self.notifyCreatorPurchase(
                        eventId: freshEvent.id,
                        creatorId: creatorId,
                        buyerUid: buyerUid,
                        buyerName: buyerName,
                        eventTitle: freshEvent.title,
                        price: chargePrice
                    )

                    self.isPurchasing = false
                    if let model = EventsService.parseTicket(key: ticketId, dict: ticket) {
                        completion(.success(model))
                    } else {
                        completion(.failure("Entrada generada. Revisa \"Mis Boletos\" para verla."))
                    }
                }
            }
        }

        if chargePrice > 0, !creatorId.isEmpty, creatorId != buyerUid {
            root.child("Balance").child(creatorId).child("balance").observeSingleEvent(of: .value) { creatorSnap in
                Task { @MainActor in
                    commitPurchase(EventsService.doubleValue(creatorSnap.value))
                }
            }
        } else {
            commitPurchase(0)
        }
    }

    private func notifyCreatorPurchase(
        eventId: String,
        creatorId: String,
        buyerUid: String,
        buyerName: String,
        eventTitle: String,
        price: Double
    ) {
        guard !creatorId.isEmpty, creatorId != buyerUid else { return }
        let ts = "\(Int(Date().timeIntervalSince1970 * 1000))"
        let notificationTitle: String
        let notificationText: String
        if price > 0 {
            notificationTitle = "🎟️ Nueva entrada vendida"
            notificationText = "\(buyerName) ha comprado una entrada a tu evento \(eventTitle) ($\(String(format: "%.2f", price)) QAV)"
        } else {
            notificationTitle = "🎟️ Nuevo registro a tu evento"
            notificationText = "\(buyerName) se ha registrado a tu evento \(eventTitle) (entrada gratis)"
        }
        let notification: [String: Any] = [
            "pId": eventId,
            "timestamp": ts,
            "pText": notificationText,
            "notification": notificationTitle,
            "sId": buyerUid,
            "sName": buyerName,
            "type": "event_ticket"
        ]
        let root = Database.database().reference()
        root.child("Users").child(creatorId).child("Notifications").child(ts).setValue(notification)
        root.child("Users").child(creatorId).child("Count").child(ts).setValue(true)
    }
    #endif
}

// MARK: - Artistic Events Feed & Explorer View
public struct EventsHomeView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var eventsService = EventsService.shared
    @Environment(\.presentationMode) var presentationMode
    
    /// `true` cuando la cartelera se lee del nodo `ArtisticEvents` (sesión real);
    /// en modo demo se mantiene el seed local de abajo.
    private let usesLiveEvents = FirebaseService.shared.canWriteToCloud

    @State private var selectedCategory: ArtisticEventModel.EventCategory? = nil
    @State private var searchText: String = ""
    @State private var isCreateEventPresented: Bool = false
    @State private var selectedEventForDetails: ArtisticEventModel? = nil
    @State private var isMyTicketsPresented: Bool = false
    
    @State private var events: [ArtisticEventModel] = [
        ArtisticEventModel(
            id: "event_1",
            title: "Gala de Violín Clásico y Huapangos",
            organizerId: "user_demo_violin_001",
            organizerName: "Israel Violín & Orquesta Proviweb",
            organizerDp: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
            description: "Una velada inolvidable combinando obras virtuosas de Paganini, Bach y los más bellos huapangos y sones arreglados para orquesta de cámara.",
            bannerUrl: "https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=800&auto=format&fit=crop&q=60",
            venueName: "Sala Nezahualcóyotl - Centro Cultural Universitario",
            address: "Insurgentes Sur 3000, Coyoacán, CDMX",
            eventDate: Date().addingTimeInterval(86400 * 3),
            durationHours: 2.5,
            category: .concert,
            ticketPriceUSD: 30.0,
            ticketPriceDiamonds: 180,
            totalCapacity: 350,
            ticketsSold: 195,
            isLiveStreamed: true,
            status: .upcoming,
            schedule: [
                EventScheduleItem(timeString: "19:00", activityTitle: "Apertura de Puertas & Copa de Bienvenida"),
                EventScheduleItem(timeString: "19:30", activityTitle: "Concierto en Mi Menor - Mendelssohn", artistName: "Israel Violín"),
                EventScheduleItem(timeString: "20:30", activityTitle: "Sones Huastecos y Huapangos", artistName: "Ensamble Huasteco Proviweb"),
                EventScheduleItem(timeString: "21:30", activityTitle: "Clausura y Sesión de Preguntas con Artistas")
            ],
            collaborators: [
                EventCollaboratorItem(name: "Israel Violín", role: "Solista Principal", avatarUrl: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60"),
                EventCollaboratorItem(name: "Elena Morales", role: "Directora Huésped", avatarUrl: "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=500&auto=format&fit=crop&q=60")
            ]
        ),
        ArtisticEventModel(
            id: "event_2",
            title: "Masterclass Internacional de Violín: Técnica y Postura",
            organizerId: "conservatorio_cdmx",
            organizerName: "Academia Filarmónica PROVIWEB",
            organizerDp: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
            description: "Clase magistral interactiva con retroalimentación de IA de Proviweb y revisión en vivo de postura de arco, afinación y presencia escénica.",
            bannerUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&auto=format&fit=crop&q=60",
            venueName: "Auditorio Silvestre Revueltas & En Línea",
            address: "Av. Paseo de la Reforma s/n, CDMX",
            eventDate: Date().addingTimeInterval(86400 * 7),
            durationHours: 3.0,
            category: .masterclass,
            ticketPriceUSD: 20.0,
            ticketPriceDiamonds: 120,
            totalCapacity: 100,
            ticketsSold: 72,
            isLiveStreamed: true,
            status: .upcoming
        )
    ]
    
    public init() {}
    
    /// Sesión real → nodo `ArtisticEvents` (orden Android por eventTimestamp);
    /// modo demo → seed local.
    public var displayEvents: [ArtisticEventModel] {
        usesLiveEvents ? eventsService.events : events
    }
    
    public var filteredEvents: [ArtisticEventModel] {
        displayEvents.filter { event in
            let matchesCategory = selectedCategory == nil || event.category == selectedCategory
            let matchesSearch = searchText.isEmpty || event.title.localizedCaseInsensitiveContains(searchText) || event.venueName.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Bar
                    HStack(spacing: 12) {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(theme.textPrimary)
                        }
                        
                        Text("Eventos Artísticos")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                        
                        Spacer()
                        
                        Button(action: { isMyTicketsPresented = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "ticket.fill")
                                    .foregroundColor(AppColors.gold)
                                Text("Mis Boletos")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.gold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.gold.opacity(0.15))
                            .cornerRadius(12)
                        }
                        
                        Button(action: { isCreateEventPresented = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(theme.cardColor)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(theme.textSecondary)
                        TextField("Buscar eventos, recitales, conciertos...", text: $searchText)
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(10)
                    .background(theme.backgroundColor)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    
                    // Category Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button(action: { selectedCategory = nil }) {
                                Text("Todos")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(selectedCategory == nil ? .white : theme.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == nil ? AppColors.primary : theme.cardColor)
                                    .cornerRadius(16)
                            }
                            
                            ForEach(ArtisticEventModel.EventCategory.allCases, id: \.self) { cat in
                                Button(action: { selectedCategory = cat }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: cat.icon)
                                        Text(cat.rawValue)
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(selectedCategory == cat ? .white : theme.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == cat ? AppColors.primary : theme.cardColor)
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    
                    // Events List
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredEvents) { event in
                                EventCardItem(event: event) {
                                    selectedEventForDetails = event
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Sesión real → observa `ArtisticEvents` y `UserEventTickets/{uid}`.
                if usesLiveEvents {
                    eventsService.ensureStarted()
                }
            }
            .sheet(isPresented: $isCreateEventPresented) {
                CreateEventView { newEvent in
                    // En vivo la lista la alimenta el servicio (nodo `ArtisticEvents`);
                    // en demo se inserta el evento local.
                    guard !usesLiveEvents else { return }
                    events.insert(newEvent, at: 0)
                }
            }
            .sheet(item: $selectedEventForDetails) { event in
                EventDetailsView(event: event)
            }
            .sheet(isPresented: $isMyTicketsPresented) {
                MyTicketsListView()
            }
        }
    }
}

// MARK: - Event Card Item
struct EventCardItem: View {
    let event: ArtisticEventModel
    let onTap: () -> Void
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Banner Image
                ZStack(alignment: .topTrailing) {
                    if let banner = event.bannerUrl, let url = URL(string: banner) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.2))
                        }
                        .frame(height: 160)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(AppColors.primaryGradient)
                            .frame(height: 160)
                            .overlay(
                                Image(systemName: "music.mic")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                    
                    // Category Badge
                    HStack(spacing: 4) {
                        Image(systemName: event.category.icon)
                        Text(event.categoryDisplayName)
                    }
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding(12)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .foregroundColor(AppColors.primary)
                            .font(.caption)
                        Text(event.eventDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                        
                        Spacer()
                        
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(AppColors.primary)
                            .font(.caption)
                        Text(event.venueName)
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.2))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Precio Entrada")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                            
                            HStack(spacing: 6) {
                                Text(event.isFree ? "Gratis" : String(format: "$%.2f %@", event.ticketPriceUSD, event.needsQavPayment ? "QAV" : "USD"))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                                
                                if !event.isFree {
                                    Text("(\(event.ticketPriceDiamonds) 💎)")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.gold)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("\(event.ticketsSold)/\(event.totalCapacity)")
                                .font(.caption2)
                                .foregroundColor(event.isSoldOut || event.status == .cancelled ? AppColors.errorRed : theme.textSecondary)
                            
                            if event.isSoldOut {
                                Text("Agotado")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.errorRed)
                            }
                            
                            Text("Ver Detalles")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(AppColors.primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(14)
            }
            .background(theme.cardColor)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
