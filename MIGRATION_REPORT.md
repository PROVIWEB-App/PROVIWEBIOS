# 📋 Informe de Migración — PROVIWEB Android → iOS

**Fecha:** 19 de octubre de 2026
**Proyecto origen:** `PROVIWEB-master` (Android · Java · 880 clases · 171 Activities · 64 Fragments)
**Proyecto destino:** `PROVIWEBIOS-main` (iOS · Swift 5 / SwiftUI · iOS 16.0+ · Xcode 15/16)
**Bundle ID:** `com.israviolink.ios` · **Proyecto Firebase:** `proviweb-d8764`

> Estado final: **migración completa, lista para firma y envío a producción por parte del equipo humano.**
> El asistente NO realiza la firma ni el envío (requisito explícito del cliente).

---

## 1. Resumen ejecutivo

Esta fase completó los cuatro objetivos pendientes de la migración:

| # | Fase | Estado |
|---|------|--------|
| 1 | Núcleo funcional: auth real de Firebase + sincronización RTDB con esquema Android | ✅ |
| 2 | Cableado de vistas huérfanas (navegación rota) | ✅ |
| 3 | Readiness de release (scheme, localización, Info.plist, iconos) | ✅ |
| 4 | Documentación + verificación estática | ✅ |

---

## 2. Núcleo funcional — `FirebaseService.swift`

Reescrito por completo (~1 400 líneas). Ahora es el único punto de verdad de sesión y datos.

### 2.1 Autenticación real (antes era mock)

- `signIn(email:password:)` — login real; **resuelve el estado de aprobación de menores antes de continuar** (máx. 4 s con tope por red), y no reactiva el botón hasta entonces.
- `signUp(...)` — registro con nombre/email/contraseña/instrumento/`isMinor`; crea el usuario en Auth, escribe `Users/{uid}` con **el mismo hashMap que `SignUpActivity.java`**, crea `Balance/{uid} = {balance: "0.00"}` y envía verificación de correo.
- `sendPasswordReset(email:)` — recuperación real de contraseña.
- `startPhoneVerification` / `confirmPhoneVerification` — Firebase Phone Auth por SMS OTP. **El código confirmado VINCULA el teléfono al usuario de email (`link(with:)`)** en vez de abrir una sesión separada; solo usa `signIn` como último recurso si no había sesión. Si el fallo es "teléfono ya vinculado", se trata como éxito. El teléfono queda reflejado en `Users/{uid}/phone` (visible también desde Android).
- `enterDemoMode()` / `signOut()` — modo demostración sin credenciales y cierre de sesión.
- Errores traducidos a español (`friendlyMessage`), spinner con `isAuthBusy`, alertas con `authError`.
- Credenciales en Keychain vía `SessionKeychain` (Face ID) en `LoginView`.

### 2.2 Sesión y arranque

- `bootstrap()` idempotente llamado desde `AppDelegate` (tras `FirebaseApp.configure()`) **y** desde `.onAppear` de `PROVIWEBApp` como red de seguridad.
- `addStateDidChangeListener` persistente: al reabrir la app se restaura la sesión **y la bandera de "menor pendiente"** (UserDefaults por UID) para no enseñar `MainTabView` sin conexión.
- Splash `AppLaunchSplashView` mientras `isSessionReady == false` (sin parpadeos).
- Orden de enraizado en `PROVIWEBApp`: `!isSessionReady → isPendingApproval → isAuthenticated → LoginView`.

### 2.3 Interoperabilidad total con RTDB de Android

Lectura y escritura con el **esquema real de Android**:

