import Darwin.Mach
import Foundation
import os.log

/// Runtime performance monitoring and metrics collection
@MainActor
final class PerformanceMonitor: ObservableObject {
    struct Metric {
        let name: String
        let duration: TimeInterval
        let timestamp: Date
        let metadata: [String: String]
    }

    struct MemorySnapshot {
        let timestamp: Date
        let usedMemoryMB: Double
        let availableMemoryMB: Double

        var usagePercentage: Double {
            usedMemoryMB / (usedMemoryMB + availableMemoryMB) * 100
        }
    }

    // MARK: - State

    @Published private(set) var recentMetrics: [Metric] = []
    @Published private(set) var memorySnapshots: [MemorySnapshot] = []

    private let maxStoredMetrics = 100
    private let logger = Logger(subsystem: "com.shiftpro", category: "Performance")

    private var operationStartTimes: [String: Date] = [:]
    private var memoryTimer: DispatchSourceTimer?

    deinit {
        memoryTimer?.cancel()
    }

    // MARK: - Timing Measurement

    func startMeasuring(_ operationName: String) {
        operationStartTimes[operationName] = Date()
        logger.debug("Started: \(operationName)")
    }

    func endMeasuring(_ operationName: String, metadata: [String: String] = [:]) {
        guard let startTime = operationStartTimes.removeValue(forKey: operationName) else {
            logger.warning("No start time found for operation: \(operationName)")
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        let metric = Metric(
            name: operationName,
            duration: duration,
            timestamp: Date(),
            metadata: metadata
        )

        recentMetrics.insert(metric, at: 0)

        // Trim if needed
        if recentMetrics.count > maxStoredMetrics {
            recentMetrics = Array(recentMetrics.prefix(maxStoredMetrics))
        }

        logger.info("\(operationName) completed in \(String(format: "%.3f", duration * 1000))ms")

        // Warn if slow
        if duration > 0.1 {  // 100ms threshold
            logger.warning("\(operationName) took \(String(format: "%.3f", duration * 1000))ms - exceeds 100ms threshold")
        }
    }

    func measure<T>(_ operationName: String, metadata: [String: String] = [:], operation: () throws -> T) rethrows -> T {
        startMeasuring(operationName)
        defer { endMeasuring(operationName, metadata: metadata) }
        return try operation()
    }

    func measureAsync<T>(_ operationName: String, metadata: [String: String] = [:], operation: () async throws -> T) async rethrows -> T {
        startMeasuring(operationName)
        defer { endMeasuring(operationName, metadata: metadata) }
        return try await operation()
    }

    // MARK: - Memory Monitoring

    func captureMemorySnapshot() {
        let snapshot = MemorySnapshot(
            timestamp: Date(),
            usedMemoryMB: memoryUsedMB(),
            availableMemoryMB: memoryAvailableMB()
        )

        memorySnapshots.insert(snapshot, at: 0)

        // Keep last 50 snapshots
        if memorySnapshots.count > 50 {
            memorySnapshots = Array(memorySnapshots.prefix(50))
        }

        let usedMB = String(format: "%.1f", snapshot.usedMemoryMB)
        let usagePct = String(format: "%.1f", snapshot.usagePercentage)
        logger.debug("Memory: \(usedMB)MB used (\(usagePct)%)")

        // Warn if high memory usage
        if snapshot.usagePercentage > 80 {
            logger.warning("High memory usage: \(String(format: "%.1f", snapshot.usagePercentage))%")
        }
    }

    func startMemoryMonitoring(interval: TimeInterval = 5.0) {
        memoryTimer?.cancel()
        memoryTimer = nil

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let monitor = self else { return }
            Task { @MainActor in
                monitor.captureMemorySnapshot()
            }
        }
        timer.resume()
        memoryTimer = timer
    }

    func stopMemoryMonitoring() {
        memoryTimer?.cancel()
        memoryTimer = nil
    }

    // MARK: - Statistics

    func averageDuration(for operationName: String) -> TimeInterval? {
        let matching = recentMetrics.filter { $0.name == operationName }
        guard !matching.isEmpty else { return nil }

        let total = matching.reduce(0) { $0 + $1.duration }
        return total / Double(matching.count)
    }

    func slowestOperations(limit: Int = 10) -> [Metric] {
        Array(recentMetrics.sorted { $0.duration > $1.duration }.prefix(limit))
    }

    func recentOperations(limit: Int = 20) -> [Metric] {
        Array(recentMetrics.prefix(limit))
    }

    // MARK: - Reporting

    func generatePerformanceReport() -> String {
        var report = "Performance Report\n"
        report += "==================\n\n"

        // Memory stats
        if let latestMemory = memorySnapshots.first {
            report += "Current Memory Usage:\n"
            report += "  Used: \(String(format: "%.1f", latestMemory.usedMemoryMB))MB\n"
            report += "  Usage: \(String(format: "%.1f", latestMemory.usagePercentage))%\n\n"
        }

        // Slowest operations
        report += "Slowest Operations:\n"
        for metric in slowestOperations(limit: 5) {
            report += "  \(metric.name): \(String(format: "%.3f", metric.duration * 1000))ms\n"
        }

        // Operation averages
        report += "\nAverage Durations:\n"
        let uniqueOperations = Set(recentMetrics.map { $0.name })
        for operation in uniqueOperations.sorted() {
            if let avg = averageDuration(for: operation) {
                report += "  \(operation): \(String(format: "%.3f", avg * 1000))ms\n"
            }
        }

        return report
    }

    func clearMetrics() {
        recentMetrics.removeAll()
        memorySnapshots.removeAll()
        operationStartTimes.removeAll()
    }

    // MARK: - Memory Helpers

    private func memoryUsedMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        return Double(info.resident_size) / 1024.0 / 1024.0
    }

    private func memoryAvailableMB() -> Double {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let freeBytes = Double(vmStats.free_count) * Double(pageSize)
        return freeBytes / 1024.0 / 1024.0
    }
}
