import Foundation
import OSLog

/// Manages persistent caching of project data to disk
/// Uses JSON format for simplicity and human-readability
actor CacheManager {
    private let logger = Logger(subsystem: "com.gitmonitor", category: "CacheManager")
    private let fileManager = FileManager.default
    
    // Throttling configuration
    private var lastSaveTime: Date = .distantPast
    private let saveThrottleInterval: TimeInterval = 30.0  // Min 30s between saves
    
    // MARK: - Cache File Location
    
    /// Returns the cache file URL, creating directories if needed
    private var cacheFileURL: URL {
        get throws {
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let gitManDir = appSupport.appendingPathComponent("GitMan", isDirectory: true)
            
            // Create GitMan directory if it doesn't exist
            if !fileManager.fileExists(atPath: gitManDir.path) {
                try fileManager.createDirectory(at: gitManDir, withIntermediateDirectories: true)
                logger.info("Created cache directory: \(gitManDir.path)")
            }
            
            return gitManDir.appendingPathComponent("projects.cache")
        }
    }
    
    // MARK: - Save Cache
    
    /// Save cache to disk with optional throttling
    /// - Parameters:
    ///   - cache: The cache data to save
    ///   - force: If true, bypasses throttling and saves immediately
    func saveCache(_ cache: ProjectCache, force: Bool = false) async throws {
        // Check throttling unless forced
        if !force {
            let elapsed = Date().timeIntervalSince(lastSaveTime)
            if elapsed < saveThrottleInterval {
                logger.debug("Save throttled (last save \(elapsed, format: .fixed(precision: 1))s ago)")
                return
            }
        }
        
        let url = try cacheFileURL
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(cache)
        
        // Write atomically to prevent corruption
        try data.write(to: url, options: [.atomic])
        
        lastSaveTime = Date()
        logger.info("Cache saved: \(cache.projects.count) projects, \(data.count) bytes")
    }
    
    // MARK: - Load Cache
    
    /// Load cache from disk
    /// - Returns: Cached data if available, nil if cache doesn't exist
    func loadCache() async throws -> ProjectCache? {
        let url = try cacheFileURL
        
        guard fileManager.fileExists(atPath: url.path) else {
            logger.info("No cache file found")
            return nil
        }
        
        let data = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let cache = try decoder.decode(ProjectCache.self, from: data)
        
        logger.info("Cache loaded: \(cache.projects.count) projects from \(cache.lastScanDate)")
        
        return cache
    }
    
    // MARK: - Cache Validation
    
    /// Check if cache is still valid based on age and configuration
    /// - Parameters:
    ///   - cache: The cache to validate
    ///   - maxAge: Maximum age in seconds (default: 1 hour)
    /// - Returns: True if cache is valid, false otherwise
    func isCacheValid(_ cache: ProjectCache, maxAge: TimeInterval = 3600) -> Bool {
        let age = Date().timeIntervalSince(cache.lastScanDate)
        let isValid = age < maxAge
        
        if !isValid {
            logger.debug("Cache expired: \(age, format: .fixed(precision: 0))s old (max: \(maxAge)s)")
        }
        
        return isValid
    }
    
    /// Check if monitored paths have changed since cache was created
    /// - Parameters:
    ///   - cache: The cache to validate
    ///   - currentPaths: Current monitored paths
    /// - Returns: True if paths match, false if they've changed
    func pathsMatch(_ cache: ProjectCache, currentPaths: [String]) -> Bool {
        let cached = Set(cache.monitoredPaths)
        let current = Set(currentPaths)
        
        let matches = cached == current
        
        if !matches {
            logger.warning("Monitored paths changed. Cached: \(cached.count), Current: \(current.count)")
        }
        
        return matches
    }
    
    // MARK: - Clear Cache
    
    /// Delete the cache file from disk
    func clearCache() async throws {
        let url = try cacheFileURL
        
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
            logger.info("Cache cleared")
        }
    }
    
    // MARK: - Cache Statistics
    
    /// Get cache file size and metadata
    func getCacheStats() async throws -> CacheStats? {
        let url = try cacheFileURL
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? UInt64 ?? 0
        let modificationDate = attributes[.modificationDate] as? Date
        
        return CacheStats(
            sizeBytes: size,
            lastModified: modificationDate
        )
    }
}

// MARK: - Data Models

/// Cache container for all project data
struct ProjectCache: Codable {
    /// Cache format version for future migrations
    var version: String = "1.0"
    
    /// When this cache was last updated
    var lastScanDate: Date
    
    /// Monitored paths at time of cache creation
    var monitoredPaths: [String]
    
    /// All projects with their hierarchical structure
    var projects: [Project]
    
    init(monitoredPaths: [String], projects: [Project]) {
        self.lastScanDate = Date()
        self.monitoredPaths = monitoredPaths
        self.projects = projects
    }
}

/// Cache file statistics
struct CacheStats {
    let sizeBytes: UInt64
    let lastModified: Date?
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(sizeBytes))
    }
}
