import Foundation
import SwiftUI
import Combine
import AVFoundation
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Chat Service (RTDB esquema exacto de Android: `Chats` + `Chatlist`)
//
// Réplica de ChatActivity.java / ChatFragment.java / AdapterChatList.java:
//   Chats/{pushId}  = { sender, receiver, msg, type, timestamp: String(millis), isSeen: Bool }
//   Chatlist/{yo}/{otro} = { id, lastMsg, timestamp: String, lastMsgType, lastSenderId }
// Los mensajes entrantes sin leer se marcan `isSeen = true` (como hace Android al abrir el hilo).
@MainActor
public final class ChatService: ObservableObject {
    public static let shared = ChatService()

    @Published public private(set) var conversations: [ChatModel] = []
    @Published public private(set) var threadMessages: [ChatMessageModel] = []
    @Published public private(set) var unreadByUser: [String: Int] = [:]
    @Published public private(set) var totalUnreadCount: Int = 0
    @Published public private(set) var activeThreadUid: String? = nil
    /// `MutedChats/{miUid}/{uid}` — uids que yo he silenciado (bandeja + hilo).
    @Published public private(set) var mutedUids: Set<String> = []
    /// `BlockedUsers/{miUid}/{otro}` = true → yo le bloqueé (esquema A del chat).
    @Published public private(set) var isBlockedByMe: Bool = false
    /// `BlockedUsers/{otro}/{miUid}` = true → él me bloqueó.
    @Published public private(set) var isPeerBlockedMe: Bool = false
    /// Igual que ChatActivity.checkBlockStatus: si él me bloqueó O yo le bloqueé, el chat se deshabilita.
    public var isChatBlocked: Bool { isBlockedByMe || isPeerBlockedMe }

    private struct RawSummary {
        var lastMsg: String = ""
        var timestamp: String = "0"
        var lastMsgType: String = "text"
        var lastSenderId: String = ""
    }

    private var summaries: [String: RawSummary] = [:]
    private var peers: [String: UserModel] = [:]
    private var peerOnline: [String: Bool] = [:]
    private var isStarted = false
    #if canImport(FirebaseDatabase)
    private var listObserver: (handle: DatabaseHandle, remove: () -> Void)?
    private var unreadObserver: (handle: DatabaseHandle, remove: () -> Void)?
    private var threadObservers: [(handle: DatabaseHandle, remove: () -> Void)] = []
    private var presenceObserver: (handle: DatabaseHandle, remove: () -> Void)?
    private var mutedListObserver: (handle: DatabaseHandle, remove: () -> Void)?
    private var mutedThreadObserver: (handle: DatabaseHandle, remove: () -> Void)?
    private var blockObservers: [(handle: DatabaseHandle, remove: () -> Void)] = []
    #endif

    private init() {}

    private var myUid: String? { FirebaseService.shared.authenticatedUid }

    // MARK: Arranque (bandeja + no leídos)
    public func ensureStarted() {
        guard !isStarted, let myUid = myUid, FirebaseService.shared.canWriteToCloud else { return }
        isStarted = true
        #if canImport(FirebaseDatabase)
        observeChatlist(myUid: myUid)
        observeUnreadCount(myUid: myUid)
        observeMutedChats(myUid: myUid)
        #endif
    }

