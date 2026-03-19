import SwiftUI

struct FocusTag: Identifiable {
    let id: String
    let label: String
}

struct FocusTagsView: View {
    let tags: [FocusTag]
    let onRemove: (FocusTag) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags) { tag in
                    HStack(spacing: 4) {
                        Text(tag.label)
                            .font(.caption)
                        Button {
                            onRemove(tag)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.12), in: Capsule())
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
