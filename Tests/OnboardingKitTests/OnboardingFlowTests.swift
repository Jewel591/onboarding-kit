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

/// The footer slot is additive for inferred call sites: a flow whose steps
/// carry their own actions keeps compiling against the two-argument form, and
/// resolves to `Footer == EmptyView` rather than picking up an inset it never
/// asked for. Explicit `OnboardingFlow<Step, Content>` spellings need the
/// third generic parameter.
@MainActor
@Test
func flowWithoutFooterStaysFooterless() throws {
    let flow = OnboardingFlow(controller: try makeController()) { step in
        Text(step.rawValue)
    }

    #expect(type(of: flow) == OnboardingFlow<FlowStep, Text, EmptyView>.self)
}

/// The opt-in form carries the host's footer type through. The footer is a
/// sibling of the stack: mounted once, and its height comes out of the stack's
/// frame so every pushed page lays out above it.
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
