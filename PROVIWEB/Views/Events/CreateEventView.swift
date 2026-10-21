import SwiftUI

// MARK: - Create Artistic Event View
public struct CreateEventView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @ObservedObject private var eventsService = EventsService.shared
    @Environment(\.presentationMode) var presentationMode
    
    /// `true` con sesión real: el evento se escribe en `ArtisticEvents` (esquema Android);
    /// en modo demo se mantiene la creación local de siempre.
    private let usesLiveEvents = FirebaseService.shared.canWriteToCloud

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
    @State private var isSaving: Bool = false
    @State private var createErrorMessage: String? = nil
    
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
                            TextField("Precio Entrada (QAV)", text: $ticketPriceText)
                                .keyboardType(.decimalPad)
                        }
                        
                        TextField("Aforo / Capacidad Total", text: $capacityText)
                            .keyboardType(.numberPad)
                        
                        Toggle("Transmitir en Vivo por PROVIWEB", isOn: $isLiveStreamed)
                    }
                    
                    Section {
                        Button(action: saveEvent) {
                            Text(isSaving ? "Publicando..." : "Publicar Evento")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .disabled(title.isEmpty || venueName.isEmpty || isSaving)
                        .listRowBackground(title.isEmpty || venueName.isEmpty || isSaving ? Color.gray : AppColors.primary)
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
            .alert(isPresented: Binding(
                get: { createErrorMessage != nil },
                set: { if !$0 { createErrorMessage = nil } }
            )) {
                Alert(
                    title: Text("No se pudo publicar"),
                    message: Text(createErrorMessage ?? "Error desconocido."),
                    dismissButton: .default(Text("Entendido"))
                )
            }
        }
    }
    
    private func saveEvent() {
        let price = isFree ? 0.0 : (Double(ticketPriceText) ?? 20.0)
        let capacity = Int(capacityText) ?? 100
        let nowMillis = Date().timeIntervalSince1970 * 1000
        
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
            isLiveStreamed: isLiveStreamed,
            status: .upcoming,
            schedule: [],
            collaborators: [],
            creatorUsername: firebase.currentUser?.username ?? "",
            categoryRaw: category.rawValue,
            mediaType: "image",
            eventType: "presencial",
            accessType: "publico",
            eventDateText: EventsService.readableDateFormatter.string(from: eventDate),
            eventTime: EventsService.timeFormatter.string(from: eventDate),
            eventTimestamp: nowMillis,
            onlinePlatform: "",
            paymentMethod: isFree ? "free" : "qav",
            priceQav: price,
            purchaseLink: "",
            createdAt: nowMillis,
            rawStatus: "active"
        )
        
        // Sesión real → escribe el nodo completo `ArtisticEvents/{pushKey}` (esquema Android).
        guard usesLiveEvents else {
            // Modo demo → experiencia local de siempre.
            onEventCreated(newEvent)
            presentationMode.wrappedValue.dismiss()
            return
        }
        
        isSaving = true
        eventsService.createEvent(
            title: title,
            description: description,
            categoryRaw: category.rawValue,
            eventDate: eventDate,
            venueName: venueName,
            address: address,
            isFree: isFree,
            priceQav: price,
            maxCapacity: capacity,
            // Esta vista no tiene selector de imagen: se publica sin portada (coverUrl vacío),
            // igual que Android cuando no elige medios.
            coverUrl: ""
        ) { result in
            self.isSaving = false
            switch result {
            case .success(let event):
                self.onEventCreated(event)
                self.presentationMode.wrappedValue.dismiss()
            case .failure(let message):
                self.createErrorMessage = message
            }
        }
    }
}
