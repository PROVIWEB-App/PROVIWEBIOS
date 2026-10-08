import SwiftUI

// MARK: - Legal, Terms & Support Center View
public struct LegalAndSupportView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTab: Int = 0
    @State private var supportTicketSubject: String = ""
    @State private var supportTicketMessage: String = ""
    @State private var isSupportSentAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Picker("Sección", selection: $selectedTab) {
                        Text("Términos").tag(0)
                        Text("Privacidad").tag(1)
                        Text("Soporte").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            if selectedTab == 0 {
                                termsContent
                            } else if selectedTab == 1 {
                                privacyContent
                            } else {
                                supportContent
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Términos & Soporte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSupportSentAlert) {
                Alert(
                    title: Text("¡Ticket Enviado!"),
                    message: Text("Nuestro equipo de soporte técnico revisará tu solicitud y te responderá en breve a tu correo registrado."),
                    dismissButton: .default(Text("Aceptar")) {
                        supportTicketSubject = ""
                        supportTicketMessage = ""
                    }
                )
            }
        }
    }
    
    private var termsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Términos y Condiciones de Uso")
                .font(.headline)
                .foregroundColor(theme.textPrimary)
            
            Text("Bienvenido a PROVIWEB. Al utilizar nuestra plataforma, aceptas los términos y condiciones relativos a la creación de contenido musical, derechos de autor de partituras, servicios de contratación de agrupaciones musicales y el uso del monedero QAV y recompensas de práctica.")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .lineSpacing(4)
            
            Text("1. Propiedad Intelectual")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
            
            Text("Los usuarios retienen todos los derechos morales y patrimoniales sobre sus obras musicales originales, partituras publicadas y grabaciones de audio/video compartidas en la red.")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .lineSpacing(4)
            
            Text("2. Contratación de Agrupaciones y Músicos")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
            
            Text("Las cotizaciones acordadas entre clientes y directores representan un compromiso de servicio. PROVIWEB facilita la comunicación, cobro de anticipos y validación de autenticidad.")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(theme.cardColor)
        .cornerRadius(18)
    }
    
    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Política de Privacidad y Protección de Datos")
                .font(.headline)
                .foregroundColor(theme.textPrimary)
            
            Text("En PROVIWEB nos tomamos muy en serio tu privacidad. Esta política describe cómo recolectamos, almacenamos y procesamos tu información personal, ubicación para servicios cercanos y datos biométricos locales.")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .lineSpacing(4)
            
            Text("Ubicación y Micrófono")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
            
            Text("El acceso al micrófono se utiliza exclusivamente de manera local en el afinador cromático, metrónomo interactivo y estimación de postura musical. Nunca grabamos audio ambiental sin tu consentimiento explícito.")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(theme.cardColor)
        .cornerRadius(18)
    }
    
    private var supportContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Centro de Ayuda y Soporte")
                .font(.headline)
                .foregroundColor(theme.textPrimary)
            
            Text("¿Tienes algún problema con un pago, cotización, partitura o reporte técnico? Escríbenos directamente.")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            
            TextField("Asunto de la Consulta", text: $supportTicketSubject)
                .padding(10)
                .background(theme.backgroundColor)
                .cornerRadius(10)
            
            TextEditor(text: $supportTicketMessage)
                .frame(height: 100)
                .padding(4)
                .background(theme.backgroundColor)
                .cornerRadius(10)
            
            Button(action: {
                isSupportSentAlert = true
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Enviar Consulta")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(supportTicketSubject.isEmpty || supportTicketMessage.isEmpty ? Color.gray : AppColors.primary)
                .cornerRadius(16)
            }
            .disabled(supportTicketSubject.isEmpty || supportTicketMessage.isEmpty)
        }
        .padding(16)
        .background(theme.cardColor)
        .cornerRadius(18)
    }
}
