import Foundation
import StoreKit
import SwiftUI

// MARK: - StoreKit In-App Rating & Review Manager
public class InAppReviewService {
    public static let shared = InAppReviewService()
    
    private let reviewCountKey = "PROVIWEB_ReviewActionCount"
    private let lastVersionPromptedKey = "PROVIWEB_LastVersionPromptedForReview"
    
    private init() {}
    
    public func requestReviewIfAppropriate() {
        let currentCount = UserDefaults.standard.integer(forKey: reviewCountKey) + 1
        UserDefaults.standard.set(currentCount, forKey: reviewCountKey)
        
        // Prompt after completing meaningful actions (e.g. after practice sessions or post creation)
        if currentCount >= 5 {
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                    UserDefaults.standard.set(0, forKey: self.reviewCountKey)
                }
            }
        }
    }
}
