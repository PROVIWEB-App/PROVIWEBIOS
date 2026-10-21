import Foundation
import SwiftUI
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Pages Service (RTDB esquema exacto de Android: nodo `Pages`)
//
// Réplica de Android:
//   CreatePageActivity.java:94-107  -> Pages/{pageId} + FollowPages (creación)
//   EditPagesActivity.java:183-189  -> updateChildren(name/username/bio/link) (edición)
//   PagesActivity.java:204-246      -> lectura de `Pages` filtrando `id == uid` ("mis páginas")
//   ModelPages.java                 -> CADA campo es String
//
//   Pages/{pageId} = { id, pId, name, bio, link, username, photo, cover, cat, verified }
//   OJO: `id` es el UID del DUEÑO (CreatePageActivity.java:96); `pId` = pageId.
//   pageId = String.valueOf(System.currentTimeMillis()) (CreatePageActivity.java:94,105)
//            => es un TIMESTAMP, NO una push key.
//   FollowPages/{uid}/{pageId}/{pageId} = true (CreatePageActivity.java:107).
//   No se implementa `Pages/{pageId}/Posts/...` (fuera de alcance de este módulo).
@MainActor
final class ArtistPagesService: ObservableObject {
    static let shared = ArtistPagesService()

    /// Páginas propias: `Pages` filtrado por `id == miUid` (PagesActivity.java:213-216).
    @Published private(set) var pages: [ArtistPageModel] = []

    private var rawPages: [String: [String: Any]] = [:]
    private var isStarted = false
    #if canImport(FirebaseDatabase)
    private var pagesObserver: (handle: DatabaseHandle, remove: () -> Void)?
    #endif

    private init() {}

    func ensureStarted() {
        guard !isStarted, FirebaseService.shared.canWriteToCloud else { return }
        isStarted = true
        #if canImport(FirebaseDatabase)
        observePages()
        #endif
    }

