# ✅ RELEASE_CHECKLIST — Firma y publicación en App Store

**App:** PROVIWEB · **Bundle ID:** `com.israviolink.ios` · **Versión:** 1.0.0 (build 1) · **iOS:** 16.0+
**Responsable:** equipo humano (el asistente no firma ni envía).

---

## FASE A — Primera apertura en macOS

- [ ] Abrir `PROVIWEB.xcodeproj` con **Xcode 15.2+** (el CI usa **Xcode 16.2**).
- [ ] Esperar a que SPM resuelva `firebase-ios-sdk ≥ 11.0.0` (menú inferior de Xcode).
- [ ] Seleccionar target **PROVIWEB → Signing & Capabilities**:
  - [ ] Marcar **Automatically manage signing**.
  - [ ] **Team:** seleccionar la cuenta de desarrollo de la organización (aquí se fija el `DEVELOPMENT_TEAM` que deliberadamente no se configuró en el repositorio).
  - [ ] Bundle Identifier = `com.israviolink.ios` (sin cambios).
- [ ] Comprobar capacidades activas: **Push Notifications**, **Associated Domains** (`applinks:proviweb.com`), **Keychain Sharing**, **Background Modes** (audio, remote-notification…).
- [ ] `PROVIWEB/Config/PROVIWEB.entitlements → aps-environment` es `development`; Xcode lo ajusta a `production` en la exportación de distribución (o verificarlo al firmar).
- [ ] Primer build: **Product → Build (⌘B)**. Si aparecen errores, son del entorno/equipo (revisar antes de publicar); la verificación estática previa está en `MIGRATION_REPORT.md`.

## FASE B — Consola Firebase (`proviweb-d8764`)

- [ ] **Authentication → Sign-in method:** habilitar **Email/Password** y **Phone**.
- [ ] **Phone Auth:** subir la clave **APNs Auth Key (.p8)** del proyecto de Apple (o certificado APNs) para recibir los SMS de OTP.
- [ ] **Realtime Database:** confirmar reglas (nodos `Users`, `Posts` (+ `Comments`/`commentCount`), `cLikes`, `Reply`, `Aplausos`, `Balance`, `Reels`, `MinorApprovalRequests`, y ahora también `Chats` (+ `reactions`), `Chatlist`, `BlockedUsers`, `MutedChats`, `CallHistory`, `Product`, `UserLocation`, `ArtisticEvents`, `EventTickets`, `UserEventTickets`, `JobOffers`, `JobApplications`, `Songs`, `books`, `BookedClasses`, `StudentClasses`, `ClassRequests`, `PlatformCommission`, `Verification*`, `AdsPost`, `Ads`, `Pages`, `FollowPages`, `MusicalQuotes`, `ClientQuotes`, `GroupQuotes`, `CotizacionBanda`, `CotizacionComprador`) — mismas que `database.rules.json` de Android. **Importante:** las reglas de `Chats` exigen `.indexOn: ["sender", "receiver"]` (ya presentes en las de Android) y `Chatlist/{uid}` solo es legible por su dueño.
- [ ] **App Store Connect → App:** crear la app con `com.israviolink.ios` si aún no existe.
- [ ] `GoogleService-Info.plist` correcto (bundle `com.israviolink.ios`) — ya está en `PROVIWEB/Config/` y en el target.
- [ ] *(Opcional)* Firebase App Distribution: secretos `FIREBASE_TOKEN` en GitHub → el workflow publica el IPA en los grupos `testers,qa-team`.

## FASE C — Verificación previa

