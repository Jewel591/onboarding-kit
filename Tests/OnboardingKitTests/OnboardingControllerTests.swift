import Testing
@testable import OnboardingKit

private enum TestStep: String, OnboardingStep {
    case welcome
    case permission
    case ready
    case addedLater
}

@MainActor
private final class MemoryStore: OnboardingStoring {
    var state: OnboardingStoredState
    private(set) var completionWrites: [Bool] = []
    private(set) var stepWrites: [String?] = []

    init(completion: Bool? = nil, currentStepID: String? = nil) {
        state = OnboardingStoredState(completion: completion, currentStepID: currentStepID)
    }

    func loadState() -> OnboardingStoredState { state }

    func setCompletion(_ completed: Bool) {
        completionWrites.append(completed)
        state = OnboardingStoredState(
            completion: completed,
            currentStepID: state.currentStepID
        )
    }

    func setCurrentStepID(_ stepID: String?) {
        stepWrites.append(stepID)
        state = OnboardingStoredState(
            completion: state.completion,
            currentStepID: stepID
        )
    }
}

@MainActor
private func makePlan(
    _ steps: [TestStep] = [.welcome, .permission, .ready]
) throws -> OnboardingPlan<TestStep> {
    try OnboardingPlan(steps)
}

@MainActor
@Test
func navigationDerivesFromVariablePlanAndPersistsStableID() throws {
    let store = MemoryStore()
    let controller = OnboardingController(plan: try makePlan(), store: store)

    #expect(controller.stepCount == 3)
    #expect(controller.currentPosition == 1)
    #expect(!controller.canGoBack)
    #expect(controller.navigationPath.isEmpty)

    controller.advance()
    #expect(controller.currentStep == .permission)
    #expect(controller.navigationDirection == .forward)
    #expect(controller.currentPosition == 2)
    #expect(controller.navigationPath == [.permission])
    #expect(store.state.currentStepID == "permission")

    controller.retreat()
    #expect(controller.currentStep == .welcome)
    #expect(controller.navigationDirection == .backward)
    #expect(store.state.currentStepID == "welcome")
}

@MainActor
@Test
func systemNavigationPopSynchronizesControllerAndPersistedProgress() throws {
    let store = MemoryStore()
    let controller = OnboardingController(plan: try makePlan(), store: store)
    controller.advance()
    controller.advance()
    #expect(controller.navigationPath == [.permission, .ready])

    controller.navigationPath = [.permission]

    #expect(controller.currentStep == .permission)
    #expect(controller.navigationDirection == .backward)
    #expect(controller.navigationPath == [.permission])
    #expect(store.state.currentStepID == "permission")
}

@MainActor
@Test
func navigationPathRejectsHostPushesAndInvalidPrefixes() throws {
    let store = MemoryStore()
    let controller = OnboardingController(plan: try makePlan(), store: store)
    controller.advance()

    controller.navigationPath = [.permission, .ready]
    #expect(controller.currentStep == .permission)

    controller.navigationPath = [.ready]
    #expect(controller.currentStep == .permission)
    #expect(controller.navigationPath == [.permission])
}

@MainActor
@Test
func firstStepRetreatIsNoOp() throws {
    let controller = OnboardingController(plan: try makePlan(), store: MemoryStore())
    controller.retreat()
    #expect(controller.currentStep == .welcome)
    #expect(controller.navigationDirection == .none)
}

@MainActor
@Test
func advancingFromLastStepCompletesAndClearsProgress() throws {
    let store = MemoryStore(currentStepID: "ready")
    let controller = OnboardingController(plan: try makePlan(), store: store)
    controller.advance()

    #expect(controller.isCompleted)
    #expect(!controller.shouldPresent)
    #expect(controller.currentStep == .welcome)
    #expect(store.state.completion == true)
    #expect(store.state.currentStepID == nil)
}

