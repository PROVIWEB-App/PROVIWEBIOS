import Foundation
import SwiftUI
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Notifications Service (RTDB esquema exacto de Android: `Users/{uid}/Notifications`)
//
// Escritura: AdapterPost.java:1543-1564 (formato pId/timestamp/pText/notification/sId/sName/type
//           + `Users/{uid}/Count/{ts} = true` como badge).
// Lectura:  NotificationScreen.getAllNotifications (línea 557-644) lee el nodo completo.
// No leído: NotificationScreen.isNotificationUnread (línea 884) NO usa un campo `read`,
//           usa las claves de `Users/{uid}/Count/{ts}` (unreadNotificationsCache, línea 131-149).
// Al abrir: NotificationScreen.onCreate (línea 252-256) borra `Count` entero → badge limpio.
// "Marcar leídas": NotificationScreen.markAllAsRead (línea 897-905) → `Count.removeValue()`
//           (nunca borra `Notifications`, sólo "Eliminar todas" lo hace).
@MainActor
public final class NotificationsService: ObservableObject {
    public static let shared = NotificationsService()

    @Published public private(set) var notifications: [NotificationItemModel] = []
    /// Claves (timestamp en millis como String) marcadas como no leídas por `Count`.
    @Published public private(set) var unreadKeys: Set<String> = []

    private var rawItems: [(key: String, dict: [String: Any])] = []
    private var isStarted = false
    #if canImport(FirebaseDatabase)
    private var listObserver: (handle: DatabaseHandle, remove: () -> Void)?
    private var countObserver: (handle: DatabaseHandle, remove: () -> Void)?
    #endif

    private init() {}

    /// UID real de la sesión; `currentUserId` sólo como último recurso (modo demo).
    private var myUid: String? {
        FirebaseService.shared.authenticatedUid ?? FirebaseService.shared.currentUserId
    }

    public func ensureStarted() {
        guard !isStarted, FirebaseService.shared.canWriteToCloud else { return }
        isStarted = true
        #if canImport(FirebaseDatabase)
        // Réplica de NotificationScreen.onCreate:252-256 (limpia el badge al abrir).
        clearRemoteCount()
        observeNotifications()
        observeUnreadCount()
        #endif
    }

    // MARK: - Marcar leídas (NotificationScreen.markAllAsRead:897)
    public func markAllAsRead() {
        #if canImport(FirebaseDatabase)
        if FirebaseService.shared.canWriteToCloud {
            clearRemoteCount()
        }
        #endif
        unreadKeys = []
        rebuild()
    }

    #if canImport(FirebaseDatabase)
    private func clearRemoteCount() {
        guard let uid = myUid else { return }
        Database.database().reference().child("Users").child(uid).child("Count").removeValue()
    }

