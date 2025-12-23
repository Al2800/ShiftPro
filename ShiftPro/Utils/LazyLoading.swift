import Foundation
import SwiftUI
import SwiftData

/// Lazy loading utilities for efficient data access
struct LazyLoading {

    // MARK: - Lazy Query Wrapper

    /// Wraps a SwiftData query for lazy loading with pagination
    struct LazyQuery<T: PersistentModel> {
        let context: ModelContext
        let predicate: Predicate<T>?
        let sortDescriptors: [SortDescriptor<T>]
        let batchSize: Int

        init(
            context: ModelContext,
            predicate: Predicate<T>? = nil,
            sortDescriptors: [SortDescriptor<T>] = [],
            batchSize: Int = 50
        ) {
            self.context = context
            self.predicate = predicate
            self.sortDescriptors = sortDescriptors
            self.batchSize = batchSize
        }

        func fetch(offset: Int = 0, limit: Int? = nil) throws -> [T] {
            var descriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortDescriptors)
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit ?? batchSize
            return try context.fetch(descriptor)
        }

        func count() throws -> Int {
            var descriptor = FetchDescriptor<T>(predicate: predicate)
            return try context.fetchCount(descriptor)
        }
    }

    // MARK: - Lazy List Item

    /// Wrapper for lazy-loaded list items
    struct LazyItem<T: Identifiable> {
        enum State {
            case notLoaded
            case loading
            case loaded(T)
            case failed(Error)
        }

        let id: T.ID
        private(set) var state: State = .notLoaded

        init(id: T.ID) {
            self.id = id
        }

        mutating func markLoading() {
            state = .loading
        }

        mutating func markLoaded(_ item: T) {
            state = .loaded(item)
        }

        mutating func markFailed(_ error: Error) {
            state = .failed(error)
        }

        var item: T? {
            if case .loaded(let item) = state {
                return item
            }
            return nil
        }

        var isLoaded: Bool {
            if case .loaded = state {
                return true
            }
            return false
        }
    }
}

// MARK: - SwiftUI Components

struct LazyLoadingView<Content: View>: View {
    @Binding var isLoading: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            content()

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
    }
}

struct LazyLoadingList<Item: Identifiable, RowContent: View>: View {
    let items: [Item]
    let isLoading: Bool
    let hasMore: Bool
    let onLoadMore: () -> Void
    @ViewBuilder let rowContent: (Item) -> RowContent

    var body: some View {
        List {
            ForEach(items) { item in
                rowContent(item)
                    .onAppear {
                        // Load more when reaching the last item
                        if item.id == items.last?.id && hasMore && !isLoading {
                            onLoadMore()
                        }
                    }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
    }
}

// MARK: - Debounce Helper

@MainActor
final class DebouncedLoader: ObservableObject {
    private var task: Task<Void, Never>?
    private let delay: Duration

    init(delay: Duration = .milliseconds(300)) {
        self.delay = delay
    }

    func debounce(action: @escaping () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

// MARK: - Prefetch Helper

struct PrefetchTrigger: View {
    let threshold: Int  // Items from end to trigger
    let currentIndex: Int
    let totalItems: Int
    let onPrefetch: () -> Void

    var body: some View {
        Color.clear
            .frame(height: 0)
            .onAppear {
                if totalItems - currentIndex <= threshold {
                    onPrefetch()
                }
            }
    }
}

// MARK: - Batch Processor

struct BatchProcessor<T> {
    let batchSize: Int
    let items: [T]

    init(items: [T], batchSize: Int = 100) {
        self.items = items
        self.batchSize = batchSize
    }

    func process(_ processor: (ArraySlice<T>) throws -> Void) rethrows {
        var index = 0
        while index < items.count {
            let endIndex = min(index + batchSize, items.count)
            let batch = items[index..<endIndex]
            try processor(batch)
            index = endIndex
        }
    }

    func processAsync(_ processor: @escaping (ArraySlice<T>) async throws -> Void) async rethrows {
        var index = 0
        while index < items.count {
            let endIndex = min(index + batchSize, items.count)
            let batch = items[index..<endIndex]
            try await processor(batch)
            index = endIndex
        }
    }
}
