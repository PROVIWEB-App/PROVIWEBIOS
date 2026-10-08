import SwiftUI

// MARK: - Muse Headband & Musical Focus Device View
public struct MuseDeviceView: View {
    @ObservedObject private var ble = MuseBLEService.shared
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header Status
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(ble.isConnected ? AppColors.success.opacity(0.15) : AppColors.primary.opacity(0.12))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: ble.isConnected ? "wave.3.forward.circle.fill" : "headphones")
                                .font(.system(size: 38))
                                .foregroundColor(ble.isConnected ? AppColors.success : AppColors.primary)
                        }
                        
                        Text(ble.isConnected ? "Dispositivo Muse Conectado" : "Dispositivo Muse Desconectado")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                        
                        Text(ble.isConnected ? "Midiendo enfoque neuronal y ritmo cerebral durante tu práctica musical." : "Conecta tu diadema Muse vía Bluetooth para registrar tu nivel de concentración y calma.")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 20)
                    
                    if ble.isConnected {
                        // Telemetry Cards
                        VStack(spacing: 14) {
                            HStack(spacing: 16) {
                                // Focus Meter
                                VStack(spacing: 8) {
                                    Text("Enfoque")
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                    Text("\(Int(ble.focusScore * 100))%")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.primary)
                                    ProgressView(value: ble.focusScore)
                                        .accentColor(AppColors.primary)
                                }
                                .padding(16)
                                .background(theme.cardColor)
                                .cornerRadius(18)
                                
                                // Calm Meter
                                VStack(spacing: 8) {
                                    Text("Calma")
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                    Text("\(Int(ble.calmScore * 100))%")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.gold)
                                    ProgressView(value: ble.calmScore)
                                        .accentColor(AppColors.gold)
                                }
                                .padding(16)
                                .background(theme.cardColor)
                                .cornerRadius(18)
                            }
                            .padding(.horizontal, 16)
                            
                            HStack {
                                Image(systemName: "battery.75")
                                    .foregroundColor(AppColors.success)
                                Text("Batería: \(ble.batteryLevel)%")
                                    .font(.caption)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Button("Desconectar") {
                                    ble.disconnect()
                                }
                                .font(.caption)
                                .foregroundColor(AppColors.errorRed)
                            }
                            .padding(14)
                            .background(theme.cardColor)
                            .cornerRadius(14)
                            .padding(.horizontal, 16)
                        }
                    } else {
                        // Scan & Devices List
                        VStack(spacing: 12) {
                            Button(action: {
                                if ble.isScanning {
                                    ble.stopScanning()
                                } else {
                                    ble.startScanning()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: ble.isScanning ? "stop.fill" : "antenna.radiowaves.left.and.right")
                                    Text(ble.isScanning ? "Detener Búsqueda" : "Buscar Dispositivos BLE")
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(ble.isScanning ? AppColors.errorRed : AppColors.primary)
                                .cornerRadius(20)
                            }
                            
                            if ble.discoveredPeripherals.isEmpty && ble.isScanning {
                                ProgressView("Buscando diadema Muse...")
                                    .padding(.top, 16)
                            } else {
                                List(ble.discoveredPeripherals, id: \.identifier) { p in
                                    HStack {
                                        Text(p.name ?? "Dispositivo BLE Desconocido")
                                            .foregroundColor(theme.textPrimary)
                                        Spacer()
                                        Button("Conectar") {
                                            ble.connect(peripheral: p)
                                        }
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.primary)
                                    }
                                }
                                .listStyle(PlainListStyle())
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Diadema Muse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
