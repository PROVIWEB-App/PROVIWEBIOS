import SwiftUI

// MARK: - Artistic Events Feed & Explorer View
public struct EventsHomeView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
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
    
    public var filteredEvents: [ArtisticEventModel] {
        events.filter { event in
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
            .sheet(isPresented: $isCreateEventPresented) {
                CreateEventView { newEvent in
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
                        Text(event.category.rawValue)
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
                                Text(event.isFree ? "Gratis" : String(format: "$%.2f USD", event.ticketPriceUSD))
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
                                .foregroundColor(theme.textSecondary)
                            
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
