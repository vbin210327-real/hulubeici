import Foundation
import CloudKit
import Combine

@MainActor
final class CloudKitSyncService {
    static let shared = CloudKitSyncService()

    private let container: CKContainer
    private let database: CKDatabase
    private let recordID = CKRecord.ID(recordName: "UserData")

    private var cancellables: Set<AnyCancellable> = []
    private var uploadTask: Task<Void, Never>? = nil
    private var isApplyingRemote = false

    private init() {
        let containerID = APIConfig.AppSyncConfig.iCloudContainerID
        self.container = CKContainer(identifier: containerID)
        self.database = container.privateCloudDatabase
    }

    // MARK: - Public API

    func bind(
        bookStore: WordBookStore,
        progressStore: SectionProgressStore,
        dailyProgressStore: DailyProgressStore,
        visibilityStore: WordVisibilityStore,
        userProfile: UserProfileStore
    ) {
        // Observe any change and debounce-upload a merged snapshot
        [bookStore.objectWillChange,
         progressStore.objectWillChange,
         dailyProgressStore.objectWillChange,
         visibilityStore.objectWillChange,
         userProfile.objectWillChange]
            .forEach { publisher in
                publisher
                    .receive(on: RunLoop.main)
                    .sink { [weak self] _ in self?.scheduleUpload(
                        bookStore: bookStore,
                        progressStore: progressStore,
                        dailyProgressStore: dailyProgressStore,
                        visibilityStore: visibilityStore,
                        userProfile: userProfile
                    ) }
                    .store(in: &cancellables)
            }
    }

    func initialPull(
        bookStore: WordBookStore,
        progressStore: SectionProgressStore,
        dailyProgressStore: DailyProgressStore,
        visibilityStore: WordVisibilityStore,
        userProfile: UserProfileStore
    ) async {
        guard APIConfig.AppSyncConfig.iCloudEnabled else { return }
        do {
            let record = try await database.record(for: recordID)
            guard let asset = record["payload"] as? CKAsset,
                  let url = asset.fileURL,
                  let data = try? Data(contentsOf: url) else {
                return
            }
            let snapshot = try JSONDecoder().decode(CloudSnapshot.self, from: data)
            try await apply(snapshot: snapshot,
                            bookStore: bookStore,
                            progressStore: progressStore,
                            dailyProgressStore: dailyProgressStore,
                            visibilityStore: visibilityStore,
                            userProfile: userProfile)
            print("✅ iCloud pull succeeded: \(snapshot.updatedAt)")
        } catch {
            // No record yet or other error – ignore on first run
            print("ℹ️ iCloud pull skipped/failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Upload

    private func scheduleUpload(
        bookStore: WordBookStore,
        progressStore: SectionProgressStore,
        dailyProgressStore: DailyProgressStore,
        visibilityStore: WordVisibilityStore,
        userProfile: UserProfileStore
    ) {
        guard APIConfig.AppSyncConfig.iCloudEnabled else { return }
        guard !isApplyingRemote else { return }

        uploadTask?.cancel()
        uploadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s debounce
            guard !Task.isCancelled else { return }
            do {
                let snapshot = buildSnapshot(
                    bookStore: bookStore,
                    progressStore: progressStore,
                    dailyProgressStore: dailyProgressStore,
                    visibilityStore: visibilityStore,
                    userProfile: userProfile
                )
                try await upload(snapshot: snapshot)
                print("📤 iCloud uploaded at \(snapshot.updatedAt)")
            } catch {
                print("❌ iCloud upload failed: \(error.localizedDescription)")
            }
        }
    }

    private func upload(snapshot: CloudSnapshot) async throws {
        // Write payload to temp file for CKAsset
        let data = try JSONEncoder().encode(snapshot)
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        try data.write(to: tmpURL)

        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "UserData", recordID: recordID)
        }

        record["updatedAt"] = snapshot.updatedAt as NSDate
        record["schemaVersion"] = snapshot.schemaVersion as NSNumber
        record["payload"] = CKAsset(fileURL: tmpURL)

        _ = try await database.modifyRecords(saving: [record], deleting: [])
        try? FileManager.default.removeItem(at: tmpURL)
    }

