import SwiftUI

// MARK: - Search & Discover Music Teachers & Classes View
public struct SearchClassesView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedInstrument: String = "Violín"
    @State private var searchText: String = ""
    @State private var selectedTeacherForBooking: TeacherModel? = nil
    @State private var isMyBookedClassesPresented: Bool = false
    
    let instruments = ["Todos", "Violín", "Piano", "Guitarra", "Canto", "Violonchelo", "Trompeta", "Flauta", "Composición"]
    
    @State private var teachers: [TeacherModel] = [
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
    
    public var filteredTeachers: [TeacherModel] {
        teachers.filter { teacher in
            let matchesInstrument = selectedInstrument == "Todos" || teacher.instrument == selectedInstrument
            let matchesSearch = searchText.isEmpty ||
                teacher.name.localizedCaseInsensitiveContains(searchText) ||
                teacher.institution.localizedCaseInsensitiveContains(searchText)
            
            return matchesInstrument && matchesSearch
        }
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
                            ForEach(instruments, id: \.self) { inst in
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
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredTeachers) { teacher in
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
            .navigationBarHidden(true)
            .sheet(item: $selectedTeacherForBooking) { teacher in
                BookClassView(teacher: teacher)
            }
            .sheet(isPresented: $isMyBookedClassesPresented) {
                MyBookedClassesView()
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
