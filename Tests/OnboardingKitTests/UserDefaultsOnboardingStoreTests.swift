import Foundation
import Testing
@testable import OnboardingKit

private func makeDefaults() throws -> (UserDefaults, cleanup: () -> Void) {
    let suiteName = "OnboardingKitTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    return (defaults, { defaults.removePersistentDomain(forName: suiteName) })
}

@MainActor
@Test
func missingLegacyKeysLeavePackageCompletionAbsent() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }
    let store = UserDefaultsOnboardingStore(userDefaults: defaults)
    store.seedCompletion(fromLegacyKeys: ["legacy"])
    #expect(store.loadState().completion == nil)
}

@MainActor
@Test
func anyTrueLegacyKeySeedsCompleted() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }
    defaults.set(false, forKey: "legacy.v1")
    defaults.set(true, forKey: "legacy.v2")
    let store = UserDefaultsOnboardingStore(userDefaults: defaults)
    store.seedCompletion(fromLegacyKeys: ["legacy.v1", "legacy.v2"])
    #expect(store.loadState().completion == true)
}

@MainActor
@Test
func existingFalsePackageValueCannotBeReseededByLegacyTrue() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }
    defaults.set(false, forKey: UserDefaultsOnboardingStore.completionKey)
    defaults.set(true, forKey: "legacy")
    let store = UserDefaultsOnboardingStore(userDefaults: defaults)
    store.seedCompletion(fromLegacyKeys: ["legacy"])
    #expect(store.loadState().completion == false)
}

@MainActor
@Test
func allPresentFalseLegacyKeysSeedExplicitFalse() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }
    defaults.set(false, forKey: "legacy.v1")
    defaults.set(false, forKey: "legacy.v2")
    let store = UserDefaultsOnboardingStore(userDefaults: defaults)
    store.seedCompletion(fromLegacyKeys: ["legacy.v1", "legacy.v2"])
    #expect(store.loadState().completion == false)
}

@MainActor
@Test
func completionAndProgressRoundTripIndependently() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }
    let store = UserDefaultsOnboardingStore(userDefaults: defaults)

    store.setCompletion(false)
    store.setCurrentStepID("location")
    #expect(store.loadState() == OnboardingStoredState(
        completion: false,
        currentStepID: "location"
    ))

    store.setCurrentStepID(nil)
    #expect(store.loadState().currentStepID == nil)
}
