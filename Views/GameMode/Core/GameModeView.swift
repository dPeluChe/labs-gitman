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
                            await coordinator.refreshProjects()
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
                
                // Recent Activity removed (handled by 2.5D ReportBoard)
            }
        }
        .onAppear {
            sceneStore.scene.coordinator = coordinator
            // Note: Portals are automatically created in didMove(to:)
            // They are auto-synced with ProjectScannerViewModel via GameCoordinator
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
