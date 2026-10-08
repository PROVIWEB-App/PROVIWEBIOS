import SwiftUI

// MARK: - Edit User Profile View
public struct EditProfileView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var instrument: String = ""
    @State private var experienceYears: Int = 10
    @State private var phone: String = ""
    @State private var location: String = ""
    @State private var isSavedAlert: Bool = false
    
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
                                Button(action: {}) {
                                    Text("Cambiar Foto")
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
                    username = u.username
                    bio = u.bio ?? ""
                    instrument = u.instrument ?? "Violín"
                    experienceYears = u.experienceYears ?? 10
                    phone = u.phone ?? ""
                    location = u.location ?? "CDMX"
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
        isSavedAlert = true
    }
}
