import SwiftUI
import AVKit

// MARK: - Video Series & Course Masterclass Player (ViewSerieActivity.java equivalent)
public struct VideoSeriesPlayerView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedEpisodeIndex: Int = 0
    @State private var episodes = [
        SeriesEpisodeModel(id: "ep1", number: 1, title: "Fundamentos de la Postura del Violín", duration: "12:45", videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", isCompleted: true),
        SeriesEpisodeModel(id: "ep2", number: 2, title: "Agarre del Arco y Distribución de Peso", duration: "15:20", videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4", isCompleted: true),
        SeriesEpisodeModel(id: "ep3", number: 3, title: "Afinación en Primera Posición", duration: "18:10", videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4", isCompleted: false),
        SeriesEpisodeModel(id: "ep4", number: 4, title: "Cambios de Posición a 3ra y 5ta", duration: "21:30", videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4", isCompleted: false)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Video Player Area
                    let currentEp = episodes[selectedEpisodeIndex]
                    if let url = URL(string: currentEp.videoUrl) {
                        VideoPlayer(player: AVPlayer(url: url))
                            .frame(height: 230)
                            .background(Color.black)
                    }
                    
                    // Current Episode Info
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Episodio \(currentEp.number) de \(episodes.count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                            
                            Spacer()
                            
                            Text(currentEp.duration)
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                        }
                        
                        Text(currentEp.title)
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(16)
                    .background(theme.cardColor)
                    
                    // Episodes List
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Capítulos del Curso")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            
                            ForEach(0..<episodes.count, id: \.self) { idx in
                                let ep = episodes[idx]
                                Button(action: {
                                    selectedEpisodeIndex = idx
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedEpisodeIndex == idx ? AppColors.primary : Color.gray.opacity(0.2))
                                                .frame(width: 36, height: 36)
                                            
                                            Text("\(ep.number)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(selectedEpisodeIndex == idx ? .white : theme.textPrimary)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ep.title)
                                                .font(.subheadline)
                                                .fontWeight(selectedEpisodeIndex == idx ? .bold : .regular)
                                                .foregroundColor(theme.textPrimary)
                                                .multilineTextAlignment(.leading)
                                            
                                            Text(ep.duration)
                                                .font(.caption2)
                                                .foregroundColor(theme.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if ep.isCompleted {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(AppColors.success)
                                        }
                                    }
                                    .padding(12)
                                    .background(selectedEpisodeIndex == idx ? AppColors.primary.opacity(0.1) : theme.cardColor)
                                    .cornerRadius(14)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Serie Masterclass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

struct SeriesEpisodeModel: Identifiable {
    let id: String
    let number: Int
    let title: String
    let duration: String
    let videoUrl: String
    let isCompleted: Bool
}
