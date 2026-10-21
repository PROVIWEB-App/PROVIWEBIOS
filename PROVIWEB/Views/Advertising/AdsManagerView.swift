import SwiftUI
import PhotosUI
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - My Ads ViewModel (AdsManagerActivity.java:369-370 + CreateAdsActivity.java:2320-2408)
//
// Gestiona MIS anuncios en el nodo RTDB real de Android:
//   Lectura: AdsPost.orderByChild("id").equalTo(uid)
//   Escritura: AdsPost/{String(millis)} con CADA campo String
//     { id, pId, text, pViews: "0", type, expiry, video, image, pTime }
@MainActor
public final class MyAdsViewModel: ObservableObject {
    @Published public var myAds: [AdPostModel] = []
    @Published public var didLoad: Bool = false

    /// `true` con sesión real (no demo): en demo se conserva el seed y la escritura queda desactivada.
    public var usesLiveAds: Bool { FirebaseService.shared.canWriteToCloud }

    private var isStarted = false
    /// UID de la sesión bajo la que se registró el observer (para reiniciar si cambia la cuenta).
    private var observedUid: String? = nil
    #if canImport(FirebaseDatabase)
    private var observer: (handle: DatabaseHandle, remove: () -> Void)?
    #endif

    public init() {}

    /// Baja el observer (cierre de la vista o cambio de cuenta).
    public func close() {
        #if canImport(FirebaseDatabase)
        observer?.remove()
        observer = nil
        #endif
        isStarted = false
        observedUid = nil
    }

    deinit {
        #if canImport(FirebaseDatabase)
        observer?.remove()
        #endif
    }

    // MARK: - Observador de mis anuncios
    public func ensureStarted() {
        guard FirebaseService.shared.canWriteToCloud,
              let uid = FirebaseService.shared.authenticatedUid else { return }
        // Tras un logout/login con otra cuenta hay que re-observar bajo el nuevo uid.
        if observedUid != uid {
            close()
            observedUid = uid
        }
        guard !isStarted else { return }
        isStarted = true
        #if canImport(FirebaseDatabase)
        // Mismo query que AdsManagerActivity.getMyAds (líneas 369-370).
        let query = Database.database().reference().child("AdsPost")
            .queryOrdered(byChild: "id").queryEqual(toValue: uid)
        let handle = query.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var rows: [AdPostModel] = []
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    rows.append(AdPostModel(id: snap.key, dict: dict))
                }
                // Más reciente primero (pTime epoch ms como String).
                rows.sort { $0.pTimeMillis > $1.pTimeMillis }
                self.myAds = rows
                self.didLoad = true
            }
        }
        observer = (handle: handle, remove: { query.removeObserver(withHandle: handle) })
        #else
        didLoad = true
        #endif
    }

    // MARK: - Publicación de anuncios (réplica de CreateAdsActivity.java:2320-2408)
    /// Escribe `AdsPost/{millis}` con el esquema exacto de Android. Para `type == "image"`
    /// sube la foto a `Post/Post_{millis}` en Storage (misma ruta que Android, CreateAdsActivity.java:2346).
    public func publishAd(
        text: String,
        type: String,
        expiryDays: Int,
        imageData: Data?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard FirebaseService.shared.canWriteToCloud,
              let uid = FirebaseService.shared.authenticatedUid else {
            completion(.failure(NSError(
                domain: "AdsManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Se requiere una sesión real para publicar anuncios."]
            )))
            return
        }

        let timeStamp = String(Int64(Date().timeIntervalSince1970 * 1000))

        let finishWrite: (String) -> Void = { imageUrl in
            #if canImport(FirebaseDatabase)
            // CADA campo String, idénticos a CreateAdsActivity.java:2322-2332.
            let payload: [String: String] = [
                "id": uid,
                "pId": timeStamp,
                "text": text,
                "pViews": "0",
                "type": type,
                "expiry": String(expiryDays),
                "video": "no",
                "image": imageUrl,
                "pTime": timeStamp
            ]
            Database.database().reference().child("AdsPost").child(timeStamp).setValue(payload) { error, _ in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
            #else
            completion(.failure(NSError(
                domain: "AdsManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "La base de datos no está disponible en esta compilación."]
            )))
            #endif
        }

        if type == "image", let data = imageData {
            // Mismo path de Storage que Android (CreateAdsActivity.java:2346): "Post/" + "Post_" + millis.
            UploadManager.shared.uploadData(data: data, path: "Post/Post_\(timeStamp)", mimeType: "image/jpeg") { result in
                switch result {
                case .success(let url):
                    finishWrite(url)
                case .failure(let error):
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            }
        } else {
            finishWrite("no")
        }
    }
}