    #if canImport(FirebaseDatabase)
    private func observePages() {
        let ref = Database.database().reference().child("Pages")
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var next: [String: [String: Any]] = [:]
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    next[snap.key] = dict
                }
                self.rawPages = next
                self.rebuild()
            }
        }
        pagesObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }
    #endif

    private func rebuild() {
        guard let myUid = FirebaseService.shared.authenticatedUid else {
            pages = []
            return
        }
        // PagesActivity.java:213-216: "mis páginas" = `Pages/{key}/id == uid` (lectura global filtrada
        // en cliente; no existe índice `Pages` por uid).
        let mapped: [ArtistPageModel] = rawPages.compactMap { key, dict in
            guard ArtistPagesService.stringValue(dict["id"]) == myUid else { return nil }
            return ArtistPagesService.parsePage(pageId: key, dict: dict)
        }
        pages = mapped.sorted { ($0.pId) > ($1.pId) }
    }

    static func parsePage(pageId: String, dict: [String: Any]) -> ArtistPageModel {
        let cover = stringValue(dict["cover"]) ?? ""
        let photo = stringValue(dict["photo"]) ?? ""
        let coverImage: String? = {
            if !cover.isEmpty { return cover }
            return photo.isEmpty ? nil : photo
        }()
        return ArtistPageModel(
            id: pageId,                                     // clave del nodo `Pages` (timestamp)
            name: stringValue(dict["name"]) ?? "Página sin nombre",
            category: stringValue(dict["cat"]) ?? "",
            followers: 0,                                   // Android no guarda seguidores en `Pages`
            cover: coverImage,
            bio: stringValue(dict["bio"]) ?? "",
            username: stringValue(dict["username"]) ?? "",
            link: stringValue(dict["link"]) ?? "",
            ownerUid: stringValue(dict["id"]) ?? "",        // `Pages/{key}/id` = UID del dueño
            pId: stringValue(dict["pId"]) ?? pageId,
            isVerified: (stringValue(dict["verified"]) ?? "") == "yes"
        )
    }

    static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String { return value }
        if let value = raw as? NSNumber { return value.stringValue }
        return nil
    }

    /// Crea `Pages/{ts}` (pageId = timestamp, igual que CreatePageActivity.java:94-107) y
    /// `FollowPages/{uid}/{ts}/{ts} = true` en UNA sola escritura multi-ruta (atómica).
    func createPage(name: String, username: String, bio: String, link: String, cat: String) {
        #if canImport(FirebaseDatabase)
        guard FirebaseService.shared.canWriteToCloud,
              let uid = FirebaseService.shared.authenticatedUid else { return }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !username.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let ts = "\(Int(Date().timeIntervalSince1970 * 1000))"
        let page: [String: Any] = [
            "id": uid,            // UID del dueño (OJO: no es el pageId)
            "pId": ts,
            "name": name,
            "bio": bio,
            "link": link,
            "username": username,
            "photo": "",
            "cover": "",
            "cat": cat
            // `verified` no se escribe al crear (tampoco lo hace CreatePageActivity.java)
        ]
        var updates: [String: Any] = ["Pages/\(ts)": page]
        updates["FollowPages/\(uid)/\(ts)/\(ts)"] = true
        Database.database().reference().updateChildValues(updates)
        #endif
    }

    /// Edita `Pages/{pageId}` = EditPagesActivity.updatePageData:183-189 (name/username/bio/link),
    /// con la comprobación de unicidad de username de EditPagesActivity.java:160-180.
    func updatePage(pageId: String,
                    originalUsername: String,
                    name: String,
                    username: String,
                    bio: String,
                    link: String,
                    completion: @escaping (String?) -> Void) {
        #if canImport(FirebaseDatabase)
        guard FirebaseService.shared.canWriteToCloud else { completion(nil); return }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion("Introduce el nombre de la página"); return
        }
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion("Introduce un username"); return
        }
        let root = Database.database().reference()
        // EditPagesActivity.java:160: sólo consulta unicidad si el username cambió.
        if username == originalUsername {
            applyPageUpdate(root: root, pageId: pageId, name: name, username: username, bio: bio, link: link, completion: completion)
            return
        }
        root.child("Users").queryOrdered(byChild: "username").queryEqual(toValue: username)
            .observeSingleEvent(of: .value) { [weak self] snapshot in
                Task { @MainActor in
                    guard let self = self else { return }
                    if snapshot.childrenCount > 0 {
                        completion("Ese username ya existe, prueba con otro")
                        return
                    }
                    self.applyPageUpdate(root: root, pageId: pageId, name: name, username: username, bio: bio, link: link, completion: completion)
                }
            }
        #else
        completion(nil)
        #endif
    }

    #if canImport(FirebaseDatabase)
    private func applyPageUpdate(root: DatabaseReference,
                                 pageId: String,
                                 name: String,
                                 username: String,
                                 bio: String,
                                 link: String,
                                 completion: @escaping (String?) -> Void) {
        // Nunca `setValue` sobre el nodo completo: fusión de campos (EditPagesActivity.java:184-189).
        let values: [String: Any] = ["name": name, "username": username, "bio": bio, "link": link]
        root.child("Pages").child(pageId).updateChildValues(values) { error, _ in
            Task { @MainActor in
                completion(error?.localizedDescription)
            }
        }
    }
    #endif
}

// MARK: - Artist Pages & Ensemble Profiles View
public struct ArtistPagesView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var service = ArtistPagesService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isCreatePagePresented: Bool = false
    @State private var editingPage: ArtistPageModel? = nil

    /// `true` cuando la lista proviene del nodo `Pages` en la nube (sesión real).
    private let usesLivePages: Bool = FirebaseService.shared.canWriteToCloud

    /// Seed de demostración (sólo se muestra en modo demo, sin sesión real).
    private static let seedPages: [ArtistPageModel] = [
        ArtistPageModel(id: "p1", name: "Cuarteto de Cuerdas Bellas Artes", category: "Ensamble Clásico", followers: 1240, cover: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&auto=format&fit=crop&q=60"),
        ArtistPageModel(id: "p2", name: "Academia de Violín Contemporáneo", category: "Escuela de Música", followers: 3890, cover: "https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=800&auto=format&fit=crop&q=60")
    ]

    private var pages: [ArtistPageModel] { usesLivePages ? service.pages : ArtistPagesView.seedPages }

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

                        if pages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "rectangle.stack.badge.plus")
                                    .font(.system(size: 44))
                                    .foregroundColor(theme.textSecondary)
                                Text("Aún no tienes páginas de artista o ensamble.\nCrea la tuya con el botón de arriba.")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(theme.textSecondary)
                            }
                            .padding(.top, 48)
                            .padding(.horizontal, 24)
                        }

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

                                HStack(spacing: 6) {
                                    Text(page.name)
                                        .font(.headline)
                                        .foregroundColor(theme.textPrimary)

                                    if page.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption)
                                            .foregroundColor(AppColors.primary)
                                    }
                                }

                                if !page.bio.isEmpty {
                                    Text(page.bio)
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                        .lineLimit(2)
                                }

                                HStack {
                                    Text(page.category)
                                        .font(.caption)
                                        .foregroundColor(AppColors.primary)
                                    Spacer()
                                    if page.followers > 0 {
                                        Text("\(page.followers) seguidores")
                                            .font(.caption)
                                            .foregroundColor(theme.textSecondary)
                                    } else if !page.username.isEmpty {
                                        Text("@\(page.username)")
                                            .font(.caption)
                                            .foregroundColor(theme.textSecondary)
                                    }
                                }

                                if usesLivePages {
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            editingPage = page
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "pencil")
                                                Text("Editar")
                                            }
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(AppColors.primary.opacity(0.12))
                                            .cornerRadius(10)
                                        }
                                    }
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
            .sheet(item: $editingPage) { page in
                CreateArtistPageSheet(existing: page)
            }
            .onAppear {
                if usesLivePages { service.ensureStarted() }
            }
        }
    }
}

