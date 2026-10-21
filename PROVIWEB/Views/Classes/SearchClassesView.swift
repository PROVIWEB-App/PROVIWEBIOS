import SwiftUI

// MARK: - Search & Discover Music Teachers & Classes View
public struct SearchClassesView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var classes = ClassesService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedInstrument: String = "Violín"
    @State private var searchText: String = ""
    @State private var selectedTeacherForBooking: TeacherModel? = nil
    @State private var isMyBookedClassesPresented: Bool = false
    @State private var isClassRequestPresented: Bool = false
    
    let instruments = ["Todos", "Violín", "Piano", "Guitarra", "Canto", "Violonchelo", "Trompeta", "Flauta", "Composición"]
    
    // Seed local de demostración; en sesión real se sustituye por `Users` (verifiedprofesor == "yes").
    @State private var seedTeachers: [TeacherModel] = [
        TeacherModel(
            id: "teacher_1",
            name: "Mtro. Israel Violín",
            username: "israviolink",
            avatarUrl: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
            instrument: "Violín",
            bio: "Solista y pedagogo con más de 15 años de trayectoria. Especialista en repertorio clásico, técnica rusa, cambio de posiciones y estilo de mariachi virtuoso.",
            hourlyRateUSD: 40.0,
            hourlyRateDiamonds: 240,
            rating: 5.0,
            reviewCount: 48,
            experienceYears: 15,
            institution: "Conservatorio Nacional & Proviweb Academy",
            modality: .online,
            availableDays: ["Lunes", "Miércoles", "Viernes", "Sábado"],
            timeSlots: [
                ClassTimeSlot(dayOfWeek: "Lunes", startTime: "10:00", endTime: "11:00"),
                ClassTimeSlot(dayOfWeek: "Lunes", startTime: "16:00", endTime: "17:00"),
                ClassTimeSlot(dayOfWeek: "Miércoles", startTime: "15:00", endTime: "16:00"),
                ClassTimeSlot(dayOfWeek: "Sábado", startTime: "11:00", endTime: "12:00")
            ]
        ),
        TeacherModel(
            id: "teacher_2",
            name: "Dra. Sofía Mendoza",
            username: "sofiamendoza_piano",
            avatarUrl: "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=500&auto=format&fit=crop&q=60",
            instrument: "Piano",
            bio: "Concertista de piano. Graduada en Juilliard y Escuela Superior de Música. Clases de técnica pianística, lectura a primera vista y armonía aplicada.",
            hourlyRateUSD: 50.0,
            hourlyRateDiamonds: 300,
            rating: 4.9,
            reviewCount: 35,
            experienceYears: 12,
            institution: "The Juilliard School Alumna",
            modality: .hybrid,
            availableDays: ["Martes", "Jueves", "Sábado"],
            timeSlots: [
                ClassTimeSlot(dayOfWeek: "Martes", startTime: "11:00", endTime: "12:00"),
                ClassTimeSlot(dayOfWeek: "Jueves", startTime: "17:00", endTime: "18:00")
            ]
        ),
        TeacherModel(
            id: "teacher_3",
            name: "Carlos Velasco",
            username: "carlos_guitarra",
            avatarUrl: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop&q=60",
            instrument: "Guitarra",
            bio: "Guitarrista clásico y flamenco. Enfoque moderno en solfeo, ritmo, rasgueos tradicionales y acompañamiento de ensambles.",
            hourlyRateUSD: 30.0,
            hourlyRateDiamonds: 180,
            rating: 4.8,
            reviewCount: 29,
            experienceYears: 8,
            institution: "Facultad de Música UNAM",
            modality: .online,
            availableDays: ["Lunes", "Martes", "Viernes"]
        )
    ]
    
    public init() {}
    
    private func matchesFilters(_ teacher: TeacherModel) -> Bool {
        let matchesInstrument = selectedInstrument == "Todos" || teacher.instrument == selectedInstrument
        let matchesSearch = searchText.isEmpty ||
            teacher.name.localizedCaseInsensitiveContains(searchText) ||
            teacher.institution.localizedCaseInsensitiveContains(searchText)
        
        return matchesInstrument && matchesSearch
    }
    
    public var filteredTeachers: [TeacherModel] {
        seedTeachers.filter(matchesFilters)
    }
    
    /// Lista real de profesores verificados (SearchClassesActivity.loadTeachers) en sesión real;
    /// en demostración conserva el seed local.
    private var displayedTeachers: [TeacherModel] {
        if classes.usesLiveClasses && classes.didLoadTeachers {
            return classes.verifiedTeachers.filter(matchesFilters)
        }
        return seedTeachers.filter(matchesFilters)
    }
    
    private var isWaitingForTeachers: Bool {
        classes.usesLiveClasses && !classes.didLoadTeachers
    }
    
    /// Píldoras de instrumento: la lista fija + los instrumentos reales que traiga `Users`.
    private var availableInstruments: [String] {
        guard classes.usesLiveClasses, classes.didLoadTeachers, !classes.verifiedTeachers.isEmpty else {
            return instruments
        }
        var merged = Set(instruments)
        merged.formUnion(classes.verifiedTeachers.map { $0.instrument })
        let sorted = merged.filter { $0 != "Todos" && !$0.isEmpty }.sorted()
        return ["Todos"] + sorted
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top App Bar
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(theme.textPrimary)
                        }
                        
                        Text("Clases Particulares & Maestros")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                        
                        Spacer()
                        
                        Button(action: { isClassRequestPresented = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.pencil")
                                    .foregroundColor(AppColors.gold)
                                Text("Solicitar")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.gold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.gold.opacity(0.15))
                            .cornerRadius(12)
                        }
                        
                        Button(action: { isMyBookedClassesPresented = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(AppColors.primary)
                                Text("Mis Clases")
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
                        TextField("Buscar maestros por nombre, institución...", text: $searchText)
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(10)
                    .background(theme.backgroundColor)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    
                    // Instrument Selector Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableInstruments, id: \.self) { inst in
                                Button(action: { selectedInstrument = inst }) {
                                    Text(inst)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedInstrument == inst ? .white : theme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedInstrument == inst ? AppColors.primary : theme.cardColor)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    
                    // Teacher Cards List
                    if isWaitingForTeachers {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Cargando profesores verificados…")
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                if displayedTeachers.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 36))
                                            .foregroundColor(theme.textSecondary)
                                        Text("No se encontraron profesores con esos filtros")
                                            .font(.subheadline)
                                            .foregroundColor(theme.textSecondary)
                                    }
                                    .padding(.top, 30)
                                }
                                ForEach(displayedTeachers) { teacher in
                                    TeacherCardItem(teacher: teacher) {
                                        selectedTeacherForBooking = teacher
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Lee `Users` y filtra `verifiedprofesor == "yes"` (no-op en modo demostración).
                classes.searchTeachers()
            }
            .sheet(item: $selectedTeacherForBooking) { teacher in
                BookClassView(teacher: teacher)
            }
            .sheet(isPresented: $isMyBookedClassesPresented) {
                MyBookedClassesView()
            }
            .sheet(isPresented: $isClassRequestPresented) {
                ClassRequestSheet(
                    instruments: availableInstruments.filter { $0 != "Todos" },
                    initialInstrument: availableInstruments.contains(selectedInstrument) ? selectedInstrument : ""
                )
            }
        }
    }
}

