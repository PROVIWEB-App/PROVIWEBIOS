import Foundation
import SwiftUI
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Musical Quotes Service (RTDB: `CotizacionComprador/{uid}` + enriquecimiento `MusicalQuotes`)
//
// LECTURA de "mis cotizaciones": réplica literal de MyQuotesActivity.java:83 → lee
// `CotizacionComprador/{miUid}` (nodo legado). Se elige este nodo (y no `ClientQuotes/{uid}`)
// porque es exactamente lo que Android muestra en "Mis cotizaciones" y es el ÚNICO nodo que
// contiene las cotizaciones creadas por el flujo antiguo (LocationActivity.java:2703-2738),
// que NO escriben `MusicalQuotes` ni `ClientQuotes`.
// Para enriquecer cada cotización (groupId, duración, foto, notas) se lee `MusicalQuotes/{quoteId}`
// (escrito junto al legado por MusicalQuoteRepository.java:161-192 y por este módulo en iOS).
//
// ESCRITURA (confirmación): AdapterCotizacionBanda.java:389-397
//   CotizacionBanda/{ownerUid}/{id}    -> aceptada "yes" / status "accepted" / confirmada "yes"
//   MusicalQuotes/{id}/status          -> "ACCEPTED"
//   CotizacionComprador/{clientId}/{id}-> aceptada "yes" / status "accepted" / confirmada "yes"
@MainActor
final class MusicalQuotesService: ObservableObject {
    static let shared = MusicalQuotesService()

    @Published private(set) var quotes: [MusicalQuoteModel] = []

    private var rawLegacy: [String: [String: Any]] = [:]
    private var rawQuotes: [String: [String: Any]] = [:]
    private var requestedQuoteIds: Set<String> = []
    /// `quoteId -> ownerUid` resuelto desde `MusicalQuotes` (para escribir también en `CotizacionBanda`).
    private var ownerUids: [String: String] = [:]
    private var isStarted = false
    #if canImport(FirebaseDatabase)
    private var quotesObserver: (handle: DatabaseHandle, remove: () -> Void)?
    #endif

    private init() {}

    func ensureStarted() {
        guard !isStarted, FirebaseService.shared.canWriteToCloud else { return }
        isStarted = true
        #if canImport(FirebaseDatabase)
        observeClientQuotes()
        #endif
    }

