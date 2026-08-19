import Foundation

public struct OnboardingStoredState: Equatable, Sendable {
    /// `nil` means the package completion key has never been written.
    public let completion: Bool?
    public let currentStepID: String?

    public init(completion: Bool?, currentStepID: String?) {
        self.completion = completion
        self.currentStepID = currentStepID
    }
}

@MainActor
public protocol OnboardingStoring: AnyObject {
    func loadState() -> OnboardingStoredState
    func setCompletion(_ completed: Bool)
    func setCurrentStepID(_ stepID: String?)
}

/// UserDefaults persistence using package-owned, portfolio-wide key names.
@MainActor
public final class UserDefaultsOnboardingStore: OnboardingStoring {
    static let completionKey = "OnboardingKit.completed"
    static let currentStepKey = "OnboardingKit.currentStep"

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func loadState() -> OnboardingStoredState {
        let completion: Bool?
        if userDefaults.object(forKey: Self.completionKey) == nil {
            completion = nil
        } else {
            completion = userDefaults.bool(forKey: Self.completionKey)
        }

        return OnboardingStoredState(
            completion: completion,
            currentStepID: userDefaults.string(forKey: Self.currentStepKey)
        )
    }

    public func setCompletion(_ completed: Bool) {
        userDefaults.set(completed, forKey: Self.completionKey)
    }

    public func setCurrentStepID(_ stepID: String?) {
        if let stepID {
            userDefaults.set(stepID, forKey: Self.currentStepKey)
        } else {
            userDefaults.removeObject(forKey: Self.currentStepKey)
        }
    }

    /// Seeds completion from prior app-owned Bool keys exactly once.
    ///
    /// An existing package value, including explicit `false`, is authoritative.
    /// Any present true legacy key wins; present all-false keys seed false; all
    /// absent keys leave the package value absent.
    public func seedCompletion(fromLegacyKeys legacyKeys: [String]) {
        guard userDefaults.object(forKey: Self.completionKey) == nil else {
            return
        }

        var foundLegacyValue = false
        var anyCompleted = false
        for key in legacyKeys where userDefaults.object(forKey: key) != nil {
            foundLegacyValue = true
            anyCompleted = anyCompleted || userDefaults.bool(forKey: key)
        }

        guard foundLegacyValue else {
            return
        }
        userDefaults.set(anyCompleted, forKey: Self.completionKey)
    }
}
