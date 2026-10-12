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
    @State private var isSplitSheetCreatorPresented: Bool = false
    @State private var isMediaPickerPresented: Bool = false
    
    public var body: some View {
        VStack(spacing: 0) {
            // Chat Messages List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.currentMessages) { msg in
                        MessageBubbleView(
                            message: msg,
                            onSignSplitSheet: {
                                viewModel.signSplitSheet(messageId: msg.id)
                            },
                            onProposalStatusChanged: { status in
                                viewModel.updateProposalStatus(messageId: msg.id, status: status)
                            }
                        )
                    }
                }
                .padding(16)
            }
            
            // Input Bar
            HStack(spacing: 10) {
                // Split Sheet Creator Action (Android DialogSplitSheetCreator equivalent)
                Button(action: {
                    isSplitSheetCreatorPresented = true
                }) {
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                        .foregroundColor(AppColors.primary)
                }
                
                // Photo Attachment Action
                Button(action: {
                    viewModel.sendMediaImage(
                        receiverId: chat.userId,
                        imageUrl: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=60"
                    )
                }) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .foregroundColor(theme.textSecondary)
                }
                
                TextField("Escribe un mensaje...", text: $viewModel.messageText)
                    .padding(10)
                    .background(theme.cardColor)
                    .cornerRadius(20)
                
                if viewModel.messageText.isEmpty {
                    // Voice Note Record & Send Action
                    Button(action: {
                        viewModel.sendVoiceNote(receiverId: chat.userId, duration: 4.5)
                    }) {
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.chatPrimary)
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
            .padding(.horizontal, 14)
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
        .sheet(isPresented: $isSplitSheetCreatorPresented) {
            SplitSheetCreatorSheet(collaboratorId: chat.userId, collaboratorName: chat.userName) { title, genre, myRole, myPct, collabRole, collabPct in
                viewModel.sendSplitSheet(
                    receiverId: chat.userId,
                    collaboratorName: chat.userName,
                    songTitle: title,
                    genre: genre,
                    creatorRole: myRole,
                    creatorPercent: myPct,
                    collaboratorRole: collabRole,
                    collaboratorPercent: collabPct
                )
            }
        }
    }
}

// MARK: - Message Bubble View with Split-Sheet, Job Proposal, Audio Waveform & Images
struct MessageBubbleView: View {
    let message: ChatMessageModel
    var onSignSplitSheet: (() -> Void)? = nil
    var onProposalStatusChanged: ((String) -> Void)? = nil
    @ObservedObject private var theme = ThemeManager.shared
    @State private var isPlayingAudio: Bool = false
    
    var isCurrentUser: Bool {
        message.sender == FirebaseService.shared.currentUserId
    }
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                switch message.type {
                case .splitSheet:
                    // Interactive Split Sheet Card (Android DialogSplitSheetCreator)
                    if let split = message.splitSheet {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(AppColors.gold)
                                Text("ACUERDO SPLIT SHEET")
                                    .font(.caption2)
                                    .fontWeight(.black)
                                    .tracking(1)
                                    .foregroundColor(AppColors.gold)
                                Spacer()
                                Text(split.status == "signed" ? "FIRMADO ✅" : "PENDIENTE ✍️")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(split.status == "signed" ? AppColors.success.opacity(0.2) : AppColors.warningOrange.opacity(0.2))
                                    .foregroundColor(split.status == "signed" ? AppColors.success : AppColors.warningOrange)
                                    .cornerRadius(6)
                            }
                            
                            Text(split.songTitle)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textPrimary)
                            
                            Text("Género: \(split.genre)")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                            
                            Divider()
                            
