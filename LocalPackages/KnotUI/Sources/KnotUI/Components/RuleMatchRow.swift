import SwiftUI
import TunnelServices

struct RuleMatchRow: View {
    let item: RuleItem

    var body: some View {
        HStack(spacing: 10) {
            Text(item.matchRule.rawValue)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.blue)

            Text(item.value)
                .font(.body)
                .lineLimit(1)

            Spacer()

            Text(item.strategy.rawValue)
                .font(.caption)
                .foregroundStyle(strategyColor)
        }
    }

    private var strategyColor: Color {
        switch item.strategy {
        case .DIRECT: return .green
        case .REJECT: return .red
        case .COPY: return .blue
        case .DEFAULT: return .secondary
        case .NONE: return .gray
        }
    }
}
