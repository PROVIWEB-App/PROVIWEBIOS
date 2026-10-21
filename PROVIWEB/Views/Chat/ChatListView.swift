import SwiftUI
import UIKit
import PhotosUI

// MARK: - Chat List View
public struct ChatListView: View {
    @StateObject private var viewModel = ChatViewModel()
    @ObservedObject private var theme = ThemeManager.shared
    @State private var searchText: String = ""

    public init() {}

    private var filteredChats: [ChatModel] {
        guard !searchText.isEmpty else { return viewModel.chats }
        return viewModel.chats.filter { $0.userName.localizedCaseInsensitiveContains(searchText) }
    }

    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(theme.textSecondary)
                        TextField("Buscar chats, artistas o grupos...", text: $searchText)
                    }
                    .padding(10)
                    .background(theme.cardColor)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    if filteredChats.isEmpty {
                        VStack(spacing: 10) {
                            Spacer()
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 44))
                                .foregroundColor(theme.textSecondary)
                            Text("Aún no tienes conversaciones")
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(filteredChats) { chat in
                                NavigationLink(destination: ChatConversationView(chat: chat)) {
                                    ChatRowView(chat: chat)
                                }
                                .listRowBackground(theme.cardColor)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Mensajes")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.openInbox() }
        }
    }
}

// MARK: - Chat Row View
struct ChatRowView: View {
    let chat: ChatModel
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(urlString: chat.userDp, size: 50, isVerified: true)
                
