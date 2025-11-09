import Foundation
import SwiftUI

@MainActor
class SyncStatusStore: ObservableObject {
    enum SyncState: Equatable {
        case idle
        case syncing
        case success
        case failed(String)
    }

    @Published var wordbookSyncState: SyncState = .idle
    @Published var progressSyncState: SyncState = .idle
    @Published var lastSyncTime: Date?
    @Published var showSyncError: Bool = false
    @Published var syncErrorMessage: String = ""

    // Track individual wordbook sync attempts
    private var failedSyncs: Set<UUID> = []

    func markWordbookSyncStarted() {
        wordbookSyncState = .syncing
    }

    func markWordbookSyncSuccess() {
        wordbookSyncState = .success
        lastSyncTime = Date()

        // Auto-hide success after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if case .success = wordbookSyncState {
                wordbookSyncState = .idle
            }
        }
    }

    func markWordbookSyncFailed(_ error: Error, wordbookId: UUID? = nil) {
        let errorMessage = error.localizedDescription
        wordbookSyncState = .failed(errorMessage)
        syncErrorMessage = "词书同步失败: \(errorMessage)"
        showSyncError = true

        if let id = wordbookId {
            failedSyncs.insert(id)
        }

        print("❌ Sync failed: \(errorMessage)")
    }

    func markProgressSyncStarted() {
        progressSyncState = .syncing
    }

    func markProgressSyncSuccess() {
        progressSyncState = .success
        lastSyncTime = Date()

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if case .success = progressSyncState {
                progressSyncState = .idle
            }
        }
    }

    func markProgressSyncFailed(_ error: Error) {
        let errorMessage = error.localizedDescription
        progressSyncState = .failed(errorMessage)
        syncErrorMessage = "进度同步失败: \(errorMessage)"
        showSyncError = true

        print("❌ Progress sync failed: \(errorMessage)")
    }

    func dismissError() {
        showSyncError = false
    }

    func hasFailedSync(for wordbookId: UUID) -> Bool {
        failedSyncs.contains(wordbookId)
    }

    func clearFailedSync(for wordbookId: UUID) {
        failedSyncs.remove(wordbookId)
    }

    func retryFailedSyncs() -> [UUID] {
        let failed = Array(failedSyncs)
        failedSyncs.removeAll()
        return failed
    }
}

// MARK: - Sync Status Banner View

struct SyncStatusBanner: View {
    let state: SyncStatusStore.SyncState

    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()

            case .syncing:
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在同步...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)

            case .success:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("已同步")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(20)

            case .failed:
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("同步失败")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state)
    }
}
