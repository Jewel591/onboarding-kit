# Migration reference

## Conflict precedence

A migration adopts OnboardingKit's fixed navigation, persistence, completion,
replay, reset, and debug semantics. If an app-local implementation conflicts
with those semantics and does not represent a concrete product requirement,
change the app and delete the old behavior instead of adding a compatibility
option to the Kit.

Keep host-owned UI, permission services, platform behavior, and product-specific
completion effects. “The old app already works this way” is not an exception;
an exception must describe a real product semantic the Kit cannot express.

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
    onboardingActive = false
    onboardingController.complete()
}
```

Both the final page and a visible Skip button call this helper. Adapt the
host-owned completion effects to the target app, then complete the controller.
Debug overrides are presentation fixtures and do not call this helper
automatically.

Do not import or call WhatsNewKit from this helper. Onboarding and What's New
own independent state: completing onboarding only releases the root gate. Once
that gate is released, let the app's surface coordinator reevaluate eligible
surfaces normally. WhatsNewKit advances its seen watermark only after the user
actually dismisses What's New.

## Permission pages

OnboardingKit provides no permission API or prompt state. If the migrated flow
mentions protected access, read [permission-design.md](permission-design.md)
and keep the entire implementation in the host app.
