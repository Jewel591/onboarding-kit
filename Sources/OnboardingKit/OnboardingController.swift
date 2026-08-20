import Foundation
import Observation

public enum OnboardingNavigationDirection: Equatable, Sendable {
    case none
    case forward
    case backward
}

/// The single source of truth for a host app's linear onboarding flow.
@MainActor
@Observable
public final class OnboardingController<Step: OnboardingStep> {
    public private(set) var currentStep: Step
    public private(set) var navigationDirection: OnboardingNavigationDirection = .none
    public private(set) var isCompleted: Bool
    public private(set) var isReplaying = false

    private let plan: OnboardingPlan<Step>
    private let store: any OnboardingStoring
    private let debugOverride: OnboardingDebugOverride?
    /// Last visible stack, kept after `complete()` so the host can dismiss
    /// without `NavigationStack` popping back to the first step.
    private var dismissedNavigationPath: [Step]?

    public init(
        plan: OnboardingPlan<Step>,
        store: any OnboardingStoring = UserDefaultsOnboardingStore(),
        debugOverride: OnboardingDebugOverride? = nil
    ) {
        self.plan = plan
        self.store = store
        self.debugOverride = debugOverride

        let stored = store.loadState()
        let resolvedCompletion: Bool
        switch debugOverride {
        case .forceCompleted:
            resolvedCompletion = true
        case .forceIncomplete:
            resolvedCompletion = false
        case nil:
            resolvedCompletion = stored.completion == true
        }

        isCompleted = resolvedCompletion
        if !resolvedCompletion,
           let savedID = stored.currentStepID,
           let savedIndex = plan.index(for: savedID) {
            currentStep = plan.steps[savedIndex]
        } else {
            currentStep = plan.firstStep
        }
    }

    public var shouldPresent: Bool {
        isReplaying || !isCompleted
    }

    public var stepCount: Int {
        plan.count
    }

    /// One-based position for host-owned progress UI.
    public var currentPosition: Int {
        guard let index = plan.index(of: currentStep) else {
            return 1
        }
        return index + 1
    }

    public var canGoBack: Bool {
        currentPosition > 1
    }

    public var isLastStep: Bool {
        currentPosition == stepCount
    }

    /// The fixed value-based path used by ``OnboardingFlow``.
    ///
    /// The first plan step is the stack root, so only subsequent steps appear
    /// in the path. The setter accepts only a shorter valid prefix, which is
    /// how the system back button and interactive pop gesture report a pop.
    var navigationPath: [Step] {
        get {
            if let dismissedNavigationPath {
                return dismissedNavigationPath
            }
            return Array(plan.steps.dropFirst().prefix(max(currentPosition - 1, 0)))
        }
        set {
            guard dismissedNavigationPath == nil else { return }
            let availableSteps = plan.steps.dropFirst()
            guard newValue.count <= availableSteps.count,
                  Array(availableSteps.prefix(newValue.count)) == newValue,
                  newValue.count < navigationPath.count else {
                return
            }

            while navigationPath.count > newValue.count {
                retreat()
            }
        }
    }

    var firstStep: Step {
        plan.firstStep
    }

    /// Advances one step. Advancing from the last step completes onboarding.
    public func advance() {
        guard shouldPresent, let currentIndex = plan.index(of: currentStep) else {
            return
        }

        let nextIndex = currentIndex + 1
        guard plan.steps.indices.contains(nextIndex) else {
            complete()
            return
        }

        navigationDirection = .forward
        currentStep = plan.steps[nextIndex]
        persistProgressIfNeeded()
    }

    /// Moves back one step. The first step is a no-op.
    public func retreat() {
        guard shouldPresent, let currentIndex = plan.index(of: currentStep) else {
            return
        }

        let previousIndex = currentIndex - 1
        guard plan.steps.indices.contains(previousIndex) else {
            navigationDirection = .none
            return
        }

        navigationDirection = .backward
        currentStep = plan.steps[previousIndex]
        persistProgressIfNeeded()
    }

    /// Completes either a first-run presentation or a transient replay.
    /// User-facing Skip actions call this same method.
    ///
    /// The visible step and navigation path stay on the last page so the host
    /// can dismiss the flow like a cover. `beginReplay()` and `reset()` return
    /// to the first step; the next launch also starts at the first step.
    public func complete() {
        navigationDirection = .none
        if dismissedNavigationPath == nil {
            dismissedNavigationPath = Array(
                plan.steps.dropFirst().prefix(max(currentPosition - 1, 0))
            )
        }

        if isReplaying {
            isReplaying = false
            return
        }

        isCompleted = true
        guard debugOverride == nil else {
            return
        }
        store.setCompletion(true)
        store.setCurrentStepID(nil)
    }

    /// Starts a transient user-initiated replay without clearing completion.
    public func beginReplay() {
        guard isCompleted else {
            return
        }
        dismissedNavigationPath = nil
        isReplaying = true
        navigationDirection = .none
        currentStep = plan.firstStep
    }

    /// Deliberately clears persisted completion and progress.
    public func reset() {
        dismissedNavigationPath = nil
        store.setCompletion(false)
        store.setCurrentStepID(nil)
        isReplaying = false
        navigationDirection = .none
        currentStep = plan.firstStep
        isCompleted = debugOverride == .forceCompleted
    }

    private func persistProgressIfNeeded() {
        guard debugOverride == nil, !isReplaying, !isCompleted else {
            return
        }
        store.setCurrentStepID(currentStep.rawValue)
    }
}
