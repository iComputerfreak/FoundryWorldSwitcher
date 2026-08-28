import Foundation

/// Serializes Discord message writes independently for each date poll.
actor DatePollMessageUpdateCoordinator {
    private struct PendingUpdate {
        let token: UUID
        let completion: Task<Void, Never>
    }

    private var pendingUpdates: [String: PendingUpdate] = [:]

    func perform<T: Sendable>(
        pollID: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let predecessor = pendingUpdates[pollID]?.completion
        let token = UUID()
        let operationTask = Task<Result<T, any Error>, Never> {
            await predecessor?.value
            do {
                return .success(try await operation())
            } catch {
                return .failure(error)
            }
        }
        let completion = Task<Void, Never> {
            _ = await operationTask.value
        }
        pendingUpdates[pollID] = PendingUpdate(token: token, completion: completion)

        let result = await operationTask.value
        if pendingUpdates[pollID]?.token == token {
            pendingUpdates[pollID] = nil
        }
        return try result.get()
    }
}
