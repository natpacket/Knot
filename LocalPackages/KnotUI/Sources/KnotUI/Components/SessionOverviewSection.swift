import SwiftUI

struct SessionOverviewSection: View {
    let title: String
    let items: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text(item.0)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 120, alignment: .leading)
                        Text(item.1)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}
