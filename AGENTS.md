# OnboardingKit

Public Swift package that standardizes first-run onboarding state and linear
navigation across Ivens' Apple app portfolio. Host apps own every screen and
all product-specific side effects.

## Product boundary

- The package owns an ordered plan with any nonzero number of stable step IDs,
  forward/back navigation, navigation direction, current-step restoration,
  completion state, replay, reset, debug overrides, legacy completion seeding,
  and the request-in-flight state shared by permission education pages.
- Host apps own all SwiftUI/UIKit rendering, copy, assets, animations, system
  permission APIs, Info.plist purpose strings, entitlements, authentication,
  paywalls, business-data setup, and completion side effects.
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
- Permission education never blocks navigation. The package coalesces an
  in-flight explicit request, but never imports or invokes a permission API.

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