    private func observeNotifications() {
        guard let uid = myUid else { return }
        let ref = Database.database().reference().child("Users").child(uid).child("Notifications")
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var next: [(key: String, dict: [String: Any])] = []
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    next.append((key: snap.key, dict: dict))
                }
                self.rawItems = next
                self.rebuild()
            }
        }
        listObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }

    private func observeUnreadCount() {
        guard let uid = myUid else { return }
        let ref = Database.database().reference().child("Users").child(uid).child("Count")
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var keys: Set<String> = []
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot else { continue }
                    keys.insert(snap.key)
                }
                self.unreadKeys = keys
                self.rebuild()
            }
        }
        countObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }
    #endif

    private func rebuild() {
        let unread = unreadKeys
        let mapped: [NotificationItemModel] = rawItems.map { item in
            let dict = item.dict
            let title = NotificationsService.stringValue(dict["notification"]) ?? "Notificación"
            let body = NotificationsService.stringValue(dict["pText"])
                ?? NotificationsService.stringValue(dict["text"])
                ?? ""
            var millis = NotificationsService.numberValue(dict["timestamp"]) ?? 0
            if millis <= 0 { millis = Double(item.key) ?? 0 }
            return NotificationItemModel(
                id: item.key,
                type: NotificationType(androidType: NotificationsService.stringValue(dict["type"]) ?? ""),
                title: title,
                subtitle: body.isEmpty ? title : body,
                timeAgo: NotificationsService.formatTime(millis: millis),
                isUnread: unread.contains(item.key)
            )
        }
        notifications = mapped.sorted { lhs, rhs in
            (Double(lhs.id) ?? 0) > (Double(rhs.id) ?? 0)
        }
    }

    static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String { return value }
        if let value = raw as? NSNumber { return value.stringValue }
        return nil
    }

    static func numberValue(_ raw: Any?) -> Double? {
        if let value = raw as? NSNumber { return value.doubleValue }
        if let value = raw as? String { return Double(value) }
        return nil
    }

    static func formatTime(millis: Double) -> String {
        guard millis > 0 else { return "" }
        let date = Date(timeIntervalSince1970: millis / 1000)
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "Ahora" }
        if diff < 3600 { return "Hace \(Int(diff / 60)) min" }
        if diff < 86_400 { return "Hace \(Int(diff / 3600)) h" }
        if diff < 604_800 {
            let days = Int(diff / 86_400)
            return days <= 1 ? "Ayer" : "Hace \(days) días"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Notifications Center View
public struct NotificationsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var service = NotificationsService.shared
    @Environment(\.presentationMode) var presentationMode
    
    /// `true` cuando la lista proviene del nodo `Users/{uid}/Notifications` (sesión real).
    private let usesLiveNotifications: Bool = FirebaseService.shared.canWriteToCloud

    @State private var demoNotifications: [NotificationItemModel] = [
        NotificationItemModel(id: "1", type: .like, title: "A María García le gustó tu publicación", subtitle: "Práctica del Concierto de Mendelssohn", timeAgo: "Hace 10 min", isUnread: true),
        NotificationItemModel(id: "2", type: .proximity, title: "¡Músico cerca de ti!", subtitle: "Hay un artista a menos de 100 metros", timeAgo: "Hace 45 min", isUnread: true),
        NotificationItemModel(id: "3", type: .missedCall, title: "Llamada perdida de María García", subtitle: "Toca para devolver la llamada", timeAgo: "Hace 2 horas", isUnread: true),
        NotificationItemModel(id: "4", type: .songApproved, title: "Canción aprobada", subtitle: "Tu obra 'Czardas de Monti' ha sido verificada y publicada.", timeAgo: "Ayer", isUnread: false)
    ]
    
    private var notifications: [NotificationItemModel] {
        usesLiveNotifications ? service.notifications : demoNotifications
    }

    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                List {
                    if notifications.isEmpty {
                        Text("No tienes notificaciones.")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .padding(.vertical, 24)
                    }

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
                        if usesLiveNotifications {
                            // Como Android: borra `Users/{uid}/Count` (NotificationScreen:897).
                            service.markAllAsRead()
                        } else {
                            for i in 0..<demoNotifications.count {
                                demoNotifications[i].isUnread = false
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.primary)
                }
            }
            .onAppear {
                if usesLiveNotifications { service.ensureStarted() }
            }
        }
    }
}

// MARK: - Notification Item Model
public struct NotificationItemModel: Identifiable {
    public let id: String
    let type: NotificationType
    let title: String
    let subtitle: String
    let timeAgo: String
    var isUnread: Bool
}

public enum NotificationType {
    case like
    case comment
    case missedCall
    case proximity
    case songApproved
    case gift
    case follow
    case balance
    case practice
    case jobApplication
    case share
    case mention
    case minorApproval
    case unknown

    /// Tolerante al campo `type` de Android (NotificationScreen agrupa por esos valores).
    init(androidType: String) {
        switch androidType.lowercased() {
        case "like", "post_like", "song_like", "song_reaction":
            self = .like
        case "comment", "reply", "song_comment", "songcomment":
            self = .comment
        case "share", "song_share":
            self = .share
        case "mention":
            self = .mention
        case "gift":
            self = .gift
        case "follow":
            self = .follow
        case "balance", "withdraw":
            self = .balance
        case "practice":
            self = .practice
        case "job_application", "job_proposal", "job_contract":
            self = .jobApplication
        case "minor_approval":
            self = .minorApproval
        case "song_approved", "verification", "verification_approved", "qav":
            self = .songApproved
        default:
            self = .unknown
        }
    }
    
    var icon: String {
        switch self {
        case .like: return "heart.fill"
        case .comment: return "bubble.right.fill"
        case .missedCall: return "phone.arrow.down.left.fill"
        case .proximity: return "location.fill"
        case .songApproved: return "checkmark.seal.fill"
        case .gift: return "gift.fill"
        case .follow: return "person.badge.plus.fill"
        case .balance: return "dollarsign.circle.fill"
        case .practice: return "music.note"
        case .jobApplication: return "briefcase.fill"
        case .share: return "arrowshape.turn.up.right.fill"
        case .mention: return "at"
        case .minorApproval: return "exclamationmark.shield.fill"
        case .unknown: return "bell.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .like: return .red
        case .comment: return AppColors.primary
        case .missedCall: return AppColors.warningOrange
        case .proximity: return AppColors.success
        case .songApproved: return AppColors.gold
        case .gift: return AppColors.gold
        case .follow: return AppColors.primary
        case .balance: return AppColors.success
        case .practice: return AppColors.warningOrange
        case .jobApplication: return AppColors.primary
        case .share: return AppColors.success
        case .mention: return AppColors.primary
        case .minorApproval: return AppColors.warningOrange
        case .unknown: return AppColors.primary
        }
    }
}
