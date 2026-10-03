import SwiftUI

// MARK: - Masterclass & Live Video Meeting Room View
public struct LiveMeetingRoomView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var roomIdText: String = ""
    @State private var isInMeeting: Bool = false
    @State private var isMuted: Bool = false
    @State private var isVideoOn: Bool = true
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                if !isInMeeting {
                    VStack(spacing: 24) {
                        Image(systemName: "video.bubble.left.fill")
                            .font(.system(size: 64))
                            .foregroundColor(AppColors.primary)
                            .padding(.top, 40)
                        
                        Text("Salas de Masterclass y Reuniones")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.textPrimary)
                        
                        Text("Conéctate con profesores y ensambles para clases grupales en vivo y ensayos remotos.")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        VStack(spacing: 12) {
                            TextField("ID o Código de la Sala", text: $roomIdText)
                                .padding(14)
                                .background(theme.cardColor)
                                .cornerRadius(14)
                                .padding(.horizontal, 24)
                            
                            Button(action: {
                                if !roomIdText.isEmpty {
                                    isInMeeting = true
                                }
                            }) {
                                Text("Unirse a la Sala")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppColors.primary)
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        Spacer()
                    }
                } else {
                    // Active Video Meeting Room UI
                    VStack {
                        // Participant Video Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MeetingVideoTile(name: "Israel Violín (Tú)", isMuted: isMuted, color: Color.blue.opacity(0.4))
                            MeetingVideoTile(name: "Profesor Juan Pérez", isMuted: false, color: Color.purple.opacity(0.4))
                        }
                        .padding(16)
                        
                        Spacer()
                        
                        // Meeting Controls Bar
                        HStack(spacing: 24) {
                            Button(action: { isMuted.toggle() }) {
                                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(isMuted ? AppColors.errorRed : Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: { isVideoOn.toggle() }) {
                                Image(systemName: isVideoOn ? "video.fill" : "video.slash.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(isVideoOn ? Color.white.opacity(0.2) : AppColors.errorRed)
                                    .clipShape(Circle())
                            }
                            
                            Button(action: { isInMeeting = false }) {
                                Image(systemName: "phone.down.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(18)
                                    .background(AppColors.errorRed)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.bottom, 36)
                    }
                    .background(Color.black.ignoresSafeArea())
                }
            }
            .navigationTitle("Reunión / Masterclass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

struct MeetingVideoTile: View {
    let name: String
    let isMuted: Bool
    let color: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(color)
            .frame(height: 220)
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Text(name)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                        if isMuted {
                            Image(systemName: "mic.slash.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(8)
                }
            )
    }
}
