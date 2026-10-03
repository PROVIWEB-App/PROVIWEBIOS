import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

// MARK: - Firebase Analytics & Crashlytics Integration Manager
public class AnalyticsService {
    public static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Analytics Events
    public func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters)
        #else
        print("[Analytics Event] \(name): \(parameters ?? [:])")
        #endif
    }
    
    public func logScreenView(screenName: String, screenClass: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass
        ])
        #else
        print("[Analytics ScreenView] \(screenName) (\(screenClass))")
        #endif
    }
    
    public func logPracticeSessionCompleted(durationSeconds: Int, rewardEarned: Bool) {
        logEvent("practice_session_completed", parameters: [
            "duration_seconds": durationSeconds,
            "reward_earned": rewardEarned ? 1 : 0
        ])
    }
    
    public func logAIProfessorSession(exercise: String, score: Double, pitchAccuracy: Double) {
        logEvent("ai_professor_session", parameters: [
            "exercise_name": exercise,
            "overall_score": score,
            "pitch_accuracy": pitchAccuracy
        ])
    }
    
    public func logMusicPlay(songTitle: String, artist: String) {
        logEvent("music_song_played", parameters: [
            "song_title": songTitle,
            "artist": artist
        ])
    }
    
    public func logQuoteRequested(bandType: String, budget: Double) {
        logEvent("musician_quote_requested", parameters: [
            "band_type": bandType,
            "budget_usd": budget
        ])
    }
    
    // MARK: - Crashlytics & Error Reporting
    public func setUserId(_ userId: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(userId)
        #endif
    }
    
    public func setCustomKey(_ key: String, value: Any) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #endif
    }
    
    public func logCrashMessage(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #else
        print("[Crashlytics Log] \(message)")
        #endif
    }
    
    public func recordError(_ error: Error, additionalInfo: [String: Any]? = nil) {
        #if canImport(FirebaseCrashlytics)
        if let info = additionalInfo {
            for (key, val) in info {
                Crashlytics.crashlytics().setCustomValue(val, forKey: key)
            }
        }
        Crashlytics.crashlytics().record(error: error)
        #else
        print("[Crashlytics Non-Fatal Error] \(error.localizedDescription) - Info: \(additionalInfo ?? [:])")
        #endif
    }
}
