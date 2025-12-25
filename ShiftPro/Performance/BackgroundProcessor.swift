import Foundation
import SwiftData

/// Manages background processing of heavy operations to keep UI responsive
@MainActor
final class BackgroundProcessor {
    enum Priority {
        case high
        case normal
        case low

        var qos: DispatchQoS.QoSClass {
            switch self {
            case .high: return .userInitiated
            case .normal: return .utility
            case .low: return .background
            }
        }
    }

    struct Task: Identifiable {
        let id: UUID
        let name: String
        let priority: Priority
        let work: @Sendable () async throws -> Void

        init(name: String, priority: Priority = .normal, work: @escaping @Sendable () async throws -> Void) {
            self.id = UUID()
            self.name = name
            self.priority = priority
            self.work = work
        }
    }

    // MARK: - State

    private var activeTasks: [UUID: SwiftTask<Void, Error>] = [:]
    private var taskQueue: [Task] = []
    private let maxConcurrentTasks: Int = 3

    // MARK: - Scheduling

    func schedule(_ task: Task) async throws {
        // Add to queue
        taskQueue.append(task)

        // Sort by priority
        taskQueue.sort { lhs, rhs in
            UInt32(lhs.priority.qos.rawValue.rawValue) > UInt32(rhs.priority.qos.rawValue.rawValue)
        }

        // Process queue
        try await processQueue()
    }

    func scheduleImport(of shifts: [Shift], in context: ModelContext) async throws {
        let task = Task(name: "Import \(shifts.count) shifts", priority: .high) {
            // Process in batches to avoid memory spikes
            let batchSize = 100
            for batch in shifts.chunked(into: batchSize) {
                for shift in batch {
                    context.insert(shift)
                }
                try context.save()
            }
        }

        try await schedule(task)
    }

    func schedulePayPeriodCalculation(for periodId: PersistentIdentifier, context: ModelContext) async throws {
        let task = Task(name: "Calculate pay period", priority: .normal) {
            // Heavy calculation here
            // This would run in background without blocking UI
        }

        try await schedule(task)
    }

    // MARK: - Queue Processing

    private func processQueue() async throws {
        while !taskQueue.isEmpty && activeTasks.count < maxConcurrentTasks {
            guard let task = taskQueue.first else { break }
            taskQueue.removeFirst()

            let swiftTask = SwiftTask(priority: taskPriority(for: task.priority)) {
                try await task.work()
            }

            activeTasks[task.id] = swiftTask

            // Remove from active tasks when complete
            SwiftTask {
                _ = try? await swiftTask.value
                await MainActor.run {
                    self.activeTasks.removeValue(forKey: task.id)
                }
            }
        }
    }

    private func taskPriority(for priority: Priority) -> TaskPriority {
        switch priority {
        case .high: return .high
        case .normal: return .medium
        case .low: return .low
        }
    }

    // MARK: - Cancellation

    func cancelAll() {
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        taskQueue.removeAll()
    }

    func cancel(_ taskId: UUID) {
        if let task = activeTasks[taskId] {
            task.cancel()
            activeTasks.removeValue(forKey: taskId)
        }
        taskQueue.removeAll { $0.id == taskId }
    }

    // MARK: - Status

    var isProcessing: Bool {
        !activeTasks.isEmpty || !taskQueue.isEmpty
    }

    var activeTaskCount: Int {
        activeTasks.count
    }

    var queuedTaskCount: Int {
        taskQueue.count
    }
}

// MARK: - SwiftTask Typealias

private typealias SwiftTask = Task

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
