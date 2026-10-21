import SwiftUI

// MARK: - Booking & Availability Calendar View (AdapterCalendarioDisponibilidad.java equivalent)
public struct BookingCalendarView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedDate: Date = Date()
    @State private var selectedTimeSlot: String = "18:00 - 20:00"
    @State private var eventType: String = "Boda / Recepción"
    @State private var isSuccessAlert: Bool = false
    
    // Callback opcional: devuelve la fecha elegida a la vista que lo presenta
    public var onDateSelected: ((Date) -> Void)? = nil
    
    let timeSlots = [
        "10:00 - 12:00",
        "12:00 - 14:00",
        "16:00 - 18:00",
        "18:00 - 20:00",
        "20:00 - 22:00",
        "22:00 - 00:00"
    ]
    
    public init(onDateSelected: ((Date) -> Void)? = nil) {
        self.onDateSelected = onDateSelected
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Date Picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("1. Selecciona la Fecha del Evento")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                            
                            DatePicker("", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .padding(10)
                                .background(theme.cardColor)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Time Slots
                        VStack(alignment: .leading, spacing: 10) {
                            Text("2. Horario Disponible")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(timeSlots, id: \.self) { slot in
                                    Button(action: {
                                        selectedTimeSlot = slot
                                    }) {
                                        Text(slot)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(selectedTimeSlot == slot ? .white : theme.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(selectedTimeSlot == slot ? AppColors.primary : theme.cardColor)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Event Details Form
                        VStack(alignment: .leading, spacing: 10) {
                            Text("3. Tipo de Evento")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                            
                            Picker("Tipo de Evento", selection: $eventType) {
                                Text("Boda / Recepción").tag("Boda / Recepción")
                                Text("XV Años / Fiesta").tag("XV Años")
                                Text("Concierto / Serenata").tag("Concierto")
                                Text("Misa / Ceremonia").tag("Ceremonia")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .padding(.horizontal, 16)
                        
                        // Submit Booking Button
                        Button(action: {
                            onDateSelected?(selectedDate)
                            isSuccessAlert = true
                        }) {
                            Text("Confirmar Solicitud de Reserva")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.primary)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Agendar Contratación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSuccessAlert) {
                Alert(title: Text("Reserva Enviada"), message: Text("El director de la agrupación ha recibido tu fecha y horario solicitados."), dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                })
            }
        }
    }
}