                            // Creator %
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(split.creatorName)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.textPrimary)
                                    Text(split.creatorRole)
                                        .font(.caption2)
                                        .foregroundColor(theme.textSecondary)
                                }
                                Spacer()
                                Text("\(split.creatorPercentage)%")
                                    .font(.headline)
                                    .fontWeight(.black)
                                    .foregroundColor(AppColors.primary)
                                Image(systemName: split.creatorSigned ? "checkmark.seal.fill" : "circle")
                                    .foregroundColor(AppColors.success)
                            }
                            
                            // Collaborator %
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(split.collaboratorName)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.textPrimary)
                                    Text(split.collaboratorRole)
                                        .font(.caption2)
                                        .foregroundColor(theme.textSecondary)
                                }
                                Spacer()
                                Text("\(split.collaboratorPercentage)%")
                                    .font(.headline)
                                    .fontWeight(.black)
                                    .foregroundColor(AppColors.primary)
                                Image(systemName: split.collaboratorSigned ? "checkmark.seal.fill" : "pencil.circle")
                                    .foregroundColor(split.collaboratorSigned ? AppColors.success : AppColors.warningOrange)
                            }
                            
                            // Hash Fingerprint
                            Text("Certificado SHA-256: \(split.digitalCertificateHash.prefix(12))...")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(theme.textSecondary)
                            
                            // Sign Button if not signed
                            if !split.collaboratorSigned {
                                Button(action: {
                                    onSignSplitSheet?()
                                }) {
                                    HStack {
                                        Image(systemName: "signature")
                                        Text("Firmar Acuerdo Digitalmente")
                                            .fontWeight(.bold)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(AppColors.primary)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(14)
                        .background(theme.cardColor)
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                        .frame(maxWidth: 300)
                    }
                    
                case .proposal:
                    // Interactive Gig Proposal Card (Android JobProposal in Chat)
                    if let prop = message.proposal {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "briefcase.fill")
                                    .foregroundColor(AppColors.primary)
                                Text("CONTRATO MUSICAL")
                                    .font(.caption2)
                                    .fontWeight(.black)
                                    .tracking(1)
                                    .foregroundColor(AppColors.primary)
                                Spacer()
                                Text(prop.jobStatus)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(prop.jobStatus == "ACCEPTED" ? AppColors.success.opacity(0.2) : (prop.jobStatus == "REJECTED" ? AppColors.errorRed.opacity(0.2) : AppColors.warningOrange.opacity(0.2)))
                                    .foregroundColor(prop.jobStatus == "ACCEPTED" ? AppColors.success : (prop.jobStatus == "REJECTED" ? AppColors.errorRed : AppColors.warningOrange))
                                    .cornerRadius(6)
                            }
                            
                            Text(prop.jobRole)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textPrimary)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Label(prop.jobEvent, systemImage: "music.note.house")
                                Label(prop.jobDate, systemImage: "calendar")
                                Label(prop.jobLocation, systemImage: "mappin.and.ellipse")
                            }
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            
                            if let details = prop.jobDetails {
                                Text(details)
                                    .font(.caption2)
                                    .foregroundColor(theme.textSecondary)
                                    .padding(8)
                                    .background(theme.backgroundColor.opacity(0.6))
                                    .cornerRadius(8)
                            }
                            
                            HStack {
                                Text("Honorarios:")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                                Spacer()
                                Text("$\(Int(prop.jobPrice)) \(prop.jobCurrency)")
                                    .font(.title3)
                                    .fontWeight(.black)
                                    .foregroundColor(AppColors.success)
                            }
                            
                            if prop.jobStatus == "PENDING" {
                                HStack(spacing: 10) {
                                    Button(action: {
                                        onProposalStatusChanged?("REJECTED")
                                    }) {
                                        Text("Declinar")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.errorRed)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(AppColors.errorRed.opacity(0.12))
                                            .cornerRadius(8)
                                    }
                                    
                                    Button(action: {
                                        onProposalStatusChanged?("ACCEPTED")
                                    }) {
                                        Text("Aceptar Contrato")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(AppColors.success)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(theme.cardColor)
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                        .frame(maxWidth: 300)
                    }
                    
                case .audio:
                    // Interactive Voice Note Bubble with waveform
                    HStack(spacing: 12) {
                        Button(action: {
                            isPlayingAudio.toggle()
                        }) {
                            Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title)
                                .foregroundColor(isCurrentUser ? .white : AppColors.primary)
                        }
                        
                        // Animated Waveform Bars
                        HStack(spacing: 3) {
                            ForEach(0..<(message.waveform?.count ?? 8), id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(isCurrentUser ? Color.white.opacity(0.9) : AppColors.primary.opacity(0.8))
                                    .frame(width: 4, height: CGFloat(10 + (i * 4) % 24))
                            }
                        }
                        
                        Text(String(format: "0:%02d", Int(message.voiceDuration ?? 4.0)))
                            .font(.caption2)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.8) : theme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isCurrentUser ? AppColors.chatPrimary : theme.cardColor)
                    .cornerRadius(18)
                    
                case .image:
                    // Image attachment bubble
                    if let media = message.mediaUrl, let url = URL(string: media) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.2))
                        }
                        .frame(width: 220, height: 160)
                        .cornerRadius(14)
                        .clipped()
                    }
                    
                default:
                    // Standard Text Message Bubble
                    Text(message.message)
                        .font(.body)
                        .foregroundColor(isCurrentUser ? .white : theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isCurrentUser ? AppColors.chatPrimary : theme.cardColor)
                        .cornerRadius(18)
                }
                
                Text(message.timestamp ?? "")
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 4)
            }
            
            if !isCurrentUser { Spacer() }
        }
    }
}

// MARK: - Split Sheet Creator Modal (DialogSplitSheetCreator.java equivalent)
struct SplitSheetCreatorSheet: View {
    let collaboratorId: String
    let collaboratorName: String
    let onCreated: (String, String, String, Int, String, Int) -> Void
    
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var songTitle: String = ""
    @State private var genre: String = "Música Clásica / Mariachi"
    @State private var creatorRole: String = "Compositor & 1er Violín"
    @State private var collaboratorRole: String = "Arreglista / Cello"
    @State private var creatorPercentage: Double = 50.0
    
    var collaboratorPercentage: Double {
        100.0 - creatorPercentage
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Información de la Obra Musical")) {
                        TextField("Título de la Canción u Obra", text: $songTitle)
                        TextField("Género", text: $genre)
                    }
                    
                    Section(header: Text("Tus Datos (Creador)")) {
                        TextField("Tu Rol en la Obra", text: $creatorRole)
                        HStack {
                            Text("Tu Porcentaje:")
                            Spacer()
                            Text("\(Int(creatorPercentage))%")
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                        }
                        Slider(value: $creatorPercentage, in: 1...99, step: 1)
                    }
                    
                    Section(header: Text("Datos del Colaborador (\(collaboratorName))")) {
                        TextField("Rol del Colaborador", text: $collaboratorRole)
                        HStack {
                            Text("Porcentaje Colaborador:")
                            Spacer()
                            Text("\(Int(collaboratorPercentage))%")
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.gold)
                        }
                    }
                    
                    Section(footer: Text("Al generar el acuerdo, se calculará un hash criptográfico SHA-256 inmutable vinculado a los usuarios.")) {
                        Button(action: {
                            guard !songTitle.isEmpty else { return }
                            onCreated(
                                songTitle,
                                genre,
                                creatorRole,
                                Int(creatorPercentage),
                                collaboratorRole,
                                Int(collaboratorPercentage)
                            )
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                Text("Generar y Firmar Split Sheet ✍️")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(AppColors.primary)
                        .disabled(songTitle.isEmpty)
                    }
                }
            }
            .navigationTitle("Nuevo Split Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