    // MARK: - Apply

    private func apply(
        snapshot: CloudSnapshot,
        bookStore: WordBookStore,
        progressStore: SectionProgressStore,
        dailyProgressStore: DailyProgressStore,
        visibilityStore: WordVisibilityStore,
        userProfile: UserProfileStore
    ) async throws {
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        // 1) Wordbooks: add/update (not deleting local extras to avoid surprise data loss)
        for section in snapshot.sections {
            if bookStore.sections.contains(where: { $0.id == section.id }) {
                bookStore.updateSection(section)
            } else {
                bookStore.addSection(section)
            }
        }

        // 2) Progress
        for (id, state) in snapshot.sectionProgress {
            progressStore.setProgress(for: id, completedPages: state.completedPages, completedPasses: state.completedPasses)
        }

        // 3) Daily
        dailyProgressStore.replaceAll(snapshot.dailyProgress)

        // 4) Visibility
        visibilityStore.replaceAll(hiddenWordIDs: snapshot.visibilityHiddenWordIDs,
                                   hiddenMeaningIDs: snapshot.visibilityHiddenMeaningIDs)

        // 5) Profile
        userProfile.userName = snapshot.profile.displayName
        userProfile.avatarEmoji = snapshot.profile.avatarEmoji
    }

    // MARK: - Build snapshot

    private func buildSnapshot(
        bookStore: WordBookStore,
        progressStore: SectionProgressStore,
        dailyProgressStore: DailyProgressStore,
        visibilityStore: WordVisibilityStore,
        userProfile: UserProfileStore
    ) -> CloudSnapshot {
        let sections = bookStore.sections
        var progress: [UUID: SectionProgressStore.ProgressState] = [:]
        for section in sections {
            progress[section.id] = progressStore.progress(for: section.id)
        }

        let daily = dailyProgressStore.allRecords()
        let vis = visibilityStore.currentSnapshot()
        let profile = CloudSnapshot.Profile(displayName: userProfile.userName, avatarEmoji: userProfile.avatarEmoji)

        return CloudSnapshot(
            sections: sections,
            sectionProgress: progress,
            dailyProgress: daily,
            visibilityHiddenWordIDs: vis.hiddenWordIDs,
            visibilityHiddenMeaningIDs: vis.hiddenMeaningIDs,
            profile: profile,
            updatedAt: Date(),
            schemaVersion: 1
        )
    }
}

// MARK: - Helpers

private extension CKDatabase {
    func record(for id: CKRecord.ID) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { cont in
            fetch(withRecordID: id) { record, error in
                if let record = record { cont.resume(returning: record) }
                else { cont.resume(throwing: error ?? NSError(domain: "CloudKit", code: -1)) }
            }
        }
    }

    func modifyRecords(saving: [CKRecord], deleting: [CKRecord.ID]) async throws -> (saved: [CKRecord], deleted: [CKRecord.ID]) {
        try await withCheckedThrowingContinuation { cont in
            let op = CKModifyRecordsOperation(recordsToSave: saving, recordIDsToDelete: deleting)
            op.savePolicy = .allKeys
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success: cont.resume(returning: (saving, deleting))
                case .failure(let error): cont.resume(throwing: error)
                }
            }
            self.add(op)
        }
    }
}

// MARK: - Snapshot Model

struct CloudSnapshot: Codable {
    struct Profile: Codable { let displayName: String; let avatarEmoji: String }

    let sections: [WordSection]
    let sectionProgress: [UUID: SectionProgressStore.ProgressState]
    let dailyProgress: [String: Int]
    let visibilityHiddenWordIDs: [UUID: Set<UUID>]
    let visibilityHiddenMeaningIDs: [UUID: Set<UUID>]
    let profile: Profile
    let updatedAt: Date
    let schemaVersion: Int
}

