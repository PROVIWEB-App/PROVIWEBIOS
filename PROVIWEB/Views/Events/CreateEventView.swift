import SwiftUI

// MARK: - Create Artistic Event View
public struct CreateEventView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    public var onEventCreated: (ArtisticEventModel) -> Void
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var venueName: String = ""
    @State private var address: String = ""
    @State private var eventDate: Date = Date().addingTimeInterval(86400 * 7)
    @State private var durationHours: Double = 2.0
    @State private var category: ArtisticEventModel.EventCategory = .concert
    @State private var ticketPriceText: String = "25.00"
    @State private var capacityText: String = "150"
    @State private var isFree: Bool = false
    @State private var isLiveStreamed: Bool = true
    
    public init(onEventCreated: @escaping (ArtisticEventModel) -> Void) {
        self.onEventCreated = onEventCreated
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Información Principal")) {
                        TextField("Título del Evento o Concierto", text: $title)
                        
                        Picker("Categoría", selection: $category) {
                            ForEach(ArtisticEventModel.EventCategory.allCases, id: \.self) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                        
                        TextEditor(text: $description)
                            .frame(height: 90)
                            .overlay(
                                Group {
                                    if description.isEmpty {
                                        Text("Describe el evento, programa, repertorio y artistas participantes...")
                                            .foregroundColor(Color.gray.opacity(0.6))
                                            .padding(6)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    }
                                }
                            )
                    }
                    
                    Section(header: Text("Fecha y Lugar")) {
                        DatePicker("Fecha y Hora", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                        Stepper("Duración: \(String(format: "%.1f", durationHours)) horas", value: $durationHours, in: 0.5...12.0, step: 0.5)
                        
                        TextField("Nombre del Recinto / Sala", text: $venueName)
                        TextField("Dirección Completa", text: $address)
                    }
                    
                    Section(header: Text("Boletaje & Transmisión")) {
                        Toggle("Evento Gratuito", isOn: $isFree)
                        
                        if !isFree {
                            TextField("Precio Entrada (USD)", text: $ticketPriceText)
                                .keyboardType(.decimalPad)
                        }
                        
                        TextField("Aforo / Capacidad Total", text: $capacityText)
                            .keyboardType(.numberPad)
                        
                        Toggle("Transmitir en Vivo por PROVIWEB", isOn: $isLiveStreamed)
                    }
                    
                    Section {
                        Button(action: saveEvent) {
                            Text("Publicar Evento")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .disabled(title.isEmpty || venueName.isEmpty)
                        .listRowBackground(title.isEmpty ? Color.gray : AppColors.primary)
                    }
                }
            }
            .navigationTitle("Crear Evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
    
    private func saveEvent() {
        let price = isFree ? 0.0 : (Double(ticketPriceText) ?? 20.0)
        let capacity = Int(capacityText) ?? 100
        
        let newEvent = ArtisticEventModel(
            title: title,
            organizerId: firebase.currentUserId,
            organizerName: firebase.currentUser?.name ?? "Israel Violín",
            organizerDp: firebase.currentUser?.image,
            description: description,
            venueName: venueName,
            address: address,
            eventDate: eventDate,
            durationHours: durationHours,
            category: category,
            ticketPriceUSD: price,
            ticketPriceDiamonds: Int(price * 6),
            totalCapacity: capacity,
            ticketsSold: 0,
            isFree: isFree,
            isLiveStreamed: isLiveStreamed
        )
        
        onEventCreated(newEvent)
        presentationMode.wrappedValue.dismiss()
    }
}
