import SwiftUI
import MapKit

// MARK: - Musical Hub: Explore Mariachis, Bands & Ensembles
public struct MusicalHubView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedType: MusicalGroupProfileModel.GroupType? = nil
    @State private var searchText: String = ""
    @State private var isQuotesManagerPresented: Bool = false
    @State private var selectedGroupForQuote: MusicalGroupProfileModel? = nil
    
    @State private var groups: [MusicalGroupProfileModel] = [
        MusicalGroupProfileModel(
            id: "group_1",
            name: "Mariachi Sinfónico Real de México",
            directorName: "Mtro. Alejandro Morales",
            directorId: "director_01",
            groupType: .mariachi,
            location: "Ciudad de México (Cobertura CDMX y EdoMéx)",
            coverageRadiusKm: 60,
            membersCount: 10,
            avatarUrl: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
            coverBannerUrl: "https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=800&auto=format&fit=crop&q=60",
            rating: 5.0,
            reviewsCount: 84,
            basePricePerHourUSD: 300.0,
            experienceYears: 18,
            repertoireCount: 450,
            isVerified: true,
            packages: [
                MusicalServicePackageModel(
                    title: "Serenata Express (7 Canciones)",
                    durationHours: 0.75,
                    musiciansCount: 8,
                    description: "Ideal para aniversarios y cumpleaños. Traje de gala negro y plata.",
                    priceUSD: 220.0
                ),
                MusicalServicePackageModel(
                    title: "Hora Completa de Gala",
                    durationHours: 1.0,
                    musiciansCount: 10,
                    description: "Repertorio completo tradicional y moderno con trompetas y violines de primera.",
                    priceUSD: 300.0
                )
            ]
        ),
        MusicalGroupProfileModel(
            id: "group_2",
            name: "Cuarteto de Cuerdas Bellas Artes",
            directorName: "Elena Vargas",
            directorId: "director_02",
            groupType: .cuartetoCuerdas,
            location: "Guadalajara, Jalisco",
            coverageRadiusKm: 40,
            membersCount: 4,
            avatarUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=60",
            rating: 4.9,
            reviewsCount: 52,
            basePricePerHourUSD: 240.0,
            experienceYears: 10,
            repertoireCount: 220,
            isVerified: true,
            packages: [
                MusicalServicePackageModel(
                    title: "Música para Boda Religiosa o Civil",
                    durationHours: 1.5,
                    musiciansCount: 4,
                    description: "Canon de Pachelbel, Marcha Nupcial, arreglos pop y música clásica sacra.",
                    priceUSD: 350.0
                )
            ]
        ),
        MusicalGroupProfileModel(
            id: "group_3",
            name: "Banda La Sinaloense Imperial",
            directorName: "Gonzalo Beltrán",
            directorId: "director_03",
            groupType: .bandaSinaloense,
            location: "Mazatlán, Sinaloa",
            coverageRadiusKm: 100,
            membersCount: 14,
            avatarUrl: "https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&auto=format&fit=crop&q=60",
            rating: 4.8,
            reviewsCount: 41,
            basePricePerHourUSD: 450.0,
            experienceYears: 14,
            repertoireCount: 350,
            isVerified: true
        )
    ]
    
    public init() {}
    
    public var filteredGroups: [MusicalGroupProfileModel] {
        groups.filter { grp in
            let matchesType = selectedType == nil || grp.groupType == selectedType
            let matchesSearch = searchText.isEmpty ||
                grp.name.localizedCaseInsensitiveContains(searchText) ||
                grp.location.localizedCaseInsensitiveContains(searchText)
            
            return matchesType && matchesSearch
        }
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Bar
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(theme.textPrimary)
                        }
                        
                        Text("Hub Musical: Agrupaciones")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                        
                        Spacer()
                        
                        Button(action: { isQuotesManagerPresented = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.plaintext.fill")
                                    .foregroundColor(AppColors.primary)
                                Text("Cotizaciones")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.primary.opacity(0.12))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(theme.cardColor)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(theme.textSecondary)
                        TextField("Buscar mariachis, cuartetos, bandas por ciudad...", text: $searchText)
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(10)
                    .background(theme.backgroundColor)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    
                    // Group Type Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button(action: { selectedType = nil }) {
                                Text("Todas")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(selectedType == nil ? .white : theme.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedType == nil ? AppColors.primary : theme.cardColor)
                                    .cornerRadius(16)
                            }
                            
                            ForEach(MusicalGroupProfileModel.GroupType.allCases, id: \.self) { type in
                                Button(action: { selectedType = type }) {
                                    Text(type.rawValue)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedType == type ? .white : theme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedType == type ? AppColors.primary : theme.cardColor)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    
                    // Groups List
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredGroups) { group in
                                MusicalGroupCardItem(group: group) {
                                    selectedGroupForQuote = group
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedGroupForQuote) { group in
                GroupQuoteRequestModal(group: group)
            }
            .sheet(isPresented: $isQuotesManagerPresented) {
                MusicalQuotesManagerView()
            }
        }
    }
}

