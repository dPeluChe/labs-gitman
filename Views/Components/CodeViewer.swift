import SwiftUI

struct CodeViewer: View {
    let content: String
    let fileExtension: String
    
    var body: some View {
        ScrollView {
            Text(content)
                .font(.monospaced(.body)())
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .background(Color(.textBackgroundColor))
    }
}

