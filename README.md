# OnboardingKit

An opinionated SwiftUI + Observation Swift package for first-run onboarding across
Ivens' Apple app portfolio. Apps provide an ordered collection of typed steps
and render each screen themselves; the package supplies one definition of
navigation, persisted progress, completion, replay, reset, and migration.

> **Important UI boundary:** OnboardingKit provides only the unstyled
> `OnboardingFlow` infrastructure container. It does not contain any concrete
> onboarding screen. Every app designs and implements its own screens so the
> experience matches that product's visual language. When designing or
> revising those screens, prefer relevant studies from the private
> [ScreenStudies](https://github.com/Jewel591/screenstudies/) repository as the
> visual source of truth. Its page implementation may be copied into the host
> app and adapted there, but ScreenStudies itself must never be added as a
> package, source-tree, or runtime dependency. Apart from product-specific copy,
> branding, data, and surrounding app shell, preserve the selected study's
> layout, spacing, shape language, color roles, type hierarchy, interactions,
> and documented details as faithfully as possible.

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

Render the app-owned screens inside the Kit's fixed navigation container:

```swift
OnboardingFlow(controller: controller) { step in
    switch step {
    case .welcome: WelcomeView(onContinue: controller.advance)
    case .notifications: NotificationsView(onContinue: requestNotifications)
    case .location: LocationView(onContinue: requestLocation)
    case .ready: ReadyView(onComplete: finishOnboarding)
    }
}
```

The first plan step is the stack root. Every later step receives the system
back button and interactive-pop behavior automatically. The app chooses any
positive number of steps; adding or removing a page requires no navigation
configuration. Do not hide or replace the system navigation bar on individual
onboarding screens.

Onboarding should be a leaf root-gate flow: conditionally show it before the
app's main navigation, or present it as an isolated full-screen flow. An app may
have its own outer `NavigationStack`; the two stacks do not share paths. Do not
push onboarding's internal steps from the app stack, present onboarding as a
normal destination with a second exit-back meaning, or add another
`NavigationStack` inside an onboarding screen.

Use `navigationDirection`, `currentPosition`, and `stepCount` for host-owned
progress UI. Call `beginReplay()` from a user-initiated "View onboarding again"
entry without resetting completion.

## Permission boundary

OnboardingKit contains no permission functionality. It does not import a
permission framework, query or request authorization, model authorization
status, manage request-in-flight state, provide Settings recovery, declare
usage descriptions, or decide which capability an app needs. Notification,
location, photos, camera, microphone, speech, tracking, and similar access are
app-wide capabilities that must remain owned by the host app's permission
service.

This boundary prevents onboarding from becoming a second authorization source
of truth and keeps permission behavior correct when the same capability is used
elsewhere in the app. It also prevents a generic package from hiding
platform-specific purpose strings, entitlements, status changes, and recovery
behavior that App Review evaluates in the context of the actual product.

Host apps must follow these defaults:

- Inventory every protected capability the app actually uses. Add a dedicated
  host-owned acquisition step for each one to the onboarding plan; an
  education-only page that never calls the host permission service does not
  satisfy this integration contract.
- Notification acquisition is included by default across the app portfolio,
  because most apps need reminders, result delivery, or other user-chosen
  updates. Omit it only when the app has an explicit product decision that it
  has no notification use case.
- Trigger each request only from that permission page's explicit, neutral user
  action. Never request from app launch, object initialization, `onAppear`, or
  an automatic `.task`, and never chain several system prompts from one tap.
- Request only the minimum access level needed and keep authorization status in
  one app-wide service. Treat denial and restriction as normal states.
- Never require notification, location, tracking, or unrelated protected data
  merely to finish onboarding or use unrelated/core functionality. Provide an
  alternative when practical and keep forward navigation available.
- Use complete, specific purpose strings. After denial, explain the unavailable
  feature and offer Settings recovery when useful; don't repeatedly call an API
  that can no longer display the system prompt.
- When authorization was decided on an earlier install or feature use, do not
  expect iOS to show the alert again. Read the app-wide service's current
  status, keep onboarding moving, and expose Settings recovery where useful.
- Don't imitate the system alert, tell people which system choice to tap, offer
  incentives, or use misleading custom “Allow” controls.

Apple explicitly warns against launch-time requests without a functional need
and against manipulating or forcing consent. See Apple's
[Privacy HIG](https://developer.apple.com/design/human-interface-guidelines/privacy),
[App Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy),
and [protected-resource guidance](https://developer.apple.com/documentation/uikit/requesting-access-to-protected-resources).

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

- All concrete screen UI, including strings, illustrations, custom styling,
  animations, and custom page transitions. Each host app owns these and should prefer
  relevant private [ScreenStudies](https://github.com/Jewel591/screenstudies/)
  research when choosing an onboarding design.
- All permission functionality: APIs, authorization truth, prompt interaction
  state, purpose strings, entitlements, Settings recovery, and permission policy
- Authentication, subscription, paywalls, and business-data initialization
- What's New content and feature-level education
- Cross-surface arbitration and sheet serialization
- Remote-configured onboarding or arbitrary workflow graphs

## Requirements

- iOS 17+ / macOS 14+ / visionOS 1+
- Swift 6

Agent integration guidance lives in
`.agents/skills/integrate-onboardingkit/SKILL.md`.
