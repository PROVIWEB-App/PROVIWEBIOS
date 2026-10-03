import Foundation
import Combine
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

// MARK: - Background Media Upload Manager (UploadManager.java equivalent)
public class UploadManager: ObservableObject {
    public static let shared = UploadManager()
    
    @Published public var isUploading: Bool = false
    @Published public var uploadProgress: Double = 0.0
    @Published public var currentUploadTaskName: String = ""
    @Published public var lastUploadedURL: String? = nil
    
    private init() {}
    
    public func uploadData(
        data: Data,
        path: String,
        mimeType: String,
        onProgress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            self.isUploading = true
            self.uploadProgress = 0.0
            self.currentUploadTaskName = (path as NSString).lastPathComponent
        }
        
        #if canImport(FirebaseStorage)
        let storageRef = Storage.storage().reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = mimeType
        
        let uploadTask = storageRef.putData(data, metadata: metadata) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isUploading = false
            }
            if let error = error {
                completion(.failure(error))
                return
            }
            
            storageRef.downloadURL { [weak self] url, err in
                if let err = err {
                    completion(.failure(err))
                } else if let downloadURL = url?.absoluteString {
                    DispatchQueue.main.async {
                        self?.lastUploadedURL = downloadURL
                    }
                    completion(.success(downloadURL))
                }
            }
        }
        
        uploadTask.observe(.progress) { [weak self] snapshot in
            guard let progress = snapshot.progress else { return }
            let percent = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
            DispatchQueue.main.async {
                self?.uploadProgress = percent
                onProgress?(percent)
            }
        }
        #else
        // Mock fallback for previews
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.uploadProgress = 1.0
            self.isUploading = false
            let mockUrl = "https://firebasestorage.googleapis.com/v0/b/proviweb-d8764.appspot.com/o/\(path)?alt=media"
            self.lastUploadedURL = mockUrl
            completion(.success(mockUrl))
        }
        #endif
    }
}
