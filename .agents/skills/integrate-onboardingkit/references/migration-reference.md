# Migration reference

## Known shipped completion keys

These keys were found in the app matrix when OnboardingKit was created. Re-scan the target because a later release may have added another key.

| App | Legacy completion key |
|---|---|
| MONO | `HasCompletedOnboarding` |
| CodeCat | `HasCompletedOnboardingV2` |
| Apper | `hasCompletedOnboarding` |
| Filmo | `hasCompletedOnboarding5` |
| BodyWatch | `hasCompletedOnboarding6` |

Pass all keys ever shipped by that app to `seedCompletion(fromLegacyKeys:)`. If any legacy key is `true`, initial package completion becomes `true`. If legacy keys exist but all are `false`, initial package completion becomes explicit `false`. If no legacy key exists, the package key remains absent.

## Correct initialization order

```swift
@MainActor
func makeOnboardingController() throws -> OnboardingController<AppOnboardingStep> {
    let store = UserDefaultsOnboardingStore()
    store.seedCompletion(fromLegacyKeys: [
        "HasCompletedOnboarding",
        "HasCompletedOnboardingV2",
    ])

    let plan = try OnboardingPlan(AppOnboardingStep.allCases)
    return OnboardingController(
        plan: plan,
        store: store,
        debugOverride: .fromProcessInfo()
    )
}
```

Do not initialize the controller first and seed afterward; the controller deliberately takes its initial snapshot during initialization.

## One completion route

```swift
@MainActor
func finishOnboarding() {
    if onboardingController.isReplaying {
        onboardingController.complete()
        return
    }
    whatsNewCoordinator.markCurrentVersionSeen()
    onboardingController.complete()
    onboardingActive = false
}
```

Both the final page and a visible Skip button call this helper. Adapt the effects to the target app. Debug overrides are presentation fixtures and do not call this helper automatically.

## Permission-page pattern

```swift
Button("Enable Notifications") {
    Task {
        await permissionState.performRequest {
            try await notificationPermissionService.requestAuthorization()
        }
    }
}

Button("Continue") {
    onboardingController.advance()
}
.disabled(!permissionState.canAdvance) // currently always false
```

The host permission service owns current authorization status, Settings deep links, and platform-specific error handling. `OnboardingPermissionPromptState` owns only this prompt interaction's attempt/in-flight state.
