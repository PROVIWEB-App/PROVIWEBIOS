import SwiftUI
import MapKit

// MARK: - Event Details & Ticket Purchase View
public struct EventDetailsView: View {
    public let event: ArtisticEventModel
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isPurchasingTicket: Bool = false
    @State private var isTicketPurchasedAlert: Bool = false
    @State private var purchasedTicket: EventTicketModel? = nil
    @State private var isShowingDigitalTicket: Bool = false
    @State private var useDiamonds: Bool = false
    
    public init(event: ArtisticEventModel) {
        self.event = event
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
                                Text(event.category.rawValue)
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
                                
                                Text(event.status.rawValue)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.success)
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
                        
                        // Event Date & Venue Info
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.title3)
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.eventDate.formatted(date: .complete, time: .omitted))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.textPrimary)
                                    Text("Hora: \(event.eventDate.formatted(date: .omitted, time: .shortened)) (\(String(format: "%.1f", event.durationHours)) hrs)")
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
                                    Text(event.venueName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.textPrimary)
                                    Text(event.address)
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
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
                        Text("Total por Entrada")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                        
                        Text(event.isFree ? "Gratis" : String(format: "$%.2f USD", event.ticketPriceUSD))
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
                            Text("Comprar Entrada")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(AppColors.primary)
                        .cornerRadius(20)
                    }
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
        .alert(isPresented: $isTicketPurchasedAlert) {
            Alert(
                title: Text("¡Boleto Adquirido!"),
                message: Text("Tu entrada digital ha sido generada exitosamente con código QR de acceso."),
                primaryButton: .default(Text("Ver Boleto")) {
                    isShowingDigitalTicket = true
                },
                secondaryButton: .cancel(Text("Cerrar"))
            )
        }
        .sheet(isPresented: $isShowingDigitalTicket) {
            if let ticket = purchasedTicket {
                DigitalTicketView(ticket: ticket)
            }
        }
    }
    
    private func buyTicket() {
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
        self.isTicketPurchasedAlert = true
    }
}
