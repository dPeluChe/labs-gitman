import SwiftUI
import OSLog

struct AddPathSheet: View {
    @ObservedObject var viewModel: ProjectScannerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPath: String = ""
    @State private var isChoosingPath = false
    @State private var previewCount: Int? = nil
    @State private var isScanningPreview = false

    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.gitmonitor", category: "AddPath")

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Path to Monitor")
                        .font(.headline)
                    Text("Select a folder to scan for Git repositories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Current Selection & Preview
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text(selectedPath.isEmpty ? "No path selected" : (selectedPath as NSString).lastPathComponent)
                                    .font(.headline)
                                if !selectedPath.isEmpty {
                                    Text(selectedPath)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            Spacer()
                            
                            if !selectedPath.isEmpty {
                                Button("Clear") { selectedPath = ""; previewCount = nil }
                                    .font(.caption)
                            }
                        }

                        if !selectedPath.isEmpty {
                            Divider()
                            
                            if isScanningPreview {
                                HStack {
                                    ProgressView().controlSize(.small)
                                    Text("Scanning for repositories...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else if let count = previewCount {
                                HStack {
                                    Image(systemName: "arrow.triangle.branch")
                                        .foregroundColor(.purple)
                                    Text("Found \(count) Git repositories")
                                        .fontWeight(.medium)
                                    Spacer()
                                    if count > 0 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                    }
                                }
                                .font(.callout)
                            }
                        }
                    }
                    .padding(4)
                }

                // Suggestions / Existing Paths
                if selectedPath.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Suggested
                            if !suggestedPaths.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Suggested Paths")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(suggestedPaths, id: \.self) { path in
                                        SuggestedPathRow(
                                            path: path,
                                            isAdded: viewModel.getMonitoredPaths().contains(path),
                                            onTap: { selectPath(path) }
                                        )
                                    }
                                }
                            }
                            
                            // Monitored
                            if !viewModel.getMonitoredPaths().isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Monitored Paths")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(viewModel.getMonitoredPaths(), id: \.self) { path in
                                        MonitoredPathRow(
                                            path: path,
                                            onRemove: {
                                                viewModel.removeMonitoredPath(path)
                                                logger.info("Removed monitored path: \(path)")
                                                // Trigger update
                                                Task { await viewModel.scanAllProjects() }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer()

                // Actions
                HStack(spacing: 12) {
                    if selectedPath.isEmpty {
                         Button("Cancel") { dismiss() }
                             .keyboardShortcut(.cancelAction)
                        
                         Spacer()
                        
                         Button("Browse Folder...") { isChoosingPath = true }
                             .buttonStyle(.borderedProminent)
                    } else {
                        Button("Cancel") { selectedPath = ""; previewCount = nil }
                        
                        Spacer()
                        
                        Button("Add & Scan") {
                            if !viewModel.getMonitoredPaths().contains(selectedPath) {
                                viewModel.addMonitoredPath(selectedPath)
                            }
                            dismiss()
                            Task {
                                await viewModel.scanAllProjects()
                            }
                        }
                        .disabled(isScanningPreview)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .frame(width: 600, height: 550)
            .fileImporter(
                isPresented: $isChoosingPath,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectPath(url.path(percentEncoded: false))
                    }
                case .failure(let error):
                    logger.error("Failed to select path: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func selectPath(_ path: String) {
        selectedPath = path
        previewCount = nil
        isScanningPreview = true
        
        Task {
            // Quick recursive count logic
            let count = await countGitRepos(in: path)
            await MainActor.run {
                previewCount = count
                isScanningPreview = false
            }
        }
    }
    
    // Quick count without full Project generation
    private func countGitRepos(in path: String) async -> Int {
        var count = 0
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return 0 }
        
        // Check root
        if fileManager.fileExists(atPath: (path as NSString).appendingPathComponent(".git")) {
            count += 1
        }
        
        // Check children (depth 1 only for speed in preview? Or match ConfigStore logic?)
        // ConfigStore logic is depth 1 for subdirectories
        guard let items = try? fileManager.contentsOfDirectory(atPath: path) else { return count }
        
        for item in items {
            if item.hasPrefix(".") { continue }
            let itemPath = (path as NSString).appendingPathComponent(item)
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue else { continue }
            
            if fileManager.fileExists(atPath: (itemPath as NSString).appendingPathComponent(".git")) {
                count += 1
            }
        }
        return count
    }

    private var suggestedPaths: [String] {
        var paths: [String] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        
        // Common paths
        let candidates = ["code", "Projects", "Development", "src", "git"]
        
        for cand in candidates {
            let p = (home as NSString).appendingPathComponent(cand)
            if fileManager.fileExists(atPath: p) {
                paths.append(p)
            }
        }
        
        // Documents
         if let doc = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
             paths.append(doc)
         }

        return paths
    }
}

struct SuggestedPathRow: View {
    let path: String
    let isAdded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text((path as NSString).lastPathComponent)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isAdded {
                    Text("Added")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
    }
}

struct MonitoredPathRow: View {
    let path: String
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text((path as NSString).lastPathComponent)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }
}

#Preview {
    AddPathSheet(viewModel: ProjectScannerViewModel())
}
