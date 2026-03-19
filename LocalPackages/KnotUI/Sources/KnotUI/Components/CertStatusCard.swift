import SwiftUI
import KnotCore

struct CertStatusCard: View {
    let status: CertTrustStatus
    let onInstall: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.headline)
                Text(descriptionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if status != .trusted {
                Button("安装", action: onInstall)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var iconName: String {
        switch status {
        case .notInstalled: return "xmark.shield"
        case .installed: return "shield"
        case .trusted: return "checkmark.shield.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .notInstalled: return .red
        case .installed: return .orange
        case .trusted: return .green
        }
    }

    private var titleText: String {
        switch status {
        case .notInstalled: return "证书未安装"
        case .installed: return "证书未信任"
        case .trusted: return "证书已信任"
        }
    }

    private var descriptionText: String {
        switch status {
        case .notInstalled: return "需要安装 CA 证书以捕获 HTTPS 流量"
        case .installed: return "请在设置中信任证书"
        case .trusted: return "HTTPS 抓包已就绪"
        }
    }
}