    #if canImport(FirebaseDatabase)
    private func observeChatlist(myUid: String) {
        let ref = Database.database().reference().child("Chatlist").child(myUid)
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var next: [String: RawSummary] = [:]
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    let uid = snap.key
                    next[uid] = RawSummary(
                        lastMsg: ChatService.stringValue(dict["lastMsg"]) ?? "",
                        timestamp: ChatService.stringValue(dict["timestamp"]) ?? "0",
                        lastMsgType: ChatService.stringValue(dict["lastMsgType"]) ?? "text",
                        lastSenderId: ChatService.stringValue(dict["lastSenderId"]) ?? ""
                    )
                }
                self.summaries = next
                self.fetchMissingPeers()
                self.rebuildConversations()
            }
        }
        listObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }

    private func observeUnreadCount(myUid: String) {
        // Mismo query global que AdapterChatList.initializeGlobalChatListener (Android).
        let query = Database.database().reference().child("Chats")
            .queryOrdered(byChild: "receiver").queryEqual(toValue: myUid)
        let handle = query.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var counts: [String: Int] = [:]
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    guard !ChatService.coerceBool(dict["isSeen"]) else { continue }
                    let sender = ChatService.stringValue(dict["sender"]) ?? ""
                    guard !sender.isEmpty else { continue }
                    counts[sender, default: 0] += 1
                }
                self.unreadByUser = counts
                self.totalUnreadCount = counts.values.reduce(0, +)
                self.rebuildConversations()
            }
        }
        unreadObserver = (handle: handle, remove: { query.removeObserver(withHandle: handle) })
    }

    /// Icono 🔕 en la bandeja: `MutedChats/{myUid}` completo (una sola lectura para todas las filas).
    private func observeMutedChats(myUid: String) {
        let ref = Database.database().reference().child("MutedChats").child(myUid)
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var muted: Set<String> = []
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot else { continue }
                    if snap.exists() { muted.insert(snap.key) }
                }
                self.mutedUids = muted
                self.rebuildConversations()
            }
        }
        mutedListObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }
    #endif

    // MARK: Perfiles de los contactos (Users/{uid}: name, photo, isOnline)
    private func fetchMissingPeers() {
        #if canImport(FirebaseDatabase)
        for uid in summaries.keys where peers[uid] == nil {
            let ref = Database.database().reference().child("Users").child(uid)
            ref.observeSingleEvent(of: .value) { [weak self] snapshot in
                Task { @MainActor in
                    guard let self = self, let dict = snapshot.value as? [String: Any] else { return }
                    let name = ChatService.stringValue(dict["name"]) ?? "Artista..."
                    let photo = ChatService.stringValue(dict["image"])
                        ?? ChatService.stringValue(dict["photo"])
                    self.peers[uid] = UserModel(id: uid, name: name, image: photo)
                    self.peerOnline[uid] = ChatService.coerceBool(dict["isOnline"])
                    self.rebuildConversations()
                }
            }
        }
        #endif
    }

    private func rebuildConversations() {
        let sorted = summaries.keys.sorted { lhs, rhs in
            (Int(summaries[lhs]?.timestamp ?? "0") ?? 0) > (Int(summaries[rhs]?.timestamp ?? "0") ?? 0)
        }
        conversations = sorted.map { uid in
            let summary = summaries[uid]
            let peer = peers[uid]
            return ChatModel(
                id: uid,
                userId: uid,
                userName: peer?.name ?? "Artista...",
                userDp: peer?.image,
                lastMessage: summary?.lastMsg ?? "",
                lastTimestamp: ChatService.formatMillis(summary?.timestamp ?? "0"),
                unreadCount: unreadByUser[uid] ?? 0,
                isOnline: peerOnline[uid] ?? false,
                isMuted: mutedUids.contains(uid)
            )
        }
    }

    // MARK: Hilo de mensajes
    public func openThread(with otherUid: String) {
        guard let myUid = myUid, FirebaseService.shared.canWriteToCloud else { return }
        #if canImport(FirebaseDatabase)
        // Reapertura del mismo hilo (doble onAppear): ya tiene observers activos,
        // no se re-adjuntan para evitar callbacks duplicados.
        if activeThreadUid == otherUid, !threadObservers.isEmpty { return }
        #endif
        ensureStarted()
        if activeThreadUid != otherUid {
            closeThread()
            activeThreadUid = otherUid
            threadMessages = []
        }
        #if canImport(FirebaseDatabase)
        ensureThreadEntry(myUid: myUid, otherUid: otherUid)
        attachThreadQuery(senderUid: myUid, receiverUid: otherUid, markIncomingSeen: false)
        attachThreadQuery(senderUid: otherUid, receiverUid: myUid, markIncomingSeen: true)
        observePeerPresence(uid: otherUid)
        observeBlockStatus(otherUid: otherUid)
        observeMutedStatus(otherUid: otherUid)
        #endif
    }

    public func closeThread() {
        #if canImport(FirebaseDatabase)
        threadObservers.forEach { $0.remove() }
        threadObservers = []
        presenceObserver?.remove()
        presenceObserver = nil
        blockObservers.forEach { $0.remove() }
        blockObservers = []
        mutedThreadObserver?.remove()
        mutedThreadObserver = nil
        #endif
        isBlockedByMe = false
        isPeerBlockedMe = false
        activeThreadUid = nil
        threadMessages = []
    }

    #if canImport(FirebaseDatabase)
    /// Al abrir el hilo Android crea las entradas `id` en ambos lados de la bandeja (ChatActivity).
    private func ensureThreadEntry(myUid: String, otherUid: String) {
        let root = Database.database().reference()
        root.child("Chatlist").child(myUid).child(otherUid).updateChildValues(["id": otherUid])
        root.child("Chatlist").child(otherUid).child(myUid).updateChildValues(["id": myUid])
    }

    private func attachThreadQuery(senderUid: String, receiverUid: String, markIncomingSeen: Bool) {
        let query = Database.database().reference().child("Chats")
            .queryOrdered(byChild: "sender").queryEqual(toValue: senderUid)
        let handle = query.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self, self.activeThreadUid == receiverUid else { return }
                var outgoing: [ChatMessageModel] = []
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any],
                          ChatService.stringValue(dict["receiver"]) == receiverUid,
                          let msg = ChatService.parseMessage(key: snap.key, dict: dict) else { continue }
                    // Marcar "visto" a los mensajes entrantes, como ChatActivity.readMessages.
                    if markIncomingSeen, !ChatService.coerceBool(dict["isSeen"]) {
                        snap.ref.child("isSeen").setValue(true)
                    }
                    outgoing.append(msg)
                }
                self.mergeThread(messages: outgoing)
            }
        }
        threadObservers.append((handle: handle, remove: { query.removeObserver(withHandle: handle) }))
    }

    private func observePeerPresence(uid: String) {
        presenceObserver?.remove()
        presenceObserver = nil
        let ref = Database.database().reference().child("Users").child(uid).child("isOnline")
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                self.peerOnline[uid] = ChatService.coerceBool(snapshot.value)
                self.rebuildConversations()
            }
        }
        presenceObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }

    /// ChatActivity.checkBlockStatus: si `BlockedUsers/{él}/{yo}` O `BlockedUsers/{yo}/{él}`
    /// existe, el hilo se deshabilita (campo de texto y envío).
    public func observeBlockStatus(otherUid: String) {
        guard let myUid = myUid, FirebaseService.shared.canWriteToCloud else { return }
        blockObservers.forEach { $0.remove() }
        blockObservers = []
        let ref = Database.database().reference().child("BlockedUsers")
        // Él me bloqueó.
        let peerRef = ref.child(otherUid).child(myUid)
        let peerHandle = peerRef.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                self.isPeerBlockedMe = snapshot.exists()
            }
        }
        blockObservers.append((handle: peerHandle, remove: { peerRef.removeObserver(withHandle: peerHandle) }))
        // Yo le bloqueé (esquema A de chat).
        let mineRef = ref.child(myUid).child(otherUid)
        let mineHandle = mineRef.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                self.isBlockedByMe = snapshot.exists()
            }
        }
        blockObservers.append((handle: mineHandle, remove: { mineRef.removeObserver(withHandle: mineHandle) }))
    }

    /// Estado de silencio del hilo abierto (`MutedChats/{myUid}/{otherUid}`).
    /// La bandeja completa ya la pinta `observeMutedChats`, aquí solo se refuerza el hilo activo.
    public func observeMutedStatus(otherUid: String) {
        guard let myUid = myUid, FirebaseService.shared.canWriteToCloud else { return }
        mutedThreadObserver?.remove()
        mutedThreadObserver = nil
        let ref = Database.database().reference().child("MutedChats").child(myUid).child(otherUid)
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                if snapshot.exists() {
                    self.mutedUids.insert(otherUid)
                } else {
                    self.mutedUids.remove(otherUid)
                }
                self.rebuildConversations()
            }
        }
        mutedThreadObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }
    #endif

    private func mergeThread(messages: [ChatMessageModel]) {
        var merged = threadMessages.filter { existing in
            !messages.contains { $0.id == existing.id }
        }
        merged.append(contentsOf: messages)
        // Orden ascendente por timestamp (String de milisegundos, como Android).
        merged.sort { (Int($0.timestamp ?? "0") ?? 0) < (Int($1.timestamp ?? "0") ?? 0) }
        threadMessages = merged
    }

    // MARK: Envío (texto e imagen)
    public func sendText(to otherUid: String, text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        sendMessage(to: otherUid, payload: clean, type: .text, preview: clean, extras: nil)
    }

    public func sendImage(to otherUid: String, imageData: Data) {
        let millis = "\(Int(Date().timeIntervalSince1970 * 1000))"
        UploadManager.shared.uploadData(data: imageData, path: "chat_photo/\(millis)", mimeType: "image/jpeg") { [weak self] result in
            switch result {
            case .success(let url):
                self?.sendMessage(to: otherUid, payload: url, type: .image, preview: "📷 Foto", extras: nil)
            case .failure(let error):
                Task { @MainActor in
                    FirebaseService.shared.authError = "No se pudo enviar la imagen: \(error.localizedDescription)"
                }
            }
        }
    }

    private func sendMessage(to otherUid: String, payload: String, type: MessageType, preview: String, extras: [String: Any]?) {
        #if canImport(FirebaseDatabase)
        guard let myUid = myUid, FirebaseService.shared.canWriteToCloud else { return }
        let root = Database.database().reference()
        let millis = "\(Int(Date().timeIntervalSince1970 * 1000))"
        // `childByAutoId()` (SDK de Firebase) genera la key local; no se guarda dentro del nodo.
        let msgRef = root.child("Chats").childByAutoId()

        // Esquema idéntico a ChatActivity.sendMessage (Android). `timestamp` es String.
        var dict: [String: Any] = [
            "sender": myUid,
            "receiver": otherUid,
            "msg": payload,
            "type": type.rawValue,
            "timestamp": millis,
            "isSeen": false
        ]
        if let extras = extras { dict.merge(extras) { _, new in new } }
        msgRef.setValue(dict)

        // Bandeja de ambos lados (ChatActivity.updateChatList): cada lado ve su `id` correcto.
        root.child("Chatlist").child(myUid).child(otherUid).updateChildValues([
            "id": otherUid,
            "lastMsg": type.inboxPreviewLabel ?? preview,
            "timestamp": millis,
            "lastMsgType": type.rawValue,
            "lastSenderId": myUid
        ])
        root.child("Chatlist").child(otherUid).child(myUid).updateChildValues([
            "id": myUid,
            "lastMsg": type.inboxPreviewLabel ?? preview,
            "timestamp": millis,
            "lastMsgType": type.rawValue,
            "lastSenderId": myUid
        ])
        #endif
    }

    // MARK: Reacciones (ChatActivity.handleMessageReaction: `Chats/{msgId}/reactions/{myUid}` = emoji)
    /// Un emoji por usuario; el segundo toque **sobrescribe** el valor (no hay borrado, igual que Android).
    public func setReaction(msgId: String, emoji: String) {
        #if canImport(FirebaseDatabase)
        guard let myUid = myUid, FirebaseService.shared.canWriteToCloud else { return }
        Database.database().reference().child("Chats").child(msgId)
            .child("reactions").child(myUid).setValue(emoji)
        #endif
    }

    // MARK: Bloqueo (ChatActivity.toggleBlockUser: `BlockedUsers/{myUid}/{hisUid}` = true)
    public func toggleBlockUser(otherUid: String) {
        #if canImport(FirebaseDatabase)
        guard let myUid = myUid, FirebaseService.shared.canWriteToCloud else { return }
        let ref = Database.database().reference().child("BlockedUsers").child(myUid).child(otherUid)
        ref.observeSingleEvent(of: .value) { [weak self] snapshot in
            Task { @MainActor in
                guard self != nil else { return }
                if snapshot.exists() {
                    ref.removeValue()
                } else {
                    ref.setValue(true)
                }
            }
        }
        #endif
    }

    // MARK: Silencio (ChatActivity.toggleMuteChat: `MutedChats/{myUid}/{hisUid}` = true)
    public func toggleMuteChat(otherUid: String) {
        #if canImport(FirebaseDatabase)
        guard let myUid = myUid, FirebaseService.shared.canWriteToCloud else { return }
        let ref = Database.database().reference().child("MutedChats").child(myUid).child(otherUid)
        ref.observeSingleEvent(of: .value) { [weak self] snapshot in
            Task { @MainActor in
                guard self != nil else { return }
                if snapshot.exists() {
                    ref.removeValue()
                } else {
                    ref.setValue(true)
                }
            }
        }
        #endif
    }

    // MARK: Historial de llamadas (CallingActivity.saveCallHistory: `CallHistory/{uid}/{room}`)
    /// `room` = String(millis) generado por el emisor; `type` es "audio" | "video".
    /// El emisor SIEMPRE escribe en su nodo; el del receptor solo si no es cancelled/declined (Android:387-415).
    public func saveCallHistory(to otherUid: String, room: String, type: String, status: String, duration: Int) {
        #if canImport(FirebaseDatabase)
        guard let myUid = myUid, FirebaseService.shared.canWriteToCloud else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        // ModelCall.java: startTime/endTime/duration/timestamp en milisegundos (long).
        let dict: [String: Any] = [
            "from": myUid,
            "to": otherUid,
            "room": room,
            "type": type,       // "audio" | "video"
            "status": status,   // answered|missed|declined|cancelled|failed|busy
            "reason": "",
            "startTime": now - Int64(duration),
            "endTime": now,
            "duration": duration,
            "timestamp": now,
            "isSeen": false
        ]
        let ref = Database.database().reference().child("CallHistory")
        ref.child(myUid).child(room).setValue(dict)
        if status != "cancelled" && status != "declined" {
            ref.child(otherUid).child(room).setValue(dict)
        }
        #endif
    }

    // MARK: Mensaje de llamada (ChatActivity:1186-1194 — al iniciar llamada se empuja en `Chats`)
    public func sendCallMessage(type: MessageType) {
        guard let otherUid = activeThreadUid else { return }
        switch type {
        case .voiceCall, .audioCall:
            sendMessage(to: otherUid, payload: "📞 Llamada de voz", type: .voiceCall, preview: "📞 Llamada de voz", extras: nil)
        case .videoCall:
            sendMessage(to: otherUid, payload: "🎥 Llamada de video", type: .videoCall, preview: "🎥 Llamada de video", extras: nil)
        default:
            break
        }
    }

    // MARK: Parsing tolerante (misma tolerancia que ModelChat.java)
    private static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String { return value }
        if let value = raw as? NSNumber { return value.stringValue }
        return nil
    }

    /// Tolerancia de Android: Bool, String "true"/"1" o Number 1.
    private static func coerceBool(_ raw: Any?) -> Bool {
        if let value = raw as? Bool { return value }
        if let value = raw as? String { return value == "true" || value == "1" }
        if let value = raw as? NSNumber { return value.boolValue }
        return false
    }

    static func parseMessage(key: String, dict: [String: Any]) -> ChatMessageModel? {
        guard let sender = stringValue(dict["sender"]), !sender.isEmpty,
              let receiver = stringValue(dict["receiver"]) else { return nil }
        let typeRaw = stringValue(dict["type"]) ?? "text"
        let type = MessageType(rawValue: typeRaw) ?? (typeRaw == "document" ? .document : .unknown)
        return ChatMessageModel(
            id: key,
            messageId: key,
            sender: sender,
            receiver: receiver,
            message: stringValue(dict["msg"]) ?? "",
            timestamp: stringValue(dict["timestamp"]) ?? "0",
            type: type,
            isSeen: coerceBool(dict["isSeen"]),
            reactions: parseReactions(dict["reactions"])
        )
    }

    /// `reactions` = { uid: emoji } (un valor String por usuario). Tolerante a valores no-string.
    private static func parseReactions(_ raw: Any?) -> [String: String]? {
        guard let dict = raw as? [String: Any], !dict.isEmpty else { return nil }
        var parsed: [String: String] = [:]
        for (uid, value) in dict {
            guard let emoji = stringValue(value), !emoji.isEmpty else { continue }
            parsed[uid] = emoji
        }
        return parsed.isEmpty ? nil : parsed
    }

    static func formatMillis(_ millis: String) -> String {
        let seconds = (Int(millis) ?? 0) / 1000
        guard seconds > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(seconds))
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) { return "Ayer" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: date)
    }
}

