import SwiftUI
import SpriteKit

struct GameModeView: View {
    @StateObject private var coordinator: GameCoordinator
    @StateObject private var sceneStore: GameSceneStore
    @ObservedObject var scannerViewModel: ProjectScannerViewModel
    @Binding var isGameModeEnabled: Bool
    
    @State private var showDebugOverlay = false
    
    init(scannerViewModel: ProjectScannerViewModel, isGameModeEnabled: Binding<Bool>) {
        self.scannerViewModel = scannerViewModel
        self._isGameModeEnabled = isGameModeEnabled
        
        let coordinator = GameCoordinator(scannerViewModel: scannerViewModel)
        self._coordinator = StateObject(wrappedValue: coordinator)
        self._sceneStore = StateObject(wrappedValue: GameSceneStore(coordinator: coordinator))
    }
    
    var body: some View {
        ZStack {
            SpriteView(scene: sceneStore.scene)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        coordinator.stopAutoPlay()
                        isGameModeEnabled = false
                    }) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .padding()

                    Button(action: {
                        Task {
                            await coordinator.discoverProjectsForGameMode()
                            sceneStore.scene.refreshPortals()
                        }
                    }) {
                        if coordinator.isDiscovering {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding()
                    .disabled(coordinator.isDiscovering)
                    
                    Spacer()
                    
                    if !coordinator.taskQueue.isEmpty {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("\(coordinator.taskQueue.count) tasks queued")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        coordinator.debugMode.toggle()
                    }) {
                        Label("Debug", systemImage: coordinator.debugMode ? "eye.fill" : "eye")
                    }
                    .buttonStyle(.bordered)
                    .padding()
                    .help("Toggle debug overlay (or press 'P' key)")
                }
                
                Spacer()
                
                if !coordinator.activeReports.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Activity")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        ForEach(coordinator.activeReports.prefix(3)) { report in
                            HStack {
                                Text(report.hasIssues ? "⚠️" : "✅")
                                Text(report.project.name)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Spacer()
                                Text(timeAgo(report.completedAt))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(report.hasIssues ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
        .onAppear {
            sceneStore.scene.coordinator = coordinator
            
            // Fast discovery: Show portals INSTANTLY without git commands
            Task {
                await coordinator.discoverProjectsForGameMode()
                sceneStore.scene.refreshPortals()
            }
        }
        .onDisappear {
            coordinator.stopAutoPlay()
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "\(Int(seconds))s ago"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m ago"
        } else {
            return "\(Int(seconds / 3600))h ago"
        }
    }
}
