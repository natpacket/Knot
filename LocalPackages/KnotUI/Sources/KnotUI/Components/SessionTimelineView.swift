import SwiftUI

public struct TimelineEntry: Identifiable {
    public let id: String
    public let label: String
    public let duration: Double   // seconds
    public let color: Color

    public init(id: String, label: String, duration: Double, color: Color) {
        self.id = id
        self.label = label
        self.duration = duration
        self.color = color
    }
}

struct SessionTimelineView: View {
    let entries: [TimelineEntry]
    let totalDuration: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Bar chart
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(entries) { entry in
                        let width = totalDuration > 0
                            ? max(2, CGFloat(entry.duration / totalDuration) * geo.size.width)
                            : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(entry.color)
                            .frame(width: width)
                    }
                }
            }
            .frame(height: 20)

            // Legend
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entries) { entry in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(entry.color)
                            .frame(width: 12, height: 12)
                        Text(entry.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f ms", entry.duration * 1000))
                            .font(.caption2)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
