import Foundation

// MARK: - Time Ago & Date Formatter Utilities (GetTimeAgo.java equivalent)
public struct DateUtils {
    public static func timeAgo(from timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000.0 > 1000000000 ? timestamp / 1000.0 : timestamp)
        let now = Date()
        let seconds = Int(now.timeIntervalSince(date))
        
        if seconds < 60 {
            return "Hace un momento"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "Hace \(minutes) min"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "Hace \(hours) h"
        }
        let days = hours / 24
        if days < 7 {
            return "Hace \(days) d"
        }
        let weeks = days / 7
        if weeks < 4 {
            return "Hace \(weeks) sem"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "d 'de' MMMM"
        return formatter.string(from: date)
    }
    
    public static func formatDuration(seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    public static func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
