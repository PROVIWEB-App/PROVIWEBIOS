# PROVIWEB iOS 🎻📱

**PROVIWEBIOS** es la aplicación nativa para iOS de **PROVIWEB**, la plataforma y red social para músicos, profesores, estudiantes, orquestas y agrupaciones musicales.

Desarrollada en **Swift 5.9+ / iOS 16.0+** utilizando **SwiftUI, Combine, AVFoundation, Apple Vision Framework, MapKit, CoreLocation y Firebase**.

---

## 🚀 Módulos y Características

- 🎻 **Profesor IA de Violín y Música**:
  - Detección de postura en tiempo real mediante **Apple Vision Framework** (`VNDetectHumanBodyPoseRequest`).
  - Detección de afinación cromática exacta y frecuencia (Hz / cents) usando **AVAudioEngine** y **Accelerate (vDSP)**.
  - Consejos verbales del Maestro IA con **AVSpeechSynthesizer**.
- 🎬 **Reels Musicales**:
  - Reproductor vertical a pantalla completa estilo TikTok/Instagram con animaciones hápticas de corazones y drawer de comentarios.
- 🎵 **Reproductor de Música & Mini-Player Global**:
  - Reproducción de fondo con `AVPlayer` y controles en pantalla de bloqueo (`MPNowPlayingInfoCenter`).
  - Mini-player flotante persistente con gestos táctiles.
- ⏱️ **Estudio de Práctica & Recompensas**:
  - Metrónomo digital de alta precisión (BPM y compases configurables).
  - Afinador cromático estroboscópico.
  - Temporizador de práctica con recompensa automática de saldo ($1.00 USD) tras superar los 200 segundos.
- 💬 **Mensajería Instantánea & Llamadas VoIP**:
  - Chat 1 a 1 y grupal con notas de voz con forma de onda visual, fotos y stickers.
  - Soporte de llamadas de voz y video con **CallKit**.
- 🎺 **Marketplace & Cotizaciones de Agrupaciones**:
  - Compra y venta de instrumentos y accesorios.
  - Cotización para Mariachi, Banda Sinaloense, Cuarteto de Cuerdas y Solistas.
  - Radar de músicos cercanos con **CoreLocation** y alerta de proximidad (<100m).
- 💎 **Monedero QAV & Cripto Web3**:
  - Saldo en USD y diamantes.
  - Clave privada asegurada en el **Keychain** de iOS (`kSecClassGenericPassword`).
  - Generador de códigos QR con `CIQRCodeGenerator` y autenticación de nonces.
- 🌗 **Diseño y Temas**:
  - Modo Oscuro (*Night*), Modo Atenuado (*Dim*) y Modo Claro (*Light*).
  - Localización en Español (`es`) e Inglés (`en`).

---

## 🛠️ Cómo abrir y compilar el proyecto en macOS

1. Clona o copia la carpeta `PROVIWEBIOS` a tu Mac.
2. Abre `PROVIWEB.xcodeproj` en **Xcode 15 o superior**.
3. Selecciona tu simulador (ej. *iPhone 15 Pro*) o tu dispositivo físico.
4. Presiona **Cmd + R** para compilar y ejecutar.