// MARK: - Musical Ads & Promotion Manager (PromotionActivity.java equivalent)
public struct AdsManagerView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @StateObject private var myAdsViewModel = MyAdsViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var isCreateAdPresented: Bool = false
    
    // Seed exclusivo del modo demo (sin sesión real de Firebase).
    @State private var activeCampaigns = [
        AdCampaignModel(id: "ad1", title: "Promoción Concierto de Gala", budgetUSD: 25.0, impressions: 4200, clicks: 310, status: "Activo"),
        AdCampaignModel(id: "ad2", title: "Clases de Violín Avanzado", budgetUSD: 15.0, impressions: 1850, clicks: 142, status: "Pausado")
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header Promo Card
                        VStack(spacing: 12) {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.gold)
                            
                            Text("Promociona tu Música o Servicios")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Llega a miles de estudiantes, directores y organizadores de eventos en tu ciudad.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                if myAdsViewModel.usesLiveAds {
                                    isCreateAdPresented = true
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Crear Nuevo Anuncio")
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(AppColors.primaryDark)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(20)
                            }
                            .disabled(!myAdsViewModel.usesLiveAds)

                            if !myAdsViewModel.usesLiveAds {
                                Text("Modo demostración: inicia sesión con tu cuenta para publicar anuncios reales.")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(20)
                        .background(AppColors.primaryGradient)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // My Ads Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Tus Anuncios Publicitarios")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 16)

                            if myAdsViewModel.usesLiveAds {
                                if myAdsViewModel.myAds.isEmpty {
                                    emptyState
                                } else {
                                    ForEach(myAdsViewModel.myAds) { ad in
                                        myAdRow(ad)
                                    }
                                }
                            } else {
                                // Modo demo: se conserva el seed original.
                                Text("Anuncios de ejemplo (modo demostración).")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                                    .padding(.horizontal, 16)

                                ForEach(activeCampaigns) { ad in
                                    demoCampaignCard(ad)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Publicidad y Promociones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
                myAdsViewModel.ensureStarted()
            }
            .onDisappear {
                myAdsViewModel.close()
            }
            .sheet(isPresented: $isCreateAdPresented) {
                CreateAdView(myAdsViewModel: myAdsViewModel)
            }
        }
    }

    // MARK: - Estado vacío (sin anuncios publicados)
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "megaphone")
                .font(.system(size: 34))
                .foregroundColor(AppColors.gold)
            Text("Aún no has publicado anuncios")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
            Text("Crea tu primer anuncio para aparecer patrocinado en el feed de toda la comunidad.")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(theme.cardColor)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Fila de anuncio real (nodo AdsPost)
    private func myAdRow(_ ad: AdPostModel) -> some View {
        let isExpired = ad.isExpired(nowMillis: Int64(Date().timeIntervalSince1970 * 1000))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(ad.text.isEmpty ? "Anuncio sin texto" : ad.text)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                Spacer()
                Text(isExpired ? "Caducado" : "Activo")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isExpired ? Color.gray.opacity(0.2) : AppColors.success.opacity(0.2))
                    .foregroundColor(isExpired ? .gray : AppColors.success)
                    .cornerRadius(8)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tipo")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                    Text(typeLabel(ad.type))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Impresiones")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                    Text(ad.pViews)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duración")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                    Text(durationLabel(ad))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .padding(16)
        .background(theme.cardColor)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    private func typeLabel(_ type: String) -> String {
        switch type {
        case "image": return "Imagen"
        case "video": return "Vídeo"
        case "post": return "Publicación"
        default: return "Texto"
        }
    }

    private func durationLabel(_ ad: AdPostModel) -> String {
        let trimmed = ad.expiry.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "—" }
        if trimmed.count <= 6 { return "\(trimmed) días" }
        let date = Date(timeIntervalSince1970: TimeInterval(Int64(trimmed) ?? 0) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Tarjeta de campaña seed (solo modo demo)
    private func demoCampaignCard(_ ad: AdCampaignModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(ad.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text(ad.status)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ad.status == "Activo" ? AppColors.success.opacity(0.2) : Color.gray.opacity(0.2))
                    .foregroundColor(ad.status == "Activo" ? AppColors.success : .gray)
                    .cornerRadius(8)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Presupuesto")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                    Text("$\(String(format: "%.2f", ad.budgetUSD)) USD")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Impresiones")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                    Text("\(ad.impressions)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clics")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                    Text("\(ad.clicks)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .padding(16)
        .background(theme.cardColor)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}

// MARK: - Create Ad View (CreateAdsActivity.java equivalent)
// Escribe `AdsPost/{millis}` con el esquema exacto de Android.
struct CreateAdView: View {
    @ObservedObject var myAdsViewModel: MyAdsViewModel
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var uploads = UploadManager.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var adText: String = ""
    @State private var adType: String = "text"
    @State private var expiryDays: Int = 7
    @State private var pickedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var isSuccess: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isPublishing: Bool = false

    private let durationOptions: [Int] = [1, 3, 7, 15, 30, 60]

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Contenido del Anuncio")) {
                        TextEditor(text: $adText)
                            .frame(height: 90)
                        Picker("Tipo de Anuncio", selection: $adType) {
                            Text("Texto").tag("text")
                            Text("Imagen").tag("image")
                        }
                    }

                    if adType == "image" {
                        Section(header: Text("Imagen")) {
                            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                                HStack(spacing: 10) {
                                    Image(systemName: "photo.fill")
                                        .foregroundColor(AppColors.primary)
                                    Text(photoData == nil ? "Elegir imagen del anuncio" : "Imagen seleccionada")
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    if photoData != nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.success)
                                    }
                                }
                            }
                            if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 160)
                                    .cornerRadius(12)
                                    .clipped()
                            }
                        }
                    }

                    Section(header: Text("Duración")) {
                        Picker("Duración (días)", selection: $expiryDays) {
                            ForEach(durationOptions, id: \.self) { days in
                                Text("\(days) días").tag(days)
                            }
                        }
                        Text("El anuncio se mostrará en el feed hasta cumplir su duración.")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }

                    Section {
                        Button(action: publish) {
                            HStack {
                                if isPublishing || uploads.isUploading {
                                    ProgressView()
                                }
                                Text(isPublishing || uploads.isUploading
                                     ? "Publicando... \(Int(uploads.uploadProgress * 100))%"
                                     : "Publicar Anuncio")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .disabled(!canPublish)
                        .listRowBackground(AppColors.primary)
                    }
                }
            }
            .navigationTitle("Crear Anuncio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onChange(of: pickedPhoto) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    } else {
                        photoData = nil
                    }
                }
            }
            .alert("Anuncio Publicado", isPresented: $isSuccess) {
                Button("OK") { presentationMode.wrappedValue.dismiss() }
            } message: {
                Text("Tu anuncio ya se muestra patrocinado en el feed de la comunidad.")
            }
            .alert("Error al Publicar", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var canPublish: Bool {
        let hasText = !adText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImage = adType != "image" || photoData != nil
        return hasText && hasImage && !isPublishing && !uploads.isUploading
    }

    private func publish() {
        guard myAdsViewModel.usesLiveAds else { return }
        isPublishing = true
        myAdsViewModel.publishAd(
            text: adText.trimmingCharacters(in: .whitespacesAndNewlines),
            type: adType,
            expiryDays: expiryDays,
            imageData: adType == "image" ? photoData : nil
        ) { result in
            isPublishing = false
            switch result {
            case .success:
                isSuccess = true
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Modelo de campaña seed (solo modo demo)
struct AdCampaignModel: Identifiable {
    let id: String
    let title: String
    let budgetUSD: Double
    let impressions: Int
    let clicks: Int
    let status: String
}
