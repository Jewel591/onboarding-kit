import SwiftUI

/// Root-gate presentation for onboarding.
///
/// Keeps the host app root mounted underneath and overlays ``OnboardingFlow``.
/// Completing onboarding dismisses the overlay downward, like a system cover.
/// The first-run overlay is already present, so launch does not slide the
/// cover up over a visible home screen.
@MainActor
public struct OnboardingCover<Step: OnboardingStep, Root: View, Flow: View>: View {
    @Bindable private var controller: OnboardingController<Step>
    @State private var isCoverVisible: Bool
    @State private var isolateRoot: Bool
    private let root: Root
    private let flow: Flow

    public init(
        controller: OnboardingController<Step>,
        @ViewBuilder root: () -> Root,
        @ViewBuilder flow: () -> Flow
    ) {
        self.controller = controller
        self.root = root()
        self.flow = flow()
        let presenting = controller.shouldPresent
        _isCoverVisible = State(initialValue: presenting)
        _isolateRoot = State(initialValue: presenting)
    }

    public var body: some View {
        ZStack {
            root
                .allowsHitTesting(!isolateRoot)
                .accessibilityHidden(isolateRoot)

            if isCoverVisible {
                flow
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .move(edge: .bottom)
                    ))
                    .zIndex(1)
            }
        }
        .onChange(of: controller.shouldPresent) { _, shouldPresent in
            if shouldPresent {
                isolateRoot = true
                isCoverVisible = true
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    isCoverVisible = false
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    if !controller.shouldPresent {
                        isolateRoot = false
                    }
                }
            }
        }
    }
}
