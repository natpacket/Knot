import SwiftUI
import KnotCore

struct EditToolbar: View {
    let selectedCount: Int
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onExport: (ExportFormat) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("全选", action: onSelectAll)
                .buttonStyle(.bordered)

            Button("取消全选", action: onDeselectAll)
                .buttonStyle(.bordered)

            Spacer()

            Text("已选 \(selectedCount) 条")
                .font(.caption)
                .foregroundStyle(.secondary)

            ExportMenu(onExport: onExport)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
