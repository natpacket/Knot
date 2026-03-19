import SwiftUI
import TunnelServices

struct HistoryTaskCell: View {
    let task: CaptureTask
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.ruleName.isEmpty ? "未命名任务" : task.ruleName)
                        .font(.body)
                        .lineLimit(1)
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(task.interceptCount.intValue) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var formattedDate: String {
        guard let ts = task.creatTime else { return "—" }
        let date = Date(timeIntervalSince1970: ts.doubleValue / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