// MARK: - Chat ViewModel
@MainActor
public class ChatViewModel: ObservableObject {
    @Published public var chats: [ChatModel] = []
    @Published public var currentMessages: [ChatMessageModel] = []
    @Published public var messageText: String = ""
    @Published public var isRecordingAudio: Bool = false
    @Published public var totalUnreadCount: Int = 0
    /// Reacciones/silencio/bloqueo observados desde `ChatService` (no-ops en modo demo).
    @Published public private(set) var mutedUids: Set<String> = []
    @Published public private(set) var isBlockedByMe: Bool = false
    @Published public private(set) var isPeerBlockedMe: Bool = false

    private let service = ChatService.shared
    private var cancellables: Set<AnyCancellable> = []
    public let usesLiveChat: Bool

    public init() {
        // Con sesión real se usa el chat en la nube; en modo demo (o sin BD) se mantiene el seed local.
        usesLiveChat = FirebaseService.shared.canWriteToCloud
        if usesLiveChat {
            service.ensureStarted()
            service.$conversations.assign(to: &$chats)
            service.$threadMessages.assign(to: &$currentMessages)
            service.$totalUnreadCount.assign(to: &$totalUnreadCount)
            service.$mutedUids.assign(to: &$mutedUids)
            service.$isBlockedByMe.assign(to: &$isBlockedByMe)
            service.$isPeerBlockedMe.assign(to: &$isPeerBlockedMe)
        } else {
            totalUnreadCount = 2
            loadMockChats()
        }
    }

