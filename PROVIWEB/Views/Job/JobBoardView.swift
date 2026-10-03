import SwiftUI

// MARK: - Musical Job Board & Gigs View (com.israviolink.app.job equivalent)
public struct JobBoardView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isPostJobPresented: Bool = false
    @State private var selectedFilter: String = "Todos"
    
    @State private var jobs = [
        JobOfferModel(id: "j1", title: "Violinista para Cuarteto de Bodas", ensemble: "Ensamble Armonía", city: "Ciudad de México", paymentUSD: 120.0, instrument: "Violín", date: "Sábado 18 Octubre", isUrgent: true),
        JobOfferModel(id: "j2", title: "Trompeta Primera para Mariachi", ensemble: "Mariachi Sol de Oro", city: "Guadalajara, JAL", paymentUSD: 80.0, instrument: "Trompeta", date: "Fines de Semana", isUrgent: false),
        JobOfferModel(id: "j3", title: "Profesor de Iniciación Musical y Cuerdas", ensemble: "Academia Amadeus", city: "Monterrey, NL", paymentUSD: 450.0, instrument: "Cuerdas", date: "Mensual / Medio Tiempo", isUrgent: false)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Post Job Banner
                        Button(action: { isPostJobPresented = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "briefcase.fill")
                                    .font(.title3)
                                Text("Publicar Vacante o Búsqueda de Músico")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.primary)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Job Offers List
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Bolsa de Trabajo Musical")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 16)
                            
                            ForEach(jobs) { job in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(job.title)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(theme.textPrimary)
                                            
                                            Text("\(job.ensemble) • \(job.city)")
                                                .font(.caption)
                                                .foregroundColor(theme.textSecondary)
                                        }
                                        Spacer()
                                        if job.isUrgent {
                                            Text("URGENTE")
                                                .font(.system(size: 9, weight: .black))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(AppColors.errorRed)
                                                .foregroundColor(.white)
                                                .cornerRadius(6)
                                        }
                                    }
                                    
                                    HStack {
                                        Label(job.instrument, systemImage: "music.note")
                                            .font(.caption2)
                                            .foregroundColor(AppColors.primary)
                                        
                                        Spacer()
                                        
                                        Text("$\(Int(job.paymentUSD)) USD")
                                            .font(.subheadline)
                                            .fontWeight(.black)
                                            .foregroundColor(AppColors.success)
                                    }
                                    
                                    HStack(spacing: 10) {
                                        Text("Fecha: \(job.date)")
                                            .font(.caption2)
                                            .foregroundColor(theme.textSecondary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            // Trigger contact / apply action
                                        }) {
                                            Text("Postularme")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 6)
                                                .background(AppColors.primary)
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                                .padding(16)
                                .background(theme.cardColor)
                                .cornerRadius(16)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Empleos y Vacantes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $isPostJobPresented) {
                PostJobSheet()
            }
        }
    }
}

struct PostJobSheet: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var title: String = ""
    @State private var ensemble: String = ""
    @State private var payment: String = ""
    @State private var instrument: String = "Violín"
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                Form {
                    Section(header: Text("Información del Empleo")) {
                        TextField("Título de la Vacante", text: $title)
                        TextField("Nombre del Ensamble / Empresa", text: $ensemble)
                        TextField("Honorarios (USD)", text: $payment)
                            .keyboardType(.decimalPad)
                        Picker("Instrumento Requerido", selection: $instrument) {
                            Text("Violín").tag("Violín")
                            Text("Viola / Cello").tag("Cuerdas")
                            Text("Trompeta").tag("Trompeta")
                            Text("Guitarra / Vihuela").tag("Guitarra")
                            Text("Vocalista").tag("Voz")
                        }
                    }
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Publicar Oferta")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(AppColors.primary)
                }
            }
            .navigationTitle("Nueva Oferta de Trabajo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

struct JobOfferModel: Identifiable {
    let id: String
    let title: String
    let ensemble: String
    let city: String
    let paymentUSD: Double
    let instrument: String
    let date: String
    let isUrgent: Bool
}
