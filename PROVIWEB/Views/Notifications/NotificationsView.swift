import SwiftUI

// MARK: - Notifications Center View
public struct NotificationsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var notifications = [
        NotificationItemModel(id: "1", type: .like, title: "A María García le gustó tu publicación", subtitle: "Práctica del Concierto de Mendelssohn", timeAgo: "Hace 10 min", isUnread: true),
        NotificationItemModel(id: "2", type: .proximity, title: "¡Músico cerca de ti!", subtitle: "Hay un artista a menos de 100 metros", timeAgo: "Hace 45 min", isUnread: true),
        NotificationItemModel(id: "3", type: .missedCall, title: "Llamada perdida de María García", subtitle: "Toca para devolver la llamada", timeAgo: "Hace 2 horas", isUnread: true),
        NotificationItemModel(id: "4", type: .songApproved, title: "Canción aprobada", subtitle: "Tu obra 'Czardas de Monti' ha sido verificada y publicada.", timeAgo: "Ayer", isUnread: false)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                List {
                    ForEach(notifications) { notif in
                        HStack(spacing: 12) {
                            // Icon based on type
                            ZStack {
                                Circle()
                                    .fill(notif.type.color.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: notif.type.icon)
                                    .foregroundColor(notif.type.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(notif.title)
                                    .font(.subheadline)
                                    .fontWeight(notif.isUnread ? .bold : .medium)
                                    .foregroundColor(theme.textPrimary)
                                
                                Text(notif.subtitle)
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                                
                                Text(notif.timeAgo)
                                    .font(.caption2)
                                    .foregroundColor(theme.textSecondary.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            if notif.isUnread {
                                Circle()
                                    .fill(AppColors.primary)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(notif.isUnread ? theme.cardColor : theme.backgroundColor)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Notificaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Marcar leídas") {
                        for i in 0..<notifications.count {
                            notifications[i].isUnread = false
                        }
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
}

// MARK: - Notification Item Model
struct NotificationItemModel: Identifiable {
    let id: String
    let type: NotificationType
    let title: String
    let subtitle: String
    let timeAgo: String
    var isUnread: Bool
}

enum NotificationType {
    case like
    case comment
    case missedCall
    case proximity
    case songApproved
    
    var icon: String {
        switch self {
        case .like: return "heart.fill"
        case .comment: return "bubble.right.fill"
        case .missedCall: return "phone.arrow.down.left.fill"
        case .proximity: return "location.fill"
        case .songApproved: return "checkmark.seal.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .like: return .red
        case .comment: return AppColors.primary
        case .missedCall: return AppColors.warningOrange
        case .proximity: return AppColors.success
        case .songApproved: return AppColors.gold
        }
    }
}