    /// ChatActivity.checkBlockStatus: si él me bloqueó O yo le bloqueé, no se puede escribir.
    public var isChatBlocked: Bool { isBlockedByMe || isPeerBlockedMe }

    /// Aviso en español para la barra de entrada (misma semántica que los hints de Android).
    public var blockedNotice: String? {
        if isPeerBlockedMe { return "Este usuario te ha bloqueado. No puedes enviarle mensajes." }
        if isBlockedByMe { return "Has bloqueado a este usuario. Desbloquéalo para poder escribirle." }
        return nil
    }

    public func openInbox() {
        guard usesLiveChat else { return }
        service.ensureStarted()
    }

    public func openThread(with uid: String) {
        guard usesLiveChat else { return }
        service.openThread(with: uid)
    }

    public func closeThread() {
        guard usesLiveChat else { return }
        service.closeThread()
    }

    public func sendImage(receiverId: String, imageData: Data) {
        guard usesLiveChat else { return }
        service.sendImage(to: receiverId, imageData: imageData)
    }

    // MARK: Reacciones (doble toque → ❤️; selector de emojis desde el menú contextual)
    /// Sobrescribe el emoji propio (esquema de Android: no hay "quitar reacción").
    public func react(messageId: String, emoji: String) {
        guard usesLiveChat else { return }
        service.setReaction(msgId: messageId, emoji: emoji)
    }

