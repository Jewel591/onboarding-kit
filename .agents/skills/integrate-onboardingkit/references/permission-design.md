# Host permission design

Read this reference whenever onboarding mentions notifications, location,
camera, microphone, photos, contacts, calendars, speech, tracking, Bluetooth,
local network, health data, or another protected capability.

## Boundary and rationale

OnboardingKit owns no permission functionality. Keep all of the following in
one host-owned, app-wide permission service:

- System framework imports and request calls
- Current authorization status and status-change observation
- Request-in-flight and repeated-tap handling
- Info.plist purpose strings, entitlements, and capability configuration
- Denied/restricted/error presentation and Settings recovery
- Decisions about required capability, minimum scope, and fallback behavior

Permissions outlive onboarding and are commonly used by settings, editors,
background services, and feature entry points. Modeling them again inside
onboarding creates two sources of truth and stale behavior after a person
changes access in Settings. A generic package also lacks the product context
needed to justify the request to the person and App Review.

## Preferred flow

1. Decide whether access is needed at all. Prefer pickers, share sheets, manual
   entry, or narrower APIs when they avoid broad protected-resource access.
2. Explain the concrete user benefit in the feature context. Prefer an
   education-only onboarding page, then request when the person first performs
   the action that needs access.
3. Trigger the system request only from a deliberate user action. Never request
   from app startup, dependency/view/view-model initialization, `onAppear`, or
   an automatic `.task`.
4. Request the minimum scope. Prefer When In Use location over Always unless
   continuous background access is essential; request only notification
   interaction types the app actually uses.
5. Read status from the host service before using the capability. People can
   change authorization in Settings at any time; never treat an onboarding Bool
   as durable authorization truth.
6. Treat denied, restricted, and request failure as ordinary states. Keep
   onboarding and unrelated/core functionality available, provide a manual or
   reduced-capability path where practical, and explain Settings recovery when
   it can help.
7. Use specific purpose strings that say what data is used for and the direct
   user benefit. Ensure every required usage-description key and entitlement is
   present before the request path ships.

For notifications, Apple recommends asking in context, such as after a person
creates something that can produce a reminder. Consider provisional
authorization only when quiet trial delivery fits the product; it is not a
generic substitute for an explicit request.

## If requesting during onboarding

Request during onboarding only when the page gives clear, immediate product
context. The button tap must directly lead to the system request; do not make
the request an incidental side effect of navigation.

If a dedicated custom screen immediately precedes the system alert, follow
Apple's pre-alert rules: use one neutral action such as Continue or Next that
clearly opens the system alert. Do not provide custom Allow/Deny choices, a
close/cancel escape on that pre-alert, an image or imitation of the system
alert, incentives, arrows, or instructions telling people which system choice
to select. The system alert owns the consent decision. After the system choice,
denial must not trap onboarding.

If permission is optional and doesn't justify a dedicated pre-alert, keep the
onboarding page educational and defer the request to the actual feature rather
than placing a second permission CTA beside onboarding navigation.

## Common mistakes to reject in review

- Requesting several permissions in sequence on first launch
- Triggering a request from initialization, `onAppear`, or automatic `.task`
- Requiring authorization to finish onboarding, dismiss a paywall, receive a
  reward, or use unrelated/core functionality
- Hiding or disabling Continue after denial, dismissal, restriction, or error
- Storing `hasRequestedPermission` or `granted` in onboarding as authorization
  truth instead of querying the system-backed host service
- Repeatedly calling a request API after denial instead of explaining Settings
  recovery
- Asking for broader access than the feature needs, such as Always location for
  a foreground-only feature or full photo-library access when a picker works
- Shipping vague purpose strings such as “needed for a better experience”
- Styling a custom button or screen to mimic the system alert or using “Allow”
  before the real alert
- Pressuring consent with incentives, warnings, countdowns, alert screenshots,
  arrows, or instructions to choose the affirmative system option
- Treating denial as an exceptional failure or silently disabling unrelated
  features

These are not merely conversion concerns. Apple's App Review Guidelines say
apps must respect permission settings, must not manipulate, trick, or force
consent to unnecessary access, and should provide alternatives where possible.
Apple also states that apps may not require people to enable notifications,
location services, tracking, or other system functionality to access app
functionality, content, or use.

## Apple sources

- [Human Interface Guidelines: Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)
- [App Review Guidelines 5.1.1: Data Collection and Storage](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [Requesting access to protected resources](https://developer.apple.com/documentation/uikit/requesting-access-to-protected-resources)
- [Asking permission to use notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [Requesting authorization to use location services](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)