    #if canImport(FirebaseDatabase)
    private func observeClientQuotes() {
        guard let uid = FirebaseService.shared.authenticatedUid else { return }
        // MyQuotesActivity.java:83: "mis cotizaciones" = CotizacionComprador/{uid}.
        let ref = Database.database().reference().child("CotizacionComprador").child(uid)
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var next: [String: [String: Any]] = [:]
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    next[snap.key] = dict
                }
                self.rawLegacy = next
                self.fetchModernQuotes()
                self.rebuild()
            }
        }
        quotesObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }

    /// MusicalQuoteRepository.loadQuotesList: una lectura puntual por `MusicalQuotes/{quoteId}`.
    private func fetchModernQuotes() {
        for quoteId in rawLegacy.keys where !requestedQuoteIds.contains(quoteId) {
            requestedQuoteIds.insert(quoteId)
            Database.database().reference().child("MusicalQuotes").child(quoteId)
                .observeSingleEvent(of: .value) { [weak self] snapshot in
                    Task { @MainActor in
                        guard let self = self else { return }
                        if let dict = snapshot.value as? [String: Any] {
                            self.rawQuotes[quoteId] = dict
                            if let owner = MusicalQuotesService.stringValue(dict["ownerUid"]), !owner.isEmpty {
                                self.ownerUids[quoteId] = owner
                            }
                        }
                        self.rebuild()
                    }
                }
        }
    }
    #endif

    private func rebuild() {
        let uid = FirebaseService.shared.authenticatedUid ?? ""
        let name = FirebaseService.shared.currentUser?.name ?? ""
        let mapped: [MusicalQuoteModel] = rawLegacy.compactMap { quoteId, legacy in
            MusicalQuotesService.buildQuote(quoteId: quoteId,
                                            legacy: legacy,
                                            modern: rawQuotes[quoteId],
                                            clientId: uid,
                                            clientName: name)
        }
        quotes = mapped.sorted { $0.createdAt > $1.createdAt }
    }

    static func buildQuote(quoteId: String,
                           legacy: [String: Any],
                           modern: [String: Any]?,
                           clientId: String,
                           clientName: String) -> MusicalQuoteModel {
        let modern = modern ?? [:]

        let groupName = stringValue(modern["groupName"])
            ?? stringValue(legacy["nameGrupo"])
            ?? "Agrupación Musical"
        let photo = stringValue(modern["groupPhoto"]) ?? ""
        let serviceName = stringValue(modern["serviceName"])
            ?? stringValue(legacy["plan"])
            ?? "Servicio musical"
        let address = stringValue(modern["eventAddress"])
            ?? stringValue(legacy["direccion"])
            ?? ""
        let notes = stringValue(modern["repertoireNotes"])
            ?? stringValue(legacy["lista"])
        let responseNotes = stringValue(modern["observations"])

        // `price` (double) del nodo nuevo; en el legado `precio` es texto tipo "$1,200".
        let price: Double
        if let modernPrice = numberValue(modern["price"]) {
            price = modernPrice
        } else {
            price = MusicalQuotesService.parseMoney(stringValue(legacy["precio"])) ?? 0
        }

        // `durationMinutes` (int) sólo existe en el nodo nuevo; el legado no lo guarda.
        let durationHours: Double
        if let minutes = numberValue(modern["durationMinutes"]) {
            durationHours = minutes / 60.0
        } else {
            durationHours = 1.0
        }

        let timestampMs = numberValue(modern["timestamp"]) ?? 0
        let createdAt: Date
        if timestampMs > 0 {
            createdAt = Date(timeIntervalSince1970: timestampMs / 1000)
        } else if let parsed = parseDate(stringValue(legacy["fecha"]), time: stringValue(legacy["hora"])) {
            createdAt = parsed
        } else {
            createdAt = Date(timeIntervalSince1970: 0)
        }

        let eventDate = parseDate(stringValue(modern["eventDate"]) ?? stringValue(legacy["fecha"]),
                                  time: stringValue(modern["eventTime"]) ?? stringValue(legacy["hora"]))
            ?? createdAt

        return MusicalQuoteModel(
            id: quoteId,
            groupId: stringValue(modern["groupId"]) ?? "",
            groupName: groupName,
            groupAvatar: photo.isEmpty ? nil : photo,
            clientId: clientId,
            clientName: clientName.isEmpty ? (stringValue(legacy["para"]) ?? "Cliente") : clientName,
            eventType: serviceName,
            eventDate: eventDate,
            venueAddress: address,
            durationHours: durationHours,
            quotedPriceUSD: price,
            status: mapStatus(legacyStatus: stringValue(legacy["status"]),
                              modernStatus: stringValue(modern["status"])),
            clientNotes: notes,
            responseNotes: responseNotes,
            createdAt: createdAt
        )
    }

    /// MyQuotesActivity.java:123-142 (legado) + MusicalQuoteRepository (nodo nuevo).
    static func mapStatus(legacyStatus: String?, modernStatus: String?) -> MusicalQuoteModel.QuoteStatus {
        let modern = (modernStatus ?? "").uppercased()
        switch modern {
        case "ACCEPTED": return .accepted
        case "DECLINED": return .declined
        case "COMPLETED": return .paid
        default: break
        }
        switch (legacyStatus ?? "pending").lowercased() {
        case "accepted", "in_progress", "arrived", "service_started": return .accepted
        case "declined", "cancelled": return .declined
        case "completed", "service_completed": return .paid
        default: return .pending
        }
    }

    // MARK: - Confirmar ("Pagar y Confirmar")
    /// Réplica de AdapterCotizacionBanda.java:389-397 (aceptada "yes" / status "accepted" /
    /// confirmada "yes" en ambas réplicas + MusicalQuotes/.../status "ACCEPTED").
    func confirmQuote(_ quote: MusicalQuoteModel) {
        #if canImport(FirebaseDatabase)
        guard FirebaseService.shared.canWriteToCloud,
              let uid = FirebaseService.shared.authenticatedUid else { return }
        guard !quote.id.isEmpty else { return }

        var updates: [String: Any] = [
            "CotizacionComprador/\(uid)/\(quote.id)/aceptada": "yes",
            "CotizacionComprador/\(uid)/\(quote.id)/confirmada": "yes",
            "CotizacionComprador/\(uid)/\(quote.id)/status": "accepted",
            "MusicalQuotes/\(quote.id)/status": "ACCEPTED"
        ]
        if let ownerUid = ownerUids[quote.id], !ownerUid.isEmpty, ownerUid != uid {
            updates["CotizacionBanda/\(ownerUid)/\(quote.id)/aceptada"] = "yes"
            updates["CotizacionBanda/\(ownerUid)/\(quote.id)/confirmada"] = "yes"
            updates["CotizacionBanda/\(ownerUid)/\(quote.id)/status"] = "accepted"
        }
        Database.database().reference().updateChildValues(updates)
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

    /// `precio` legado: "$1,200" / "$1,200.50" -> Double.
    static func parseMoney(_ raw: String?) -> Double? {
        guard let raw = raw else { return nil }
        let cleaned = raw.filter { $0.isNumber || $0 == "." }
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    /// Android guarda `eventDate`/`fecha` como texto libre; se prueban los formatos habituales.
    static func parseDate(_ dateText: String?, time: String?) -> Date? {
        guard let dateText = dateText, !dateText.isEmpty else { return nil }
        let trimmedTime = (time ?? "").trimmingCharacters(in: .whitespaces)
        let combined = trimmedTime.isEmpty ? dateText : "\(dateText) \(trimmedTime)"
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "dd/MM/yyyy HH:mm:ss",
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy",
            "MM/dd/yyyy HH:mm",
            "MM/dd/yyyy",
            "d 'de' MMMM 'de' yyyy",
            "MMMM d, yyyy"
        ]
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "es_MX")
        parser.timeZone = TimeZone.current
        for format in formats {
            parser.dateFormat = format
            if let parsed = parser.date(from: combined) { return parsed }
            if combined != dateText, let parsed = parser.date(from: dateText) { return parsed }
        }
        let iso = ISO8601DateFormatter()
        return iso.date(from: combined) ?? iso.date(from: dateText)
    }
}

