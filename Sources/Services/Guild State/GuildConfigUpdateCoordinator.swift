/// Serializes asynchronous guild configuration transitions that span persisted state and Discord writes.
actor GuildConfigUpdateCoordinator {
    private var predecessor: Task<Void, Never>?

    func perform<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let previous = predecessor
        let operationTask = Task<Result<T, any Error>, Never> {
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
