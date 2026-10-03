import Foundation
import CallKit
import AVFoundation
import Combine

// MARK: - VoIP & Video Calling Service
public class CallKitService: NSObject, ObservableObject, CXProviderDelegate {
    public static let shared = CallKitService()
    
    private let callController = CXCallController()
    private var provider: CXProvider?
    
    @Published public var isIncomingCall: Bool = false
    @Published public var isCallActive: Bool = false
    @Published public var isVideoCall: Bool = true
    @Published public var isMuted: Bool = false
    @Published public var callerName: String = "Israel Violín"
    @Published public var callerAvatar: String? = nil
    @Published public var callDurationSeconds: Int = 0
    
    private var callTimer: Timer?
    
    override init() {
        super.init()
        setupCallKitProvider()
    }
    
    private func setupCallKitProvider() {
        let config = CXProviderConfiguration()
        config.supportsVideo = true
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        
        provider = CXProvider(configuration: config)
        provider?.setDelegate(self, queue: nil)
    }
    
    public func startCall(callerName: String, isVideo: Bool) {
        self.callerName = callerName
        self.isVideoCall = isVideo
        self.isCallActive = true
        self.callDurationSeconds = 0
        
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.callDurationSeconds += 1
        }
    }
    
    public func endCall() {
        self.isIncomingCall = false
        self.isCallActive = false
        callTimer?.invalidate()
        callTimer = nil
    }
    
    public func toggleMute() {
        self.isMuted.toggle()
    }
    
    // CXProviderDelegate
    public func providerDidReset(_ provider: CXProvider) {
        endCall()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        self.isIncomingCall = false
        self.isCallActive = true
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        endCall()
        action.fulfill()
    }
}
