import Foundation
import Darwin

enum EngagementProfileStore {
    enum StoreError: Error {
        case applicationSupportUnavailable
        case noActiveEngagement
        case activeProfileMismatch
        case profileTooLarge
        case unsafeProfileFile
    }

    private struct ActiveRecord: Codable {
        let engagementID: UUID
        let profileHash: String
    }

    private static let lock = NSRecursiveLock()

    static func save(_ profile: EngagementProfile, fileManager: FileManager = .default) throws {
        try synchronized {
            let data = try encodedProfile(profile)
            let directory = try profilesDirectory(fileManager: fileManager)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: draftProfileURL(profile.engagementID, fileManager: fileManager), options: .atomic)
        }
    }

    static func load(_ engagementID: UUID, fileManager: FileManager = .default) throws -> EngagementProfile {
        try synchronized {
            try decodeProfile(at: draftProfileURL(engagementID, fileManager: fileManager))
        }
    }

    static func activate(_ profile: EngagementProfile, now: Date = Date(), fileManager: FileManager = .default) throws {
        try synchronized {
            try profile.validate(now: now)
            let data = try encodedProfile(profile)
            let directory = try profilesDirectory(fileManager: fileManager)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            // Activation points at immutable content, never the mutable draft filename.
            let immutableURL = try immutableProfileURL(profile.engagementID, profileHash: profile.profileHash, fileManager: fileManager)
            if fileManager.fileExists(atPath: immutableURL.path) {
                guard try boundedData(at: immutableURL) == data else {
                    throw StoreError.activeProfileMismatch
                }
            } else {
                try data.write(to: immutableURL, options: .atomic)
            }
            try data.write(to: draftProfileURL(profile.engagementID, fileManager: fileManager), options: .atomic)

            let record = ActiveRecord(engagementID: profile.engagementID, profileHash: profile.profileHash)
            let recordData = try EngagementProfile.canonicalEncoder().encode(record)
            try recordData.write(to: activeURL(fileManager: fileManager), options: .atomic)
        }
    }

    static func loadActive(now: Date = Date(), fileManager: FileManager = .default) throws -> EngagementProfile {
        try synchronized {
            let url = try activeURL(fileManager: fileManager)
            guard fileManager.fileExists(atPath: url.path) else {
                throw StoreError.noActiveEngagement
            }
            let recordData = try boundedData(at: url)
            let record = try EngagementProfile.decoder().decode(ActiveRecord.self, from: recordData)
            let immutableURL = try immutableProfileURL(record.engagementID, profileHash: record.profileHash, fileManager: fileManager)
            let profile = try decodeProfile(at: immutableURL)
            guard profile.engagementID == record.engagementID,
                  profile.profileHash == record.profileHash else {
                throw StoreError.activeProfileMismatch
            }
            try profile.validate(now: now)
            return profile
        }
    }

    static func deactivate(fileManager: FileManager = .default) throws {
        try synchronized {
            let url = try activeURL(fileManager: fileManager)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    static func reset(fileManager: FileManager = .default) throws {
        try synchronized {
            let directory = try engagementDirectory(fileManager: fileManager)
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
        }
    }

    private static func synchronized<T>(_ work: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try work()
    }

    private static func encodedProfile(_ profile: EngagementProfile) throws -> Data {
        let data = try EngagementProfile.canonicalEncoder().encode(profile)
        guard data.count <= EngagementProfile.maximumProfileBytes else {
            throw StoreError.profileTooLarge
        }
        return data
    }

    private static func boundedData(at url: URL) throws -> Data {
        let descriptor = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path = path else { return -1 }
            return Darwin.open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        }
        guard descriptor >= 0 else { throw StoreError.unsafeProfileFile }
        defer { Darwin.close(descriptor) }

        var metadata = stat()
        guard Darwin.fstat(descriptor, &metadata) == 0,
              (metadata.st_mode & S_IFMT) == S_IFREG,
              metadata.st_size >= 0,
              metadata.st_size <= off_t(EngagementProfile.maximumProfileBytes) else {
            throw StoreError.unsafeProfileFile
        }

        let maximumRead = EngagementProfile.maximumProfileBytes + 1
        var data = Data()
        data.reserveCapacity(min(Int(metadata.st_size), EngagementProfile.maximumProfileBytes))
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)

        while data.count < maximumRead {
            let remaining = min(buffer.count, maximumRead - data.count)
            let count = Darwin.read(descriptor, &buffer, remaining)
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw StoreError.unsafeProfileFile
            }
            data.append(contentsOf: buffer.prefix(Int(count)))
        }
        guard data.count <= EngagementProfile.maximumProfileBytes else {
            throw StoreError.profileTooLarge
        }
        return data
    }

    private static func decodeProfile(at url: URL) throws -> EngagementProfile {
        try EngagementProfile.decoder().decode(EngagementProfile.self, from: boundedData(at: url))
    }

    private static func draftProfileURL(_ engagementID: UUID, fileManager: FileManager) throws -> URL {
        try profilesDirectory(fileManager: fileManager)
            .appendingPathComponent(engagementID.uuidString.lowercased())
            .appendingPathExtension("json")
    }

    private static func immutableProfileURL(_ engagementID: UUID, profileHash: String, fileManager: FileManager) throws -> URL {
        guard profileHash.count == 64,
              profileHash.unicodeScalars.allSatisfy({ (48...57).contains($0.value) || (97...102).contains($0.value) }) else {
            throw StoreError.activeProfileMismatch
        }
        return try profilesDirectory(fileManager: fileManager)
            .appendingPathComponent("\(engagementID.uuidString.lowercased())-\(profileHash)")
            .appendingPathExtension("json")
    }

    private static func activeURL(fileManager: FileManager) throws -> URL {
        try engagementDirectory(fileManager: fileManager).appendingPathComponent("active.json")
    }

    private static func profilesDirectory(fileManager: FileManager) throws -> URL {
        try engagementDirectory(fileManager: fileManager).appendingPathComponent("profiles", isDirectory: true)
    }

    private static func engagementDirectory(fileManager: FileManager) throws -> URL {
        guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw StoreError.applicationSupportUnavailable
        }
        return applicationSupport
            .appendingPathComponent("K3Browser", isDirectory: true)
            .appendingPathComponent("Engagement", isDirectory: true)
    }
}
