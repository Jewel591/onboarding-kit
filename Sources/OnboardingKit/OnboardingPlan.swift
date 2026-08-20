import Foundation

/// A host-defined onboarding step with a stable persisted identity.
public protocol OnboardingStep: Hashable, RawRepresentable, Sendable
where RawValue == String {}

public enum OnboardingPlanError: Error, Equatable, Sendable {
    case empty
    case duplicateStepID(String)
}

/// An immutable, ordered onboarding plan.
public struct OnboardingPlan<Step: OnboardingStep>: Sendable {
    public let steps: [Step]

    private let indexByID: [String: Int]

    public init<Steps: Collection>(_ steps: Steps) throws
    where Steps.Element == Step {
        let collected = Array(steps)
        guard !collected.isEmpty else {
            throw OnboardingPlanError.empty
        }

        var indexByID: [String: Int] = [:]
        for (index, step) in collected.enumerated() {
            guard indexByID.updateValue(index, forKey: step.rawValue) == nil else {
                throw OnboardingPlanError.duplicateStepID(step.rawValue)
            }
        }

        self.steps = collected
        self.indexByID = indexByID
    }

    public var firstStep: Step {
        // Construction proves non-emptiness; this does not need an unsafe unwrap.
        steps[steps.startIndex]
    }

    public var count: Int {
        steps.count
    }

    func index(for stepID: String) -> Int? {
        indexByID[stepID]
    }

    func index(of step: Step) -> Int? {
        index(for: step.rawValue)
    }
}