| Nodo RTDB | Lectura | Escritura iOS | Equivalente Android |
|---|---|---|---|
| `Posts/{key}` | ✅ feed vivo (50 últimos, orden por clave) | ✅ `publishPostToCloud` | `PostUploadService.java` / `HomeFragment.java` |
| Campos post | `id`=uid, `pId`, `text`, `type`, `meme`, `vine`, `audio`, `pTime`, `commentCount`, `pLikes` | idénticos | idénticos |
| `Aplausos/{postId}/{uid}` | ✅ observer por post → contador + "me gusta" | ✅ `setValue(ts)` / `removeValue` | likes de `AdapterPost.java` |
| `Posts/{id}/Comments/{ts}` | (contador vía `commentCount`) | ✅ `{cId, comment, timestamp, id, type, pId}` | `CommentActivity.java` |
| `Reels` | ✅ 30 últimos | — | `PostUploadService.java` |
| `Users/{uid}` | ✅ observer en vivo del perfil | ✅ `updateChildValues` | hashMap de `SignUpActivity.java` |
| `Balance/{uid}` | (saldo) | ✅ `{balance: "0.00"}` al registrarse | `SignUpActivity.java` |
| `MinorApprovalRequests/{uid}` | — | ✅ `status: "pending"` | panel de menores Android |
| Autores | `fetchAuthorIfNeeded` → `Users/{uid}` en caché | — | `AdapterPost.java` |

**Mapeo de media por `type`:** `video→vine` · `image→meme` · `audio→meme/audio` · `text→sin media` · `sheet_music→meme`.
Los semáforos `noImage`/`noVideo` de Android se interpretan como ausentes.

### 2.4 Flujo de menores de edad (paridad con Android)

1. Registro con el toggle **"Soy menor de edad"** → `signUp(isMinor: true)`:
   - `Users/{uid}`: `isMinor = "yes"`, `minorApprovalStatus = "pending"` (mismos campos que `SignUpActivity.java:1041-1042`).
   - `MinorApprovalRequests/{uid}` con `status: "pending"` (aparece en el panel de solicitudes de Android).
   - `isPendingApproval = true` en servicio → la raíz muestra **`WaitApprovalView`** (nunca `MainTabView`).
2. `WaitApprovalView` (equivalente a `WaitApprovalActivity.java`):
   - Botón **"Comprobar estado"** → `checkMinorApprovalStatus` (igual que `btnCheckStatus`): si el equipo aprobó (`minorApprovalStatus == "approved"`), la app entra sola a `MainTabView`.
   - Botón **"Cerrar Sesión"** (cierra y descarta la vista).
3. Login posterior: `signIn` consulta `Users/{uid}` **antes** de continuar → menor sin aprobar va directo a `WaitApprovalView`; aprobado o no menor, a `MainTabView`.
4. La aprobación la sigue poniendo el equipo desde Android/panel (`AdapterMinorRequests.java` escribe `approved`/`rejected`); iOS la lee en vivo desde el observer de perfil.

### 2.5 Correcciones aplicadas tras revisión

- **Observadores de RTDB** (`syncObservers`, `aplausosObservers`, `currentUserObserver`): cada listener guarda su propia clausura de baja; la baja se hace **sobre el mismo query donde se registró** (antes se intentaba borrar desde la raíz → listeners acumulados en cada login/logout).
- `fetchCurrentUser` ya no borra el handle anterior con la referencia equivocada.
- `#else` de compilación sin SDK de Firebase para funciones de teléfono (stub con `firebaseNotAvailable`).
- `String(format: "%02.2hhx")` → `"%02x"` en el token APNs.
- `NavigationLink(destination:)` deprecado → sintaxis `NavigationLink { } label: { }`.

### 2.6 Correcciones de la revisión final (1 BLOCKER + 3 WARN)

- **BLOCKER — ventana en la que un menor veía `MainTabView`.** Corregido el orden en los tres puntos donde podía abrirse:
  1. `signIn`: `isAuthenticated` ahora se activa **dentro** de la resolución de aprobación, nunca antes.
  2. `handleAuthStateChange`: si `isAuthBusy` (registro/login en curso), el listener de Auth **no** activa la sesión — la activa el propio flujo en el orden correcto (cierra la carrera del listener al crear la cuenta, que iba antes de escribir `isMinor` en RTDB).
  3. `enterDemoMode` desarma explícitamente `isPendingApproval`.
