import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "搜索"
    var onCommit: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .onSubmit(onCommit)

            if !text.isEmpty {
                Button {
                    text = ""
                    onCommit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
