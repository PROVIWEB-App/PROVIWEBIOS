import SwiftUI

// MARK: - Teacher Availability Configuration View
public struct TeacherAvailabilityView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var hourlyRateText: String = "40.00"
    @State private var modality: TeacherModel.LessonModality = .online
    @State private var selectedDays: Set<String> = ["Lunes", "Miércoles", "Viernes"]
    @State private var startHour: String = "10:00"
    @State private var endHour: String = "18:00"
    @State private var isSavedAlertPresented: Bool = false
    
    let daysOfWeek = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Tarifa de Clase por Hora")) {
                        HStack {
                            Text("$ USD:")
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                            TextField("Tarifa en USD", text: $hourlyRateText)
                                .keyboardType(.decimalPad)
                        }
                        
                        Picker("Modalidad", selection: $modality) {
                            ForEach(TeacherModel.LessonModality.allCases, id: \.self) { mod in
                                Text(mod.rawValue).tag(mod)
                            }
                        }
                    }
                    
                    Section(header: Text("Días Disponibles para Enseñar")) {
                        ForEach(daysOfWeek, id: \.self) { day in
                            HStack {
                                Text(day)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                if selectedDays.contains(day) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedDays.contains(day) {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Franja Horaria General")) {
                        HStack {
                            Text("Desde:")
                            Spacer()
                            TextField("10:00", text: $startHour)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Hasta:")
                            Spacer()
                            TextField("18:00", text: $endHour)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    Section {
                        Button(action: {
                            isSavedAlertPresented = true
                        }) {
                            Text("Guardar Disponibilidad")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .listRowBackground(AppColors.primary)
                    }
                }
            }
            .navigationTitle("Configurar Disponibilidad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSavedAlertPresented) {
                Alert(
                    title: Text("¡Disponibilidad Guardada!"),
                    message: Text("Tus alumnos ya pueden ver tus nuevos horarios y reservar clases particulares."),
                    dismissButton: .default(Text("Aceptar")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
}
