# OnboardingKit

An opinionated Foundation + Observation Swift package for first-run onboarding across
Ivens' Apple app portfolio. Apps provide an ordered collection of typed steps
and render each screen themselves; the package supplies one definition of
navigation, persisted progress, completion, replay, reset, migration, and
permission-prompt interaction state.

## Fixed portfolio policy

- A plan contains any nonzero number of stable string-backed steps.
- Progress is restored by step ID. A removed or renamed ID falls back to the
  first current step.
- Completion wins over progress and survives app and onboarding revisions.
- Advancing from the last step completes onboarding.
- A user-facing Skip action also calls `complete()`; there is deliberately no
  second skip state.
- Replay is transient and never clears the completion waterline.
- Debug overrides are transient and never write persistent state.
- Permission education is always optional: a failed or denied request never
  disables forward navigation.

## Usage

```swift
import OnboardingKit

enum AppOnboardingStep: String, OnboardingStep {
    case welcome
    case notifications
    case location
    case ready
}

@MainActor
func makeOnboarding() throws -> OnboardingController<AppOnboardingStep> {
    let store = UserDefaultsOnboardingStore()
    store.seedCompletion(fromLegacyKeys: ["HasCompletedOnboarding"])

    let plan = try OnboardingPlan([
        .welcome, .notifications, .location, .ready,
    ])
    return OnboardingController(
        plan: plan,
        store: store,
        debugOverride: OnboardingDebugOverride.fromProcessInfo()
    )
}
```

The app switches over typed `currentStep` and owns every screen. Use
`navigationDirection`, `currentPosition`, and `stepCount` for host-owned
transitions and progress UI. Call `beginReplay()` from a user-initiated
"View onboarding again" entry without resetting completion.

## Permission education

`OnboardingPermissionPromptState` standardizes the part that belongs to the
onboarding experience: requests start only after an explicit user action,
duplicate taps are ignored while a request is in flight, attempted state is
observable, and `canAdvance` is always true.

The package deliberately does not query or request notifications, location,
photos, camera, microphone, or any other system capability. Those services
are app-wide infrastructure also used outside onboarding and remain the
host's single source of truth.

## Migration contract

Call `seedCompletion(fromLegacyKeys:)` before constructing the first
`OnboardingController`. Seeding only happens when the package completion key
does not exist. An explicit package value of `false`—for example after
`reset()`—is authoritative and is never overwritten by a surviving legacy
`true` value. Legacy keys are read but never updated or deleted by the package.

## Debug override

In Debug builds, use one paired launch argument:

```text
-OnboardingKit.completed YES
-OnboardingKit.completed NO
```

`YES` hides onboarding for the current process; `NO` forces it visible. Both
leave completion and saved progress untouched. Release builds ignore them.

## Deliberately out of scope

- Screen UI, strings, illustrations, animations, and page transitions
- System permission implementations, purpose strings, and entitlements
- Authentication, subscription, paywalls, and business-data initialization
- What's New content and feature-level education
- Cross-surface arbitration and sheet serialization
- Remote-configured onboarding or arbitrary workflow graphs

## Requirements

- iOS 17+ / macOS 14+ / visionOS 1+
- Swift 6

Agent integration guidance lives in
`.agents/skills/integrate-onboardingkit/SKILL.md`.
