import SwiftUI
import MapKit

// MARK: - Event Details & Ticket Purchase View
public struct EventDetailsView: View {
    public let event: ArtisticEventModel
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @ObservedObject private var eventsService = EventsService.shared
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.openURL) private var openURL
    
    /// `true` cuando la compra se ejecuta contra RTDB (sesión real, nodo `ArtisticEvents`);
    /// en modo demo se mantiene la compra local de siempre.
    private let usesLiveEvents = FirebaseService.shared.canWriteToCloud

    @State private var isPurchasingTicket: Bool = false
    @State private var purchasedTicket: EventTicketModel? = nil
    @State private var isShowingDigitalTicket: Bool = false
    @State private var useDiamonds: Bool = false
    @State private var purchaseAlert: PurchaseAlert? = nil

    /// Alertas del flujo de compra (confirmación, éxito y error en español).
    private enum PurchaseAlert: Identifiable {
        case confirm
        case success
        case failure(String)

        var id: String {
            switch self {
            case .confirm: return "confirm"
            case .success: return "success"
            case .failure(let message): return "failure-\(message)"
            }
        }
    }

    public init(event: ArtisticEventModel) {
        self.event = event
    }

    /// Versión más fresca del evento cuando la lista en vivo se actualiza
    /// (aforo/estado reales de `ArtisticEvents`).
    private var currentEvent: ArtisticEventModel {
        guard usesLiveEvents,
              let live = eventsService.events.first(where: { $0.id == event.id }) else {
            return event
        }
        return live
    }

    /// `true` cuando la entrada se paga con saldo QAV (solo en vivo).
    private var needsQavPayment: Bool {
        usesLiveEvents && currentEvent.needsQavPayment
    }

    private var isSoldOut: Bool {
        usesLiveEvents && currentEvent.isSoldOut
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            theme.backgroundColor.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Top Hero Banner
                    ZStack(alignment: .topLeading) {
                        if let banner = event.bannerUrl, let url = URL(string: banner) {
                            AsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(height: 240)
                            .clipped()
                        } else {
                            Rectangle()
                                .fill(AppColors.primaryGradient)
                                .frame(height: 240)
                        }
                        
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Image(systemName: "chevron.left")
                                        .foregroundColor(.white)
                                        .font(.subheadline)
                                )
                        }
                        .padding(16)
                    }
                    
                    VStack(alignment: .leading, spacing: 18) {
                        // Title & Category
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(currentEvent.categoryDisplayName)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppColors.primary.opacity(0.12))
                                    .cornerRadius(10)
                                
                                if event.isLiveStreamed {
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.red).frame(width: 6, height: 6)
                                        Text("Transmisión en Vivo")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                
                                Spacer()
                                
                                Text(currentEvent.status.rawValue)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(statusColor)
                            }
                            
                            Text(event.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textPrimary)
                        }
                        
                        // Organizer Card
                        HStack(spacing: 12) {
                            AvatarView(urlString: event.organizerDp, size: 44, isVerified: true)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.organizerName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.textPrimary)
                                Text("Organizador")
                                    .font(.caption2)
                                    .foregroundColor(theme.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding(12)
                        .background(theme.cardColor)
                        .cornerRadius(14)
                        
                        // Estado real del evento (aforo, acceso y tipo: datos de `ArtisticEvents`)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.3.fill")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.primary)
                                Text("👥 \(currentEvent.ticketsSold) personas inscritas")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.textPrimary)
                                if currentEvent.totalCapacity > 0 {
                                    Text("/ \(currentEvent.totalCapacity) aforo máx.")
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                }
                                Spacer()
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: currentEvent.isOnlineEvent ? "video.fill" : "mappin.and.ellipse")
                                    .font(.caption)
                                    .foregroundColor(AppColors.primary)
                                Text(currentEvent.isOnlineEvent
                                     ? "Evento en línea\(currentEvent.onlinePlatform.isEmpty ? "" : " (\(currentEvent.onlinePlatform))")"
                                     : "Evento presencial · Acceso \(currentEvent.accessType == "privado" ? "privado" : "público")")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                                Spacer()
                            }
                            
                            if currentEvent.isSoldOut {
                                HStack(spacing: 6) {
                                    Image(systemName: "slash.circle.fill")
                                    Text("Aforo completo / Entradas agotadas")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                .foregroundColor(AppColors.errorRed)
                            }
                            
                            if currentEvent.status == .cancelled {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("Evento cancelado por el organizador")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                .foregroundColor(AppColors.errorRed)
                            } else if currentEvent.status == .completed {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle")
                                    Text("Evento finalizado")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                .foregroundColor(theme.textSecondary)
                            }
                        }
                        .padding(14)
                        .background(theme.cardColor)
                        .cornerRadius(14)
                        
                        // Event Date & Venue Info
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.title3)
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(currentEvent.eventDateText.isEmpty ? event.eventDate.formatted(date: .complete, time: .omitted) : currentEvent.eventDateText)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.textPrimary)
                                    Text(currentEvent.eventTime.isEmpty
                                         ? "Hora: \(event.eventDate.formatted(date: .omitted, time: .shortened)) (\(String(format: "%.1f", event.durationHours)) hrs)"
                                         : "Hora: \(currentEvent.eventTime) (\(String(format: "%.1f", event.durationHours)) hrs)")
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                }
                                Spacer()
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.title3)
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(currentEvent.venueName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.textPrimary)
                                    if !event.address.isEmpty {
                                        Text(event.address)
                                            .font(.caption)
                                            .foregroundColor(theme.textSecondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .padding(14)
                        .background(theme.cardColor)
                        .cornerRadius(14)
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Acerca del Evento")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                            
                            Text(event.description)
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                                .lineSpacing(4)
                        }
                        
                        // Program / Schedule if available
                        if !event.schedule.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Programa del Evento")
                                    .font(.headline)
                                    .foregroundColor(theme.textPrimary)
                                
                                ForEach(event.schedule) { item in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(item.timeString)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.primary)
                                            .frame(width: 50, alignment: .leading)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.activityTitle)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(theme.textPrimary)
                                            
                                            if let artist = item.artistName {
                                                Text(artist)
                                                    .font(.caption2)
                                                    .foregroundColor(theme.textSecondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding(14)
                            .background(theme.cardColor)
                            .cornerRadius(14)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 100) // Padding for sticky bottom purchase bar
                }
            }
            
            // Sticky Purchase Bottom Bar
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(needsQavPayment ? "Total por Entrada (QAV)" : "Total por Entrada")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                        
                        Text(priceText)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        buyTicket()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "ticket.fill")
                            Text(buttonTitle)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(buttonBackground)
                        .cornerRadius(20)
                    }
                    .disabled(!canPurchase)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    theme.cardColor
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -4)
                )
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if usesLiveEvents {
                eventsService.ensureStarted()
            }
        }
        .alert(item: $purchaseAlert) { alert in
            switch alert {
            case .confirm:
                return Alert(
                    title: Text("🎟️ Confirmar Compra de Entrada"),
                    message: Text(needsQavPayment
                                  ? String(format: "¿Deseas pagar %.1f QAV de tu saldo para adquirir tu entrada a \"%@\"?\n\nLos fondos se acreditarán directamente al organizador.", currentEvent.priceQav, currentEvent.title)
                                  : "¿Deseas inscribirte a \"\(currentEvent.title)\"? Tu entrada digital se generará al instante."),
                    primaryButton: .default(Text(needsQavPayment ? "Comprar con QAV" : "Confirmar")) {
                        performLivePurchase()
                    },
                    secondaryButton: .cancel(Text("Cancelar"))
                )
            case .success:
                return Alert(
                    title: Text("¡Boleto Adquirido!"),
                    message: Text("Tu entrada digital ha sido generada exitosamente con código QR de acceso."),
                    primaryButton: .default(Text("Ver Boleto")) {
                        isShowingDigitalTicket = true
                    },
                    secondaryButton: .cancel(Text("Cerrar"))
                )
            case .failure(let message):
                return Alert(
                    title: Text("No se pudo completar"),
                    message: Text(message),
                    dismissButton: .default(Text("Entendido"))
                )
            }
        }
        .sheet(isPresented: $isShowingDigitalTicket) {
            if let ticket = purchasedTicket {
                DigitalTicketView(ticket: ticket)
            }
        }
    }
    
    // MARK: - Estado del botón de compra (espejo de updateActionButton() en Android)
    private var priceText: String {
        guard !currentEvent.isFree else { return "Gratis" }
        return String(format: "$%.2f %@", currentEvent.ticketPriceUSD, needsQavPayment ? "QAV" : "USD")
    }
    
    /// Evento "link": Android abre el sitio oficial y homologa después con QR.
    private var isLinkPurchase: Bool {
        usesLiveEvents
            && currentEvent.paymentMethod.lowercased() == "link"
            && !currentEvent.purchaseLink.isEmpty
    }
    
    private var buttonTitle: String {
        if isPurchasingTicket {
            return needsQavPayment ? "Procesando pago QAV..." : "Generando entrada..."
        }
        if currentEvent.status == .cancelled {
            return "⚠️ Evento Cancelado por Organizador"
        }
        if currentEvent.status == .completed {
            return "Evento finalizado"
        }
        if isSoldOut {
            return "🚫 Entradas Agotadas (Aforo Completo)"
        }
        if isLinkPurchase {
            return "🌐 Comprar en Sitio Oficial"
        }
        if needsQavPayment {
            return String(format: "💰 Comprar Entrada (%.1f QAV)", currentEvent.priceQav)
        }
        if usesLiveEvents {
            return "🎟️ Inscribirme Gratis"
        }
        return "Comprar Entrada"
    }
    
    private var buttonBackground: Color {
        if currentEvent.status == .cancelled { return AppColors.errorRed }
        if isSoldOut { return Color.gray }
        if !canPurchase { return Color.gray }
        return AppColors.primary
    }
    
    private var canPurchase: Bool {
        guard !isPurchasingTicket else { return false }
        if currentEvent.status == .cancelled || currentEvent.status == .completed { return false }
        if isSoldOut { return false }
        return true
    }
    
    private var statusColor: Color {
        switch currentEvent.status {
        case .cancelled: return AppColors.errorRed
        case .soldOut: return AppColors.warningOrange
        case .completed: return theme.textSecondary
        case .upcoming, .ongoing: return AppColors.success
        }
    }
    
    private func buyTicket() {
        guard canPurchase else { return }
        
        if isLinkPurchase {
            if let url = URL(string: currentEvent.purchaseLink) {
                openURL(url)
            }
            return
        }
        
        guard usesLiveEvents else {
            // Modo demo: entrada local (sin red), como hasta ahora.
            let ticket = EventTicketModel(
                eventId: event.id,
                eventTitle: event.title,
                eventDate: event.eventDate,
                venueName: event.venueName,
                attendeeId: firebase.currentUserId,
                attendeeName: firebase.currentUser?.name ?? "Israel Violín",
                attendeeEmail: firebase.currentUser?.email ?? "israel@proviweb.com",
                pricePaidUSD: event.ticketPriceUSD,
                seatTier: "Acceso General VIP"
            )
            self.purchasedTicket = ticket
            self.purchaseAlert = .success
            return
        }
        
        // Sesión real: pide confirmación antes de tocar el saldo (como Android).
        purchaseAlert = .confirm
    }
    
    /// Compra real contra RTDB (aforo, saldo QAV, doble nodo de entrada y notificación).
    private func performLivePurchase() {
        isPurchasingTicket = true
        eventsService.purchaseTicket(currentEvent) { result in
            // `self` es un struct: se usa explícitamente y sin `weak` (los @State siguen vivos
            // a través del almacenamiento de SwiftUI).
            self.isPurchasingTicket = false
            switch result {
            case .success(let userTicket):
                self.purchasedTicket = userTicket.asDisplayTicket()
                self.purchaseAlert = .success
            case .failure(let message):
                self.purchaseAlert = .failure(message)
            }
        }
    }
}
