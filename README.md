# PROVIWEB iOS 🎻📱

**PROVIWEBIOS** es la aplicación nativa para iOS de **PROVIWEB**, la plataforma y red social para músicos, profesores, estudiantes, orquestas y agrupaciones musicales. Representa la **migración completa al 100% del proyecto Android (PROVIWEBAPP)** a arquitectura nativa Apple.

Desarrollada en **Swift 5.9+ / iOS 16.0+** utilizando **SwiftUI, Combine, AVFoundation, PDFKit, CoreBluetooth, Apple Vision Framework, MapKit, CoreLocation y Firebase SDK**.

---

## 🚀 Arquitectura y Módulos Migrados

### 1. 🎫 Eventos Artísticos & Boletos Digitales (Events Module)
- **Cartelera de Conciertos y Recitales** (`EventsHomeView`): Filtros por categoría (Concierto, Recital, Masterclass, Serenata, Festival, Jam Session).
- **Publicador de Eventos** (`CreateEventView`): Registro de aforo, precio en USD/Diamantes, transmisión en vivo y cartelera.
- **Detalle y Compra de Boletos** (`EventDetailsView`): Cronograma por bloques y confirmación de entradas.
- **Boleto Digital con QR Check-in** (`DigitalTicketView` & `MyTicketsListView`): Generación dinámica de QR para acceso en puerta con validación de seguridad.

### 2. 🎼 Archivo de Partituras & Visor PDF con Metrónomo Flotante (Archive Module)
- **Biblioteca de Partituras Clasificada** (`SheetMusicArchiveView`):
  - *Clásico*: Violín, Viola, Cello, Contrabajo, Flauta, Oboe, Clarinete, Trompeta, Trombón, Timpani, Coro.
  - *Mariachi*: Violines, Trompetas, Guitarrón, Vihuela, Arpa, Voz.
  - *Banda & Regional*: Trompeta, Trombón, Clarinete, Saxofón, Bajo Eléctrico.
  - *Jazz & Ensamble*: Piano, Guitarra, Batería, Saxofón.
- **Visor Interactivo PDFKit** (`SheetMusicPDFViewer`):
  - Motor nativo `PDFView` con zoom continuo y renderizado de alta fidelidad.
  - **Metrónomo Flotante Integrado**: Practica directamente sobre la partitura ajustando el tempo BPM y compás visual sin salir de la vista.
  - **Pista de Acompañamiento**: Reproducción de pistas de audio sincronizadas de fondo.

### 3. 🎓 Clases Particulares & Gestión Docente (Classes & Masterclasses)
- **Directorio de Maestros** (`SearchClassesView`): Búsqueda por instrumento, tarifa horaria, modalidad (En línea, Presencial, Híbrido) y calificaciones.
- **Reserva de Clases** (`BookClassView`): Elección de fecha, horarios disponibles, notas del alumno y pago en USD o Diamantes PROVIWEB.
- **Configuración de Disponibilidad** (`TeacherAvailabilityView`): Los maestros establecen sus días, franjas horarias y tarifas por hora.
- **Mis Clases Reservadas** (`MyBookedClassesView`): Acceso directo a la sala de videoconferencia en vivo con enlace de reunión.

### 4. 🎺 Hub Musical & Cotizador de Mariachis y Agrupaciones (Musical Hub & Quotes)
- **Directorio de Agrupaciones** (`MusicalHubView`): Mariachis, Cuartetos de Cuerdas, Bandas Sinaloenses, Tríos Románticos y Orquestas con radio de cobertura en kilómetros.
- **Solicitud Inmediata de Cotización** (`GroupQuoteRequestModal`): Cálculo de horas, canciones requeridas y dirección del evento.
- **Gestor y Comparador de Cotizaciones** (`MusicalQuotesManagerView`): Bandeja de cotizaciones (Pendientes, Aceptadas, Declinadas, Pagadas) y comparador visual en paralelo.

### 5. 🧠 Diadema Muse EEG & Telemetría Neuro-Musical (CoreBluetooth Gadget)
- **Servicio CoreBluetooth** (`MuseBLEService`): Protocolo oficial Muse Gadget (`4D757365-0001-4000-8000-6A6F6C6C7900`) con soporte en segundo plano.
- **Monitor de Enfoque y Calma** (`MuseDeviceView`): Medición en tiempo real del nivel de concentración (Focus) y relajación (Calm) del músico durante su práctica en el estudio.

### 6. 🎻 Profesor IA & Análisis Biomecánico de Postura
- **Apple Vision Framework** (`PoseEstimationService`): Rastreo esquelético con `VNDetectHumanBodyPoseRequest` para verificar la alineación del codo, muñeca y violín.
- **Afinador Cromático de Precisión** (`ChromaticTunerService`): Transformada rápida de Fourier (FFT) acelerada por vDSP/Accelerate con detección en hercios y cents.
- **Síntesis de Voz** (`AVSpeechSynthesizer`): Corrección auditiva en tiempo real.

### 7. 🎬 Reels Musicales & Reproductor de Audio
- **Reels en Pantalla Completa** (`ReelsView` & `VideoSeriesPlayerView`): Video vertical, animaciones de me gusta, música original asociada y comentarios en tiempo real.
- **Reproductor de Música Global** (`MusicPlayerView` & `AudioPlayerService`): Mini-player flotante persistente, soporte para bloqueo con `MPNowPlayingInfoCenter` y exploración de canciones (`MusicExploreView`).

