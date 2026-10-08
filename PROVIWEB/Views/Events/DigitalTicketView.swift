import SwiftUI

// MARK: - Digital Ticket with QR Code Check-in View
public struct DigitalTicketView: View {
    public let ticket: EventTicketModel
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var walletService = Web3WalletService.shared
    @Environment(\.presentationMode) var presentationMode
    
    public init(ticket: EventTicketModel) {
        self.ticket = ticket
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Ticket Card
                        VStack(spacing: 0) {
                            // Top Ticket Header
                            VStack(spacing: 8) {
                                HStack {
                                    Text("PROVIWEB PASS")
                                        .font(.caption2)
                                        .fontWeight(.black)
                                        .foregroundColor(AppColors.primary)
                                        .tracking(2)
                                    Spacer()
                                    Text(ticket.seatTier)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(AppColors.primary)
                                        .cornerRadius(8)
                                }
                                
                                Text(ticket.eventTitle)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(20)
                            
                            // Ticket Perforated Divider
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(theme.backgroundColor)
                                    .frame(width: 20, height: 20)
                                    .offset(x: -10)
                                
                                Line()
                                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                                
                                Circle()
                                    .fill(theme.backgroundColor)
                                    .frame(width: 20, height: 20)
                                    .offset(x: 10)
                            }
                            
                            // Ticket QR & Details
                            VStack(spacing: 16) {
                                // Dynamic QR Code
                                if let qr = walletService.generateQRCode(from: ticket.qrData) {
                                    Image(uiImage: qr)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 170, height: 170)
                                        .padding(12)
                                        .background(Color.white)
                                        .cornerRadius(16)
                                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                                }
                                
                                Text(ticket.ticketCode)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.textSecondary)
                                    .tracking(2)
                                
                                // Event Metadata Grid
                                HStack(spacing: 20) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("FECHA")
                                            .font(.caption2)
                                            .foregroundColor(theme.textSecondary)
                                        Text(ticket.eventDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(theme.textPrimary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("HORA")
                                            .font(.caption2)
                                            .foregroundColor(theme.textSecondary)
                                        Text(ticket.eventDate.formatted(date: .omitted, time: .shortened))
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(theme.textPrimary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("TITULAR")
                                            .font(.caption2)
                                            .foregroundColor(theme.textSecondary)
                                        Text(ticket.attendeeName)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(theme.textPrimary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.horizontal, 8)
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(AppColors.primary)
                                    Text(ticket.venueName)
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(20)
                        }
                        .background(theme.cardColor)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Verification Notice
                        HStack(spacing: 10) {
                            Image(systemName: "shield.checkmark.fill")
                                .foregroundColor(AppColors.success)
                            Text("Boleto verificado y asegurado por PROVIWEB. Muestra este código en la entrada del evento.")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(14)
                        .background(AppColors.success.opacity(0.1))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("Boleto Digital")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

// MARK: - Dashed Line Shape
struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - My Tickets List View
public struct MyTicketsListView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTicket: EventTicketModel? = nil
    
    @State private var sampleTickets: [EventTicketModel] = [
        EventTicketModel(
            ticketCode: "PRV-TCK-784210",
            eventId: "event_1",
            eventTitle: "Gala de Violín Clásico y Huapangos",
            eventDate: Date().addingTimeInterval(86400 * 3),
            venueName: "Sala Nezahualcóyotl - Centro Cultural Universitario",
            attendeeId: "user_demo_violin_001",
            attendeeName: "Israel Violín Maestro",
            attendeeEmail: "israel@proviweb.com",
            pricePaidUSD: 30.0,
            seatTier: "Acceso General VIP"
        )
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                if sampleTickets.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "ticket")
                            .font(.system(size: 48))
                            .foregroundColor(theme.textSecondary)
                        Text("No tienes boletos activos")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(sampleTickets) { ticket in
                                Button(action: { selectedTicket = ticket }) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(AppColors.primary.opacity(0.15))
                                                .frame(width: 50, height: 50)
                                            Image(systemName: "ticket.fill")
                                                .foregroundColor(AppColors.primary)
                                                .font(.title3)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(ticket.eventTitle)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(theme.textPrimary)
                                                .lineLimit(1)
                                            
                                            Text(ticket.eventDate.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption)
                                                .foregroundColor(theme.textSecondary)
                                            
                                            Text(ticket.seatTier)
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(AppColors.gold)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(theme.textSecondary)
                                            .font(.caption)
                                    }
                                    .padding(14)
                                    .background(theme.cardColor)
                                    .cornerRadius(16)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Mis Boletos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(item: $selectedTicket) { ticket in
                DigitalTicketView(ticket: ticket)
            }
        }
    }
}