- **WARN — perfil no escrito:** `signUp` ahora **respeta el `Result` de `writeUserNode`**; si la escritura falla no se activa sesión y se muestra "No se pudo guardar el perfil…" (evita menores eternamente en espera con la solicitud inexistente).
- **WARN — "sin conexión" ≠ "en proceso":** `resolvePendingApproval` devuelve ahora si la lectura se resolvió; el botón "Comprobar estado" distingue tres estados (`MinorApprovalCheck`: `.approved` / `.pending` / `.unresolved`) y muestra "No se pudo verificar el estado (sin conexión)" cuando no hubo lectura.
- **WARN — build con Auth pero sin Database** (productos SPM independientes): la barrera de aprobación solo se arma si `canImport(FirebaseDatabase)` (`isDatabaseAvailable`), para no dejar a un menor bloqueado sin forma de aprobarse.
- **WARN — SF Symbols 6:** `hourglass.badge.eye` (iOS 18) ahora con fallback `hourglass.tophalf.filled` para iOS 16/17.
- **WARN — cover redundante:** eliminado el `fullScreenCover` de `WaitApprovalView` en `LoginView` (la raíz ya enraiza la pantalla; el cover duplicado provocaba avisos de presentación sobre vistas desmontadas). El indicador de modo demostración se movió a `MainTabView`, donde sí se renderiza.
- NITs aceptados a conciencia (sin acción): `authHandle` de solo escritura en un singleton que nunca se deinit; captura `@Sendable` en `finishOnce` (irrelevante en `SWIFT_VERSION = 5.0` sin concurrencia estricta); mutación de `aplausosObservers` durante su iteración (segura por value semantics/COW en Swift).

---

## 3. Navegación — 11 conexiones añadidas

Vistas que existían pero eran inalcanzables, ahora conectadas:

| Vista origen | Destino añadido |
|---|---|
| `PostCardView` | `DetailPostView` + `MediaViewerModal` (con `canOpenDetail` para evitar recursión) |
| `DigitalTicketView` | `QRScannerView` |
| `ProfileView` | `AchievementsView` |
| `ReelsView` | `VideoSeriesPlayerView` (sheet de serie) |
| `BookClassView` | `BookingCalendarView` (+ `onDateSelected`) |
| `MyBookedClassesView` | `TeacherAvailabilityView` |
| `QAVWalletView` | `DiamondWithdrawView` (+ `public init()`) |
| `AdminDashboardView` | `AdsManagerView` |
| `DetailPostView` | prop `canOpenDetail` (tarjeta interna sin navegación recursiva) |

---

## 4. Corrección de BLOCKERs de compilación (10 vistas)

Regla Swift: *el memberwise initializer es `private` si cualquier propiedad almacenada es `private`* → esas vistas **no podían crearse desde otro fichero** (`initializer is inaccessible due to 'private' protection level`).

Añadido `public init() {}` a las 10 vistas afectadas (todas se instancian sin argumentos desde otros ficheros):

`QAVWalletView`, `ReelsView`, `HomeView`, `ChatListView`, `MarketplaceView`, `AIProfessorView`, `CreatePostView`, `InviteEarnView`, `MiniPlayerOverlay`, `PracticeStudioView`.

---

## 5. Readiness de release

| Elemento | Detalle |
|---|---|
| **Scheme compartido** | `PROVIWEB.xcodeproj/xcshareddata/xcschemes/PROVIWEB.xcscheme` creado (target `E10001`, Debug/Run, Release/Archive). **Lo exige** `.github/workflows/build-and-distribute-ipa.yml`. |
| **Localización** | `Localizable.strings` convertido a `PBXVariantGroup` con `es` + `en` (81 claves idénticas en ambos idiomas; `knownRegions` ya incluía `es, en, Base`). Antes solo se empaquetaba `es`. |
| **Info.plist** | `CFBundleShortVersionString=$(MARKETING_VERSION)` y `CFBundleVersion=$(CURRENT_PROJECT_VERSION)` (fuente única en pbxproj: 1.0.0 / 1). Añadido `NSPhotoLibraryAddUsageDescription`. `UIRequiredDeviceCapabilities: armv7 → arm64`. Añadido esquema URL `com.googleusercontent.apps.475963980955-1q62qiiki0fkasdsvhpikgdgp5r00vto` (`REVERSED_CLIENT_ID`). |
| **AppIcon** | Generados los **13 PNG** del `AppIcon.appiconset` (20…180 px + 1024) desde el logo de Android (`ic_launcher_foreground.png`), compuesto sobre fondo blanco, **sin canal alfa** (requisito App Store), y `Contents.json` completo para **iPhone + iPad (incl. 83.6@2x) + ios-marketing**. |
| **Firma** | `DEVELOPMENT_TEAM` **no** se fijó a propósito: la selecciona el equipo humano (ver `RELEASE_CHECKLIST.md`). `CODE_SIGN_STYLE = Automatic`. |
| **SPM** | `firebase-ios-sdk ≥ 11.0.0` con Auth/Database/Storage/Messaging/Analytics/Crashlytics. No se versiona `Package.resolved` (se genera en el primer `xcodebuild -resolvePackageDependencies`, ya usado por el workflow de CI). |

