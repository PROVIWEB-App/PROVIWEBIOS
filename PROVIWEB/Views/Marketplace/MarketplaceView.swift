import SwiftUI
import MapKit

// MARK: - Marketplace & Musician Hiring View (LocationActivity & Marketplace)
public struct MarketplaceView: View {
    @StateObject private var viewModel = MarketplaceViewModel()
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var theme = ThemeManager.shared
    
    @State private var isHireSheetPresented: Bool = false
    @State private var isMusicalHubPresented: Bool = false
    @State private var isQuotesManagerPresented: Bool = false
    @State private var isFullRadarPresented: Bool = false
    @State private var selectedMusicianPin: NearbyMusicianPin? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Category Horizontal Bar
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(viewModel.categories, id: \.self) { cat in
                                    Button(action: {
                                        viewModel.selectedCategory = cat
                                    }) {
                                        Text(cat)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(viewModel.selectedCategory == cat ? .white : theme.textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(viewModel.selectedCategory == cat ? AppColors.primary : theme.cardColor)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 12)
                        
                        // Nearby Musicians Radar / Map Card (LocationActivity)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(AppColors.primary)
                                Text("Radar Musical en Vivo (GPS)")
                                    .font(.headline)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Button(action: { isFullRadarPresented = true }) {
                                    HStack(spacing: 4) {
                                        Text("Explorar Radar")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                                }
                            }
                            
                            // Interactive Map with Pins
                            ZStack(alignment: .bottom) {
                                Map(coordinateRegion: $locationService.region, annotationItems: locationService.allMusicians) { pin in
                                    MapAnnotation(coordinate: pin.coordinate) {
                                        Button(action: {
                                            selectedMusicianPin = pin
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }) {
                                            VStack(spacing: 2) {
                                                Circle()
                                                    .fill(pin.category == "Mariachi" ? AppColors.gold : AppColors.primary)
                                                    .frame(width: 32, height: 32)
                                                    .overlay(
                                                        Text(pinCategoryEmoji(pin.category))
                                                            .font(.system(size: 16))
                                                    )
                                                    .shadow(radius: 4)
                                                
                                                Text(pin.name.prefix(12))
                                                    .font(.system(size: 8, weight: .bold))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.white.opacity(0.9))
                                                    .foregroundColor(.black)
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 200)
                                .cornerRadius(16)
                                
                                // Selected Pin Quick Card
                                if let selected = selectedMusicianPin {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(selected.name)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(theme.textPrimary)
                                                if selected.isVerified {
                                                    Image(systemName: "checkmark.seal.fill")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(AppColors.infoBlue)
                                                }
                                            }
                                            
                                            Text("\(String(format: "%.1f km", selected.distanceKm)) • $\(Int(selected.pricePerHourUSD))/hr")
                                                .font(.caption2)
                                                .foregroundColor(theme.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            isHireSheetPresented = true
                                        }) {
                                            Text("Cotizar")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(AppColors.primary)
                                                .cornerRadius(10)
                                        }
                                        
                                        Button(action: { selectedMusicianPin = nil }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(theme.textSecondary)
                                        }
                                    }
                                    .padding(10)
                                    .background(theme.cardColor)
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                                    .padding(8)
                                }
                            }
                            
                            HStack {
                                Text("\(locationService.nearbyMusiciansCount) Artistas dentro de \(Int(locationService.radarRadiusKm)) km")
                                    .font(.caption2)
                                    .foregroundColor(theme.textSecondary)
                                Spacer()
                                Text(locationService.isNearMusiciansAlert ? "¡Músico a menos de 500m!" : "Radar Activo")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(locationService.isNearMusiciansAlert ? AppColors.success : AppColors.primary)
                            }
                        }
                        .padding(16)
                        .background(theme.cardColor)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        
                        // Hire Bands & Ensembles CTA Banner
                        HStack(spacing: 16) {
                            Image(systemName: "music.mic.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.gold)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("¿Buscas Mariachi o Agrupación?")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Cotiza serenatas, bodas y eventos en minutos.")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                isMusicalHubPresented = true
                            }) {
                                Text("Ver Grupos")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primaryDark)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .cornerRadius(16)
                            }
                        }
                        .padding(16)
                        .background(AppColors.primaryGradient)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        
                        // Products Grid
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Instrumentos y Accesorios")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 16)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(viewModel.products) { prod in
                                    ProductCardView(product: prod)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Marketplace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isQuotesManagerPresented = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.fill")
                            Text("Cotizaciones")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(AppColors.primary)
                    }
                }
            }
            .sheet(isPresented: $isHireSheetPresented) {
                HireMusicianQuoteView()
            }
            .sheet(isPresented: $isMusicalHubPresented) {
                MusicalHubView()
            }
            .sheet(isPresented: $isQuotesManagerPresented) {
                MusicalQuotesManagerView()
            }
            .sheet(isPresented: $isFullRadarPresented) {
                MusicalRadarFullMapView()
            }
        }
    }
    
    private func pinCategoryEmoji(_ category: String) -> String {
        switch category {
        case "Mariachi": return "🎻"
        case "Violinista Solista": return "🎻"
        case "Cuarteto de Cuerdas": return "🎼"
        case "Banda Regional": return "🎺"
        case "Estudio de Grabación": return "🎙️"
        default: return "🎶"
        }
    }
}

// MARK: - Musical Radar Full Map View (LocationActivity 1:1)
public struct MusicalRadarFullMapView: View {
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedCategory: String = "Todos"
    @State private var selectedMusician: NearbyMusicianPin? = nil
    @State private var isQuoteModalPresented: Bool = false
    
