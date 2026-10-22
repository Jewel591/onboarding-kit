#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import OnboardingKit

private enum CoverStep: String, OnboardingStep {
    case welcome
}

@MainActor
private final class PresentingStore: OnboardingStoring {
    func loadState() -> OnboardingStoredState {
        OnboardingStoredState(completion: nil, currentStepID: nil)
    }

    func setCompletion(_ completed: Bool) {}

    func setCurrentStepID(_ stepID: String?) {}
}

private final class MarkerView: NSView {}

private struct Marker: NSViewRepresentable {
    let view: MarkerView

    func makeNSView(context: Context) -> MarkerView { view }

    func updateNSView(_ nsView: MarkerView, context: Context) {}
}

/// Jewel591/onboarding-kit#7: on iPhone Duo the system draws a vertical
/// toolbar inside the trailing safe-area inset. The cover must not clip the
/// flow's hit area to its safe-area frame, or taps on that toolbar fall
/// through to the isolated root and are lost. Here a flow view that extends
/// into a padded trailing inset stands in for the system bar.
@MainActor
@Test
func coverLetsTapsReachFlowContentInSafeAreaInset() throws {
    let controller = OnboardingController(
        plan: try OnboardingPlan([CoverStep.welcome]),
        store: PresentingStore()
    )
    #expect(controller.shouldPresent)

    let inset: CGFloat = 80
    let marker = MarkerView()
    let cover = OnboardingCover(controller: controller) {
        Color.clear
    } flow: {
        Marker(view: marker)
            .frame(width: inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .ignoresSafeArea()
    }
    .safeAreaPadding(.trailing, inset)

    let host = NSHostingView(rootView: cover)
    host.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host
    host.layoutSubtreeIfNeeded()

    let pointInInset = NSPoint(x: host.bounds.maxX - inset / 2, y: host.bounds.midY)
    let hit = host.hitTest(host.convert(pointInInset, to: host.superview))

    #expect(hit === marker)
    _ = window
}
#endif