- [ ] PowerShell (Windows) o terminal:
  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts/check-integrity.ps1 -Root .
  ```
  Resultado esperado: **SIN PROBLEMAS**.
- [ ] Comprobar iconos: `PROVIWEB/Assets.xcassets/AppIcon.appiconset` (13 PNG + Contents.json iPhone/iPad/marketing, sin alfa).
- [ ] Comprobar scheme compartido: `PROVIWEB.xcodeproj/xcshareddata/xcschemes/PROVIWEB.xcscheme`.
- [ ] Versionado: `MARKETING_VERSION` (1.0.0) y `CURRENT_PROJECT_VERSION` (1) en ambas configuraciones de `project.pbxproj` — **subir `CURRENT_PROJECT_VERSION` en cada envío**.

## FASE D — QA funcional (smoke test en dispositivo)

- [ ] Arranque → splash → pantalla de login (sin parpadeos).
- [ ] **Registro** con email y contraseña → correo de verificación → feed.
- [ ] **Registro marcando "Soy menor de edad"** → pantalla `WaitApprovalView`; botón *Comprobar estado* (debe decir "en proceso"); aprobarlo desde Android/panel → *Comprobar estado* → entra a `MainTabView`.
- [ ] **Login** con cuenta menor ya aprobada → entra directo; con cuenta menor pendiente → `WaitApprovalView`.
- [ ] **Explorar sin cuenta (modo demo)** → app navegable sin credenciales; *Cerrar sesión* vuelve al login.
- [ ] **Face ID** / clave guardada en Keychain al reabrir la app.
- [ ] Feed con datos reales de RTDB: **like** (contador `Aplausos`), **comentario** (`commentCount`), crear **publicación** → visible desde Android y viceversa.
- [ ] Teléfono (si Phone Auth habilitado): OTP real vincula el número; si no está habilitado, muestra el error en español y se puede *Omitir*.
- [ ] Reels, Perfil, Ajustes, Monedero y las 9 navegaciones nuevas (ver §3 de `MIGRATION_REPORT.md`).
- [ ] **Chat (interop con Android)**: abrir un chat existente desde Android → mensaje visible en iOS; enviar mensaje de texto → aparece en Android; la bandeja muestra nombre/foto reales de `Users/{uid}`; badge de no leídos; al abrir el hilo, los entrantes se marcan leídos (check doble en Android).
- [ ] **Chat con foto**: adjuntar imagen → se sube a `chat_photo/` y Android la muestra como "📷 Foto".
- [ ] **Marketplace**: productos del nodo `Product` visibles; si Android tiene promocionados, aparecen primero.
- [ ] **Publicar producto** en iOS (botón "Publicar", foto opcional) → visible en Android (`Product/{timestamp}`).
- [ ] **Editar perfil → Cambiar Foto**: la foto se sube a `profile_photo/` y se refleja en Android (`Users/{uid}/photo`); guardar cambios del perfil persiste tras reiniciar.
- [ ] **Crear publicación con foto**: la foto sube a `post_photo/` y el post se ve con imagen en Android; sin foto → post de texto sin imagen fija.
- [ ] **Ubicación**: con permiso concedido, la posición se publica en `UserLocation/{uid}` (verificable con el mapa de Android o en la consola RTDB); el mapa del Marketplace muestra marcadores de usuarios con ubicación; sin permiso, la app no se rompe.
- [ ] **Eventos (interop)**: cartelera desde `ArtisticEvents` (mismos eventos que en Android); crear un evento desde iOS → visible en Android con fecha/hora/categoría correctas.
- [ ] **Compra de entrada**: con saldo, comprar una entrada → `EventTickets/{eventId}` y `UserEventTickets/{uid}` creados, `registeredCount` +1, saldo descontado y creador notificado; sin saldo → alerta en español sin descontar nada; evento agotado → alerta; entrada en "Mis Boletos" abre el QR (`PROVIWEB_TICKET:...`).
- [ ] **Empleos (interop)**: ofertas desde `JobOffers` (solo `active`); "Publicar Vacante" → visible en Android; "Postularme" → `JobApplications/{jobId}/{uid}` creado, `applicationsCount` +1 y notificación al publisher.
- [ ] **Notificaciones**: acción de Android (like/regalo/reserva) → aparece en `NotificationsView`; badge de no leídas coherente con `Users/{uid}/Count`; "Marcar leídas" limpia el badge (igual que Android).
- [ ] **Canciones y Partituras**: `Songs` y `books` en vivo (vienen de Android); en Admin, aprobar/rechazar una canción pendiente → Android refleja `verificationStatus`; visor de PDF abre el PDF real (`books/content`) o muestra "no disponible" sin crash.
- [ ] **Clases**: buscar profesores (solo `verifiedprofesor == "yes"`); reservar con saldo → `BookedClasses` + `StudentClasses` creados, saldo descontado 100 %, profesor notificado y comisión del 10 % en `PlatformCommission`; sin saldo → alerta; "Mis Clases" muestra la reserva; solicitud de clase → `ClassRequests`.
- [ ] **Verificación**: enviar solicitud (cualquier tipo) → nodo `Verification*` con `status: "pending"` en la consola; sin sesión real → alerta en español.
- [ ] **Comentarios**: abrir un post → comentarios en vivo desde `Posts/{id}/Comments`; comentar → visible en Android y contador `commentCount` +1; responder a un comentario → `Reply/{parentId}`; like de comentario (`cLikes`); el dueño del post recibe notificación.
- [ ] **Chat avanzado**: reaccionar a un mensaje (menú contextual) → el emoji aparece en Android (`Chats/{msgId}/reactions`); silenciar chat → icono 🔕 y sin notificaciones; bloquear usuario → input, envío y llamadas deshabilitados en ambos lados; al iniciar una llamada → mensaje `voice_call`/`video_call` en el hilo y registro en `CallHistory`.
- [ ] **Anuncios en el feed**: `AdsPost` de Android aparecen intercalados (1 arriba + 1 cada 4 posts) con etiqueta "Patrocinado"; tocar/un mostrar incrementa `pViews`; "Mis anuncios" lista los propios y permite publicar uno nuevo (visible en Android); con `Ads/type = "off"` no se muestran.
- [ ] **Páginas de artista**: crear una página → `Pages/{millis}` + `FollowPages` en la consola; "Mis páginas" se filtra por dueño.
- [ ] **Cotizaciones**: en el Hub, agrupaciones listadas desde `Users` con `musicservice == "yes"`; solicitar cotización → `MusicalQuotes` + `CotizacionBanda`/`CotizacionComprador` creados, dueño notificado; "Mis cotizaciones" muestra las recibidas (`CotizacionComprador/{uid}`); confirmar desde iOS → Android refleja `aceptada/confirmada = "yes"`.
- [ ] **Push:** notificación recibida en el dispositivo (APNs).
- [ ] Sin red: la app no se rompe (seed local + tope de 4 s en la consulta de aprobación).

## FASE E — Archive y distribución

**Opción 1 — GitHub Actions (recomendada):**
- [ ] Push a `main` → workflow *Build & Distribute PROVIWEB iOS IPA* → artefactos `PROVIWEB-IPA` y `PROVIWEB-Simulator-Appetize` → publicación automática en Firebase App Distribution.

**Opción 2 — Manual en Xcode:**
- [ ] `Product → Archive` (destino iOS, configuración Release).
- [ ] Organizer → **Distribute App → App Store Connect → Upload** (o **Export** .ipa con *App Store Connect* distribution).
- [ ] Verificar en Organizer que la app usa `PROVIWEB.appiconset` y que `CFBundleShortVersionString=1.0.0`.

## FASE F — App Store Connect

- [ ] Pestaña **App Store**: nombre, subtítulo, descripción, categorías (Música / Educación), edad.
- [ ] **Privacidad**: declarar uso de Cámara, Micrófono, Fotos, Ubicación, Face ID, Bluetooth, Contactos (según cuestionario).
- [ ] Capturas de pantalla para 6,1" y 6,7" (y iPad si se soporta — `TARGETED_DEVICE_FAMILY = 1,2`).
- [ ] **TestFlight** → prueba interna con el equipo antes de *Enviar a revisión*.
- [ ] Enviar a revisión → publicación.

---

### 🛟 Solución de problemas rápidos

| Síntoma | Acción |
|---|---|
| *"requires a development team"* | Fase A → Signing & Capabilities → Team. |
| Firma push falla | Regenerar perfil automático (Xcode → Manage Certificates) o re-subir APNs key a Firebase. |
| Workflow: *scheme PROVIWEB not found* | Comprobar `xcshareddata/xcschemes/PROVIWEB.xcscheme` (Fase C). |
| SMS OTP no llega | Phone Auth + APNs key en Firebase (Fase B). |
| Icono rechazado por alfa | Regenerar con `scripts/generate-appicon.ps1` (genera PNG sin alfa). |
| Menor entra al feed sin aprobar | Revisar `Users/{uid}/minorApprovalStatus` en RTDB (debe ser `pending`/`approved`). |