### 8. 💬 Mensajería & Llamadas VoIP (CallKit)
- **Chat Realtime interoperable con Android** (`ChatService`, `ChatListView` & `ChatViewModel`): sincronizado con los nodos `Chats` y `Chatlist` de Firebase (mismo esquema que Android), bandeja en vivo, no leídos, marcar como leído, envío de texto y fotos (subidas a `chat_photo/`), y representación de tipos (imagen, ubicación, sticker…).
- **Llamadas de Audio y Video** (`CallKitService`): Integración con el framework nativo de telefonía de iOS (CallKit) para responder llamadas directamente desde la pantalla de bloqueo.

### 9. 💎 Monedero QAV & Cripto Web3
- **Gestión de Saldo y Diamantes** (`QAVWalletView`): Conversión entre USD, diamantes y tokens.
- **Almacenamiento Seguro Keychain** (`Web3WalletService`): Respaldo de llaves privadas en el Secure Enclave de iOS.
- **Soporte Deep Links Reown / WalletConnect**: Esquemas `wc:` y `proviweb://` para firmas descentralizadas.
- **Retiro de Fondos** (`DiamondWithdrawView`): Transferencias a cuenta bancaria o wallet.

### 10. 👤 Perfil, Actividad Social & Configuración
- **Comunidad y Visitas** (`SocialInsightsView`): Seguidores, seguidos, me gusta en posts/reels y visualización de quién visitó el perfil.
- **Ajustes del Sistema** (`SettingsView`): Preferencias de notificaciones, efectos de sonido y selector de temas (*Night*, *Dim*, *Light*).
- **Seguridad Biométrica** (`WalletSecurityView`): Protección mediante Face ID / Touch ID y exportación controlada de claves privadas.
- **Solicitud de Verificación** (`VerificationRequestView`): Solicitud de insignia para estudiantes, maestros y entidades/mariachis.
- **Términos y Soporte** (`LegalAndSupportView`): Términos legales, privacidad y buzón de soporte técnico.

---

## 📂 Estructura del Proyecto

```
PROVIWEBIOS/
├── PROVIWEB.xcodeproj/          # Proyecto Xcode con targets, SPM y Build Phases
├── PROVIWEB/
│   ├── App/                     # Entrada principal (@main) y AppDelegate
│   ├── Config/                  # Info.plist, Entitlements y GoogleService-Info.plist
│   ├── Core/
│   │   ├── Audio/               # Reproductor, Metrónomo vDSP, Efectos de sonido
│   │   ├── Calling/             # CallKit VoIP
│   │   ├── Location/            # CoreLocation para radar musical
│   │   ├── Network/             # Firebase Realtime, Analytics, NetworkMonitor
│   │   ├── Theme/               # Paleta de colores, Temas Night/Dim/Light
│   │   ├── Vision/              # PoseEstimation (Vision) y MuseBLEService (CoreBluetooth)
│   │   └── Web3/                # Keychain Web3 y QR Generator
│   ├── Models/                  # EventModel, ClassModel, SheetMusicModel, MusicalGroupModel, PostModel, SongModel, UserModel
│   ├── ViewModels/              # Feed, Chat, Marketplace
│   ├── Views/
│   │   ├── Archive/             # SheetMusicArchiveView, SheetMusicPDFViewer
│   │   ├── Classes/             # SearchClassesView, BookClassView, TeacherAvailabilityView, MyBookedClassesView
│   │   ├── Events/              # EventsHomeView, EventDetailsView, DigitalTicketView, CreateEventView
│   │   ├── Marketplace/         # MarketplaceView, MusicalHubView, MusicalQuotesManagerView, BookingCalendarView
│   │   ├── Profile/             # ProfileView, SocialInsightsView, AchievementsView
│   │   ├── Settings/            # SettingsView, EditProfileView, WalletSecurityView, LegalAndSupportView
│   │   ├── Verification/        # VerificationRequestView
│   │   ├── Components/          # MuseDeviceView, PostCardView, MediaViewerModal, QRScannerView
│   │   ├── AIProfessor/         # AIProfessorView
│   │   ├── Practice/            # PracticeStudioView
│   │   ├── Music/               # MusicExploreView, MusicPlayerView
│   │   ├── Reels/               # ReelsView, VideoSeriesPlayerView
│   │   ├── Chat/                # ChatListView
│   │   ├── Wallet/              # QAVWalletView, DiamondWithdrawView
│   │   ├── Main/                # MainTabView
│   │   ├── Home/                # HomeView
│   │   └── Menu/                # SideDrawerView, InviteEarnView
│   └── Resources/               # Localizable.strings (es, en), Assets.xcassets, Sonidos
└── preview/                     # Servidor y simulador interactivo para desarrollo
```

---

## 🛠️ Cómo compilar y ejecutar en Xcode

1. Abre `PROVIWEB.xcodeproj` en **Xcode 15 o superior**.
2. Los paquetes de **Firebase iOS SDK** se resolverán automáticamente mediante Swift Package Manager (SPM).
3. Selecciona tu simulador (ej. *iPhone 16 Pro* o *iPad Pro*) o un dispositivo físico iOS.
4. Presiona **Cmd + R** (Product > Run) para compilar y lanzar la aplicación.

---

## 📦 Documentación de entrega

- **[MIGRATION_REPORT.md](MIGRATION_REPORT.md)** — informe completo de la migración Android → iOS: auth real Firebase, esquema RTDB interoperable, flujo de aprobación de menores, navegaciones conectadas, correcciones y resultados de verificación estática.
- **[RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)** — checklist de firma, QA y publicación en App Store para el equipo humano.
- **`scripts/check-integrity.ps1`** — verificación estática reproducible (balance de código, vistas sin `init()`, pbxproj, iconos, scheme).
- **`scripts/generate-appicon.ps1`** — regenera el `AppIcon.appiconset` (PNG sin alfa) a partir del logo de Android.
