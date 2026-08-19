import Testing
@testable import OnboardingKit

private enum PermissionTestError: Error {
    case denied
}

@MainActor
@Test
func permissionPromptNeverBlocksForwardNavigation() async {
    let state = OnboardingPermissionPromptState()
    #expect(state.canAdvance)
    let didStart = await state.performRequest {}
    #expect(didStart)
    #expect(state.hasAttemptedRequest)
    #expect(!state.isRequesting)
    #expect(state.canAdvance)
}

@MainActor
@Test
func duplicatePermissionTapIsIgnoredWhileRequestIsRunning() async {
    let state = OnboardingPermissionPromptState()
    let first = Task { @MainActor in
        await state.performRequest {
            try? await Task.sleep(for: .milliseconds(30))
        }
    }

    while !state.isRequesting {
        await Task.yield()
    }
    let secondDidStart = await state.performRequest {}
    let firstDidStart = await first.value

    #expect(firstDidStart)
    #expect(!secondDidStart)
    #expect(!state.isRequesting)
}

@MainActor
@Test
func thrownPermissionRequestStillClearsInFlightState() async {
    let state = OnboardingPermissionPromptState()

    await #expect(throws: PermissionTestError.denied) {
        try await state.performRequest {
            throw PermissionTestError.denied
        }
    }

    #expect(state.hasAttemptedRequest)
    #expect(!state.isRequesting)
    #expect(state.canAdvance)
}