    // MARK: Silencio / bloqueo del hilo
    public func toggleMute(otherUid: String) {
        guard usesLiveChat else { return }
        service.toggleMuteChat(otherUid: otherUid)
    }

    public func toggleBlock(otherUid: String) {
        guard usesLiveChat else { return }
        service.toggleBlockUser(otherUid: otherUid)
    }

    /// Al pulsar los botones de llamada: guarda el intento en `CallHistory` (status "cancelled",
    /// como marca de intento) y empuja el mensaje `voice_call`/`video_call` en `Chats` + `Chatlist`,
    /// igual que ChatActivity.java:1186-1194 al iniciar una llamada.
    public func registerCallAttempt(to otherUid: String, isVideo: Bool) {
        guard usesLiveChat else { return }
        let room = "\(Int(Date().timeIntervalSince1970 * 1000))"
        service.saveCallHistory(to: otherUid, room: room, type: isVideo ? "video" : "audio", status: "cancelled", duration: 0)
        service.sendCallMessage(type: isVideo ? .videoCall : .voiceCall)
    }

    private func loadMockChats() {
        chats = [
            ChatModel(
                id: "chat_1",
                userId: "user_maria_01",
                userName: "María García (Violonchelo)",
                userDp: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=500&auto=format&fit=crop&q=60",
                lastMessage: "¡Excelente ensayo de hoy! Nos vemos el jueves para afinar el cuarteto 🎻",
                lastTimestamp: "10:45 AM",
                unreadCount: 2,
                isOnline: true
            ),
            ChatModel(
                id: "chat_2",
                userId: "entity_mariachi_01",
                userName: "Mariachi Sinfónico Real",
                userDp: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
                lastMessage: "Confirmada la cotización para la serenata del sábado.",
                lastTimestamp: "Ayer",
                unreadCount: 0,
                isOnline: false
            )
        ]
        
        currentMessages = [
            ChatMessageModel(
                id: "msg_1",
                sender: "user_maria_01",
                receiver: "user_demo_violin_001",
                message: "Hola Israel, ¿practicaste el pasaje rápido del tercer movimiento?",
                timestamp: "10:30 AM",
                type: .text
            ),
            ChatMessageModel(
                id: "msg_2",
                sender: "user_demo_violin_001",
                receiver: "user_maria_01",
                message: "Sí, usé el metrónomo de PROVIWEB y ya subí a 130 BPM con el Profesor IA 🎯",
                timestamp: "10:35 AM",
                type: .text
            ),
            ChatMessageModel(
                id: "msg_3",
                sender: "user_maria_01",
                receiver: "user_demo_violin_001",
                message: "¡Excelente ensayo de hoy! Nos vemos el jueves para afinar el cuarteto 🎻",
                timestamp: "10:45 AM",
                type: .text
            )
        ]
    }
    
