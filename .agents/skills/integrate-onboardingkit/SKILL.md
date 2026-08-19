---
name: integrate-onboardingkit
description: Integrate, migrate, review, or troubleshoot an Apple app that uses the OnboardingKit Swift package. Use when adding a first-run onboarding flow, replacing app-local onboarding navigation or UserDefaults completion state, supporting a variable number of onboarding pages, or auditing host-owned permission education inside onboarding.
---

# Integrate OnboardingKit

Use OnboardingKit as the single owner of onboarding navigation, completion, resumable progress, replay, debug overrides, and legacy completion migration. The host app owns every screen, every system permission API, and all app-specific completion side effects.

## Build host-owned screens

OnboardingKit contains no SwiftUI/UIKit onboarding `View`. Implement every
screen in the host app so it matches that app's visual language and project UI
rules.

When creating or redesigning onboarding screens, first look for a relevant
study in Ivens' private
[ScreenStudies](https://github.com/Jewel591/screenstudies/) repository and use
the selected page as the visual source of truth, not merely as inspiration. Its
Swift source may be copied into the host app and adapted there. Do not import
ScreenStudies as a package, source-tree, or runtime dependency, and do not move
that screen UI into OnboardingKit. Apart from product-specific copy,
localization, branding, data, real service wiring, and the surrounding app
shell, preserve the study's layout, spacing, shape language, color roles, type
hierarchy, interaction model, and documented research details as faithfully as
possible. Before editing UI, follow the ScreenStudies root README migration
contract and product-playbook `SS-*` rules. If the private repository is
unavailable, continue with the host app's established design system rather than
blocking the state-layer integration.

## Before editing

1. Read the target repository's `AGENTS.md` and its current onboarding implementation.
2. For UI work, load the `reference-screenstudies` skill, then read the
   ScreenStudies root migration contract, the target page's research notes,
   Swift implementation, and reference image before editing.
3. Read this package's `README.md` and public declarations under `Sources/OnboardingKit/`.
4. Inventory the existing ordered screens, completion/progress keys, launch arguments, permission calls, and completion side effects.
5. For a migration, read [references/migration-reference.md](references/migration-reference.md).
6. If onboarding mentions or requests protected access, read [references/permission-design.md](references/permission-design.md) before editing.

## Resolve migration conflicts

Treat migration as adoption of the Kit's fixed behavior, not as a requirement
to reproduce every legacy behavior. When the host implementation conflicts
with OnboardingKit and the Kit contract is the stronger portfolio default,
change the host to match the Kit and remove the old path in the same migration.
Do not add configuration to the Kit merely to preserve a weaker app-local
implementation.

Preserve only genuine host concerns: screen UI, product copy, app-specific
completion effects, system permission services, and platform-specific product
behavior. Record an exception only when the product has a concrete semantic
requirement that the fixed Kit contract cannot represent; a historical local
implementation is not by itself a reason for an exception.

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

OnboardingKit contains no permission functionality—not even prompt interaction
state. Keep `UNUserNotificationCenter`, Core Location, camera, microphone,
photos, speech, tracking, authorization truth, request de-duplication, Settings
recovery, purpose strings, and entitlements in the host app.

Prefer an education-only onboarding page and request authorization later, when
the person first uses the protected feature. If the product genuinely needs to
request during onboarding, require an explicit user action, request minimum
scope, and let denial or restriction continue through onboarding. Never request
from launch, initialization, `onAppear`, or an automatic task, and never gate
unrelated/core functionality on consent.

Read [references/permission-design.md](references/permission-design.md) for the
required host pattern, App Review rationale, and anti-pattern checklist.

## Debug and replay

- `-OnboardingKit.completed YES` hides onboarding for that debug process.
- `-OnboardingKit.completed NO` forces onboarding visible for that debug process.
- Neither argument writes `UserDefaults`.
- Use `beginReplay()` for a user-requested replay from Settings; it does not clear completion.
- Use `reset()` only for an explicit destructive developer/test reset.

## Migration checklist

- Inventory behavior conflicts and explicitly choose the Kit contract wherever
  it is the stronger portfolio default; delete the displaced host path.
- Replace app-local page index and completion state with one controller.
- Seed all shipped completion keys before controller initialization.
- Remove all remaining writers to the old keys in the same change.
- Keep page views and their content in the app.
- Keep all permission APIs, authorization truth, prompt state, recovery, and
  policy in the app; remove any attempted permission abstraction from the Kit.
- Preserve one common host completion helper for first-run final Continue and Skip; keep replay-only closure from repeating first-run effects.
- Verify a completed legacy install stays completed.
- Verify an interrupted flow resumes by stable step ID.
- Verify a removed saved ID falls back to the first current step.
- If the host requests protected access, verify denial, restriction, request
  failure, and repeated taps never trap onboarding or unrelated functionality.
- Run the package's `swift test` plus the target app's smallest relevant tests.
- Run the product-playbook `onboarding-kit-lint` required by the app's lifecycle stage.

## Red lines

- Do not put SwiftUI/UIKit screens, copy, colors, illustrations, analytics
  schemas, or product strategy parameters in the package. ScreenStudies source
  may be copied into a host app for faithful page migration, but never into
  OnboardingKit and never as an imported package/source-tree dependency.
- Do not put any permission concern in the package, including request APIs,
  authorization status, request-in-flight/attempted state, purpose strings,
  entitlements, Settings recovery, or policy.
- Do not key persisted progress by numeric page index.
- Do not version completion to replay onboarding after an app update.
- Do not add configurable policy objects for behavior already fixed by the package.
- Do not make onboarding a dependency of business modules or import app modules into the package.
