import Foundation

// MARK: - Protocol

protocol ResultCacheProtocol: Sendable {
    func result(for hash: ImageHash) -> AnalysisResult?
    func store(_ result: AnalysisResult, for hash: ImageHash)
    func evictAll()
}

// MARK: - NSCache Box

/// NSCache requires class-type values.
private final class CachedResultBox {
    let result: AnalysisResult
    init(_ result: AnalysisResult) { self.result = result }
}

// MARK: - Production Implementation

/// Thread-safe cache backed by NSCache. NSCache already handles memory pressure
/// eviction on its own, so no additional LRU bookkeeping is needed.
final class ResultCache: ResultCacheProtocol, @unchecked Sendable {

    private let cache: NSCache<NSString, CachedResultBox>

    init(countLimit: Int = 100, totalCostLimit: Int = 0) {
        cache = NSCache()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit   // 0 = no byte limit
        cache.name = "com.ozspidey.SnapTag.ResultCache"
    }

    func result(for hash: ImageHash) -> AnalysisResult? {
        cache.object(forKey: NSString(string: hash.value))?.result
    }

    func store(_ result: AnalysisResult, for hash: ImageHash) {
        cache.setObject(CachedResultBox(result), forKey: NSString(string: hash.value))
    }

    func evictAll() {
        cache.removeAllObjects()
    }
}
