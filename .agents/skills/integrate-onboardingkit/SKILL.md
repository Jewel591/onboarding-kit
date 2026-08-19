---
name: integrate-onboardingkit
description: Integrate, migrate, review, or troubleshoot an Apple app that uses the OnboardingKit Swift package. Use when adding a first-run onboarding flow, replacing app-local onboarding navigation or UserDefaults completion state, supporting a variable number of onboarding pages, or coordinating permission prompts inside onboarding.
---

# Integrate OnboardingKit

Use OnboardingKit as the single owner of onboarding navigation, completion, resumable progress, replay, debug overrides, and legacy completion migration. The host app owns every screen, every system permission API, and all app-specific completion side effects.

## Before editing

1. Read the target repository's `AGENTS.md` and its current onboarding implementation.
2. Read this package's `README.md` and public declarations under `Sources/OnboardingKit/`.
3. Inventory the existing ordered screens, completion/progress keys, launch arguments, permission calls, and completion side effects.
4. For a migration, read [references/migration-reference.md](references/migration-reference.md).

## Add the package

Add the public package using an up-to-next-major requirement:

```text
https://github.com/Jewel591/onboarding-kit
```

Import `OnboardingKit` in the production application target. Do not copy package source into the app.

## Define the app-owned plan

The app chooses any positive number of pages. Give every page a stable string identifier; never use an array index as persisted identity.

```swift
import OnboardingKit

enum AppOnboardingStep: String, OnboardingStep {
    case welcome
    case capture
    case notifications
}

let plan = try OnboardingPlan([
    AppOnboardingStep.welcome,
    .capture,
    .notifications,
])
```

Changing page count is an app change only. Preserve existing raw values when reordering pages. If a saved step is removed, the Kit intentionally restarts at the first current step. A completed user is never re-onboarded merely because the plan changes.

## Construct the store and controller

Seed old completion keys before the first controller reads the store:

```swift
let store = UserDefaultsOnboardingStore()
store.seedCompletion(fromLegacyKeys: ["hasCompletedOnboarding"])

let controller = OnboardingKit.OnboardingController(
    plan: plan,
    store: store,
    debugOverride: .fromProcessInfo()
)
```

For a new app with no legacy key, omit `seedCompletion`. For a migration, include every historical completion key still present in shipped builds. The migration is intentionally one-way: once `OnboardingKit.completed` exists, even as explicit `false`, legacy values cannot overwrite it.

Render the host-owned page by switching on `controller.currentStep`. Read `currentPosition`, `stepCount`, `canGoBack`, and `navigationDirection` for app-owned controls and animation. Use `advance()` and `retreat()` for navigation.

User-facing Skip and final Continue both call the same app helper, which runs app-specific completion effects and then calls `controller.complete()`. Do not add a second skip state or skip key.

## Preserve host completion effects

OnboardingKit only records onboarding state. The app remains responsible for effects such as marking What's New as seen, clearing launch surfaces, or publishing `onboardingActive = false`.

Route first-run final Continue and user Skip through one host helper so these effects cannot diverge. A replay may call `controller.complete()` directly, or the helper may branch on `isReplaying`, when first-run-only effects must not repeat. A debug force-completed launch argument changes presentation only; it must not impersonate a real completion event or silently run one-time product effects.

Onboarding is the root launch gate. Do not enqueue it as a `SurfaceCoordinatorKit` candidate. The host may expose whether onboarding is active so lower-priority surfaces stay suppressed.

## Permissions

Keep `UNUserNotificationCenter`, Core Location, microphone, photos, speech, and other OS permission APIs in the app. Request them only after an explicit user action on the relevant page; never request from `onAppear`.

Use `OnboardingPermissionPromptState` only for local interaction state:

```swift
await permissionState.performRequest {
    try await notificationPermissionService.requestAuthorization()
}
```

It de-duplicates an in-flight request, records that an attempt occurred, and always leaves forward navigation available. Authorization status and Settings recovery remain owned by the app's permission service. Never create a second authorization truth inside onboarding, and never block Continue because the user denied or dismissed a permission prompt.

## Debug and replay

- `-OnboardingKit.completed YES` hides onboarding for that debug process.
- `-OnboardingKit.completed NO` forces onboarding visible for that debug process.
- Neither argument writes `UserDefaults`.
- Use `beginReplay()` for a user-requested replay from Settings; it does not clear completion.
- Use `reset()` only for an explicit destructive developer/test reset.

## Migration checklist

- Replace app-local page index and completion state with one controller.
- Seed all shipped completion keys before controller initialization.
- Remove all remaining writers to the old keys in the same change.
- Keep page views and their content in the app.
- Keep permission APIs and permission truth in the app.
- Preserve one common host completion helper for first-run final Continue and Skip; keep replay-only closure from repeating first-run effects.
- Verify a completed legacy install stays completed.
- Verify an interrupted flow resumes by stable step ID.
- Verify a removed saved ID falls back to the first current step.
- Verify denial, thrown permission requests, and repeated taps never trap navigation.
- Run the package's `swift test` plus the target app's smallest relevant tests.
- Run the product-playbook `onboarding-kit-lint` required by the app's lifecycle stage.

## Red lines

- Do not put SwiftUI/UIKit screens, copy, colors, illustrations, analytics schemas, or product strategy parameters in the package.
- Do not put OS permission requests or authorization status in the package.
- Do not key persisted progress by numeric page index.
- Do not version completion to replay onboarding after an app update.
- Do not add configurable policy objects for behavior already fixed by the package.
- Do not make onboarding a dependency of business modules or import app modules into the package.