    let categories = ["Todos", "Mariachi", "Violinista Solista", "Cuarteto de Cuerdas", "Banda Regional", "Estudio de Grabación"]
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Category Bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { cat in
                                Button(action: { selectedCategory = cat }) {
                                    Text(cat)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedCategory == cat ? .white : theme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(selectedCategory == cat ? AppColors.primary : theme.cardColor)
                                        .cornerRadius(14)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(theme.cardColor)
                    
                    // Radar Radius Slider Bar
                    HStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(AppColors.primary)
                        Text("Radio:")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                        Text("\(Int(locationService.radarRadiusKm)) km")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primary)
                        
                        Slider(value: Binding(
                            get: { locationService.radarRadiusKm },
                            set: { locationService.updateRadarRadius($0) }
                        ), in: 1...50, step: 1)
                        .accentColor(AppColors.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.backgroundColor)
                    
                    // Map View
                    ZStack(alignment: .bottom) {
                        Map(
                            coordinateRegion: $locationService.region,
                            annotationItems: locationService.musicians(forCategory: selectedCategory)
                        ) { pin in
                            MapAnnotation(coordinate: pin.coordinate) {
                                Button(action: {
                                    selectedMusician = pin
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }) {
                                    VStack(spacing: 2) {
                                        Circle()
                                            .fill(pin.category == "Mariachi" ? AppColors.gold : AppColors.primary)
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Text(pinCategoryEmoji(pin.category))
                                                    .font(.system(size: 18))
                                            )
                                            .shadow(color: Color.black.opacity(0.3), radius: 4)
                                        
                                        Text(pin.name)
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.95))
                                            .foregroundColor(.black)
                                            .cornerRadius(6)
                                            .shadow(radius: 2)
                                    }
                                }
                            }
                        }
                        .ignoresSafeArea(edges: .bottom)
                        
                        // Selected Pin Full Detail Card
                        if let musician = selectedMusician {
                            VStack(spacing: 10) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(AppColors.primaryGradient)
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Text(musician.name.prefix(1))
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(musician.name)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(theme.textPrimary)
                                            if musician.isVerified {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .foregroundColor(AppColors.infoBlue)
                                                    .font(.caption2)
                                            }
                                        }
                                        
                                        Text(musician.directorName.isEmpty ? musician.category : "\(musician.directorName) • \(musician.category)")
                                            .font(.caption2)
                                            .foregroundColor(theme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: { selectedMusician = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(theme.textSecondary)
                                    }
                                }
                                
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(AppColors.gold)
                                        Text(String(format: "%.1f (%d)", musician.rating, musician.reviewsCount))
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(theme.textPrimary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(String(format: "%.1f km", musician.distanceKm)) de ti")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.primary)
                                    
                                    Spacer()
                                    
                                    Text(String(format: "$%.0f USD / hora", musician.pricePerHourUSD))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.success)
                                }
                                
                                Button(action: { isQuoteModalPresented = true }) {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                        Text("Solicitar Cotización Inmediata")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(AppColors.primary)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(16)
                            .background(theme.cardColor)
                            .cornerRadius(20)
                            .shadow(radius: 10)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Radar de Músicos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $isQuoteModalPresented) {
                HireMusicianQuoteView()
            }
        }
    }
    
    private func pinCategoryEmoji(_ category: String) -> String {
        switch category {
        case "Mariachi": return "🎻"
        case "Violinista Solista": return "🎻"
        case "Cuarteto de Cuerdas": return "🎼"
        case "Banda Regional": return "🎺"
        case "Estudio de Grabación": return "🎙️"
        default: return "🎶"
        }
    }
}

// MARK: - Product Card View
struct ProductCardView: View {
    let product: ProductModel
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let firstImg = product.images.first, let url = URL(string: firstImg) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .frame(height: 140)
                .clipped()
                .cornerRadius(12)
            }
            
            Text(product.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)
            
            Text(String(format: "$%.2f USD", product.price))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primary)
            
            Text(product.sellerName)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
        }
        .padding(12)
        .background(theme.cardColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Hire Musician Quote View
public struct HireMusicianQuoteView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedBandType: String = "Mariachi"
    @State private var eventDate: Date = Date()
    @State private var hours: Int = 2
    @State private var budgetText: String = "500"
    @State private var isSuccessAlertPresented: Bool = false
    
    let bandTypes = ["Mariachi", "Banda Sinaloense", "Cuarteto de Cuerdas", "Violinista Solista", "Grupo de Jazz"]
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Tipo de Agrupación")) {
                        Picker("Agrupación", selection: $selectedBandType) {
                            ForEach(bandTypes, id: \.self) { type in
                                Text(type)
                            }
                        }
                    }
                    
                    Section(header: Text("Detalles del Evento")) {
                        DatePicker("Fecha y Hora", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                        Stepper("Duración: \(hours) horas", value: $hours, in: 1...12)
                    }
                    
                    Section(header: Text("Presupuesto Estimado (USD)")) {
                        TextField("Presupuesto en USD", text: $budgetText)
                            .keyboardType(.numberPad)
                    }
                    
                    Button(action: {
                        isSuccessAlertPresented = true
                    }) {
                        Text("Enviar Solicitud de Cotización")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .listRowBackground(AppColors.primary)
                }
            }
            .navigationTitle("Cotizar Agrupación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSuccessAlertPresented) {
                Alert(
                    title: Text("¡Cotización Enviada!"),
                    message: Text("Los directores de las agrupaciones revisarán tu solicitud y te responderán vía chat."),
                    dismissButton: .default(Text("Aceptar")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
}
