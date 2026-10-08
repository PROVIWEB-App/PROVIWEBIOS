import SwiftUI

// MARK: - Musical Quotes Manager & Comparison View
public struct MusicalQuotesManagerView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedFilter: MusicalQuoteModel.QuoteStatus = .pending
    @State private var isCompareSheetPresented: Bool = false
    
    @State private var quotes: [MusicalQuoteModel] = [
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
            responseNotes: "Contrato firmado y anticipo completado."
        )
    ]
    
    public init() {}
    
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
                            Text("No hay cotizaciones con estado \(selectedFilter.rawValue)")
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredQuotes) { quote in
                                    QuoteCardItem(quote: quote)
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
        }
    }
}

// MARK: - Quote Card Item
struct QuoteCardItem: View {
    let quote: MusicalQuoteModel
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
                        .font(.caption)
                    Text(quote.venueAddress)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                
                if let notes = quote.clientNotes {
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
                    Button(action: {}) {
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
