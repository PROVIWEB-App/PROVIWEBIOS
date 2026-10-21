import Foundation
import SwiftUI
import MapKit
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Musical Hub Service (RTDB: nodo `Users` filtrado `musicservice == "yes"` en cliente)
//
// Réplica de Android:
//   MapMarketActivity.java:360-370  -> badges: verified / musicservice / verifiedprofesor /
//                                      verifiedentidad = String "yes" (campos de `Users`)
//   ModelUser.java                  -> name, username, location, photo, instrument, generoMusic,
//                                      basePrice, experience, rating, ratingCount, musicservice
//   LocationActivity.java:2686-2784 -> el botón "Solicitar Cotización" NO usa un nodo de
//                                      solicitudes: escribe directamente la cotización con
//                                      push key en `CotizacionBanda` + `CotizacionComprador`.
//   MusicalQuoteRepository.java:145-205 -> escritura moderna: `MusicalQuotes` (push key) +
//                                      índices ClientQuotes/GroupQuotes/RequestQuotes +
//                                      réplica legada, CADA cosa en UN updateChildren multi-ruta.
@MainActor
final class MusicalHubService: ObservableObject {
    static let shared = MusicalHubService()

    /// Agrupaciones: usuarios con `musicservice == "yes"` (MapMarketActivity.java:362).
    @Published private(set) var groups: [MusicalGroupProfileModel] = []

    private var rawUsers: [String: [String: Any]] = [:]
    private var isStarted = false
    #if canImport(FirebaseDatabase)
    private var usersObserver: (handle: DatabaseHandle, remove: () -> Void)?
    #endif

    private init() {}

    func ensureStarted() {
        guard !isStarted, FirebaseService.shared.canWriteToCloud else { return }
        isStarted = true
        #if canImport(FirebaseDatabase)
        observeMusicServices()
        #endif
    }

