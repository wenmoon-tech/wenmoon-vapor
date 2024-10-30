extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var results = [T]()
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
}