// MARK: - Musical Group Card Item
struct MusicalGroupCardItem: View {
    let group: MusicalGroupProfileModel
    let onQuoteTapped: () -> Void
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarView(urlString: group.avatarUrl, size: 52, isVerified: group.isVerified)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(group.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.gold)
                            Text(String(format: "%.1f", group.rating))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textPrimary)
                            Text("(\(group.reviewsCount))")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    
                    Text("\(group.groupType.rawValue) • Director: \(group.directorName)")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                            .foregroundColor(AppColors.primary)
                        Text(group.location)
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                        .font(.caption2)
                    Text("\(group.membersCount) Integrantes")
                        .font(.caption2)
                }
                .foregroundColor(theme.textSecondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "music.note.list")
                        .font(.caption2)
                    Text("\(group.repertoireCount)+ Temas")
                        .font(.caption2)
                }
                .foregroundColor(theme.textSecondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "location.north.circle.fill")
                        .font(.caption2)
                    Text("Radio \(group.coverageRadiusKm) km")
                        .font(.caption2)
                }
                .foregroundColor(theme.textSecondary)
            }
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Desde")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                    
                    Text(String(format: "$%.2f USD / hr", group.basePricePerHourUSD))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primary)
                }
                
                Spacer()
                
                Button(action: onQuoteTapped) {
                    Text("Solicitar Cotización")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.primary)
                        .cornerRadius(14)
                }
            }
        }
        .padding(14)
        .background(theme.cardColor)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Group Quote Request Modal
struct GroupQuoteRequestModal: View {
    let group: MusicalGroupProfileModel
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var eventType: String = "Serenata"
    @State private var eventDate: Date = Date().addingTimeInterval(86400 * 4)
    @State private var hours: Double = 1.0
    @State private var venueAddress: String = ""
    @State private var notes: String = ""
    @State private var isSentAlertPresented: Bool = false
    
    let eventTypes = ["Serenata", "Cumpleaños", "Boda", "Aniversario", "Graduación", "Corporativo"]
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Agrupación Musical")) {
                        Text(group.name)
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                        Text("Tarifa Base: \(String(format: "$%.2f USD / hr", group.basePricePerHourUSD))")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
                    }
                    
                    Section(header: Text("Detalles del Evento")) {
                        Picker("Motivo del Evento", selection: $eventType) {
                            ForEach(eventTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        
                        DatePicker("Fecha y Hora", selection: $eventDate, in: Date()...)
                        
                        Stepper("Duración: \(String(format: "%.1f", hours)) horas", value: $hours, in: 0.5...8.0, step: 0.5)
                        
                        TextField("Dirección o Lugar del Evento", text: $venueAddress)
                        
                        TextField("Canciones especiales o notas para el director", text: $notes)
                    }
                    
                    Section(header: Text("Presupuesto Estimado")) {
                        HStack {
                            Text("Total Estimado:")
                            Spacer()
                            Text(String(format: "$%.2f USD", group.basePricePerHourUSD * hours))
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    
                    Section {
                        Button(action: { isSentAlertPresented = true }) {
                            Text("Enviar Solicitud de Cotización")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .disabled(venueAddress.isEmpty)
                        .listRowBackground(venueAddress.isEmpty ? Color.gray : AppColors.primary)
                    }
                }
            }
            .navigationTitle("Cotizar Servicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSentAlertPresented) {
                Alert(
                    title: Text("¡Cotización Enviada!"),
                    message: Text("El director de \(group.name) responderá a tu solicitud con la confirmación de fecha."),
                    dismissButton: .default(Text("Aceptar")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
}
