import UIKit
import UserNotifications
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

// MARK: - iOS App Delegate with Firebase Initialization, Analytics & Crashlytics
public class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    public var window: UIWindow?
    
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 1. Configure Firebase Core
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        print("✓ Firebase inicializado correctamente en PROVIWEB iOS")
        #endif
        
        // 2. Setup Firebase Analytics
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: [
            "app_platform": "iOS",
            "app_version": "1.0.0"
        ])
        print("✓ Firebase Analytics activado")
        #endif
        
        // 3. Setup Firebase Crashlytics
        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue("PROVIWEB_iOS", forKey: "app_identifier")
        crashlytics.setCustomValue("1.0.0", forKey: "build_version")
        crashlytics.log("PROVIWEB iOS iniciado exitosamente")
        print("✓ Firebase Crashlytics activado")
        #endif
        
        // 4. Setup Push Notifications
        setupPushNotifications(application: application)
        
        // 5. Arranque de la sesión (listener de Auth + sincronización en vivo del RTDB)
        FirebaseService.shared.bootstrap()
        
        return true
    }
    
    private func setupPushNotifications(application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }
    
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02x", data) }
        let token = tokenParts.joined()
        print("FCM / APNs Device Token registrado: \(token)")
        
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([[.banner, .sound, .badge]])
    }
}