// MARK: - Musical Quotes Manager & Comparison View
public struct MusicalQuotesManagerView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var service = MusicalQuotesService.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedFilter: MusicalQuoteModel.QuoteStatus = .pending
    @State private var isCompareSheetPresented: Bool = false

    /// `true` cuando la lista proviene de `CotizacionComprador/{uid}` (sesión real).
    private let usesLiveQuotes: Bool = FirebaseService.shared.canWriteToCloud

    /// Seed de demostración (sólo se muestra en modo demo, sin sesión real).
    @State private var seedQuotes: [MusicalQuoteModel] = [
        MusicalQuoteModel(
            id: "quote_1",
            groupId: "group_1",
            groupName: "Mariachi Sinfónico Real de México",
            groupAvatar: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
            clientId: "user_demo_violin_001",
            clientName: "Israel Violín",
            eventType: "Serenata de Aniversario",
            eventDate: Date().addingTimeInterval(86400 * 5),
            venueAddress: "Av. Reforma 222, CDMX",
            durationHours: 1.0,
            quotedPriceUSD: 250.0,
            status: .pending,
            clientNotes: "Repertorio clásico: Las Mañanitas, Si Nos Dejan, Hermoso Cariño."
        ),
        MusicalQuoteModel(
            id: "quote_2",
            groupId: "group_2",
            groupName: "Cuarteto de Cuerdas Bellas Artes",
            groupAvatar: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=60",
            clientId: "user_demo_violin_001",
            clientName: "Israel Violín",
            eventType: "Boda Civil",
            eventDate: Date().addingTimeInterval(86400 * 12),
            venueAddress: "Jardín Los Encinos, Cuernavaca",
            durationHours: 2.0,
            quotedPriceUSD: 480.0,
            status: .accepted,
            clientNotes: nil,
            responseNotes: "Fecha confirmada. Incluye traslado y sonorización básica."
        ),
        MusicalQuoteModel(
            id: "quote_3",
            groupId: "group_3",
            groupName: "Banda La Sinaloense Imperial",
            groupAvatar: "https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&auto=format&fit=crop&q=60",
            clientId: "user_demo_violin_001",
            clientName: "Israel Violín",
            eventType: "Fiesta Privada",
            eventDate: Date().addingTimeInterval(86400 * 20),
            venueAddress: "Zapopan, Jalisco",
            durationHours: 3.0,
            quotedPriceUSD: 1200.0,
            status: .paid,
            clientNotes: nil,
            responseNotes: "Contrato firmado y anticipo completado."
        )
    ]

    public init() {}

    private var quotes: [MusicalQuoteModel] {
        usesLiveQuotes ? service.quotes : seedQuotes
    }

    public var filteredQuotes: [MusicalQuoteModel] {
        quotes.filter { $0.status == selectedFilter }
    }

    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Compare CTA
                    HStack {
                        Text("Gestión de Cotizaciones")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)

                        Spacer()

                        Button(action: { isCompareSheetPresented = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left.arrow.right")
                                Text("Comparar")
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.primary)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(theme.cardColor)

                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MusicalQuoteModel.QuoteStatus.allCases, id: \.self) { status in
                                Button(action: { selectedFilter = status }) {
                                    Text(status.rawValue)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedFilter == status ? .white : theme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedFilter == status ? AppColors.primary : theme.cardColor)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    // Quotes List
                    if filteredQuotes.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 44))
                                .foregroundColor(theme.textSecondary)
                            Text(usesLiveQuotes && quotes.isEmpty
                                 ? "Aún no tienes cotizaciones.\nSolicita una desde el Hub Musical."
                                 : "No hay cotizaciones con estado \(selectedFilter.rawValue)")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(.horizontal, 24)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredQuotes) { quote in
                                    QuoteCardItem(quote: quote) {
                                        // AdapterCotizacionBanda.java:389-397 (no-op en modo demo).
                                        service.confirmQuote(quote)
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("Cotizaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $isCompareSheetPresented) {
                QuoteComparisonModal(quotes: quotes)
            }
            .onAppear {
                if usesLiveQuotes { service.ensureStarted() }
            }
        }
    }
}