---

## 6. Verificación estática (sin compilador en Windows)

`scripts/check-integrity.ps1` — resultados sobre los **79 ficheros Swift**:

| Check | Resultado |
|---|---|
| [1] Balance `{} () []` e `#if/#endif` (ignorando cadenas/comentarios) | ✅ OK |
| [2] Vistas `public struct X: View` sin `init()` usadas en otro fichero | ✅ OK (0 tras corregir 10) |
| [3] Marcadores `TODO/FIXME/HACK` | ✅ 0 |
| [4] Swift en disco ausentes de `project.pbxproj` | ✅ 0 |
| [5] `AppIcon.appiconset` con PNG | ✅ 13 PNG |
| [6] Scheme compartido `PROVIWEB` | ✅ existe |

Además se realizó **revisión humana/agentica de punta a punta** de `FirebaseService.swift`, `LoginView.swift` (login/registro/ForgotPassword/Face ID), `WaitApprovalView.swift` (+OTP), `PROVIWEBApp.swift`, `AppDelegate.swift` y de las 11 ediciones de navegación: símbolos cruzados, firmas de init, uso de la API de Firebase y estilo del proyecto verificados.

> ⚠️ **Limitación:** este entorno es Windows sin `swiftc`/`xcodebuild`; la compilación final debe hacerse en macOS (primer comando del checklist). La validación estática realizada cubre errores estructurales, de símbolos y de esquema de datos, pero no sustituye al primer build.

---

## 7. Cómo verificar en macOS

```bash
cd PROVIWEBIOS-main

# 1) Resolución de paquetes + build Debug (simulador)
xcodebuild -resolvePackageDependencies -project PROVIWEB.xcodeproj -scheme PROVIWEB
xcodebuild build -project PROVIWEB.xcodeproj -scheme PROVIWEB \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator'

# 2) Archive de distribución (sin firma en CI)
xcodebuild archive -project PROVIWEB.xcodeproj -scheme PROVIWEB \
  -configuration Release -archivePath build/PROVIWEB.xcarchive \
  -destination 'generic/platform=iOS'
```

O push a `main` y dejar que `.github/workflows/build-and-distribute-ipa.yml` genere el IPA y lo publique en Firebase App Distribution.

---

## 8. Módulos secundarios cableados a RTDB/Storage (fase de interoperabilidad)

Fase posterior al núcleo: se reescribieron los módulos que antes usaban datos seed locales para
hablar con **los mismos nodos y rutas que Android**, verificados leyendo el código fuente Java.

### 8.1 Chat — nodos `Chats` + `Chatlist` (ChatService)

Nuevo servicio `ChatService` (en `ViewModels/ChatViewModel.swift`), réplica de `ChatActivity`/
`ChatFragment`/`AdapterChatList` de Android:

