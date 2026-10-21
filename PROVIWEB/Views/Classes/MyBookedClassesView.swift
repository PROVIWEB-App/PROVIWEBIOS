import SwiftUI

// MARK: - My Booked Classes & Sessions View
public struct MyBookedClassesView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var classes = ClassesService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isLiveRoomPresented: Bool = false
    @State private var selectedBookingForCall: BookedClassModel? = nil
    @State private var isAvailabilityPresented: Bool = false
    
    // Seed de demostración: sólo se muestra cuando no hay sesión real (Android lee `StudentClasses/{uid}`).
    @State private var seedBookings: [BookedClassModel] = [
        BookedClassModel(
            id: "book_1",
            teacherId: "teacher_1",
            teacherName: "Mtro. Israel Violín",
            teacherAvatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
            studentId: "student_demo_1",
            studentName: "Santiago Rivera",
            studentAvatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop&q=60",
            instrument: "Violín",
            scheduledDate: Date().addingTimeInterval(86400),
            startTime: "16:00",
            endTime: "17:00",
            modality: .online,
            lessonTopic: "Técnica de Spiccato y Concierto de Mendelssohn",
            priceUSD: 40.0,
            status: .confirmed,
            videoRoomId: "room_violin_masterclass_01",
            notes: "Traer la partitura con arcos marcados y afinador listo."
        ),
        BookedClassModel(
            id: "book_2",
            teacherId: "teacher_2",
            teacherName: "Dra. Sofía Mendoza",
            teacherAvatar: "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=500&auto=format&fit=crop&q=60",
            studentId: "student_demo_1",
            studentName: "Santiago Rivera",
            instrument: "Piano",
            scheduledDate: Date().addingTimeInterval(86400 * 4),
            startTime: "11:00",
            endTime: "12:00",
            modality: .online,
            lessonTopic: "Armonía al Teclado e Improvisación",
            priceUSD: 50.0,
            status: .confirmed,
            videoRoomId: "room_piano_masterclass_02"
        )
    ]
    
    public init() {}
    
    /// Nodos reales (`StudentClasses/{uid}`, igual que MyBookedClassesActivity.java:82) en sesión real;
    /// conserva el seed de demostración cuando no hay cuenta de Firebase.
    private var bookings: [BookedClassModel] {
        guard classes.usesLiveClasses, classes.didLoadMyClasses else { return seedBookings }
        return classes.myClasses.map { $0.uiModel }
    }
    
    private var isWaitingForCloud: Bool {
        classes.usesLiveClasses && !classes.didLoadMyClasses
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                if isWaitingForCloud {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Cargando tus clases reservadas…")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                    }
                } else if bookings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 48))
                            .foregroundColor(theme.textSecondary)
                        Text("No tienes clases reservadas actualmente")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(bookings) { booking in
                                BookedClassCardItem(booking: booking) {
                                    selectedBookingForCall = booking
                                    isLiveRoomPresented = true
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Mis Clases Reservadas")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Observador de `StudentClasses/{uid}` (no-op en modo demostración).
                classes.ensureStarted()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isAvailabilityPresented = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.plus")
                            Text("Disponibilidad")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                    }
                }
            }
            .sheet(isPresented: $isLiveRoomPresented) {
                LiveMeetingRoomView()
            }
            .sheet(isPresented: $isAvailabilityPresented) {
                TeacherAvailabilityView()
            }
        }
    }
}

// MARK: - Booked Class Card Item
struct BookedClassCardItem: View {
    let booking: BookedClassModel
    let onJoinRoom: () -> Void
    @ObservedObject private var theme = ThemeManager.shared
    
    /// Colores de estado alineados con MyBookedClassesActivity.java (confirmada/finalizada verde,
    /// cancelada rojo, pendiente color primario).
    private var statusColor: Color {
        switch booking.status {
        case .confirmed, .completed, .ongoing:
            return AppColors.success
        case .cancelled:
            return AppColors.errorRed
        default:
            return AppColors.primary
        }
    }
    
    /// Misma regla que MyBookedClassesActivity: sólo clases virtuales confirmadas o finalizadas.
    private var canJoinRoom: Bool {
        booking.modality != .inPerson &&
        (booking.status == .confirmed || booking.status == .completed)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarView(urlString: booking.teacherAvatar, size: 48, isVerified: true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.teacherName)
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                    Text("Clase de \(booking.instrument)")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
                
                Text(booking.status.rawValue)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(8)
            }
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "book.fill")
                        .foregroundColor(AppColors.primary)
                        .font(.caption)
                    Text(booking.lessonTopic)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(theme.textSecondary)
                        .font(.caption)
                    Text("\(booking.scheduledDate.formatted(date: .complete, time: .omitted)) • \(booking.startTime) - \(booking.endTime)")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                
                if let notes = booking.notes {
                    Text(notes)
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 2)
                }
            }
            
            HStack {
                Text(String(format: "$%.2f USD", booking.priceUSD))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
                
                Spacer()
                
                if canJoinRoom {
                    Button(action: onJoinRoom) {
                        HStack(spacing: 6) {
                            Image(systemName: "video.fill")
                            Text("Entrar a Clase")
                                .fontWeight(.bold)
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.primary)
                        .cornerRadius(12)
                    }
                } else {
                    Text(booking.modality == .inPerson ? "Clase presencial" : "Se habilita al confirmar")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(theme.cardColor)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