// MARK: - Quote Card Item
struct QuoteCardItem: View {
    let quote: MusicalQuoteModel
    var onConfirm: () -> Void = {}
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AvatarView(urlString: quote.groupAvatar, size: 44, isVerified: true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(quote.groupName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                    Text(quote.eventType)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                Text(quote.status.rawValue)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(8)
            }

            Divider()
                .background(Color.gray.opacity(0.2))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(AppColors.primary)
                        .font(.caption)
                    Text("\(quote.eventDate.formatted(date: .complete, time: .shortened)) (\(String(format: "%.1f", quote.durationHours)) hrs)")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .foregroundColor(AppColors.primary)
                    Text(quote.venueAddress)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }

                if let notes = quote.clientNotes, !notes.isEmpty {
                    Text("Nota: \(notes)")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 2)
                }
            }

            HStack {
                Text(String(format: "$%.2f USD", quote.quotedPriceUSD))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)

                Spacer()

                if quote.status == .accepted {
                    Button(action: onConfirm) {
                        Text("Pagar y Confirmar")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(AppColors.success)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(14)
        .background(theme.cardColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    private var statusColor: Color {
        switch quote.status {
        case .pending: return AppColors.warningOrange
        case .accepted: return AppColors.primary
        case .declined: return AppColors.errorRed
        case .paid: return AppColors.success
        }
    }
}

// MARK: - Quote Comparison Modal
struct QuoteComparisonModal: View {
    let quotes: [MusicalQuoteModel]
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(quotes) { q in
                            VStack(alignment: .leading, spacing: 14) {
                                AvatarView(urlString: q.groupAvatar, size: 50, isVerified: true)

                                Text(q.groupName)
                                    .font(.headline)
                                    .foregroundColor(theme.textPrimary)
                                    .frame(height: 44, alignment: .topLeading)

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Precio")
                                        .font(.caption2)
                                        .foregroundColor(theme.textSecondary)
                                    Text(String(format: "$%.2f USD", q.quotedPriceUSD))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.primary)

                                    Text("Duración")
                                        .font(.caption2)
                                        .foregroundColor(theme.textSecondary)
                                    Text("\(String(format: "%.1f", q.durationHours)) horas")
                                        .font(.subheadline)
                                        .foregroundColor(theme.textPrimary)

                                    Text("Estado")
                                        .font(.caption2)
                                        .foregroundColor(theme.textSecondary)
                                    Text(q.status.rawValue)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.gold)
                                }

                                Spacer()

                                Button(action: {}) {
                                    Text("Seleccionar")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(AppColors.primary)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(16)
                            .frame(width: 220)
                            .background(theme.cardColor)
                            .cornerRadius(18)
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Comparador de Cotizaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
