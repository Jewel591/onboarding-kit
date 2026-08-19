import Foundation

public enum OnboardingDebugOverride: Equatable, Sendable {
    case forceCompleted
    case forceIncomplete

    /// Reads the fixed paired launch argument used across the app portfolio.
    /// Release builds always return `nil`.
    public static func fromProcessInfo(
        _ processInfo: ProcessInfo = .processInfo
    ) -> OnboardingDebugOverride? {
        #if DEBUG
        from(arguments: processInfo.arguments)
        #else
        nil
        #endif
    }

    static func from(arguments: [String]) -> OnboardingDebugOverride? {
        guard let keyIndex = arguments.firstIndex(of: "-OnboardingKit.completed") else {
            return nil
        }

        let valueIndex = arguments.index(after: keyIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }

        switch arguments[valueIndex].uppercased() {
        case "YES": return .forceCompleted
        case "NO": return .forceIncomplete
        default: return nil
        }
    }
}
