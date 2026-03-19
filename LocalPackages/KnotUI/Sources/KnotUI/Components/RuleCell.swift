import SwiftUI
import TunnelServices

struct RuleCell: View {
    let rule: Rule
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.subName)
                    .font(.body)
                    .lineLimit(1)
                Text("\(rule.ruleItems.count) 条规则")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
    }
}
