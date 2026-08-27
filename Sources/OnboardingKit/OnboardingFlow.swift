import SwiftUI

/// A fixed, unstyled navigation container for a host-owned onboarding flow.
///
/// The host supplies every screen. OnboardingKit supplies the system
/// `NavigationStack`, value-based path, back button, and interactive-pop
/// synchronization for the controller's variable-length plan.
///
/// ## Flow-level footer
///
/// A flow whose primary call to action is the same control on every step can
/// pass one `footer`. The footer is built once, reads the controller for what
/// to show, and stays planted while step content pushes past it.
///
/// ```swift
/// OnboardingFlow(controller: controller) { step in
///     MyPage(step: step)
/// } footer: {
///     MyFooter(step: controller.currentStep, action: advance)
/// }
/// ```
///
/// Attaching the same inset from the host is not equivalent, which is why this
/// slot exists. Outside the stack — on `OnboardingFlow` itself — the inset
/// never reaches a pushed page's bounds, so trailing page content lays out
/// underneath the footer. Inside the host's `content` closure the bounds are
/// correct, but the closure is evaluated per destination, so the footer becomes
/// one mounting point per page and rides the push transition. The slot below is
/// the only position that gets both: a single planted footer whose height is
/// subtracted from every step's layout.
///
/// Reserving a fixed slot is a trade: it keeps the button baseline from moving
/// between steps, and it permanently removes that height from every page's
/// content area — including steps whose footer draws nothing. Size the footer
/// for the tallest step and check the shortest page still breathes.
@MainActor
public struct OnboardingFlow<Step: OnboardingStep, Content: View, Footer: View>: View {
    @Bindable private var controller: OnboardingController<Step>
    private let content: (Step) -> Content
    private let footer: () -> Footer

    public init(
        controller: OnboardingController<Step>,
        @ViewBuilder content: @escaping (Step) -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.controller = controller
        self.content = content
        self.footer = footer
    }

    public var body: some View {
        NavigationStack(path: $controller.navigationPath) {
            content(controller.firstStep)
                .navigationDestination(for: Step.self, destination: content)
                // Inside the stack, so the inset both shrinks each pushed
                // page's bounds and keeps the footer out of the push
                // transition. Neither holds when a host attaches this itself.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    footer()
                }
        }
    }
}

extension OnboardingFlow where Footer == EmptyView {
    /// A flow whose steps each carry their own actions.
    public init(
        controller: OnboardingController<Step>,
        @ViewBuilder content: @escaping (Step) -> Content
    ) {
        self.init(controller: controller, content: content) {
            EmptyView()
        }
    }
}
