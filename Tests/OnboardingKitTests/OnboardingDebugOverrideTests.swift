import Testing
@testable import OnboardingKit

@Test
func debugOverrideRequiresExactPairedArgument() {
    #expect(OnboardingDebugOverride.from(
        arguments: ["App", "-OnboardingKit.completed", "YES"]
    ) == .forceCompleted)
    #expect(OnboardingDebugOverride.from(
        arguments: ["App", "-OnboardingKit.completed", "NO"]
    ) == .forceIncomplete)
    #expect(OnboardingDebugOverride.from(
        arguments: ["App", "-OnboardingKit.completed"]
    ) == nil)
    #expect(OnboardingDebugOverride.from(
        arguments: ["App", "-OnboardingKit.completed-ish", "YES"]
    ) == nil)
}
