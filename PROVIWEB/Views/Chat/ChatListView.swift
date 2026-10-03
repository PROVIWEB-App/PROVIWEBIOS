import SwiftUI

// MARK: - Chat List View
public struct ChatListView: View {
    @StateObject private var viewModel = ChatViewModel()
    @ObservedObject private var theme = ThemeManager.shared
    @State private var selectedChat: ChatModel? = nil
    
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
                        TextField("Buscar chats, artistas o grupos...", text: .constant(""))
                    }
                    .padding(10)
                    .background(theme.cardColor)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    List {
                        ForEach(viewModel.chats) { chat in
                            NavigationLink(destination: ChatConversationView(chat: chat)) {
                                ChatRowView(chat: chat)
                            }
                            .listRowBackground(theme.cardColor)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Mensajes")
            .navigationBarTitleDisplayMode(.inline)
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
    
    public var body: some View {
        VStack(spacing: 0) {
            // Chat Messages List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.currentMessages) { msg in
                        MessageBubbleView(message: msg)
                    }
                }
                .padding(16)
            }
            
            // Input Bar
            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .foregroundColor(theme.textSecondary)
                }
                
                TextField("Escribe un mensaje...", text: $viewModel.messageText)
                    .padding(10)
                    .background(theme.cardColor)
                    .cornerRadius(20)
                
                if viewModel.messageText.isEmpty {
                    Button(action: {
                        viewModel.isRecordingAudio.toggle()
                    }) {
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .foregroundColor(viewModel.isRecordingAudio ? AppColors.errorRed : AppColors.chatPrimary)
                    }
                } else {
                    Button(action: {
                        viewModel.sendMessage(receiverId: chat.userId)
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.chatPrimary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.backgroundColor)
        }
        .background(theme.backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
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
                    }) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(AppColors.chatPrimary)
                    }
                    
                    Button(action: {
                        callKit.startCall(callerName: chat.userName, isVideo: true)
                    }) {
                        Image(systemName: "video.fill")
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
    @ObservedObject private var theme = ThemeManager.shared
    
    var isCurrentUser: Bool {
        message.sender == FirebaseService.shared.currentUserId
    }
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.message)
                    .font(.body)
                    .foregroundColor(isCurrentUser ? .white : theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isCurrentUser ? AppColors.chatPrimary : theme.cardColor)
                    .cornerRadius(18)
                
                Text(message.timestamp ?? "")
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 4)
            }
            
            if !isCurrentUser { Spacer() }
        }
    }
}
