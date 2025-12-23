import Foundation
import SwiftData

/// Pagination system for efficiently loading large datasets
@MainActor
final class DataPaginator<T: PersistentModel> {
    struct Page {
        let items: [T]
        let offset: Int
        let hasMore: Bool
    }

    // MARK: - Configuration

    let pageSize: Int
    private let context: ModelContext
    private var fetchDescriptor: FetchDescriptor<T>

    // MARK: - State

    private(set) var currentPage: Int = 0
    private(set) var totalLoaded: Int = 0
    private(set) var isLoading: Bool = false
    private(set) var hasMorePages: Bool = true

    // MARK: - Initialization

    init(
        context: ModelContext,
        fetchDescriptor: FetchDescriptor<T>,
        pageSize: Int = 50
    ) {
        self.context = context
        self.fetchDescriptor = fetchDescriptor
        self.pageSize = pageSize
    }

    // MARK: - Pagination

    func loadNextPage() async throws -> Page? {
        guard hasMorePages && !isLoading else {
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        // Calculate offset
        let offset = currentPage * pageSize

        // Create paginated fetch descriptor
        var paginatedDescriptor = fetchDescriptor
        paginatedDescriptor.fetchLimit = pageSize
        paginatedDescriptor.fetchOffset = offset

        // Fetch data
        let items = try context.fetch(paginatedDescriptor)

        // Update state
        hasMorePages = items.count == pageSize
        if !items.isEmpty {
            currentPage += 1
            totalLoaded += items.count
        }

        return Page(
            items: items,
            offset: offset,
            hasMore: hasMorePages
        )
    }

    func reset() {
        currentPage = 0
        totalLoaded = 0
        hasMorePages = true
        isLoading = false
    }

    func reload() async throws -> Page? {
        reset()
        return try await loadNextPage()
    }

    // MARK: - Prefetching

    func shouldPrefetch(at index: Int) -> Bool {
        // Prefetch when user is 80% through current page
        let threshold = totalLoaded - Int(Double(pageSize) * 0.2)
        return index >= threshold && hasMorePages && !isLoading
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

@MainActor
final class PaginatedList<T: PersistentModel>: ObservableObject {
    @Published private(set) var items: [T] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?

    private let paginator: DataPaginator<T>

    init(paginator: DataPaginator<T>) {
        self.paginator = paginator
    }

    func loadInitial() async {
        guard items.isEmpty else { return }
        await loadMore()
    }

    func loadMore() async {
        guard !paginator.isLoading else { return }

        isLoading = true
        error = nil

        do {
            if let page = try await paginator.loadNextPage() {
                items.append(contentsOf: page.items)
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func reload() async {
        items.removeAll()
        paginator.reset()
        await loadMore()
    }

    func shouldLoadMore(currentItem: T?) -> Bool {
        guard let item = currentItem else { return false }
        guard let index = items.firstIndex(where: { ObjectIdentifier($0) == ObjectIdentifier(item) }) else {
            return false
        }
        return paginator.shouldPrefetch(at: index)
    }
}
