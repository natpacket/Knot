import SwiftUI
import KnotCore

struct ExportMenu: View {
    let onExport: (ExportFormat) -> Void

    var body: some View {
        Menu {
            ForEach(ExportFormat.allCases) { format in
                Button {
                    onExport(format)
                } label: {
                    Text(format.rawValue)
                }
            }
        } label: {
            Label("导出", systemImage: "square.and.arrow.up")
        }
    }
}
