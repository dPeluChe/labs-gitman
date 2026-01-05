import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: ProjectScannerViewModel
    @State private var isScanning = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.accentColor)
                Text("GitMonitor")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task { await refreshAll() }
                }) {
                    Image(systemName: isScanning ? "arrow.clockwise" : "arrow.clockwise")
                        .rotationEffect(.degrees(isScanning ? 360 : 0))
                        .animation(isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isScanning)
                }
                .buttonStyle(.borderless)
                .disabled(isScanning)
            }
            .padding()
            .background(Color(.controlBackgroundColor))

            Divider()

            // Summary Stats
            HStack(spacing: 20) {
                statItem(title: "Projects", value: "\(viewModel.projects.count)", icon: "folder")
                statItem(title: "With Changes", value: "\(viewModel.gitRepositories.filter { $0.gitStatus?.hasUncommittedChanges == true }.count)", icon: "pencil")
                statItem(title: "PRs", value: "\(viewModel.gitRepositories.reduce(0) { $0 + ($1.gitStatus?.pendingPullRequests ?? 0) })", icon: "arrow.triangle.pull")
            }
            .padding()
            .background(Color(.controlBackgroundColor).opacity(0.5))

            Divider()

            // Projects List
            if viewModel.projects.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.projects.prefix(10)) { project in
                            MenuBarProjectRow(project: project)
                                .contextMenu {
                                    Button("Open in Terminal") {
                                        openTerminal(project: project)
                                    }
                                    Button("Open in Finder") {
                                        NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                                    }
                                }
                            Divider()
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Open GitMonitor") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
        }
        .frame(width: 350, height: 450)
    }

    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No projects monitored")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Add Project") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.borderless)
        }
        .frame(maxHeight: .infinity)
        .padding()
    }

    private func refreshAll() async {
        isScanning = true
        await viewModel.scanAllProjects()
        isScanning = false
    }

    private func openTerminal(project: Project) {
        let script = "open -a Terminal \"\(project.path)\""
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", script]
        task.launch()
    }
}

struct MenuBarProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 8) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 24, height: 24)

                Image(systemName: statusIcon)
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let status = project.gitStatus {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 8))
                        Text(status.currentBranch)
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if status.hasUncommittedChanges {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.orange)
                        }

                        if status.pendingPullRequests > 0 {
                            Image(systemName: "arrow.triangle.pull")
                                .font(.system(size: 8))
                            Text("\(status.pendingPullRequests)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var statusIcon: String {
        guard let status = project.gitStatus else {
            return "questionmark"
        }
        if status.hasUncommittedChanges { return "pencil" }
        if status.pendingPullRequests > 0 { return "arrow.triangle.pull" }
        return "checkmark"
    }

    private var statusColor: Color {
        guard let status = project.gitStatus else {
            return .secondary
        }
        if status.hasUncommittedChanges { return .orange }
        if status.pendingPullRequests > 0 { return .blue }
        return .green
    }
}