    #if canImport(FirebaseDatabase)
    private func observeMusicServices() {
        let ref = Database.database().reference().child("Users")
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var next: [String: [String: Any]] = [:]
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    next[snap.key] = dict
                }
                self.rawUsers = next
                self.rebuild()
            }
        }
        usersObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }
    #endif

    private func rebuild() {
        // MapMarketActivity.java:362: `musicservice == "yes"` identifica a los prestadores de
        // servicio musical (mariachis/agrupaciones). Filtrado en cliente.
        let mapped: [MusicalGroupProfileModel] = rawUsers.compactMap { uid, dict in
            guard MusicalHubService.isMusicService(dict) else { return nil }
            return MusicalHubService.parseGroup(uid: uid, dict: dict)
        }
        groups = mapped.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func isMusicService(_ dict: [String: Any]) -> Bool {
        stringValue(dict["musicservice"]) == "yes"
    }

    static func parseGroup(uid: String, dict: [String: Any]) -> MusicalGroupProfileModel {
        let name = stringValue(dict["name"]) ?? ""
        let username = stringValue(dict["username"]) ?? ""
        let displayName = name.isEmpty ? (username.isEmpty ? "Agrupación Musical" : username) : name
        let instrument = stringValue(dict["instrument"]) ?? ""
        let genre = stringValue(dict["generoMusic"]) ?? ""
        let photo = stringValue(dict["photo"]) ?? ""
        let location = stringValue(dict["location"]) ?? ""
        let verified = stringValue(dict["verified"]) == "yes"
            || stringValue(dict["verifiedprofesor"]) == "yes"
            || stringValue(dict["verifiedprofesorart"]) == "yes"
            || stringValue(dict["verifiedentidad"]) == "yes"
        let basePrice = numberValue(dict["basePrice"]) ?? 250.0
        let experience = Int(numberValue(dict["experience"]) ?? 12)

        return MusicalGroupProfileModel(
            id: uid,
            name: displayName,
            directorName: username.isEmpty ? displayName : username,
            directorId: uid,
            groupType: groupType(from: "\(instrument) \(genre)"),
            location: location.isEmpty ? "Ubicación no especificada" : location,
            avatarUrl: photo.isEmpty ? nil : photo,
            rating: numberValue(dict["rating"]) ?? 0.0,
            reviewsCount: Int(numberValue(dict["ratingCount"]) ?? 0),
            basePricePerHourUSD: basePrice,
            experienceYears: experience,
            isVerified: verified
        )
    }

    static func groupType(from text: String) -> MusicalGroupProfileModel.GroupType {
        let text = text.lowercased()
        if text.contains("mariachi") { return .mariachi }
        if text.contains("banda") { return .bandaSinaloense }
        if text.contains("cuarteto") || text.contains("cuerda") { return .cuartetoCuerdas }
        if text.contains("orquesta") { return .orquestaCamara }
        if text.contains("jazz") { return .jazzEnsemble }
        if text.contains("trio") || text.contains("trío") { return .trioRomantico }
        if text.contains("violin") || text.contains("violín") { return .violinSolista }
        return .grupoVersatil
    }

    // MARK: - Envío de cotización (escritura atómica multi-ruta)
    /// MusicalQuoteRepository.executeSendQuote:161-192 + notificación al dueño (NotificationHelper).
    /// quoteId = push key de `MusicalQuotes` (igual que MusicalQuoteRepository.java:115-116).
    func sendQuote(group: MusicalGroupProfileModel,
                   eventType: String,
                   eventDate: Date,
                   hours: Double,
                   venueAddress: String,
                   notes: String,
                   onDone: @escaping (Bool) -> Void) {
        #if canImport(FirebaseDatabase)
        guard FirebaseService.shared.canWriteToCloud,
              let clientId = FirebaseService.shared.authenticatedUid else {
            onDone(false)
            return
        }
        let ownerUid = group.id
        guard !ownerUid.isEmpty,
              !venueAddress.trimmingCharacters(in: .whitespaces).isEmpty,
              let quoteId = Database.database().reference().child("MusicalQuotes").childByAutoId().key else {
            onDone(false)
            return
        }

        let root = Database.database().reference()
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let tsString = "\(millis)"
        let price = group.basePricePerHourUSD * hours
        let clientName = FirebaseService.shared.currentUser?.name ?? "Cliente PROVIWEB"
        let dateText = MusicalHubService.dateString(eventDate, format: "yyyy-MM-dd")
        let timeText = MusicalHubService.dateString(eventDate, format: "HH:mm")
        let formattedPrice = MusicalHubService.formattedMoney(price)

        // MusicalQuote.toMap() (MusicalQuote.java:132-159) — CADA campo del esquema nuevo.
        // Sin `ServiceRequests` no se escribe la clave `requestId` (repo:169-171 la omite).
        let quote: [String: Any] = [
            "id": quoteId,
            "groupId": ownerUid,                   // agrupación = usuario con `musicservice == "yes"`
            "groupName": group.name,
            "groupPhoto": group.avatarUrl ?? "",
            "ownerUid": ownerUid,
            "clientId": clientId,
            "clientName": clientName,
            "serviceId": "",
            "serviceName": eventType,
            "durationMinutes": Int(hours * 60),
            "musiciansCount": 1,
            "price": price,
            "transportIncluded": true,             // defaults del modelo Android
            "equipmentIncluded": true,
            "repertoireNotes": notes,
            "conditions": "",
            "observations": "",
            "validUntil": "",
            "status": "PENDING",
            "timestamp": millis,
            "eventDate": dateText,
            "eventTime": timeText,
            "eventAddress": venueAddress
        ]

        // Réplica legado (MusicalQuoteRepository.java:174-192), mismas claves que lee
        // MyQuotesActivity.java:83 / AdapterCotizacionComprador.
        let legacy: [String: Any] = [
            "id": clientId,
            "idCotizante": clientId,
            "nameGrupo": group.name,
            "para": clientName,
            "precio": formattedPrice,
            "plan": eventType,
            "fecha": dateText,
            "hora": timeText,
            "direccion": venueAddress,
            "lista": notes,
            "aceptada": "",                        // cadena vacía = pendiente (repo:185)
            "confirmada": "no",
            "status": "pending"
        ]

        var updates: [String: Any] = [
            "MusicalQuotes/\(quoteId)": quote,
            "ClientQuotes/\(clientId)/\(quoteId)": true,
            "GroupQuotes/\(ownerUid)/\(quoteId)": true,
            "CotizacionBanda/\(ownerUid)/\(quoteId)": legacy,
            "CotizacionComprador/\(clientId)/\(quoteId)": legacy
        ]
        // RequestQuotes SÓLO se escribe si existe un `requestId` real (repo:169-171).

        // Notificación al dueño del grupo (Users/{ownerUid}/Notifications/{ts}), formato iOS
        // ya usado en el proyecto (JobBoardView / EventsHomeView).
        if ownerUid != clientId {
            let notification: [String: Any] = [
                "pId": quoteId,
                "timestamp": tsString,
                "pText": "Nueva cotización para tu agrupación \(group.name): \(formattedPrice)",
                "notification": "🎼 Nueva cotización",
                "sId": clientId,
                "sName": clientName,
                "type": "quote"
            ]
            updates["Users/\(ownerUid)/Notifications/\(tsString)"] = notification
            updates["Users/\(ownerUid)/Count/\(tsString)"] = true
        }

        // Una sola escritura multi-ruta: se publica la cotización + índices + réplicas +
        // notificación en bloque. Nunca `runTransaction`.
        root.updateChildValues(updates) { error, _ in
            Task { @MainActor in
                onDone(error == nil)
            }
        }
        #else
        onDone(false)
        #endif
    }

    // MARK: - Helpers
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

    static func dateString(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    /// Réplica de MusicalQuote.getFormattedPrice() ("$%,.0f", MusicalQuote.java:128-130).
    static func formattedMoney(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let amount = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "$" + amount
    }
}

// MARK: - Musical Hub: Explore Mariachis, Bands & Ensembles
public struct MusicalHubView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var service = MusicalHubService.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedType: MusicalGroupProfileModel.GroupType? = nil
    @State private var searchText: String = ""
    @State private var isQuotesManagerPresented: Bool = false
    @State private var selectedGroupForQuote: MusicalGroupProfileModel? = nil

    /// `true` cuando la lista proviene de `Users` (musicservice == "yes") en la nube (sesión real).
    private let usesLiveHub: Bool = FirebaseService.shared.canWriteToCloud

    /// Seed de demostración (sólo se muestra en modo demo, sin sesión real).
    @State private var seedGroups: [MusicalGroupProfileModel] = [
        MusicalGroupProfileModel(
            id: "group_1",
            name: "Mariachi Sinfónico Real de México",
            directorName: "Mtro. Alejandro Morales",
            directorId: "director_01",
            groupType: .mariachi,
            location: "Ciudad de México (Cobertura CDMX y EdoMéx)",
            coverageRadiusKm: 60,
            membersCount: 10,
            avatarUrl: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
            coverBannerUrl: "https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=800&auto=format&fit=crop&q=60",
            rating: 5.0,
            reviewsCount: 84,
            basePricePerHourUSD: 300.0,
            experienceYears: 18,
            repertoireCount: 450,
            isVerified: true,
            packages: [
                MusicalServicePackageModel(
                    title: "Serenata Express (7 Canciones)",
                    durationHours: 0.75,
                    musiciansCount: 8,
                    description: "Ideal para aniversarios y cumpleaños. Traje de gala negro y plata.",
                    priceUSD: 220.0
                ),
                MusicalServicePackageModel(
                    title: "Hora Completa de Gala",
                    durationHours: 1.0,
                    musiciansCount: 10,
                    description: "Repertorio completo tradicional y moderno con trompetas y violines de primera.",
                    priceUSD: 300.0
                )
            ]
        ),
        MusicalGroupProfileModel(
            id: "group_2",
            name: "Cuarteto de Cuerdas Bellas Artes",
            directorName: "Elena Vargas",
            directorId: "director_02",
            groupType: .cuartetoCuerdas,
            location: "Guadalajara, Jalisco",
            coverageRadiusKm: 40,
            membersCount: 4,
            avatarUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=60",
            rating: 4.9,
            reviewsCount: 52,
            basePricePerHourUSD: 240.0,
            experienceYears: 10,
            repertoireCount: 220,
            isVerified: true,
            packages: [
                MusicalServicePackageModel(
                    title: "Música para Boda Religiosa o Civil",
                    durationHours: 1.5,
                    musiciansCount: 4,
                    description: "Canon de Pachelbel, Marcha Nupcial, arreglos pop y música clásica sacra.",
                    priceUSD: 350.0
                )
            ]
        ),
        MusicalGroupProfileModel(
            id: "group_3",
            name: "Banda La Sinaloense Imperial",
            directorName: "Gonzalo Beltrán",
            directorId: "director_03",
            groupType: .bandaSinaloense,
            location: "Mazatlán, Sinaloa",
            coverageRadiusKm: 100,
            membersCount: 14,
            avatarUrl: "https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&auto=format&fit=crop&q=60",
            rating: 4.8,
            reviewsCount: 41,
            basePricePerHourUSD: 450.0,
            experienceYears: 14,
            repertoireCount: 350,
            isVerified: true
        )
    ]

    public init() {}

    private var groups: [MusicalGroupProfileModel] {
        usesLiveHub ? service.groups : seedGroups
    }

    public var filteredGroups: [MusicalGroupProfileModel] {
        groups.filter { grp in
            let matchesType = selectedType == nil || grp.groupType == selectedType
            let matchesSearch = searchText.isEmpty ||
                grp.name.localizedCaseInsensitiveContains(searchText) ||
                grp.location.localizedCaseInsensitiveContains(searchText)

            return matchesType && matchesSearch
        }
    }

    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Bar
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(theme.textPrimary)
                        }

                        Text("Hub Musical: Agrupaciones")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)

                        Spacer()

                        Button(action: { isQuotesManagerPresented = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.plaintext.fill")
                                    .foregroundColor(AppColors.primary)
                                Text("Cotizaciones")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.primary.opacity(0.12))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(theme.cardColor)

                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(theme.textSecondary)
                        TextField("Buscar mariachis, cuartetos, bandas por ciudad...", text: $searchText)
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(10)
                    .background(theme.backgroundColor)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // Group Type Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button(action: { selectedType = nil }) {
                                Text("Todas")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(selectedType == nil ? .white : theme.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedType == nil ? AppColors.primary : theme.cardColor)
                                    .cornerRadius(16)
                            }

                            ForEach(MusicalGroupProfileModel.GroupType.allCases, id: \.self) { type in
                                Button(action: { selectedType = type }) {
                                    Text(type.rawValue)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedType == type ? .white : theme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedType == type ? AppColors.primary : theme.cardColor)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    // Groups List
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            if groups.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "person.3.sequence")
                                        .font(.system(size: 44))
                                        .foregroundColor(theme.textSecondary)
                                    Text("No hay agrupaciones con servicio musical disponibles por el momento.")
                                        .font(.subheadline)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(theme.textSecondary)
                                }
                                .padding(.top, 48)
                                .padding(.horizontal, 24)
                            } else if filteredGroups.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 36))
                                        .foregroundColor(theme.textSecondary)
                                    Text("Sin resultados para tu búsqueda o filtro.")
                                        .font(.subheadline)
                                        .foregroundColor(theme.textSecondary)
                                }
                                .padding(.top, 48)
                            }

                            ForEach(filteredGroups) { group in
                                MusicalGroupCardItem(group: group) {
                                    selectedGroupForQuote = group
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedGroupForQuote) { group in
                GroupQuoteRequestModal(group: group)
            }
            .sheet(isPresented: $isQuotesManagerPresented) {
                MusicalQuotesManagerView()
            }
            .onAppear {
                if usesLiveHub { service.ensureStarted() }
            }
        }
    }
}