// MARK: - Teacher Card Item
struct TeacherCardItem: View {
    let teacher: TeacherModel
    let onBookTapped: () -> Void
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AvatarView(urlString: teacher.avatarUrl, size: 54, isVerified: teacher.isVerifiedTeacher)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(teacher.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(theme.textPrimary)
                        
                        Spacer()
                        
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.gold)
                            Text(String(format: "%.1f", teacher.rating))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textPrimary)
                            Text("(\(teacher.reviewCount))")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    
                    Text("\(teacher.instrument) • \(teacher.institution)")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                    
                    Text(teacher.modality.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                }
            }
            
            Text(teacher.bio)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .lineLimit(2)
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tarifa por Hora")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                    
                    HStack(spacing: 6) {
                        Text(String(format: "$%.2f USD", teacher.hourlyRateUSD))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primary)
                        
                        Text("(\(teacher.hourlyRateDiamonds) 💎)")
                            .font(.caption2)
                            .foregroundColor(AppColors.gold)
                    }
                }
                
                Spacer()
                
                Button(action: onBookTapped) {
                    Text("Reservar Clase")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(AppColors.primary)
                        .cornerRadius(14)
                }
            }
        }
        .padding(16)
        .background(theme.cardColor)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Solicitud pública de clase (réplica del diálogo de SearchClassesActivity, líneas 512-566)
struct ClassRequestSheet: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    let instruments: [String]
    @State private var instrument: String = ""
    @State private var level: String = "Principiante"
    @State private var budget: String = "20.00"
    @State private var requestDescription: String = ""
    @State private var isSending: Bool = false
    @State private var isAlertPresented: Bool = false
    @State private var isErrorAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
    private let levels = ["Principiante", "Intermedio", "Avanzado"]
    
    init(instruments: [String], initialInstrument: String) {
        self.instruments = instruments
        _instrument = State(initialValue: initialInstrument)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Instrumento y Nivel"),
                        footer: Text("Describe lo que buscas: los profesores verificados verán tu solicitud pública en la app.")) {
                    Picker("Instrumento", selection: $instrument) {
                        Text("Selecciona").tag("")
                        ForEach(instruments, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    
                    Picker("Nivel", selection: $level) {
                        ForEach(levels, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }
                
                Section(header: Text("Presupuesto y Detalles")) {
                    HStack {
                        Text("Presupuesto por clase (USD)")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        TextField("20.00", text: $budget)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    
                    TextField("¿Qué quieres aprender? (ej. Violín intermedio, 1 hora semanal)", text: $requestDescription)
                }
                
                Section(footer: Text("Android guarda esta solicitud en ClassRequests/{requestId} con estado \"open\".")) {
                    EmptyView()
                }
                
                Section {
                    Button(action: submit) {
                        HStack(spacing: 8) {
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isSending ? "Publicando…" : "Publicar Solicitud de Clase")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(instrument.isEmpty || isSending)
                    .listRowBackground(instrument.isEmpty ? Color.gray : AppColors.primary)
                }
            }
            .navigationTitle("Solicitar Clase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
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
    
    private func submit() {
        guard ClassesService.shared.usesLiveClasses else {
            alertTitle = "Se requiere una cuenta"
            alertMessage = "Publicar una solicitud de clase está disponible con una cuenta real de PROVIWEB. Inicia sesión e inténtalo de nuevo."
            isErrorAlert = true
            isAlertPresented = true
            return
        }
        
        isSending = true
        ClassesService.shared.createClassRequest(
            instrument: instrument,
            level: level,
            budget: budget,
            description: requestDescription
        ) { result in
            isSending = false
            switch result {
            case .success:
                alertTitle = "Solicitud Publicada"
                alertMessage = "Tu solicitud fue publicada. Los profesores verificados podrán ofrecerte una clase."
                isErrorAlert = false
            case .failure(let error):
                alertTitle = "No se pudo publicar la solicitud"
                alertMessage = error.localizedDescription
                isErrorAlert = true
            }
            isAlertPresented = true
        }
    }
}
