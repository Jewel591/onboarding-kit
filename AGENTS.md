# OnboardingKit

Public Swift package that standardizes first-run onboarding state and linear
navigation across Ivens' Apple app portfolio. Host apps own every screen and
all product-specific side effects.

## Product boundary

- The package never contains, exports, or prescribes an onboarding SwiftUI/UIKit
  `View`. Every host app implements screens that match its own product style.
  For onboarding UI design, prefer relevant research in the private
  [ScreenStudies](https://github.com/Jewel591/screenstudies/) repository before
  inventing a design from scratch. The selected page is the visual source of
  truth, not a moodboard: its Swift source may be copied into the host app, but
  ScreenStudies must not be imported as a package, source-tree, or runtime
  dependency. Only adapt product-specific copy, localization, branding, data,
  real service wiring, and the surrounding app shell. Preserve the study's
  layout, spacing, shape language, color roles, type hierarchy, interaction
  model, and documented research details as faithfully as possible. Follow the
  ScreenStudies root README migration contract and product-playbook `SS-*`
  rules when implementing or reviewing the UI.
- The package owns an ordered plan with any nonzero number of stable step IDs,
  forward/back navigation, navigation direction, current-step restoration,
  completion state, replay, reset, debug overrides, and legacy completion
  seeding.
- Host apps own all SwiftUI/UIKit rendering, copy, assets, animations, system
  permission APIs, Info.plist purpose strings, entitlements, authentication,
  paywalls, business-data setup, and completion side effects.
- The package owns zero permission functionality. Do not add permission
  framework imports, request APIs, authorization status, prompt interaction
  state, purpose strings, entitlements, Settings recovery, or permission policy.
  Permission is an app-wide capability whose single source of truth belongs to
  the host app, not an onboarding subsystem.
- Onboarding is a root gate before normal app content. It is not a
  SurfaceCoordinatorKit candidate. The host may publish an `onboardingActive`
  signal while the root gate is present.
- A version update or a changed step list never invalidates completion. New
  feature education belongs to WhatsNewKit or the feature itself.

## Fixed behavior

- Completion always wins over saved progress.
- Progress persists by stable step ID, never by array index. If a saved ID no
  longer exists, resume at the first current step.
- There is no separate `skip()` API. A user-facing Skip action calls
  `complete()` so the next launch stays quiet.
- `beginReplay()` never clears completion or mutates saved progress.
- Debug completion overrides are process-local and never write UserDefaults.
- `reset()` is the only public operation that deliberately clears completion.

## Host permission guidance

- Prefer onboarding education without requesting access; request in the real
  feature context when the person first uses the protected capability.
- If an onboarding request is justified, require an explicit user action and
  never trigger it during app/view/model initialization, `onAppear`, or an
  automatic task.
- Never make consent to notifications, location, tracking, or unrelated data a
  condition for completing onboarding or using unrelated/core functionality.
- Request minimum scope, keep one host-owned authorization truth, handle denial
  as expected, provide alternatives and Settings recovery where useful, and use
  accurate purpose strings.
- Avoid fake system alerts, custom “Allow” choices, incentives, prompt images,
  or instructions that pressure people toward the affirmative system choice.
- Treat violations as App Review risk, not merely UX preference. Follow Apple's
  [Privacy HIG](https://developer.apple.com/design/human-interface-guidelines/privacy)
  and [App Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy).

## Engineering

- Swift 6 strict concurrency. Public API supports iOS 17, macOS 14, and
  visionOS 1.
- Zero dependencies and no UI frameworks. Keep all mutable public state on
  `MainActor`.
- Persist only under the `OnboardingKit.` prefix. Host code may read legacy
  keys during one-time seeding but must not write package-owned keys.
- Every state or storage change requires focused Swift Testing coverage with
  an injected store or isolated UserDefaults suite. Never test against
  `.standard`.

## Companion tooling

- Keep `.agents/skills/integrate-onboardingkit/SKILL.md` aligned with public
  API, migration ordering, and the host completion hook contract.
- Keep product-playbook's `onboarding-kit-lint` aligned with the dependency
  URL and module-qualified construction API.
