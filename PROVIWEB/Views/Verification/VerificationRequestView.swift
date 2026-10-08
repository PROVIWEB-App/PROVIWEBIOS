import SwiftUI

// MARK: - Multi-Tier Verification Request View (Student, Teacher, Entity)
public struct VerificationRequestView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    public enum VerificationTier: String, CaseIterable {
        case musician = "Músico Profesional"
        case teacher = "Profesor / Maestro"
        case student = "Estudiante de Música"
        case entity = "Entidad / Conservatorio / Mariachi"
    }
    
    @State private var selectedTier: VerificationTier = .musician
    @State private var institutionName: String = ""
    @State private var credentialsUrl: String = ""
    @State private var officialIdNumber: String = ""
    @State private var isSentAlertPresented: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Tipo de Insignia de Verificación")) {
                        Picker("Categoría", selection: $selectedTier) {
                            ForEach(VerificationTier.allCases, id: \.self) { tier in
                                Text(tier.rawValue).tag(tier)
                            }
                        }
                    }
                    
                    Section(header: Text("Datos de Respaldo")) {
                        TextField("Institución, Conservatorio o Agrupación", text: $institutionName)
                        TextField("Número de Cédula o Identificación Oficial", text: $officialIdNumber)
                        TextField("Enlace a Portafolio, Título o Credencial", text: $credentialsUrl)
                    }
                    
                    Section(footer: Text("Los perfiles verificados obtienen mayor visibilidad en el Marketplace, Hub Musical y en la recomendación del Profesor IA.")) {
                        EmptyView()
                    }
                    
                    Section {
                        Button(action: {
                            isSentAlertPresented = true
                        }) {
                            Text("Enviar Solicitud de Verificación")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .disabled(institutionName.isEmpty || officialIdNumber.isEmpty)
                        .listRowBackground(institutionName.isEmpty ? Color.gray : AppColors.primary)
                    }
                }
            }
            .navigationTitle("Verificación de Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSentAlertPresented) {
                Alert(
                    title: Text("¡Solicitud Recibida!"),
                    message: Text("El equipo de moderación de PROVIWEB revisará tus credenciales dentro de las próximas 24 a 48 horas."),
                    dismissButton: .default(Text("Entendido")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
}
