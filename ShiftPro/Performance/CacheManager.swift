import Foundation
import SwiftData
import UIKit

/// Intelligent caching system for calculated data to improve performance
actor CacheManager {
    enum CacheKey: String, Sendable {
        case payPeriodSummaries = "cache.payPeriod.summaries"
        case hoursCalculations = "cache.hours.calculations"
        case patternPreviews = "cache.pattern.previews"
        case calendarEvents = "cache.calendar.events"
        case rateBreakdowns = "cache.rate.breakdowns"
    }

    struct CachedValue<T: Codable>: Codable {
        let value: T
        let timestamp: Date
        let expiresAt: Date

        var isExpired: Bool {
            Date() > expiresAt
        }

        init(value: T, ttl: TimeInterval) {
            self.value = value
            self.timestamp = Date()
            self.expiresAt = Date().addingTimeInterval(ttl)
        }
    }

    // MARK: - Configuration

    private let defaultTTL: TimeInterval = 300  // 5 minutes
    private let memoryWarningThreshold: Int = 100  // Max items in memory

    // MARK: - Storage

    private var memoryCache: [String: Any] = [:]
    private var cacheAccessTimes: [String: Date] = [:]
    private var memoryWarningObserver: NSObjectProtocol?

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    init() {
        Task { @MainActor in
            self.setupMemoryWarningObserver()
        }
    }

    // MARK: - Generic Caching

    func get<T: Codable>(_ key: CacheKey, identifier: String? = nil) -> T? {
        let cacheKey = makeCacheKey(key, identifier: identifier)

        guard let cached = memoryCache[cacheKey] as? CachedValue<T> else {
            return nil
        }

        if cached.isExpired {
            memoryCache.removeValue(forKey: cacheKey)
            cacheAccessTimes.removeValue(forKey: cacheKey)
            return nil
        }

        cacheAccessTimes[cacheKey] = Date()
        return cached.value
    }

    func set<T: Codable>(_ key: CacheKey, value: T, identifier: String? = nil, ttl: TimeInterval? = nil) {
        let cacheKey = makeCacheKey(key, identifier: identifier)
        let cached = CachedValue(value: value, ttl: ttl ?? defaultTTL)

        memoryCache[cacheKey] = cached
        cacheAccessTimes[cacheKey] = Date()

        // Evict old entries if cache is too large
        if memoryCache.count > memoryWarningThreshold {
            evictLRU()
        }
    }

    func invalidate(_ key: CacheKey, identifier: String? = nil) {
        let cacheKey = makeCacheKey(key, identifier: identifier)
        memoryCache.removeValue(forKey: cacheKey)
        cacheAccessTimes.removeValue(forKey: cacheKey)
    }

    func invalidateAll(for key: CacheKey) {
        let prefix = key.rawValue
        let keysToRemove = memoryCache.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            memoryCache.removeValue(forKey: key)
            cacheAccessTimes.removeValue(forKey: key)
        }
    }

    func clearAll() {
        memoryCache.removeAll()
        cacheAccessTimes.removeAll()
    }

    // MARK: - Domain-Specific Caching

    func cachePayPeriodSummary(_ summary: HoursCalculator.PeriodSummary, for periodId: PersistentIdentifier) {
        set(.payPeriodSummaries, value: summary, identifier: periodId.stableHash, ttl: 600)  // 10 minutes
    }

    func getPayPeriodSummary(for periodId: PersistentIdentifier) -> HoursCalculator.PeriodSummary? {
        get(.payPeriodSummaries, identifier: periodId.stableHash)
    }

    func cacheRateBreakdown(_ breakdown: [PayPeriodCalculator.RateBucket], for shifts: [Shift]) {
        let identifier = shifts.map { $0.id.stableHash }.joined(separator: "-")
        set(.rateBreakdowns, value: breakdown, identifier: identifier, ttl: 300)
    }

    func getRateBreakdown(for shifts: [Shift]) -> [PayPeriodCalculator.RateBucket]? {
        let identifier = shifts.map { $0.id.stableHash }.joined(separator: "-")
        return get(.rateBreakdowns, identifier: identifier)
    }

    // MARK: - Cache Statistics

    func cacheStats() -> (itemCount: Int, oldestAccess: Date?, newestAccess: Date?) {
        let count = memoryCache.count
        let oldest = cacheAccessTimes.values.min()
        let newest = cacheAccessTimes.values.max()
        return (count, oldest, newest)
    }

    // MARK: - Private Helpers

    private func makeCacheKey(_ key: CacheKey, identifier: String?) -> String {
        if let identifier = identifier {
            return "\(key.rawValue).\(identifier)"
        }
        return key.rawValue
    }

    private func evictLRU() {
        // Remove least recently used items (oldest 25%)
        let sortedByAccess = cacheAccessTimes.sorted { $0.value < $1.value }
        let toRemove = sortedByAccess.prefix(memoryWarningThreshold / 4)

        for (key, _) in toRemove {
            memoryCache.removeValue(forKey: key)
            cacheAccessTimes.removeValue(forKey: key)
        }
    }

    @MainActor
    private func setupMemoryWarningObserver() {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.handleMemoryWarning()
            }
        }
    }

    private func handleMemoryWarning() {
        // Clear 50% of cache on memory warning
        let sortedByAccess = cacheAccessTimes.sorted { $0.value < $1.value }
        let toRemove = sortedByAccess.prefix(memoryCache.count / 2)

        for (key, _) in toRemove {
            memoryCache.removeValue(forKey: key)
            cacheAccessTimes.removeValue(forKey: key)
        }
    }
}

// MARK: - PersistentIdentifier Extension

extension PersistentIdentifier {
    var stableHash: String {
        "\(self.hashValue)"
    }
}