    public func sendMessage(receiverId: String) {
        let text = messageText
        messageText = ""
        guard usesLiveChat else {
            // Modo demo: burbuja local sin red.
            let newMsg = ChatMessageModel(
                id: UUID().uuidString,
                sender: FirebaseService.shared.currentUserId,
                receiver: receiverId,
                message: text,
                timestamp: "Ahora",
                type: .text
            )
            currentMessages.append(newMsg)
            return
        }
        service.sendText(to: receiverId, text: text)
    }
}

// MARK: - AI Professor ViewModel
@MainActor
public class AIProfessorViewModel: ObservableObject {
    @Published public var isPracticing: Bool = false
    @Published public var currentExercise: String = "Escala de Sol Mayor (Suzuki Libro 1)"
    @Published public var detectedNote: String = "La (A4)"
    @Published public var detectedFrequency: Double = 440.0
    @Published public var centsDetuned: Double = 0.0
    @Published public var pitchAccuracyScore: Double = 94.0
    @Published public var postureScore: Double = 92.0
    @Published public var liveScore: Double = 93.0
    @Published public var maestroDialogue: String = "¡Muy bien! Mantén el arco paralelo al puente."
    @Published public var exerciseProgress: Double = 0.65
    @Published public var isVoiceFeedbackEnabled: Bool = true
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let poseService = PoseEstimationService.shared
    private let tunerService = ChromaticTunerService.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupBindings()
    }
    
    private func setupBindings() {
        poseService.$postureScore
            .assign(to: &$postureScore)
        poseService.$feedbackMessage
            .sink { [weak self] msg in
                self?.maestroDialogue = msg
                if self?.isPracticing == true && self?.isVoiceFeedbackEnabled == true {
                    self?.speakFeedback(msg)
                }
            }
            .store(in: &cancellables)
            
        tunerService.$noteName
            .assign(to: &$detectedNote)
        tunerService.$detectedPitch
            .assign(to: &$detectedFrequency)
        tunerService.$centsDetuned
            .assign(to: &$centsDetuned)
    }
    
    public func togglePracticeSession() {
        if isPracticing {
            stopSession()
        } else {
            startSession()
        }
    }
    
    public func startSession() {
        isPracticing = true
        poseService.startCamera()
        tunerService.startListening()
        speakFeedback("Iniciando práctica con el Profesor IA. Colócate frente a la cámara con tu violín.")
    }
    
    public func stopSession() {
        isPracticing = false
        poseService.stopCamera()
        tunerService.stopListening()
        speakFeedback("Excelente sesión. Tu precisión promedio fue de 94 por ciento.")
    }
    
    public func speakFeedback(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-MX")
        utterance.rate = 0.52
        speechSynthesizer.speak(utterance)
    }
}

