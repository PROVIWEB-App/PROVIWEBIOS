import Foundation
import Vision
import AVFoundation
import CoreGraphics
import Combine

// MARK: - Apple Vision Human Pose Estimation for AI Violin Tutor
public class PoseEstimationService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    public static let shared = PoseEstimationService()
    
    @Published public var postureScore: Double = 92.0 // 0 - 100%
    @Published public var feedbackMessage: String = "Postura y sujeción del violín en excelente ángulo."
    @Published public var detectedKeypoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published public var isSessionRunning: Bool = false
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let processingQueue = DispatchQueue(label: "com.proviweb.poseQueue")
    
    public override init() {
        super.init()
    }
    
    public func startCamera() {
        guard !captureSession.isRunning else { return }
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high
            
            // Front camera for self-practice reflection
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: camera) else {
                return
            }
            
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }
            
            self.videoOutput.setSampleBufferDelegate(self, queue: self.processingQueue)
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }
            
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }
    
    public func stopCamera() {
        guard captureSession.isRunning else { return }
        processingQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }
    
    // MARK: - Camera Frame Delegate & Vision Analysis
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .upMirrored, options: [:])
        do {
            try handler.perform([poseRequest])
            guard let observation = poseRequest.results?.first else { return }
            
            processPoseObservation(observation)
        } catch {
            print("Error en Vision Pose Detection: \(error)")
        }
    }
    
    private func processPoseObservation(_ observation: VNHumanBodyPoseObservation) {
        do {
            var keypoints = [VNHumanBodyPoseObservation.JointName: CGPoint]()
            
            let jointsToRecognize: [VNHumanBodyPoseObservation.JointName] = [
                .leftShoulder, .leftElbow, .leftWrist,
                .rightShoulder, .rightElbow, .rightWrist,
                .neck, .nose, .leftEye, .rightEye
            ]
            
            for joint in jointsToRecognize {
                if let point = try? observation.recognizedPoint(joint), point.confidence > 0.3 {
                    keypoints[joint] = CGPoint(x: point.location.x, y: 1 - point.location.y)
                }
            }
            
            // Analyze Violin Hold & Bow Geometry
            var score = 100.0
            var feedback = "Postura excelente."
            
            // 1. Bow Arm (Right Elbow Level)
            if let rightShoulder = keypoints[.rightShoulder],
               let rightElbow = keypoints[.rightElbow] {
                let elbowHeightDiff = rightShoulder.y - rightElbow.y
                if elbowHeightDiff > 0.25 {
                    score -= 15.0
                    feedback = "Baja un poco el hombro derecho y mantén el codo en el plano de la cuerda."
                }
            }
            
            // 2. Left Wrist straightness (Instrument Hold)
            if let leftElbow = keypoints[.leftElbow],
               let leftWrist = keypoints[.leftWrist] {
                let wristAngle = atan2(leftWrist.y - leftElbow.y, leftWrist.x - leftElbow.x) * 180 / .pi
                if abs(wristAngle) < 30 {
                    score -= 10.0
                    feedback = "Evita apoyar la muñeca izquierda contra el mástil del violín."
                }
            }
            
            // 3. Spine & Neck alignment
            if let neck = keypoints[.neck], let nose = keypoints[.nose] {
                let tilt = abs(nose.x - neck.x)
                if tilt > 0.15 {
                    score -= 10.0
                    feedback = "Relaja el cuello y coloca la barbilla cómodamente sobre la mentonera."
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.detectedKeypoints = keypoints
                self?.postureScore = max(50.0, min(100.0, score))
                self?.feedbackMessage = feedback
            }
        }
    }
}
