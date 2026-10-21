import SwiftUI

// MARK: - Digital Ticket with QR Code Check-in View
public struct DigitalTicketView: View {
    public let ticket: EventTicketModel
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var walletService = Web3WalletService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isScannerPresented: Bool = false
    @State private var scannedQRCode: String = ""
    @State private var isScanResultPresented: Bool = false
    
    public init(ticket: EventTicketModel) {
        self.ticket = ticket
    }

    // MARK: - Estado real de la entrada (check-in / finalizada / válida)
    private var isEventFinished: Bool { ticket.eventDate < Date() }

    private var ticketStateIcon: String {
        if ticket.isValidated { return "checkmark.seal.fill" }
        return isEventFinished ? "clock.badge.exclamationmark.fill" : "ticket.fill"
    }

    private var ticketStateLabel: String {
        if ticket.isValidated { return "✓ ENTRADA ACCEDIDA" }
        return isEventFinished ? "EVENTO FINALIZADO" : "✅ ENTRADA VÁLIDA"
    }

    private var ticketStateColor: Color {
        if ticket.isValidated { return AppColors.gold }
        return isEventFinished ? theme.textSecondary : AppColors.success
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
                                
                                // Estado de la entrada (`checkedIn` escrito por Android en el check-in)
                                // Tres estados reales: accedida / finalizada / válida.
                                HStack(spacing: 6) {
                                    Image(systemName: ticketStateIcon)
                                    Text(ticketStateLabel)
                                        .fontWeight(.bold)
                                }
                                .font(.caption)
                                .foregroundColor(ticketStateColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(ticketStateColor.opacity(0.12))
                                .cornerRadius(10)
                                
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
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "creditcard.fill")
                                        .foregroundColor(AppColors.gold)
                                    Text(ticket.pricePaidUSD > 0
                                         ? String(format: "Pagado: %.1f QAV", ticket.pricePaidUSD)
                                         : "Acceso Libre")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.textSecondary)
                                    Spacer()
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
                        
                        // Check-in Scanner Action (valida el QR de asistencia)
                        Button(action: { isScannerPresented = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title3)
                                Text("Escanear / Validar QR")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(AppColors.primary)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }
                }
                .fullScreenCover(isPresented: $isScannerPresented) {
                    QRScannerView(onCodeScanned: { code in
                        scannedQRCode = code
                        isScanResultPresented = true
                    })
                }
                .alert(isPresented: $isScanResultPresented) {
                    Alert(
                        title: Text("QR Escaneado"),
                        message: Text("Código de check-in: \(scannedQRCode)"),
                        dismissButton: .default(Text("OK"))
                    )
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
    @ObservedObject private var eventsService = EventsService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTicket: EventTicketModel? = nil
    
    /// `true` con sesión real: las entradas se leen de `UserEventTickets/{uid}`
    /// (mismo nodo que "Mis Boletos" en Android); en modo demo se muestra el seed local.
    private let usesLiveEvents = FirebaseService.shared.canWriteToCloud

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
    
    /// Entradas reales (con `qrPayload` de Android) o el seed de demostración.
    private var displayTickets: [EventTicketModel] {
        guard usesLiveEvents else { return sampleTickets }
        return eventsService.myTickets.map { $0.asDisplayTicket() }
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                if displayTickets.isEmpty {
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
                            ForEach(displayTickets) { ticket in
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
                                            
                                            HStack(spacing: 6) {
                                                Text(ticket.seatTier)
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(AppColors.gold)
                                                
                                                if ticket.isValidated {
                                                    Text("✓ Accedida")
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(AppColors.success)
                                                }
                                            }
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
            .onAppear {
                if usesLiveEvents {
                    eventsService.ensureStarted()
                }
            }
            .sheet(item: $selectedTicket) { ticket in
                DigitalTicketView(ticket: ticket)
            }
        }
    }
}