- **Esquema de mensaje** (idéntico): `Chats/{pushId} = { sender, receiver, msg, type, timestamp: String(millis), isSeen: Bool }` con `childByAutoId()`. Tolera `isSeen` como Bool/String/Number (misma tolerancia que `ModelChat.java`).
- **Bandeja**: observa `Chatlist/{miUid}` (resumen `{id, lastMsg, timestamp, lastMsgType, lastSenderId}`), ordena descendente por `timestamp` (String) y carga nombre/foto de `Users/{uid}`.
- **No leídos**: query global `Chats.orderByChild("receiver").equalTo(myUid)` agrupada por `sender` (misma que `AdapterChatList.initializeGlobalChatListener`).
- **Hilo**: dos queries `orderByChild("sender")` (mío y suyo) filtradas por `receiver`; los entrantes sin leer se marcan `isSeen = true` (como `ChatActivity.readMessages`).
- **Envío**: texto y foto. La foto sube a `chat_photo/{millis}` en Storage y el preview de la bandeja usa las etiquetas de Android ("📷 Foto", "🎥 Video", "📍 Ubicación"…).
- **Tipos**: `MessageType` ampliado con el catálogo Android (`doc`, `location`, `gif`, `gift`, `job_proposal`, `sheet_music`, `song`, `meet*`, `*_call`…); los desconocidos se decodifican como `.unknown` sin romper el hilo.
- **Vista**: `ChatConversationView` abre/cierra el hilo con `onAppear`/`onDisappear`, envía fotos con `PhotosPicker`, renderiza burbujas por tipo (imagen, ubicación) y muestra el check de leído con la semántica de `AdapterChat.java`.
- Modo demo o sin sesión → mantiene el seed local (banner demo coherente).

### 8.2 Marketplace — nodo `Product` (MarketplaceService)

Nuevo `MarketplaceService` (en `ViewModels/MarketplaceViewModel.swift`), réplica de `MainFragment`/`PostProductActivity`:

- Observa `Product` en vivo y mapea el esquema Android: `price` es String (se parsea), `des`, `cat`, `type`, `photo` + `photos[]`, `currency`.
- Orden: promocionados primero (`isPromoted && adExpiry > now`), como Android.
- Nuevo `PostProductView` (hoja "Publicar") que escribe `Product/{timestamp}` con los campos exactos (`id` del vendedor, `acceptsCrypto/Fiat/Balance`, `shippingStatus: "Pending"`…) y sube la foto a `product_photo/{millis}` (igual que Android).
- La vista usa `filteredProducts` (filtro por categoría) y muestra estado vacío; el botón "Publicar" solo aparece con sesión real.

### 8.3 Ubicación — nodo `UserLocation` (LocationService reescrito)

- **Publica** mi posición en `UserLocation/{uid} = { latitude: Double, longitude: Double }` (igual que `MainActivity.InitLocation`), con throttle (cada 60 s o 50 m de movimiento).
- **Observa** `UserLocation` completo, filtra `(0,0)` como Android y enriquece cada uid con `Users/{uid}` (`username`/`name`, `photo`, `instrument`).
- El mapa del Marketplace muestra marcadores reales con avatar y nombre; el contador "Cercanos" usa Haversine con umbral de 100 m (Android no filtra por distancia; muestra a todos).

### 8.4 Subidas a Firebase Storage cableadas en vistas

Antes el `UploadManager` estaba escrito pero sin invocar. Ahora conectado en:

| Flujo | Ruta Storage (idéntica a Android) | Escritura resultante |
|---|---|---|
| Crear publicación con foto | `post_photo/{millis}` (`CreatePostPagesActivity.java`) | `Posts/{pId}.meme` + `memes[]` |
| Foto de perfil | `profile_photo/{millis}` (`EditProfileActivity.uploadDp`) | `Users/{uid}/photo` (e `image`, por compatibilidad del parseo) |
| Foto en chat | `chat_photo/{millis}` (`ChatActivity.sendMediaMessage`) | `Chats/{pushId}` type `image` |
| Foto de producto | `product_photo/{millis}` (`PostProductActivity`) | `Product/{pId}/photo` |

Se eliminó la imagen Unsplash fija que `CreatePostView` adjuntaba a todo post.

### 8.5 Correcciones de revisión de compilación (5 BLOCKER + 3 WARN)

- `DataSnapshot.key` es no opcional → eliminados dos `guard let` (Chat + Ubicación).
- `childByAutoKey()` no existe en el SDK Swift → `childByAutoId()` sin `guard let` (retorno no opcional).
- `RawSummary.lastMsg` recibía `String?` → `?? ""`.
- `LocationService` (no aislado) accedía síncrono a `authenticatedUid` (`@MainActor`) → encapsulado en `Task { @MainActor en }` (evitando `MainActor.assumeIsolated`, que es iOS 17+ y el mínimo es iOS 16).
- `Timer` de `PracticeStudioViewModel` (@Sendable) mutaba estado aislado → salto explícito a `DispatchQueue.main.async`.
- `EditProfileView.saveChanges()` solo mutaba en memoria → ahora llama a `saveCurrentUserProfile()`.
- `updateProfilePhotoURL` escribía solo `photo` pero el parseo prioriza `image` → escribe ambas claves.