// MARK: - Musical Group Card Item
struct MusicalGroupCardItem: View {
    let group: MusicalGroupProfileModel
    let onQuoteTapped: () -> Void
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarView(urlString: group.avatarUrl, size: 52, isVerified: group.isVerified)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(group.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.gold)
                            Text(String(format: "%.1f", group.rating))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textPrimary)
                            Text("(\(group.reviewsCount))")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                        }
                    }

                    Text("\(group.groupType.rawValue) • Director: \(group.directorName)")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                            .foregroundColor(AppColors.primary)
                        Text(group.location)
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                        .font(.caption2)
                    Text("\(group.membersCount) Integrantes")
                        .font(.caption2)
                }
                .foregroundColor(theme.textSecondary)

                HStack(spacing: 4) {
                    Image(systemName: "music.note.list")
                        .font(.caption2)
                    Text("\(group.repertoireCount)+ Temas")
                        .font(.caption2)
                }
                .foregroundColor(theme.textSecondary)

                HStack(spacing: 4) {
                    Image(systemName: "location.north.circle.fill")
                        .font(.caption2)
                    Text("Radio \(group.coverageRadiusKm) km")
                        .font(.caption2)
                }
                .foregroundColor(theme.textSecondary)
            }

            Divider()
                .background(Color.gray.opacity(0.2))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Desde")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)

                    Text(String(format: "$%.2f USD / hr", group.basePricePerHourUSD))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primary)
                }

                Spacer()

                Button(action: onQuoteTapped) {
                    Text("Solicitar Cotización")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.primary)
                        .cornerRadius(14)
                }
            }
        }
        .padding(14)
        .background(theme.cardColor)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Group Quote Request Modal
