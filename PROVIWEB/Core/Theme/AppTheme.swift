import SwiftUI

// MARK: - App Theme & Colors for PROVIWEB iOS
public struct AppColors {
    public static let primary = Color(red: 0.094, green: 0.467, blue: 0.949) // #1877F2
    public static let primaryDark = Color(red: 0.051, green: 0.278, blue: 0.631) // #0D47A1
    public static let chatPrimary = Color(red: 0.039, green: 0.420, blue: 1.000) // #0A6BFF
    public static let musicPrimary = Color(red: 0.129, green: 0.588, blue: 0.953) // #2196F3
    public static let gold = Color(red: 1.000, green: 0.843, blue: 0.000) // #FFD700
    public static let silver = Color(red: 0.753, green: 0.753, blue: 0.753)
    public static let bronze = Color(red: 0.804, green: 0.498, blue: 0.196)
    public static let success = Color(red: 0.294, green: 0.710, blue: 0.263) // #4BB543
    public static let errorRed = Color(red: 0.827, green: 0.184, blue: 0.184) // #D32F2F
    public static let warningOrange = Color(red: 1.000, green: 0.627, blue: 0.000) // #FFA000
    
    // Backgrounds for Themes
    public static let darkBackground = Color(red: 0.059, green: 0.059, blue: 0.071) // #0F0F12
    public static let dimBackground = Color(red: 0.098, green: 0.114, blue: 0.145) // #191D25
    public static let lightBackground = Color(red: 0.965, green: 0.969, blue: 0.976) // #F6F7F9
    
    // Cards
    public static let darkCard = Color(red: 0.102, green: 0.102, blue: 0.122)
    public static let dimCard = Color(red: 0.141, green: 0.161, blue: 0.200)
    public static let lightCard = Color.white
    
    // Gradients
    public static let primaryGradient = LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let musicGradient = LinearGradient(
        colors: [AppColors.musicPrimary, Color.black.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let goldGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 0.9, green: 0.6, blue: 0.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Theme Mode Enum
public enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "light"
    case dim = "dim"
    case night = "night"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .light: return "Claro"
        case .dim: return "Atenuado"
        case .night: return "Oscuro"
        }
    }
}

// MARK: - Theme Manager
@MainActor
public class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    @AppStorage("AppThemeMode") public var currentTheme: ThemeMode = .night
    
    public var backgroundColor: Color {
        switch currentTheme {
        case .light: return AppColors.lightBackground
        case .dim: return AppColors.dimBackground
        case .night: return AppColors.darkBackground
        }
    }
    
    public var cardColor: Color {
        switch currentTheme {
        case .light: return AppColors.lightCard
        case .dim: return AppColors.dimCard
        case .night: return AppColors.darkCard
        }
    }
    
    public var textPrimary: Color {
        switch currentTheme {
        case .light: return Color.black.opacity(0.87)
        case .dim, .night: return Color.white.opacity(0.95)
        }
    }
    
    public var textSecondary: Color {
        switch currentTheme {
        case .light: return Color.gray
        case .dim, .night: return Color.white.opacity(0.65)
        }
    }
    
    public var borderColor: Color {
        switch currentTheme {
        case .light: return Color.black.opacity(0.08)
        case .dim, .night: return Color.white.opacity(0.12)
        }
    }
}