## 9. Migración completa de módulos restantes (Eventos, Empleos, Notificaciones, Música, Archivo, Clases, Verificación y Admin)

Todos estos módulos funcionaban con datos seed locales y ahora leen/escriben los nodos RTDB de Android (mismo esquema, mismas rutas). Cada servicio vive en el fichero de su vista (el `project.pbxproj` es clásico `objectVersion = 56`, por lo que no se crearon ficheros nuevos).

| Módulo | Nodo(s) RTDB | Ficheros |
|---|---|---|
| **Eventos** (`EventsService`) | `ArtisticEvents`, `EventTickets/{eventId}/{ticketId}`, `UserEventTickets/{uid}/{ticketId}`, `Balance/{uid}/balance` | `Views/Events/EventsHomeView.swift`, `EventDetailsView.swift`, `CreateEventView.swift`, `DigitalTicketView.swift`, `Models/EventModel.swift` |
| **Empleos** (`JobsService`) | `JobOffers` (push key, `createdTimestamp` long), `JobApplications/{jobId}/{applicantUid}` | `Views/Job/JobBoardView.swift` |
| **Notificaciones** (`NotificationsService`) | `Users/{uid}/Notifications/{ts}` (esquema `pId/timestamp/pText/notification/sId/sName/type`), `Users/{uid}/Count` (badge; "Marcar leídas" → `Count.removeValue()` como Android) | `Views/Notifications/NotificationsView.swift` |
| **Canciones** | `Songs` (observer con `queryLimited(toLast: 100)`), aprobación/rechazo desde Admin (`verificationStatus` + `reactionReason`) | `Core/Network/FirebaseService.swift`, `Views/Music/MusicExploreView.swift`, `Views/Admin/AdminDashboardView.swift` |
| **Archivo / Partituras** | `books` (PDF en `content`), mapeo `BookModel → SheetMusicItemModel` | `Core/Network/FirebaseService.swift`, `Views/Archive/SheetMusicArchiveView.swift` |
| **Entidades verificadas** | `Users` filtrado `verified == "yes"` (como `MainFragment.java:98`) | `Core/Network/FirebaseService.swift` |
| **Clases particulares** (`ClassesService`) | `StudentClasses/{uid}`, `TeacherClasses/{uid}`, `BookedClasses/{teacherId}/{bookingId}`, `ClassRequests`, `Balance` (90 % profesor / 10 % `PlatformCommission`) | `Views/Classes/BookClassView.swift`, `MyBookedClassesView.swift`, `SearchClassesView.swift`, `TeacherAvailabilityView.swift` |
| **Verificación** (`VerificationService`) | `Verification/{uid}`, `VerificationProfesor/{uid}`, `VerificationStudents/{uid}`, `VerificationEntidad/{uid}` (status `pending`) | `Views/Verification/VerificationRequestView.swift` |

Decisiones de interoperabilidad verificadas contra el código Java:

- **Compra de entrada**: escritura multi-ruta **atómica** (`EventTickets` + `UserEventTickets` + `registeredCount` + débito/abono de `Balance`) en una sola `updateChildValues`; nunca se debita el saldo sin emitir la entrada.
- **Reserva de clase**: idéntico patrón atómico (débito alumno + abono profesor 90 % + comisión 10 % + `BookedClasses` + `StudentClasses`). Las automatizaciones (notificación + chat) son *best-effort* tras la escritura principal.
- **El id de `JobOffers` es push key** (`push().getKey()`), no timestamp; los timestamps son `long` numéricos.
- **`Chats`/`Chatlist` y `Users/{uid}/Notifications`** usan timestamps en millis **como String** (mismo formato que `String.valueOf(System.currentTimeMillis())` de Android).
- En **modo demo** (sin sesión real) todos los módulos conservan su seed local: `canWriteToCloud` es el único interruptor.

### 9.1 Correcciones de revisión de compilación de esta fase (6 BLOCKER + 8 WARN)