@MainActor
@Test
func completeFreezesNavigationPathSoHostDismissDoesNotPopToRoot() throws {
    let controller = OnboardingController(plan: try makePlan(), store: MemoryStore())
    controller.advance()
    controller.advance()
    let visiblePath = controller.navigationPath

    controller.complete()

    #expect(controller.isCompleted)
    #expect(!controller.shouldPresent)
    #expect(controller.currentStep == .welcome)
    #expect(controller.navigationPath == visiblePath)
    #expect(visiblePath == [.permission, .ready])
}

@MainActor
@Test
func replayClearsFrozenNavigationPath() throws {
    let store = MemoryStore(completion: true)
    let controller = OnboardingController(plan: try makePlan(), store: store)
    controller.beginReplay()
    controller.advance()
    controller.advance()
    controller.complete()
    #expect(controller.navigationPath == [.permission, .ready])

    controller.beginReplay()
    #expect(controller.currentStep == .welcome)
    #expect(controller.navigationPath.isEmpty)
}

@MainActor
@Test
func oneStepPlanCompletesOnFirstAdvance() throws {
    let store = MemoryStore()
    let controller = OnboardingController(
        plan: try makePlan([.welcome]),
        store: store
    )

    #expect(controller.stepCount == 1)
    #expect(controller.isLastStep)
    controller.advance()
    #expect(controller.isCompleted)
    #expect(!controller.shouldPresent)
}

@MainActor
@Test
func savedStableIDRestoresAcrossControllerInstances() throws {
    let controller = OnboardingController(
        plan: try makePlan(),
        store: MemoryStore(currentStepID: "permission")
    )
    #expect(controller.currentStep == .permission)
    #expect(controller.currentPosition == 2)
    #expect(controller.navigationPath == [.permission])
}

@MainActor
@Test
func removedSavedStepFallsBackToFirstCurrentStep() throws {
    let changedPlan = try makePlan([.welcome, .ready, .addedLater])
    let controller = OnboardingController(
        plan: changedPlan,
        store: MemoryStore(currentStepID: "permission")
    )
    #expect(controller.currentStep == .welcome)
}

@MainActor
@Test
func completionWinsOverChangedPlanAndStaleProgress() throws {
    let changedPlan = try makePlan([.addedLater, .ready])
    let controller = OnboardingController(
        plan: changedPlan,
        store: MemoryStore(completion: true, currentStepID: "permission")
    )
    #expect(controller.isCompleted)
    #expect(!controller.shouldPresent)
    #expect(controller.currentStep == .addedLater)
}

@MainActor
@Test
func replayNeverClearsCompletionOrWritesProgress() throws {
    let store = MemoryStore(completion: true)
    let controller = OnboardingController(plan: try makePlan(), store: store)

    controller.beginReplay()
    controller.advance()
    controller.complete()

    #expect(controller.isCompleted)
    #expect(!controller.shouldPresent)
    #expect(!controller.isReplaying)
    #expect(store.completionWrites.isEmpty)
    #expect(store.stepWrites.isEmpty)
}

@MainActor
@Test
func resetIsTheExplicitPersistentClear() throws {
    let store = MemoryStore(completion: true, currentStepID: "ready")
    let controller = OnboardingController(plan: try makePlan(), store: store)
    controller.reset()

    #expect(!controller.isCompleted)
    #expect(controller.shouldPresent)
    #expect(controller.currentStep == .welcome)
    #expect(store.state.completion == false)
    #expect(store.state.currentStepID == nil)
}

@MainActor
@Test
func debugOverridesNeverMutatePersistentState() throws {
    let completedStore = MemoryStore(completion: false, currentStepID: "permission")
    let hidden = OnboardingController(
        plan: try makePlan(),
        store: completedStore,
        debugOverride: .forceCompleted
    )
    #expect(hidden.isCompleted)

    let incompleteStore = MemoryStore(completion: true)
    let forcedVisible = OnboardingController(
        plan: try makePlan(),
        store: incompleteStore,
        debugOverride: .forceIncomplete
    )
    forcedVisible.advance()
    forcedVisible.complete()

    #expect(forcedVisible.isCompleted)
    #expect(incompleteStore.completionWrites.isEmpty)
    #expect(incompleteStore.stepWrites.isEmpty)
    #expect(incompleteStore.state.completion == true)
}
