import SwiftUI
import OSLog

struct AddPathSheet: View {
    @ObservedObject var viewModel: ProjectScannerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPath: String = ""
    @State private var isChoosingPath = false

    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.gitmonitor", category: "AddPath")

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Path input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Path to Monitor")
                        .font(.headline)

                    Text("Select a folder to scan for Git repositories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Path display
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            Text(selectedPath.isEmpty ? "No path selected" : selectedPath)
                                .font(.caption)
                                .lineLimit(2)
                            Spacer()
                        }

                        if !selectedPath.isEmpty {
                            Divider()

                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(.caption2)
                                Text("All Git repos in this folder will be monitored")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Suggested paths
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Paths")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    VStack(spacing: 8) {
                        ForEach(suggestedPaths, id: \.self) { path in
                            SuggestedPathRow(
                                path: path,
                                isAdded: viewModel.getMonitoredPaths().contains(path),
                                onTap: {
                                    if !viewModel.getMonitoredPaths().contains(path) {
                                        viewModel.addMonitoredPath(path)
                                        logger.info("Added monitored path: \(path)")
                                    }
                                }
                            )
                        }
                    }
                }

                // Current monitored paths
                if !viewModel.getMonitoredPaths().isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monitored Paths")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        VStack(spacing: 8) {
                            ForEach(viewModel.getMonitoredPaths(), id: \.self) { path in
                                MonitoredPathRow(
                                    path: path,
                                    onRemove: {
                                        viewModel.removeMonitoredPath(path)
                                        logger.info("Removed monitored path: \(path)")
                                    }
                                )
                            }
                        }
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Browse...") {
                        isChoosingPath = true
                    }

                    Spacer()

                    Button("Scan Now") {
                        // Dismiss FIRST, then trigger scan
                        // This prevents blocking the UI inside the sheet
                        dismiss()
                        Task {
                            await viewModel.scanAllProjects()
                        }
                    }
                    .disabled(viewModel.getMonitoredPaths().isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 600, height: 500)
            .fileImporter(
                isPresented: $isChoosingPath,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedPath = url.path(percentEncoded: false)
                        if !viewModel.getMonitoredPaths().contains(selectedPath) {
                            viewModel.addMonitoredPath(selectedPath)
                        }
                    }
                case .failure(let error):
                    logger.error("Failed to select path: \(error.localizedDescription)")
                }
            }
        }
    }

    private var suggestedPaths: [String] {
        var paths: [String] = []

        // Add common development directories
        let homeDir = fileManager.homeDirectoryForCurrentUser.path

        // Code directory
        let codePath = (homeDir as NSString).appendingPathComponent("code")
        if fileManager.fileExists(atPath: codePath) {
            paths.append(codePath)
        }

        // Projects directory
        let projectsPath = (homeDir as NSString).appendingPathComponent("Projects")
        if fileManager.fileExists(atPath: projectsPath) {
            paths.append(projectsPath)
        }

        // Documents
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.path
        if let docs = documentsPath, fileManager.fileExists(atPath: docs) {
            paths.append(docs)
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
