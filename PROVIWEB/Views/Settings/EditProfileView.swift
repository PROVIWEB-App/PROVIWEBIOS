import SwiftUI
import PhotosUI

// MARK: - Edit User Profile View
public struct EditProfileView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @ObservedObject private var uploads = UploadManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var instrument: String = ""
    @State private var experienceYears: Int = 10
    @State private var phone: String = ""
    @State private var location: String = ""
    @State private var isSavedAlert: Bool = false
    @State private var pickedPhoto: PhotosPickerItem? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Foto de Perfil")) {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                AvatarView(urlString: firebase.currentUser?.image, size: 80, isVerified: true)
                                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                                    HStack(spacing: 4) {
                                        if uploads.isUploading {
                                            ProgressView()
                                        } else {
                                            Image(systemName: "camera.fill")
                                        }
                                        Text(uploads.isUploading
                                             ? "Subiendo... \(Int(uploads.uploadProgress * 100))%"
                                             : "Cambiar Foto")
                                    }
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section(header: Text("Información Básica")) {
                        TextField("Nombre Completo", text: $name)
                        TextField("Nombre de Usuario (@)", text: $username)
                        TextField("Instrumento Principal", text: $instrument)
                        Stepper("Años de Experiencia: \(experienceYears)", value: $experienceYears, in: 0...60)
                    }
                    
                    Section(header: Text("Biografía Artística")) {
                        TextEditor(text: $bio)
                            .frame(height: 80)
                    }
                    
                    Section(header: Text("Contacto y Ubicación")) {
                        TextField("Teléfono", text: $phone)
                            .keyboardType(.phonePad)
                        TextField("Ciudad / Estado", text: $location)
                    }
                    
                    Section {
                        Button(action: saveChanges) {
                            Text("Guardar Cambios")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .listRowBackground(AppColors.primary)
                    }
                }
            }
            .navigationTitle("Editar Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
                if let u = firebase.currentUser {
                    name = u.name
                    username = u.username ?? ""
                    bio = u.bio ?? ""
                    instrument = u.instrument ?? "Violín"
                    experienceYears = u.experienceYears ?? 10
                    phone = u.phone ?? ""
                    location = u.location ?? "CDMX"
                }
            }
            .onChange(of: pickedPhoto) { item in
                guard let item = item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    // Ruta Storage idéntica a EditProfileActivity.uploadDp() en Android.
                    let millis = "\(Int(Date().timeIntervalSince1970 * 1000))"
                    uploads.uploadData(data: data, path: "profile_photo/\(millis)", mimeType: "image/jpeg") { result in
                        if case .success(let url) = result {
                            firebase.updateProfilePhotoURL(url)
                        }
                    }
                    pickedPhoto = nil
                }
            }
            .alert(isPresented: $isSavedAlert) {
                Alert(
                    title: Text("¡Perfil Actualizado!"),
                    message: Text("Tus datos se han guardado exitosamente en la plataforma."),
                    dismissButton: .default(Text("Aceptar")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    private func saveChanges() {
        firebase.currentUser?.name = name
        firebase.currentUser?.username = username
        firebase.currentUser?.bio = bio
        firebase.currentUser?.instrument = instrument
        firebase.currentUser?.experienceYears = experienceYears
        firebase.currentUser?.phone = phone
        firebase.currentUser?.location = location
        // Persistir en `Users/{uid}` (el observer local vuelve a sobrescribir currentUser en refetch).
        firebase.saveCurrentUserProfile()
        isSavedAlert = true
    }
}
