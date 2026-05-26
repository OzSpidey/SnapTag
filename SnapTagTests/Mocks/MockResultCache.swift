import Foundation
@testable import SnapTag

final class MockResultCache: ResultCacheProtocol, @unchecked Sendable {
    private var storage: [String: AnalysisResult] = [:]
    private(set) var storeCallCount = 0
    private(set) var hitCount = 0

    func result(for hash: ImageHash) -> AnalysisResult? {
        let result = storage[hash.value]
        if result != nil { hitCount += 1 }
        return result
    }

    func store(_ result: AnalysisResult, for hash: ImageHash) {
        storeCallCount += 1
        storage[hash.value] = result
    }

    func evictAll() {
        storage.removeAll()
    }
}
