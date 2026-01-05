import SwiftUI
import QuickLook

struct FileExplorerView: View {
    let projectPath: String
    @State private var fileTree: [FileSystemNode] = []
    @State private var selectedFile: FileSystemNode?
    @State private var fileContent: String = ""
    @State private var isLoadingContent = false

    var body: some View {
        HSplitView {
            // File Tree
            VStack(alignment: .leading) {
                Text("Explorer")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                List(fileTree, id: \.id, children: \.children) { node in
                    HStack {
                        Image(systemName: node.isDirectory ? "folder" : "doc.text")
                            .foregroundColor(node.isDirectory ? .blue : .secondary)
                        Text(node.name)
                            .font(.subheadline)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !node.isDirectory {
                            selectedFile = node
                            Task { await loadFileContent(node.path) }
                        }
                    }
                    .contextMenu {
                        Button {
                            NSWorkspace.shared.open(URL(fileURLWithPath: node.path))
                        } label: {
                            Label("Open External", systemImage: "arrow.up.right.square")
                        }
                        
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
                        } label: {
                            Label("Show in Finder", systemImage: "folder")
                        }
                        
                        Divider()
                        
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(node.path, forType: .string)
                        } label: {
                            Label("Copy Path", systemImage: "doc.on.doc")
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200, maxWidth: 300)

            // File Viewer
            if let selected = selectedFile {
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text(selected.name)
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))

                    if isLoadingContent {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        CodeViewer(content: fileContent, fileExtension: (selected.name as NSString).pathExtension)
                    }
                }
                .background(Color(.textBackgroundColor))
            } else {
                VStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Select a file to view")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.controlBackgroundColor))
            }
        }
        .onAppear {
            loadFileSystem()
        }
    }

    private func loadFileSystem() {
        self.fileTree = FileSystemUtils.getContents(of: projectPath)
    }
    
    private func loadFileContent(_ path: String) async {
        isLoadingContent = true
        defer { isLoadingContent = false }
        
        do {
            let url = URL(fileURLWithPath: path)
            let content = try String(contentsOf: url, encoding: .utf8)
            fileContent = String(content.prefix(50000)) 
        } catch {
            fileContent = "Error reading file: \(error.localizedDescription)\n(Note: Binary files or non-UTF8 text are not supported yet)"
        }
    }
}

struct FileSystemNode: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    var children: [FileSystemNode]?
}

struct FileSystemUtils {
    static func getContents(of path: String) -> [FileSystemNode] {
        let fileManager = FileManager.default
        guard let items = try? fileManager.contentsOfDirectory(atPath: path) else { return [] }
        
        var nodes: [FileSystemNode] = []
        
        for item in items {
            // Skip hidden files/dirs (like .git)
            if item.hasPrefix(".") { continue }
            
            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) {
                if isDir.boolValue {
                    let children = getContents(of: fullPath)
                    nodes.append(FileSystemNode(name: item, path: fullPath, isDirectory: true, children: children.isEmpty ? nil : children))
                } else {
                    nodes.append(FileSystemNode(name: item, path: fullPath, isDirectory: false, children: nil))
                }
            }
        }
        
        return nodes.sorted {
            ($0.isDirectory && !$1.isDirectory) ||
            ($0.isDirectory == $1.isDirectory && $0.name < $1.name)
        }
    }
}
