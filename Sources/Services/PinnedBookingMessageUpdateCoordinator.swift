/// Serializes pinned booking message refreshes so an older render cannot finish last.
actor PinnedBookingMessageUpdateCoordinator {
    private var predecessor: Task<Void, Never>?

    func perform(operation: @escaping @Sendable () async throws -> Void) async throws {
        let previous = predecessor
        let operationTask = Task<Result<Void, any Error>, Never> {
            await previous?.value
            do {
                return .success(try await operation())
            } catch {
                return .failure(error)
            }
        }
        predecessor = Task<Void, Never> {
            _ = await operationTask.value
        }
        return try await operationTask.value.get()
    }
}
