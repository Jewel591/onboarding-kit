import Testing
@testable import OnboardingKit

private enum PlanStep: String, OnboardingStep {
    case welcome
    case permission
    case ready
}

@Test
func planAcceptsAnyPositiveStepCount() throws {
    let one = try OnboardingPlan([PlanStep.welcome])
    let three = try OnboardingPlan([PlanStep.welcome, .permission, .ready])

    #expect(one.count == 1)
    #expect(one.firstStep == .welcome)
    #expect(three.count == 3)
}

@Test
func planRejectsEmptyAndDuplicateIDs() {
    #expect(throws: OnboardingPlanError.empty) {
        try OnboardingPlan<PlanStep>([])
    }
    #expect(throws: OnboardingPlanError.duplicateStepID("welcome")) {
        try OnboardingPlan([PlanStep.welcome, .welcome])
    }
}