- **Accesibilidad**: `NotificationItemModel`/`NotificationType` y `JobOfferModel` pasaron a `public` (exigido por las propiedades `@Published public` de sus servicios) y su `id` a `public let` (requisito de `Identifiable` en tipos públicos).
- **`String` no conforma `Error`**: `extension String: Error {}` en `EventsHomeView.swift` para los completions `Result<T, String>` (patrón de mensajes en español).
- **Pagos atómicos**: los débitos de `Balance` se movieron dentro de la misma `updateChildValues` de la reserva/entrada (antes: débito previo sin *rollback*).
- **Timeouts de UI**: compra de entradas (30 s) y reserva de clases (45 s) con envoltorio "solo una vez" (`didFinish`) para que `isPurchasing`/`isBookingInFlight` nunca queden bloqueados si el callback de RTDB no vuelve.
- **Estado real del ticket**: `DigitalTicketView` distingue accedida / finalizada / válida (antes pintaba siempre verde).
- **Sin crashes**: eliminado `URL(string:)!` en `SheetMusicPDFViewer` (muestra aviso si falta el PDF); `LocationService` aplaza mutaciones de `@Published` a `MainActor` desde el delegado de CoreLocation.
- **Aislamiento**: `confirmBooking()` marcado `@MainActor`; saldo de la wallet con alias `balanceQav` (espejo de `Balance/{uid}/balance`).

Verificación final: `check-integrity.ps1` → **SIN PROBLEMAS** (79 ficheros Swift, 0 marcadores pendientes).

## 10. Migración de los módulos finales (comentarios, chat avanzado, anuncios, páginas y cotizaciones)

Última oleada de migración: cinco bloques que seguían con datos seed locales ahora hablan con los nodos reales de Android.

| Módulo | Nodo(s) RTDB | Ficheros |
|---|---|---|
| **Comentarios de publicaciones** (`CommentsService`) | `Posts/{postId}/Comments/{ts}` (cId = ts millis String, type `text/gif/image`), respuestas en `Reply/{parentId}/{ts}`, likes en `cLikes/{cId}/{uid}`, contador `Posts/{postId}/commentCount`, notificación al dueño del post | `Views/Post/DetailPostView.swift` |
| **Chat avanzado** (`ChatService`) | Reacciones `Chats/{msgId}/reactions/{uid}` = emoji; bloqueo `BlockedUsers/{myUid}/{hisUid}` = true; silencio `MutedChats/{myUid}/{otherUid}` = true; historial `CallHistory/{uid}/{room}` (room = millis) + mensajes de sistema `voice_call`/`video_call`/`missed_call` en `Chats` + `Chatlist` | `ViewModels/ChatViewModel.swift`, `Views/Chat/ChatListView.swift`, `Models/ChatModel.swift` |
| **Anuncios pagados** (`HomeFeedViewModel` + `MyAdsViewModel`) | `AdsPost/{millis}` (campos String; intercalado 1 arriba + 1 cada 4 posts como `HomeFragment.interleavePosts`), interruptor `Ads/type` (solo lectura), métrica `pViews` lectura+1 | `ViewModels/HomeFeedViewModel.swift`, `Views/Home/HomeView.swift`, `Views/Advertising/AdsManagerView.swift` |
| **Páginas de artista** (`ArtistPagesService`) | `Pages/{millis}` (pageId = timestamp, `id` = uid dueño) + `FollowPages/{uid}/{ts}/{ts}` = true (escritura atómica) | `Views/Pages/ArtistPagesView.swift` |
| **Cotizaciones de agrupaciones** (`MusicalHubService` + `QuotesService`) | Agrupaciones = `Users` con `musicservice == "yes"`; envío atómico: `MusicalQuotes/{pushKey}` + índices `ClientQuotes`/`GroupQuotes` + réplicas legadas `CotizacionBanda/{ownerUid}` y `CotizacionComprador/{clientId}` + notificación al dueño; "Mis cotizaciones" lee `CotizacionComprador/{miUid}` (como `MyQuotesActivity`) | `Views/Marketplace/MusicalHubView.swift`, `Views/Marketplace/MusicalQuotesManagerView.swift` |

Decisiones de interoperabilidad verificadas contra el código Java:

