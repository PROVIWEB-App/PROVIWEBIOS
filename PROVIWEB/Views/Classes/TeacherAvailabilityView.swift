import SwiftUI

// MARK: - Teacher Availability Configuration View
public struct TeacherAvailabilityView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @ObservedObject private var classes = ClassesService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var hourlyRateText: String = "40.00"
    @State private var modality: TeacherModel.LessonModality = .online
    @State private var selectedDays: Set<String> = ["Lunes", "Miércoles", "Viernes"]
    @State private var startHour: String = "10:00"
    @State private var endHour: String = "18:00"
    @State private var isLoadingCloud: Bool = false
    @State private var didLoadCloud: Bool = false
    @State private var isAlertPresented: Bool = false
    @State private var isErrorAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
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
                        Button(action: saveAvailability) {
                            HStack(spacing: 8) {
                                if isLoadingCloud {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isLoadingCloud ? "Guardando…" : "Guardar Disponibilidad")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .disabled(isLoadingCloud)
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
            .onAppear {
                loadCloudAvailability()
            }
            .alert(alertTitle, isPresented: $isAlertPresented) {
                Button("Entendido") {
                    if !isErrorAlert {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Guardado real: `Users/{uid}/availability` (TeacherAvailabilityActivity.saveAvailabilityAndProfile)
    private func saveAvailability() {
        guard ClassesService.shared.usesLiveClasses else {
            // Modo demostración: conserva el aviso local anterior (sin escritura en la nube).
            alertTitle = "¡Disponibilidad Guardada!"
            alertMessage = "Tus alumnos ya pueden ver tus nuevos horarios y reservar clases particulares."
            isErrorAlert = false
            isAlertPresented = true
            return
        }
        
        guard !selectedDays.isEmpty else {
            alertTitle = "Selecciona al menos un día"
            alertMessage = "Elige al menos un día disponible para enseñar."
            isErrorAlert = true
            isAlertPresented = true
            return
        }
        
        // Android guarda los días como abreviaturas ("LUN", "MAR", "MIÉ"…).
        let abbrDays = daysOfWeek.filter { selectedDays.contains($0) }.compactMap { ClassesService.dayNameToAbbr[$0] }
        isLoadingCloud = true
        ClassesService.shared.saveAvailability(
            days: abbrDays,
            startHour: startHour,
            endHour: endHour,
            modality: ClassesService.androidModality(from: modality),
            basePrice: hourlyRateText
        ) { result in
            isLoadingCloud = false
            switch result {
            case .success:
                alertTitle = "¡Disponibilidad Guardada!"
                alertMessage = "Tus alumnos ya pueden ver tus nuevos horarios y reservar clases particulares."
                isErrorAlert = false
            case .failure(let error):
                alertTitle = "No se pudo guardar"
                alertMessage = error.localizedDescription
                isErrorAlert = true
            }
            isAlertPresented = true
        }
    }
    
    // MARK: - Lectura de la disponibilidad publicada por Android en `Users/{uid}`
    private func loadCloudAvailability() {
        guard ClassesService.shared.usesLiveClasses, !didLoadCloud else { return }
        didLoadCloud = true
        // Se capturan como `let` para que el cierre no dependa de propiedades aisladas.
        let abbrToName = ClassesService.dayAbbrToName
        ClassesService.shared.loadAvailability { data in
            guard let data = data else { return }
            if !data.days.isEmpty {
                selectedDays = Set(data.days.compactMap { abbrToName[$0.uppercased()] ?? $0 })
            }
            startHour = data.startTime
            endHour = data.endTime
            hourlyRateText = data.basePrice
            switch data.modality {
            case "Virtual":
                modality = .online
            case "Presencial":
                modality = .inPerson
            default:
                modality = .hybrid
            }
        }
    }
}