// Modelo local. OJO: en `Pages` de RTDB el campo `id` es el UID del dueño; aquí `id` guarda el
// pageId (clave del nodo) para que `Identifiable` sea único por página, y el uid va en `ownerUid`.
struct ArtistPageModel: Identifiable {
    let id: String
    let name: String
    let category: String
    let followers: Int
    let cover: String?
    var bio: String = ""
    var username: String = ""
    var link: String = ""
    var ownerUid: String = ""
    var pId: String = ""
    var isVerified: Bool = false
}

// MARK: - Create / Edit Artist Page Sheet
struct CreateArtistPageSheet: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var pageName: String
    @State private var username: String
    @State private var bio: String
    @State private var link: String
    @State private var category: String
    @State private var errorMessage: String = ""

    private let existingPageId: String?
    private let originalUsername: String

    init(existing: ArtistPageModel? = nil) {
        self.existingPageId = existing?.id
        self.originalUsername = existing?.username ?? ""
        _pageName = State(initialValue: existing?.name ?? "")
        _username = State(initialValue: existing?.username ?? "")
        _bio = State(initialValue: existing?.bio ?? "")
        _link = State(initialValue: existing?.link ?? "")
        _category = State(initialValue: existing?.category ?? "Mariachi")
    }

    private var isEditing: Bool { existingPageId != nil }

    private var canSave: Bool {
        !pageName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                Form {
                    Section(header: Text("Datos de la Página")) {
                        TextField("Nombre del Grupo o Artista", text: $pageName)
                        TextField("Username", text: $username)
                        TextField("Biografía", text: $bio)
                        TextField("Sitio web o red social (opcional)", text: $link)
                        // La categoría sólo se elige al crear; Android no la edita
                        // (EditPagesActivity.updatePageData sólo toca name/username/bio/link).
                        if !isEditing {
                            Picker("Categoría", selection: $category) {
                                Text("Mariachi").tag("Mariachi")
                                Text("Banda Sinaloense").tag("Banda")
                                Text("Cuarteto / Orquesta").tag("Orquesta")
                                Text("Profesor / Escuela").tag("Escuela")
                                Text("Solista").tag("Solista")
                            }
                        }
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(AppColors.errorRed)
                        }
                    }

                    Button(action: save) {
                        Text(isEditing ? "Guardar Cambios" : "Crear Página")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .disabled(!canSave)
                    .listRowBackground(canSave ? AppColors.primary : Color.gray)
                }
            }
            .navigationTitle(isEditing ? "Editar Página" : "Nueva Página")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        if let pageId = existingPageId {
            ArtistPagesService.shared.updatePage(
                pageId: pageId,
                originalUsername: originalUsername,
                name: pageName.trimmingCharacters(in: .whitespaces),
                username: username.trimmingCharacters(in: .whitespaces),
                bio: bio,
                link: link
            ) { error in
                if let error = error {
                    errorMessage = error
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } else {
            // En modo demo (sin sesión real) la escritura es un no-op protegido por `canWriteToCloud`.
            ArtistPagesService.shared.createPage(
                name: pageName.trimmingCharacters(in: .whitespaces),
                username: username.trimmingCharacters(in: .whitespaces),
                bio: bio,
                link: link,
                cat: category
            )
            presentationMode.wrappedValue.dismiss()
        }
    }
}
