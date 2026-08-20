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
    }

    public var body: some View {
        ZStack {
            root

            if controller.shouldPresent {
                flow
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .move(edge: .bottom)
                    ))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: controller.shouldPresent)
    }
}
