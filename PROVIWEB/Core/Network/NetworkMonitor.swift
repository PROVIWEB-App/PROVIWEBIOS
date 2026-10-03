import Foundation
import Network
import Combine

// MARK: - Network Connectivity & Offline Sync Monitor
public class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.israviolink.networkMonitor")
    
    @Published public var isConnected: Bool = true
    @Published public var isExpensive: Bool = false
    @Published public var connectionType: ConnectionType = .wifi
    
    public enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
                self?.isExpensive = path.isExpensive
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .ethernet
                } else {
                    self?.connectionType = .unknown
                }
                
                if path.status == .satisfied {
                    print("[NetworkMonitor] Conexión activa: sincronizando datos...")
                } else {
                    print("[NetworkMonitor] Sin conexión: activando modo offline.")
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    public func stopMonitoring() {
        monitor.cancel()
    }
}
