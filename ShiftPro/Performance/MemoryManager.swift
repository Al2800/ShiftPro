import Foundation
import UIKit

/// Memory management and optimization utilities
@MainActor
final class MemoryManager: ObservableObject {
    struct ImageCacheEntry {
        let image: UIImage
        let cost: Int  // Size in bytes
        let lastAccessed: Date
    }

    // MARK: - Configuration

    private let maxImageCacheSize: Int = 50 * 1024 * 1024  // 50MB
    private let imageCompressionQuality: CGFloat = 0.8

    // MARK: - State

    @Published private(set) var currentCacheSize: Int = 0

    private var imageCache: [String: ImageCacheEntry] = [:]
    private let cacheQueue = DispatchQueue(label: "com.shiftpro.memory", attributes: .concurrent)

    init() {
        setupMemoryWarningObserver()
    }

    // MARK: - Image Caching

    func cacheImage(_ image: UIImage, forKey key: String) {
        guard let data = image.jpegData(compressionQuality: imageCompressionQuality) else {
            return
        }

        let cost = data.count
        let entry = ImageCacheEntry(image: image, cost: cost, lastAccessed: Date())

        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // Remove old entry if exists
            if let existing = self.imageCache[key] {
                self.currentCacheSize -= existing.cost
            }

            // Add new entry
            self.imageCache[key] = entry
            self.currentCacheSize += cost

            // Evict if needed
            if self.currentCacheSize > self.maxImageCacheSize {
                self.evictImageCache()
            }
        }
    }

    func getImage(forKey key: String) -> UIImage? {
        cacheQueue.sync {
            guard var entry = imageCache[key] else { return nil }

            // Update access time
            entry = ImageCacheEntry(
                image: entry.image,
                cost: entry.cost,
                lastAccessed: Date()
            )
            imageCache[key] = entry

            return entry.image
        }
    }

    func removeImage(forKey key: String) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  let entry = self.imageCache.removeValue(forKey: key) else {
                return
            }

            self.currentCacheSize -= entry.cost
        }
    }

    func clearImageCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.imageCache.removeAll()
            self?.currentCacheSize = 0
        }
    }

    private func evictImageCache() {
        // Evict least recently used until under limit
        let sortedEntries = imageCache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }

        for (key, entry) in sortedEntries {
            guard currentCacheSize > maxImageCacheSize else { break }

            imageCache.removeValue(forKey: key)
            currentCacheSize -= entry.cost
        }
    }

    // MARK: - Data Compression

    func compressImage(_ image: UIImage, targetSizeKB: Int = 500) -> UIImage? {
        var quality: CGFloat = 1.0
        var data = image.jpegData(compressionQuality: quality)

        while let currentData = data, currentData.count > targetSizeKB * 1024 && quality > 0.1 {
            quality -= 0.1
            data = image.jpegData(compressionQuality: quality)
        }

        guard let compressedData = data else { return nil }
        return UIImage(data: compressedData)
    }

    @MainActor func downsampleImage(at url: URL, to pointSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions) else {
            return nil
        }

        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }

        return UIImage(cgImage: downsampledImage)
    }

    // MARK: - Memory Pressure Handling

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    @objc private func handleMemoryWarning() {
        // Clear 75% of image cache
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let sortedEntries = self.imageCache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
            let toRemove = sortedEntries.prefix(Int(Double(sortedEntries.count) * 0.75))

            for (key, entry) in toRemove {
                self.imageCache.removeValue(forKey: key)
                self.currentCacheSize -= entry.cost
            }
        }
    }

    // MARK: - Resource Cleanup

    func performMaintenanceCleanup() {
        // Remove images older than 1 hour
        let cutoff = Date().addingTimeInterval(-3600)

        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let oldEntries = self.imageCache.filter { $0.value.lastAccessed < cutoff }

            for (key, entry) in oldEntries {
                self.imageCache.removeValue(forKey: key)
                self.currentCacheSize -= entry.cost
            }
        }
    }
}