- **Comentarios**: cId y timestamp en millis **como String** (no push key); respuestas en el nodo separado `Reply/{parentId}`; el contador usa lectura+1 (misma semántica sin transacción que Android).
- **Bloqueo de chat**: se implementó el esquema A de `ChatActivity` (`BlockedUsers/{myUid}/{hisUid}` = true); con cualquier bloqueo (mío o suyo) se deshabilitan input, envío y botones de llamada.
- **Al iniciar una llamada** desde iOS se registra `CallHistory` (status `cancelled` como marca de intento) y el mensaje `voice_call`/`video_call` en `Chats` + `Chatlist`, replicando `ChatActivity.java:1186-1194`.
- **Anuncios**: `expiry` ≤ 6 dígitos se interpreta como días y si no como epoch (réplica exacta de `HomeFragment.java:1782-1795`); el shuffle se hace una sola vez por llegada de datos para no saltar el feed.
- **Cotizaciones**: se escriben simultáneamente el esquema nuevo (`MusicalQuotes`) y las réplicas legadas que Android lee (`CotizacionBanda`/`CotizacionComprador`), en una única `updateChildValues` multi-ruta.

### 10.1 Correcciones de revisión de compilación de esta fase (4 BLOCKER + 5 WARN)

- **API del SDK de iOS**: reemplazados `orderByChild(...).equalTo(...)` (API de Android) por `queryOrdered(byChild:).queryEqual(toValue:)` en `ChatViewModel` (×2) y `AdsManagerView`; `snapshot.exists` → `snapshot.exists()` en `DetailPostView`.
- **Observers**: `openThread` ya no re-adjunta listeners si el mismo hilo está abierto; `MyAdsViewModel` da de baja su observer (`close()`/`deinit`) y se re-observa si cambia la cuenta; cada `DetailPostView` instancia su propio `CommentsService` (antes un singleton compartido pisaba postes simultáneos).
- **Feed estable**: el shuffle de anuncios dejó de ejecutarse en cada `rebuildFeedItems`; las impresiones (`pViews`) se cuentan también al mostrar la tarjeta (como `AdapterAdsPost`), no solo al tocar.
- **Paridad con Android**: botones de llamada deshabilitados con el chat bloqueado; omitida la clave `requestId: ""` en las cotizaciones; semillas de cotizaciones sin `clientNotes` heredado.

Verificación final: `check-integrity.ps1` → **SIN PROBLEMAS**.

## 11. Limitaciones conocidas / trabajo del equipo humano

1. **Firma y envío**: seleccionar Team, capacidades y firma (ver `RELEASE_CHECKLIST.md`).
2. **Google Sign-In**: se registró el esquema `REVERSED_CLIENT_ID`, pero el SDK de Google Sign-In no está añadido (no se usa en el código actual).
3. **Teléfono (SMS)**: Phone Auth debe habilitarse en la consola de Firebase con la clave APNs del proyecto; si no, el registro degrada mostrando el error en español (el usuario puede "Omitir" el OTP).
4. **`associated-domains: applinks:proviweb.com`**: requiere publicar `apple-app-site-association` en `https://proviweb.com`.
5. ~~Vistas de módulos secundarios (Mapa, Chat, Marketplace…) funcionan con datos seed locales~~ → **Superado**: Chat (`Chats`/`Chatlist` + reacciones/bloqueo/silencio/historial de llamadas), Marketplace (`Product` + cotizaciones `MusicalQuotes`/`CotizacionComprador`), Mapa (`UserLocation`), Eventos (`ArtisticEvents` + boletos), Empleos (`JobOffers`), Notificaciones (`Users/{uid}/Notifications`), Canciones (`Songs`), Partituras (`books`), Clases (`StudentClasses`/`BookedClasses`), Verificación (`Verification*`), Comentarios (`Posts/{id}/Comments`), Anuncios (`AdsPost`) y Páginas de artista (`Pages`) usan ya los nodos y rutas reales de Android. Siguen con interfaz sin backend: **llamadas VoIP** (CallKit local; iOS registra el intento en `CallHistory` + mensaje en `Chats`, pero no hay señalización WebRTC), **grupos** (`Groups`) y **juegos musicales** (funcionalidad local deliberada).