// MARK: - Practice Studio & Rewards ViewModel
@MainActor
public class PracticeStudioViewModel: ObservableObject {
    @Published public var elapsedTimeSeconds: Int = 0
    @Published public var isPracticeTimerRunning: Bool = false
    @Published public var hasEarnedSessionReward: Bool = false
    
    private var timer: Timer?
    private let firebaseService = FirebaseService.shared
    
    public var formattedTime: String {
        let hours = elapsedTimeSeconds / 3600
        let minutes = (elapsedTimeSeconds % 3600) / 60
        let seconds = elapsedTimeSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    public func toggleTimer() {
        if isPracticeTimerRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    public func startTimer() {
        isPracticeTimerRunning = true
        // El bloque de Timer llega como @Sendable sin aislamiento; se salta a main para
        // mutar estado @MainActor de forma segura (compatible con iOS 16).
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.elapsedTimeSeconds += 1
                
                // Android reward threshold: > 200 seconds ($1.00 balance reward)
                if self.elapsedTimeSeconds >= 200 && !self.hasEarnedSessionReward {
                    self.hasEarnedSessionReward = true
                    self.firebaseService.addPracticeReward()
                }
            }
        }
    }
    
    public func stopTimer() {
        isPracticeTimerRunning = false
        timer?.invalidate()
        timer = nil
    }
}
