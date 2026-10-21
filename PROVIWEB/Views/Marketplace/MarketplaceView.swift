import SwiftUI
import MapKit
import PhotosUI

// MARK: - Marketplace & Musician Hiring View
public struct MarketplaceView: View {
    @StateObject private var viewModel = MarketplaceViewModel()
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var isHireSheetPresented: Bool = false
    @State private var isMusicalHubPresented: Bool = false
    @State private var isQuotesManagerPresented: Bool = false

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
                        
                        // Nearby Musicians Radar / Map Card (datos reales de `UserLocation`)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(AppColors.primary)
                                Text("Músicos y Artistas Cerca de Ti")
                                    .font(.headline)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Text("\(locationService.nearbyMusicians.count) Cercanos")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                            }
                            
                            Map(coordinateRegion: $locationService.region,
                                annotationItems: locationService.nearbyMusicians) { musician in
                                MapAnnotation(coordinate: musician.coordinate) {
                                    VStack(spacing: 2) {
                                        if let photo = musician.photo, !photo.isEmpty, let url = URL(string: photo) {
                                            AsyncImage(url: url) { img in
                                                img.resizable().aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Image(systemName: "person.circle.fill")
                                                    .foregroundColor(AppColors.primary)
                                            }
                                            .frame(width: 34, height: 34)
                                            .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(AppColors.primary)
                                                .background(Circle().fill(Color.white))
                                        }
                                        Text(musician.name)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .shadow(color: .black.opacity(0.15), radius: 2)
                                    }
                                }
                            }
                            .frame(height: 180)
                            .cornerRadius(16)
                            .disabled(true)
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
                            HStack {
                                Text("Instrumentos y Accesorios")
                                    .font(.headline)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                if viewModel.usesLiveMarket {
                                    Button(action: { viewModel.isPostProductPresented = true }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Publicar")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(AppColors.primary)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            if viewModel.filteredProducts.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "cart.empty")
                                        .font(.system(size: 36))
                                        .foregroundColor(theme.textSecondary)
                                    Text("No hay productos publicados todavía")
                                        .font(.subheadline)
                                        .foregroundColor(theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    ForEach(viewModel.filteredProducts) { prod in
                                        ProductCardView(product: prod)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
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
            .sheet(isPresented: $viewModel.isPostProductPresented) {
                PostProductView()
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

// MARK: - Publicar Producto (PostProductActivity.java en Android)
public struct PostProductView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var uploads = UploadManager.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var title: String = ""
    @State private var priceText: String = ""
    @State private var description: String = ""
    @State private var category: String = "Instrumentos"
    @State private var condition: String = "Nuevo"
    @State private var location: String = ""
    @State private var pickedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var isPublished: Bool = false

    private let categoryOptions = ["Instrumentos", "Accesorios", "Partituras", "Agrupaciones", "Servicios"]
    private let conditionOptions = ["Nuevo", "Como Nuevo", "Usado"]

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                Form {
                    Section(header: Text("Fotografía")) {
                        PhotosPicker(selection: $pickedPhoto, matching: .images) {
                            HStack(spacing: 10) {
                                Image(systemName: "camera.fill")
                                    .foregroundColor(AppColors.primary)
                                Text(photoData == nil ? "Elegir foto del producto" : "Foto seleccionada")
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                if photoData != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.success)
                                }
                            }
                        }
                    }

                    Section(header: Text("Producto")) {
                        TextField("Título", text: $title)
                        TextField("Precio (USD)", text: $priceText)
                            .keyboardType(.decimalPad)
                        TextEditor(text: $description)
                            .frame(height: 80)
                    }

                    Section(header: Text("Clasificación")) {
                        Picker("Categoría", selection: $category) {
                            ForEach(categoryOptions, id: \.self) { Text($0) }
                        }
                        Picker("Estado", selection: $condition) {
                            ForEach(conditionOptions, id: \.self) { Text($0) }
                        }
                    }

                    Section(header: Text("Envío")) {
                        TextField("Ciudad / Dirección", text: $location)
                    }

                    Section {
                        Button(action: publish) {
                            HStack {
                                if uploads.isUploading {
                                    ProgressView()
                                }
                                Text(uploads.isUploading
                                     ? "Subiendo foto... \(Int(uploads.uploadProgress * 100))%"
                                     : "Publicar en Marketplace")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty
                                  || priceText.trimmingCharacters(in: .whitespaces).isEmpty
                                  || uploads.isUploading)
                        .listRowBackground(AppColors.primary)
                    }
                }
            }
            .navigationTitle("Nuevo Producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onChange(of: pickedPhoto) { item in
                guard let item = item else { return }
                Task {
                    photoData = try? await item.loadTransferable(type: Data.self)
                }
            }
            .alert("¡Producto Publicado!", isPresented: $isPublished) {
                Button("Aceptar") { presentationMode.wrappedValue.dismiss() }
            } message: {
                Text("Tu producto ya es visible en el Marketplace de PROVIWEB.")
            }
        }
    }

    private func publish() {
        let millis = "\(Int(Date().timeIntervalSince1970 * 1000))"
        let finish = { [title, priceText, description, category, condition, location] in
            MarketplaceService.shared.postProduct(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                price: priceText.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                condition: condition,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                photoURL: nil
            )
            isPublished = true
        }
        // Ruta Storage idéntica a PostProductActivity.java: `product_photo/{timestamp}`.
        guard let data = photoData else { finish(); return }
        uploads.uploadData(data: data, path: "product_photo/\(millis)", mimeType: "image/jpeg") { result in
            switch result {
            case .success(let url):
                MarketplaceService.shared.postProduct(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    price: priceText.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: category,
                    condition: condition,
                    location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                    photoURL: url
                )
                isPublished = true
            case .failure:
                finish()
            }
        }
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
