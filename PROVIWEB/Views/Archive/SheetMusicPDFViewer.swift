import SwiftUI
import PDFKit

// MARK: - Native PDFKit Sheet Music Reader with Floating Metronome
public struct SheetMusicPDFViewer: View {
    public let score: SheetMusicItemModel
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var metronome = MetronomeService.shared
    @ObservedObject private var audioPlayer = AudioPlayerService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isMetronomeExpanded: Bool = false
    @State private var isBackingTrackPlaying: Bool = false
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 4
    
    public init(score: SheetMusicItemModel) {
        self.score = score
    }

    /// URL del PDF tolerante: si `pdfUrl` está vacío o mal formado no se produce un crash
    /// (el visor muestra un aviso en lugar de forzar un `URL` inválido).
    private var pdfDocumentURL: URL? {
        let raw = score.pdfUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Control Bar
                HStack {
                    Button(action: {
                        metronome.stop()
                        if isBackingTrackPlaying {
                            audioPlayer.pause()
                        }
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                            Text("Cerrar")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(score.title)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(score.composer) • \(score.keySignature)")
                            .font(.caption2)
                            .foregroundColor(Color.gray)
                    }
                    
                    Spacer()
                    
                    // Audio Backing Track Toggle
                    if let track = score.audioBackingTrackUrl {
                        Button(action: {
                            toggleBackingTrack(trackUrl: track)
                        }) {
                            Image(systemName: isBackingTrackPlaying ? "speaker.wave.3.fill" : "speaker.slash.fill")
                                .font(.title3)
                                .foregroundColor(isBackingTrackPlaying ? AppColors.gold : .white)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.85))
                
                // Native PDF Reader Canvas
                Group {
                    if let pdfDocumentURL = pdfDocumentURL {
                        PDFKitViewRepresentable(url: pdfDocumentURL)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 44))
                                .foregroundColor(Color.gray)
                            Text("Partitura no disponible")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Este documento no tiene un PDF asociado en el servidor.")
                                .font(.caption)
                                .foregroundColor(Color.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                    }
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Bottom Floating Metronome Bar
            VStack(spacing: 8) {
                if isMetronomeExpanded {
                    HStack(spacing: 16) {
                        Button(action: { if metronome.bpm > 40 { metronome.bpm -= 2 } }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(metronome.bpm) },
                            set: { metronome.bpm = Int($0) }
                        ), in: 40...240, step: 1)
                        .accentColor(AppColors.primary)
                        
                        Button(action: { if metronome.bpm < 240 { metronome.bpm += 2 } }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                HStack(spacing: 14) {
                    Button(action: {
                        withAnimation { isMetronomeExpanded.toggle() }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "metronome")
                                .foregroundColor(AppColors.primary)
                            Text("\(metronome.bpm) BPM")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Visual Beat Flash Dots
                    HStack(spacing: 8) {
                        ForEach(1...metronome.timeSignatureBeats, id: \.self) { beat in
                            Circle()
                                .fill(metronome.currentBeat == beat && metronome.isRunning ? AppColors.primary : Color.gray.opacity(0.4))
                                .frame(width: 10, height: 10)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        metronome.toggle()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: metronome.isRunning ? "stop.fill" : "play.fill")
                            Text(metronome.isRunning ? "Detener" : "Iniciar")
                                .fontWeight(.bold)
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(metronome.isRunning ? AppColors.errorRed : AppColors.primary)
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.15))
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: -2)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .onAppear {
            metronome.bpm = score.tempoBpm
        }
    }
    
    private func toggleBackingTrack(trackUrl: String) {
        if isBackingTrackPlaying {
            audioPlayer.pause()
            isBackingTrackPlaying = false
        } else {
            let song = SongModel(title: "Acompañamiento - \(score.title)", artist: score.composer, audioUrl: trackUrl)
            audioPlayer.playSong(song)
            isBackingTrackPlaying = true
        }
    }
}

// MARK: - UIViewRepresentable for PDFKit PDFView
struct PDFKitViewRepresentable: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor.systemBackground
        
        // Attempt to load asynchronously or fallback to sample document
        DispatchQueue.global(qos: .userInitiated).async {
            if let document = PDFDocument(url: url) {
                DispatchQueue.main.async {
                    pdfView.document = document
                }
            } else {
                // If remote url is unreachable, create an empty score preview document
                DispatchQueue.main.async {
                    let fallbackDoc = PDFDocument()
                    pdfView.document = fallbackDoc
                }
            }
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
