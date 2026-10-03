import SwiftUI

// MARK: - Artist Pages & Ensemble Profiles View
public struct ArtistPagesView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isCreatePagePresented: Bool = false
    
    @State private var pages = [
        ArtistPageModel(id: "p1", name: "Cuarteto de Cuerdas Bellas Artes", category: "Ensamble Clásico", followers: 1240, cover: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&auto=format&fit=crop&q=60"),
        ArtistPageModel(id: "p2", name: "Academia de Violín Contemporáneo", category: "Escuela de Música", followers: 3890, cover: "https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=800&auto=format&fit=crop&q=60")
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        Button(action: {
                            isCreatePagePresented = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Crear Nueva Página de Artista o Ensamble")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.primary)
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        ForEach(pages) { page in
                            VStack(alignment: .leading, spacing: 10) {
                                if let cover = page.cover, let url = URL(string: cover) {
                                    AsyncImage(url: url) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Rectangle().fill(Color.gray.opacity(0.2))
                                    }
                                    .frame(height: 120)
                                    .cornerRadius(12)
                                    .clipped()
                                }
                                
                                Text(page.name)
                                    .font(.headline)
                                    .foregroundColor(theme.textPrimary)
                                
                                HStack {
                                    Text(page.category)
                                        .font(.caption)
                                        .foregroundColor(AppColors.primary)
                                    Spacer()
                                    Text("\(page.followers) seguidores")
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                            .padding(14)
                            .background(theme.cardColor)
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Páginas de Artista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $isCreatePagePresented) {
                CreateArtistPageSheet()
            }
        }
    }
}

struct ArtistPageModel: Identifiable {
    let id: String
    let name: String
    let category: String
    let followers: Int
    let cover: String?
}

struct CreateArtistPageSheet: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var pageName: String = ""
    @State private var category: String = "Mariachi"
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                Form {
                    Section(header: Text("Datos de la Página")) {
                        TextField("Nombre del Grupo o Artista", text: $pageName)
                        Picker("Categoría", selection: $category) {
                            Text("Mariachi").tag("Mariachi")
                            Text("Banda Sinaloense").tag("Banda")
                            Text("Cuarteto / Orquesta").tag("Orquesta")
                            Text("Profesor / Escuela").tag("Escuela")
                            Text("Solista").tag("Solista")
                        }
                    }
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Crear Página")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(AppColors.primary)
                }
            }
            .navigationTitle("Nueva Página")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
