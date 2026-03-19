import SwiftUI
import TunnelServices

struct SessionCell: View {
    let session: Session

    var body: some View {
        HStack(spacing: 10) {
            methodBadge
            VStack(alignment: .leading, spacing: 3) {
                Text(session.host ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(session.uri ?? "/")
                    .font(.body)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                statusCodeView
                downloadSizeView
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Subviews

    private var methodBadge: some View {
        Text(session.methods?.uppercased() ?? "?")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(methodColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(methodColor)
            .fixedSize()
    }

    @ViewBuilder
    private var statusCodeView: some View {
        if let stateStr = session.state, let code = Int(stateStr) {
            Text("\(code)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(statusColor(for: code))
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var downloadSizeView: some View {
        let bytes = session.downloadFlow.int64Value
        let formatted = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
        return Text(formatted)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private var methodColor: Color {
        switch session.methods?.uppercased() {
        case "GET": return .blue
        case "POST": return .green
        case "PUT": return .orange
        case "DELETE": return .red
        case "PATCH": return .purple
        default: return .gray
        }
    }

    private func statusColor(for code: Int) -> Color {
        switch code {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        case 500...: return .red
        default: return .secondary
        }
    }
}
