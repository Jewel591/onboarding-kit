---
name: integrate-onboardingkit
description: Integrate, migrate, review, or troubleshoot an Apple app that uses the OnboardingKit Swift package. Use when adding a first-run onboarding flow, replacing app-local onboarding navigation or UserDefaults completion state, supporting a variable number of onboarding pages, or auditing host-owned permission education inside onboarding.
---

# Integrate OnboardingKit

Use OnboardingKit as the single owner of the onboarding-internal system navigation container, completion, resumable progress, replay, debug overrides, and legacy completion migration. The host app owns every concrete screen, every system permission API, and all app-specific completion side effects.

## Build host-owned screens

OnboardingKit contains two unstyled SwiftUI infrastructure views,
`OnboardingFlow` and `OnboardingCover`, but no concrete onboarding screen.
Implement every screen in the host app so it matches that app's visual language
and project UI rules.

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

Render host-owned pages inside the Kit container, and present that container
with `OnboardingCover` so the app root stays mounted under the overlay:

```swift
OnboardingCover(controller: controller) {
    MainTabView()
} flow: {
    OnboardingFlow(controller: controller) { step in
        switch step {
        case .welcome: WelcomeView(onContinue: controller.advance)
        case .capture: CaptureView(onContinue: controller.advance)
        case .notifications: NotificationsView(onContinue: requestNotifications)
        }
    }
}
```

The first configured step is the stack root. Every later step receives the
system back button and interactive-pop behavior automatically. Read
`currentPosition`, `stepCount`, and `navigationDirection` for app-owned progress
UI and animations. Use `advance()` for forward navigation; system back behavior
is fixed by `OnboardingFlow`, so do not recreate a host path adapter, hide or
replace the system navigation bar, or add per-screen back controls.

Do not write `if controller.shouldPresent { OnboardingFlow } else { appRoot }`.
That root swap animates `complete()` as a navigation pop to the first page.
`OnboardingCover` dismisses downward like a system cover; `complete()` freezes
the visible step and path so the overlay does not pop or jump back to page 1
while it slides away. Call `complete()` immediately from the host helper—do
not delay it for animation.
Gate any first-run-only root `.task` work with `!controller.shouldPresent` so
mounting the app underneath the cover does not start that work early.

The app may have its own outer `NavigationStack` as an independent scope.
Do not push onboarding's internal steps from the app stack, make onboarding a
normal app destination with a competing exit-back meaning, or nest another
`NavigationStack` inside an onboarding screen. UIKit hosts that wrap
`OnboardingFlow` in a hosting controller should dismiss that controller
themselves; the frozen path still prevents a visible pop during dismiss.

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

Inventory every protected capability the app actually uses. The host onboarding
plan must include a dedicated permission acquisition step for each capability;
an education-only page that merely advances without calling the host permission
service is incomplete. Notification acquisition is the portfolio default and
must be present for most apps. Omit it only when the app has an explicit product
decision that it has no notification use case.

On each permission page, one explicit neutral action calls the app-wide host
permission service and then allows onboarding to continue regardless of grant,
denial, restriction, or request failure. Never request from launch,
initialization, `onAppear`, or an automatic task, never burst several system
prompts from one action, and never gate unrelated/core functionality on
consent. If authorization was already decided, the system may show no alert;
read the host service's current status and provide Settings recovery where
useful instead of treating the missing alert as a failed request.

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
- Replace app-local `NavigationStack`, path binding, interactive-pop adapter,
  and back controls with `OnboardingFlow`.
- Replace a root `if shouldPresent` swap with `OnboardingCover` so completion
  dismisses downward. Keep `OnboardingFlow` inside that cover.
- Seed all shipped completion keys before controller initialization.
- Remove all remaining writers to the old keys in the same change.
- Keep page views and their content in the app.
- Keep all permission APIs, authorization truth, prompt state, recovery, and
  policy in the app; remove any attempted permission abstraction from the Kit.
- Inventory all host capabilities that require protected access and add one
  explicit onboarding acquisition step per capability. Include notifications
  by default; document the rare product exception that has no notification use
  case.
- Preserve one common host completion helper for first-run final Continue and Skip; keep replay-only closure from repeating first-run effects.
- Verify a completed legacy install stays completed.
- Test the app's real step plan and stable IDs; resume and removed-ID fallback algorithms themselves belong to OnboardingKit package tests.
- If the host requests protected access, verify denial, restriction, request
  failure, already-determined status, and repeated taps never trap onboarding
  or unrelated functionality. Verify each permission page actually calls its
  host service rather than only advancing.
- Run the package's `swift test` plus the target app's smallest relevant tests.
- Run the product-playbook `onboarding-kit-lint` required by the app's lifecycle stage.

## Host test boundary

- Test only app-owned screens/step IDs, first-run completion effects versus replay, real shipped completion-key migration, permission-service mapping, and the host's surface routing.
- Navigation, stable-ID persistence, resume/fallback, skip/completion state, frozen path after `complete()`, debug overrides, and replay mechanics are fixed OnboardingKit contracts and are tested in the package once.
- Do not inspect `project.pbxproj`, imports, source strings, or deleted host flow types from XCTest; assembly and residual implementation checks belong to `onboarding-kit-lint`.
- Use isolated `UserDefaults`, fake permission services, and public APIs. Do not request real system permission in unit tests. Identical helpers in two apps are a signal to move the missing seam and tests into OnboardingKit.

## Red lines

- Do not put concrete SwiftUI/UIKit screens, copy, colors, illustrations,
  custom navigation chrome, analytics schemas, or product strategy parameters
  in the package. `OnboardingFlow` and `OnboardingCover` are the only
  infrastructure-level UI exceptions. ScreenStudies source
  may be copied into a host app for faithful page migration, but never into
  OnboardingKit and never as an imported package/source-tree dependency.
- Do not put any permission concern in the package, including request APIs,
  authorization status, request-in-flight/attempted state, purpose strings,
  entitlements, Settings recovery, or policy.
- Do not key persisted progress by numeric page index.
- Do not version completion to replay onboarding after an app update.
- Do not add configurable policy objects for behavior already fixed by the package.
- Do not make onboarding a dependency of business modules or import app modules into the package.
