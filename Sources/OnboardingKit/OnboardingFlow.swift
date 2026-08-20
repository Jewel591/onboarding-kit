import SwiftUI

/// A fixed, unstyled navigation container for a host-owned onboarding flow.
///
/// The host supplies every screen. OnboardingKit supplies the system
/// `NavigationStack`, value-based path, back button, and interactive-pop
/// synchronization for the controller's variable-length plan.
@MainActor
public struct OnboardingFlow<Step: OnboardingStep, Content: View>: View {
    @Bindable private var controller: OnboardingController<Step>
    private let content: (Step) -> Content

    public init(
        controller: OnboardingController<Step>,
        @ViewBuilder content: @escaping (Step) -> Content
    ) {
        self.controller = controller
        self.content = content
    }

    public var body: some View {
        NavigationStack(path: $controller.navigationPath) {
            content(controller.firstStep)
                .navigationDestination(for: Step.self, destination: content)
        }
    }
}
