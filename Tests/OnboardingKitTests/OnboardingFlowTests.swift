import SwiftUI
import Testing
@testable import OnboardingKit

private enum FlowStep: String, OnboardingStep {
    case welcome
    case detail
}

@MainActor
private final class StubStore: OnboardingStoring {
    func loadState() -> OnboardingStoredState {
        OnboardingStoredState(completion: nil, currentStepID: nil)
    }

    func setCompletion(_ completed: Bool) {}

    func setCurrentStepID(_ stepID: String?) {}
}

@MainActor
private func makeController() throws -> OnboardingController<FlowStep> {
    OnboardingController(
        plan: try OnboardingPlan([FlowStep.welcome, .detail]),
        store: StubStore()
    )
}

/// The footer slot is additive: a flow whose steps carry their own actions
/// keeps compiling against the two-argument form, and resolves to a footer-less
/// specialization rather than picking up an inset it never asked for.
@MainActor
@Test
func flowWithoutFooterStaysFooterless() throws {
    let flow = OnboardingFlow(controller: try makeController()) { step in
        Text(step.rawValue)
    }

    #expect(type(of: flow) == OnboardingFlow<FlowStep, Text, EmptyView>.self)
}

/// The opt-in form carries the host's footer type through, which is what puts
/// the inset inside the stack where it can both plant the footer and shrink
/// each pushed page's bounds.
@MainActor
@Test
func flowWithFooterCarriesFooterType() throws {
    let flow = OnboardingFlow(controller: try makeController()) { step in
        Text(step.rawValue)
    } footer: {
        Button("Continue") {}
    }

    #expect(type(of: flow) == OnboardingFlow<FlowStep, Text, Button<Text>>.self)
}