                if chat.isOnline == true {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.userName)
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                    // Silenciado: `MutedChats/{miUid}/{otroUid}` (AdapterChatList pinta su campana tachada).
                    if chat.isMuted == true {
                        Text("🔕")
                            .font(.caption)
                    }
                    Spacer()
                    Text(chat.lastTimestamp ?? "")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                }
                
                HStack {
                    Text(chat.lastMessage ?? "")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let count = chat.unreadCount, count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppColors.chatPrimary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Chat Conversation View
public struct ChatConversationView: View {
    public let chat: ChatModel
    @StateObject private var viewModel = ChatViewModel()
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var callKit = CallKitService.shared
    @State private var isVideoCallPresented: Bool = false
    @State private var pickedPhoto: PhotosPickerItem? = nil
    // Reacciones / silencio / bloqueo
    @State private var reactionTarget: ChatMessageModel? = nil
    @State private var isBlockConfirmPresented: Bool = false
    @State private var isMuteConfirmPresented: Bool = false
    @State private var demoAlertPresented: Bool = false
    @State private var demoAlertMessage: String = ""
    
    /// Acciones nuevas (reacciones, silencio, bloqueo, historial de llamadas) requieren cuenta real.
    @discardableResult
    private func guardCloud(_ action: String) -> Bool {
        guard viewModel.usesLiveChat else {
            demoAlertMessage = "\(action) requiere una cuenta PROVIWEB activa. Inicia sesión para usarlo."
            demoAlertPresented = true
            return false
        }
        return true
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Chat Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.currentMessages) { msg in
                            MessageBubbleView(
                                message: msg,
                                onReact: { message in reactionTarget = message },
                                onDoubleTap: { message in
                                    // Doble toque → ❤️ (AdapterChat.java:137-150). Sobrescribe, no borra.
                                    guardCloud("Reaccionar a un mensaje")
                                    viewModel.react(messageId: message.messageId ?? message.id, emoji: "❤️")
                                }
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: viewModel.currentMessages.last?.id) { lastId in
                    guard let lastId = lastId else { return }
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
            }
            
            // Aviso de bloqueo (ChatActivity.checkBlockStatus: sin campo ni botón de envío).
            if let notice = viewModel.blockedNotice {
                HStack(spacing: 8) {
                    Image(systemName: "nosign")
                        .font(.caption)
                    Text(notice)
                        .font(.caption)
                        .lineLimit(2)
                }
                .foregroundColor(AppColors.errorRed)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.cardColor)
            }
            
            // Input Bar
            HStack(spacing: 12) {
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .foregroundColor(theme.textSecondary)
                }
                .disabled(viewModel.isChatBlocked)
                
                TextField("Escribe un mensaje...", text: $viewModel.messageText)
                    .padding(10)
                    .background(theme.cardColor)
                    .cornerRadius(20)
                    .disabled(viewModel.isChatBlocked)
                
                if viewModel.messageText.isEmpty {
                    Button(action: {
                        viewModel.isRecordingAudio.toggle()
                    }) {
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .foregroundColor(viewModel.isRecordingAudio ? AppColors.errorRed : AppColors.chatPrimary)
                    }
                    .disabled(viewModel.isChatBlocked)
                } else {
                    Button(action: {
                        viewModel.sendMessage(receiverId: chat.userId)
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.chatPrimary)
                    }
                    .disabled(viewModel.isChatBlocked)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.backgroundColor)
            .opacity(viewModel.isChatBlocked ? 0.6 : 1.0)
        }
        .background(theme.backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.openThread(with: chat.userId) }
        .onDisappear { viewModel.closeThread() }
        .onChange(of: pickedPhoto) { item in
            guard let item = item else { return }
            let receiverId = chat.userId
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.sendImage(receiverId: receiverId, imageData: data)
                }
                pickedPhoto = nil
            }
        }
        // Selector de reacciones (bottom-sheet de emojis, ChatActivity.java:630-638).
        .sheet(item: $reactionTarget) { message in
            VStack(spacing: 16) {
                Text("Reaccionar al mensaje")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Text(message.message)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                HStack(spacing: 20) {
                    ForEach(["❤️", "👍", "😂", "😮", "😢", "🔥"], id: \.self) { emoji in
                        Button(action: {
                            reactionTarget = nil
                            guardCloud("Reaccionar a un mensaje")
                            viewModel.react(messageId: message.messageId ?? message.id, emoji: emoji)
                        }) {
                            Text(emoji)
                                .font(.system(size: 34))
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(theme.backgroundColor)
        }
        // Confirmación para bloquear/desbloquear (en español, como el AlertDialog de Android).
        .alert(
            viewModel.isBlockedByMe ? "Desbloquear usuario" : "¿Bloquear a \(chat.userName)?",
            isPresented: $isBlockConfirmPresented
        ) {
            Button("Cancelar", role: .cancel) {}
            Button(viewModel.isBlockedByMe ? "Desbloquear" : "Bloquear", role: .destructive) {
                guardCloud("Bloquear usuarios")
                viewModel.toggleBlock(otherUid: chat.userId)
            }
        } message: {
            if viewModel.isBlockedByMe {
                Text("¿Desbloquear a \(chat.userName)? Podrás volver a enviarle mensajes.")
            } else {
                Text("¿Bloquear a \(chat.userName)? No podrá enviarte mensajes en este chat y tú no podrás escribirle hasta desbloquearlo.")
            }
        }
        // Confirmación para silenciar/activar notificaciones.
        .alert(
            viewModel.mutedUids.contains(chat.userId) ? "Activar notificaciones" : "¿Silenciar el chat con \(chat.userName)?",
            isPresented: $isMuteConfirmPresented
        ) {
            Button("Cancelar", role: .cancel) {}
            Button(viewModel.mutedUids.contains(chat.userId) ? "Activar" : "Silenciar") {
                guardCloud("Silenciar chats")
                viewModel.toggleMute(otherUid: chat.userId)
            }
        } message: {
            if viewModel.mutedUids.contains(chat.userId) {
                Text("¿Volver a recibir notificaciones de \(chat.userName)?")
            } else {
                Text("Dejarás de recibir notificaciones de nuevos mensajes de \(chat.userName). El chat seguirá recibiendo mensajes.")
            }
        }
        // Modo demo: aviso de que la función necesita cuenta real.
        .alert("Función no disponible", isPresented: $demoAlertPresented) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(demoAlertMessage)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    AvatarView(urlString: chat.userDp, size: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(chat.userName)
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text(chat.isOnline == true ? "En línea" : "Desconectado")
                            .font(.caption2)
                            .foregroundColor(chat.isOnline == true ? AppColors.success : .gray)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        callKit.startCall(callerName: chat.userName, isVideo: false)
                        viewModel.registerCallAttempt(to: chat.userId, isVideo: false)
                    }) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(AppColors.chatPrimary)
                    }
                    .disabled(viewModel.isChatBlocked)
                    
                    Button(action: {
                        callKit.startCall(callerName: chat.userName, isVideo: true)
                        viewModel.registerCallAttempt(to: chat.userId, isVideo: true)
                    }) {
                        Image(systemName: "video.fill")
                            .foregroundColor(AppColors.chatPrimary)
                    }
                    .disabled(viewModel.isChatBlocked)
                    
                    // Menú del hilo (bottom-sheet_chat_menu de Android): silencio y bloqueo.
                    Menu {
                        Button(action: {
                            if guardCloud("Silenciar chats") {
                                isMuteConfirmPresented = true
                            }
                        }) {
                            Label(
                                viewModel.mutedUids.contains(chat.userId) ? "Activar notificaciones" : "Silenciar chat",
                                systemImage: viewModel.mutedUids.contains(chat.userId) ? "bell.fill" : "bell.slash"
                            )
                        }
                        
                        Button(role: .destructive, action: {
                            if guardCloud("Bloquear usuarios") {
                                isBlockConfirmPresented = true
                            }
                        }) {
                            Label(
                                viewModel.isBlockedByMe ? "Desbloquear usuario" : "Bloquear usuario",
                                systemImage: "nosign"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppColors.chatPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessageModel
    /// Abre el selector de emojis (menú contextual → "Reaccionar").
    var onReact: ((ChatMessageModel) -> Void)? = nil
    /// Doble toque → ❤️ (AdapterChat.java:137-150).
    var onDoubleTap: ((ChatMessageModel) -> Void)? = nil
    @ObservedObject private var theme = ThemeManager.shared
    
    var isCurrentUser: Bool {
        message.sender == FirebaseService.shared.currentUserId
    }
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                content
                // Reacciones agrupadas ("❤️ 2"), AdapterChat.java:161-176.
                if !message.groupedReactions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(message.groupedReactions, id: \.emoji) { item in
                            Text("\(item.emoji) \(item.count)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.cardColor)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 4)
                }
                HStack(spacing: 4) {
                    Text(ChatService.formatMillis(message.timestamp ?? "0"))
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                    // Check de leído con la misma semántica visual que AdapterChat.java (alpha 1.0 / 0.5).
                    if isCurrentUser {
                        Image(systemName: (message.isSeen ?? false) ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.caption2)
                            .foregroundColor((message.isSeen ?? false) ? AppColors.chatPrimary : theme.textSecondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if !isCurrentUser { Spacer() }
        }
        // Doble toque → reacción rápida ❤️.
        .onTapGesture(count: 2) {
            onDoubleTap?(message)
        }
        // Menú contextual: reaccionar (selector de emojis) o copiar.
        .contextMenu {
            Button(action: {
                onReact?(message)
            }) {
                Label("Reaccionar", systemImage: "face.smiling")
            }
            
            Button(action: {
                UIPasteboard.general.string = message.message
            }) {
                Label("Copiar", systemImage: "doc.on.doc")
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch message.type {
        case .image:
            AsyncImage(url: URL(string: message.message)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    ZStack {
                        theme.cardColor
                        Image(systemName: "photo")
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: 220, maxHeight: 260)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        case .location:
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundColor(AppColors.errorRed)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ubicación compartida")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isCurrentUser ? .white : theme.textPrimary)
                    Text(message.message)
                        .font(.caption)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.85) : theme.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .background(isCurrentUser ? AppColors.chatPrimary : theme.cardColor)
            .cornerRadius(18)
        case .voiceCall, .audioCall, .videoCall, .callMissed, .call:
            // Burbuja de llamada (Android pinta icono + texto para los tipos *_call).
            HStack(spacing: 8) {
                Image(systemName: message.type == .callMissed ? "phone.down.fill" : (message.type == .videoCall ? "video.fill" : "phone.fill"))
                    .font(.subheadline)
                    .foregroundColor(isCurrentUser ? .white.opacity(0.9) : AppColors.chatPrimary)
                Text(message.message)
                    .font(.subheadline)
                    .foregroundColor(isCurrentUser ? .white : theme.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isCurrentUser ? AppColors.chatPrimary : theme.cardColor)
            .cornerRadius(18)
        default:
            Text(message.message)
                .font(.body)
                .foregroundColor(isCurrentUser ? .white : theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isCurrentUser ? AppColors.chatPrimary : theme.cardColor)
                .cornerRadius(18)
        }
    }
}
