import Foundation

@MainActor
class DataSyncService {
    static let shared = DataSyncService()

    private let apiService = APIService.shared
    private var isSyncing = false

    private init() {}

    // MARK: - Full Sync on Login

    /// Sync all data from backend after login
    func syncAllFromBackend(
        bookStore: WordBookStore,
        progressStore: SectionProgressStore
    ) async throws {
        guard !isSyncing else {
            print("⏳ Sync already in progress, skipping")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        print("🔄 Starting full data sync from backend...")

        // 1. Sync wordbooks
        do {
            try await syncWordbooksFromBackend(bookStore: bookStore)
        } catch {
            print("❌ Failed to sync wordbooks: \(error)")
            throw error
        }

        // 2. Sync progress
        do {
            try await syncProgressFromBackend(progressStore: progressStore, bookStore: bookStore)
        } catch {
            print("❌ Failed to sync progress: \(error)")
            // Don't throw - progress sync failure shouldn't block everything
        }

        print("✅ Full data sync completed")
    }

    // MARK: - Wordbook Sync

    /// Download all wordbooks from backend and merge with local data
    private func syncWordbooksFromBackend(bookStore: WordBookStore) async throws {
        print("📚 Syncing wordbooks from backend...")

        let response = try await apiService.getWordbooks()
        print("📥 Received \(response.wordbooks.count) wordbooks from backend")

        // For now, we'll replace local data with backend data
        // In a production app, you'd want more sophisticated merging logic
        for wordbookSummary in response.wordbooks {
            // Skip template wordbooks - those are bundled locally
            if wordbookSummary.isTemplate {
                continue
            }

            // Get full wordbook details
            let detailResponse = try await apiService.getWordbook(id: wordbookSummary.id)
            let detail = detailResponse.wordbook

            // Convert API model to local model
            let wordEntries = detail.entries.map { entry in
                WordEntry(
                    id: UUID(uuidString: entry.id) ?? UUID(),
                    word: entry.lemma,
                    meaning: entry.definition
                )
            }

            let section = WordSection(
                id: UUID(uuidString: detail.id) ?? UUID(),
                title: detail.title,
                subtitle: detail.subtitle,
                words: wordEntries,
                targetPasses: detail.targetPasses
            )

            // Check if this wordbook already exists locally
            if bookStore.sections.contains(where: { $0.id == section.id }) {
                // Update existing
                bookStore.updateSection(section)
                print("  ✏️ Updated: \(section.title)")
            } else {
                // Add new
                bookStore.addSection(section)
                print("  ➕ Added: \(section.title)")
            }
        }

        print("✅ Wordbooks synced")
    }

    /// Upload all local wordbooks to backend
    func syncWordbooksToBackend(bookStore: WordBookStore) async {
        print("📤 Syncing wordbooks to backend...")

        for section in bookStore.sections {
            do {
                let entries = section.words.enumerated().map { index, word in
                    WordEntryPayload(
                        id: word.id.uuidString,
                        word: word.word,
                        meaning: word.meaning,
                        ordinal: index
                    )
                }

                // Try to update first (assumes it exists)
                do {
                    let _ = try await apiService.updateWordbook(
                        id: section.id.uuidString,
                        title: section.title,
                        subtitle: (section.subtitle?.isEmpty == false) ? section.subtitle : nil,
                        targetPasses: section.targetPasses,
                        entries: entries
                    )
                    print("  ✅ Updated: \(section.title)")
                } catch {
                    // If update fails, try to create
                    let _ = try await apiService.createWordbook(
                        title: section.title,
                        subtitle: (section.subtitle?.isEmpty == false) ? section.subtitle : nil,
                        targetPasses: section.targetPasses,
                        entries: entries
                    )
                    print("  ➕ Created: \(section.title)")
                }
            } catch {
                print("  ❌ Failed to sync \(section.title): \(error)")
            }
        }

        print("✅ Wordbooks sync to backend completed")
    }

    // MARK: - Progress Sync

    /// Download progress from backend
    private func syncProgressFromBackend(
        progressStore: SectionProgressStore,
        bookStore: WordBookStore
    ) async throws {
        print("📊 Syncing progress from backend...")

        let response = try await apiService.getSectionProgress()
        print("📥 Received progress for \(response.records.count) sections from backend")

        for progressData in response.records {
            guard let sectionId = UUID(uuidString: progressData.wordbookId) else {
                continue
            }

            // Check if this section exists locally
            guard bookStore.sections.contains(where: { $0.id == sectionId }) else {
                print("  ⚠️ Section \(progressData.wordbookId) not found locally, skipping")
                continue
            }

            // Update local progress
            progressStore.setProgress(
                for: sectionId,
                completedPages: progressData.completedPages,
                completedPasses: progressData.completedPasses
            )
            print("  ✅ Updated progress for section \(sectionId)")
        }

        print("✅ Progress synced")
    }

    /// Upload progress to backend
    func syncProgressToBackend(progressStore: SectionProgressStore, bookStore: WordBookStore) async {
        print("📤 Syncing progress to backend...")

        var progressItems: [SectionProgressItem] = []

        for section in bookStore.sections {
            let progress = progressStore.progress(for: section.id)
            progressItems.append(SectionProgressItem(
                wordbookId: section.id.uuidString,
                completedPages: progress.completedPages,
                completedPasses: progress.completedPasses
            ))
        }

        do {
            let _ = try await apiService.updateSectionProgress(items: progressItems)
            print("✅ Progress synced to backend (\(progressItems.count) sections)")
        } catch {
            print("❌ Failed to sync progress: \(error)")
        }
    }
}

