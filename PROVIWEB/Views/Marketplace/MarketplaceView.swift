import SwiftUI
import MapKit

// MARK: - Marketplace & Musician Hiring View
public struct MarketplaceView: View {
    @StateObject private var viewModel = MarketplaceViewModel()
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var isHireSheetPresented: Bool = false
    
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
                        
                        // Nearby Musicians Radar / Map Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(AppColors.primary)
                                Text("Músicos y Artistas Cerca de Ti")
                                    .font(.headline)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Text("\(locationService.nearbyMusiciansCount) Cercanos")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                            }
                            
                            Map(coordinateRegion: $locationService.region)
                                .frame(height: 180)
                                .cornerRadius(16)
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
                                isHireSheetPresented = true
                            }) {
                                Text("Cotizar")
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
            .sheet(isPresented: $isHireSheetPresented) {
                HireMusicianQuoteView()
            }
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
