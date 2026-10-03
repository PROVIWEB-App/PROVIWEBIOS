import SwiftUI

// MARK: - Musical Ads & Promotion Manager (PromotionActivity.java equivalent)
public struct AdsManagerView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isCreateAdPresented: Bool = false
    
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
                            
                            Button(action: { isCreateAdPresented = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Crear Nueva Campaña")
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(AppColors.primaryDark)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(20)
                            }
                        }
                        .padding(20)
                        .background(AppColors.primaryGradient)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Active Campaigns Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Tus Campañas Publicitarias")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 16)
                            
                            ForEach(activeCampaigns) { ad in
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
            .sheet(isPresented: $isCreateAdPresented) {
                CreateAdView()
            }
        }
    }
}

// MARK: - Create Ad View
struct CreateAdView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var adTitle: String = ""
    @State private var targetAudience: String = "Músicos en mi Ciudad"
    @State private var budgetTier: Double = 10.0
    @State private var isSuccess: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Detalles del Anuncio")) {
                        TextField("Título de la Promoción", text: $adTitle)
                        Picker("Audiencia Objetivo", selection: $targetAudience) {
                            Text("Estudiantes de Música").tag("Estudiantes")
                            Text("Profesores y Directores").tag("Profesores")
                            Text("Público General para Eventos").tag("Eventos")
                            Text("Todos en un radio de 50km").tag("Radio50")
                        }
                    }
                    
                    Section(header: Text("Presupuesto y Duración")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Presupuesto: $\(Int(budgetTier)) USD (Alcance aprox: \(Int(budgetTier * 250)) personas)")
                                .font(.caption)
                                .foregroundColor(AppColors.primary)
                            
                            Slider(value: $budgetTier, in: 5...100, step: 5)
                                .accentColor(AppColors.primary)
                        }
                    }
                    
                    Button(action: {
                        isSuccess = true
                    }) {
                        Text("Lanzar Campaña con Saldo QAV")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(AppColors.primary)
                }
            }
            .navigationTitle("Crear Promoción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSuccess) {
                Alert(title: Text("Campaña Creada"), message: Text("Tu anuncio ha sido programado y se mostrará en el muro musical."), dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                })
            }
        }
    }
}

struct AdCampaignModel: Identifiable {
    let id: String
    let title: String
    let budgetUSD: Double
    let impressions: Int
    let clicks: Int
    let status: String
}
