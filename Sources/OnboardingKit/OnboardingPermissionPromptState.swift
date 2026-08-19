import Observation

/// Interaction state for an onboarding permission-education page.
@MainActor
@Observable
public final class OnboardingPermissionPromptState {
    public private(set) var hasAttemptedRequest = false
    public private(set) var isRequesting = false

    public init() {}

    /// Permission education is optional by portfolio policy.
    public var canAdvance: Bool { true }

    /// Performs one explicit host-owned request and ignores duplicate taps
    /// until it finishes. Returns false when another request is already active.
    @discardableResult
    public func performRequest(
        _ request: @MainActor () async throws -> Void
    ) async rethrows -> Bool {
        guard !isRequesting else {
            return false
        }

        isRequesting = true
        hasAttemptedRequest = true
        defer { isRequesting = false }
        try await request()
        return true
    }
}