struct GroupQuoteRequestModal: View {
    let group: MusicalGroupProfileModel
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var eventType: String = "Serenata"
    @State private var eventDate: Date = Date().addingTimeInterval(86400 * 4)
    @State private var hours: Double = 1.0
    @State private var venueAddress: String = ""
    @State private var notes: String = ""
    @State private var isSending: Bool = false
    @State private var isSentAlertPresented: Bool = false

    let eventTypes = ["Serenata", "Cumpleaños", "Boda", "Aniversario", "Graduación", "Corporativo"]

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                Form {
                    Section(header: Text("Agrupación Musical")) {
                        Text(group.name)
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                        Text("Tarifa Base: \(String(format: "$%.2f USD / hr", group.basePricePerHourUSD))")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
                    }

                    Section(header: Text("Detalles del Evento")) {
                        Picker("Motivo del Evento", selection: $eventType) {
                            ForEach(eventTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }

                        DatePicker("Fecha y Hora", selection: $eventDate, in: Date()...)

                        Stepper("Duración: \(String(format: "%.1f", hours)) horas", value: $hours, in: 0.5...8.0, step: 0.5)

                        TextField("Dirección o Lugar del Evento", text: $venueAddress)

                        TextField("Canciones especiales o notas para el director", text: $notes)
                    }

                    Section(header: Text("Presupuesto Estimado")) {
                        HStack {
                            Text("Total Estimado:")
                            Spacer()
                            Text(String(format: "$%.2f USD", group.basePricePerHourUSD * hours))
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                        }
                    }

                    Section {
                        Button(action: sendQuote) {
                            Text(isSending ? "Enviando..." : "Enviar Solicitud de Cotización")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .disabled(venueAddress.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                        .listRowBackground(venueAddress.trimmingCharacters(in: .whitespaces).isEmpty || isSending ? Color.gray : AppColors.primary)
                    }
                }
            }
            .navigationTitle("Cotizar Servicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSentAlertPresented) {
                Alert(
                    title: Text("¡Cotización Enviada!"),
                    message: Text("El director de \(group.name) responderá a tu solicitud con la confirmación de fecha."),
                    dismissButton: .default(Text("Aceptar")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }

    /// LocationActivity.java escribe la cotización directamente (no usa nodo de solicitudes);
    /// aquí se replica con el esquema moderno completo: `MusicalQuotes` (push key) + índices
    /// `ClientQuotes`/`GroupQuotes` + réplicas `CotizacionBanda`/`CotizacionComprador` +
    /// notificación al dueño, en un único `updateChildValues` multi-ruta.
    private func sendQuote() {
        guard !isSending else { return }
        isSending = true
        MusicalHubService.shared.sendQuote(
            group: group,
            eventType: eventType,
            eventDate: eventDate,
            hours: hours,
            venueAddress: venueAddress,
            notes: notes
        ) { _ in
            // En modo demo (sin sesión real) la escritura es un no-op protegido por
            // `canWriteToCloud`; se muestra el aviso igual que el resto del proyecto.
            isSending = false
            isSentAlertPresented = true
        }
    }
}
