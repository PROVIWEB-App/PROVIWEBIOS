import SwiftUI

// MARK: - Book Private Masterclass View
public struct BookClassView: View {
    public let teacher: TeacherModel
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedDate: Date = Date().addingTimeInterval(86400 * 2)
    @State private var selectedTimeSlot: String = "16:00 - 17:00"
    @State private var lessonTopic: String = ""
    @State private var studentNotes: String = ""
    @State private var paymentWithDiamonds: Bool = false
    @State private var isSuccessAlertPresented: Bool = false
    
    let availableTimes = ["09:00 - 10:00", "11:00 - 12:00", "15:00 - 16:00", "16:00 - 17:00", "18:00 - 19:00"]
    
    public init(teacher: TeacherModel) {
        self.teacher = teacher
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    // Teacher Summary Section
                    Section(header: Text("Profesor Seleccionado")) {
                        HStack(spacing: 12) {
                            AvatarView(urlString: teacher.avatarUrl, size: 48, isVerified: teacher.isVerifiedTeacher)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(teacher.name)
                                    .font(.headline)
                                    .foregroundColor(theme.textPrimary)
                                Text("\(teacher.instrument) • \(teacher.institution)")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                                Text("Tarifa: \(String(format: "$%.2f USD", teacher.hourlyRateUSD)) / hora (\(teacher.hourlyRateDiamonds) 💎)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Date & Slot Selection
                    Section(header: Text("Fecha y Horario")) {
                        DatePicker("Fecha de la Clase", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                        
                        Picker("Horario Disponible", selection: $selectedTimeSlot) {
                            ForEach(availableTimes, id: \.self) { slot in
                                Text(slot).tag(slot)
                            }
                        }
                    }
                    
                    // Lesson Topic & Notes
                    Section(header: Text("Objetivo de Aprendizaje")) {
                        TextField("Tema (ej. Repertorio Bach, Golpes de Arco, Solfeo)", text: $lessonTopic)
                        
                        TextField("Notas o piezas que estás trabajando actualmente", text: $studentNotes)
                    }
                    
                    // Payment Method
                    Section(header: Text("Método de Pago")) {
                        Toggle("Pagar con Diamantes PROVIWEB (\(teacher.hourlyRateDiamonds) 💎)", isOn: $paymentWithDiamonds)
                        
                        HStack {
                            Text("Total a Pagar:")
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            Text(paymentWithDiamonds ? "\(teacher.hourlyRateDiamonds) Diamantes" : String(format: "$%.2f USD", teacher.hourlyRateUSD))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(paymentWithDiamonds ? AppColors.gold : AppColors.primary)
                        }
                    }
                    
                    // Confirmation Action
                    Section {
                        Button(action: confirmBooking) {
                            Text("Confirmar y Reservar Clase")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .listRowBackground(AppColors.primary)
                    }
                }
            }
            .navigationTitle("Reservar Clase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSuccessAlertPresented) {
                Alert(
                    title: Text("¡Clase Reservada con Éxito!"),
                    message: Text("El profesor ha recibido tu solicitud. Se ha generado tu enlace de sala para la fecha acordada."),
                    dismissButton: .default(Text("Entendido")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    private func confirmBooking() {
        if paymentWithDiamonds {
            firebase.walletBalance.diamonds = max(0, firebase.walletBalance.diamonds - teacher.hourlyRateDiamonds)
        }
        isSuccessAlertPresented = true
    }
}
