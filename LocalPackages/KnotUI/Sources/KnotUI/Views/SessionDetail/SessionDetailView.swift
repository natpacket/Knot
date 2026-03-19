import SwiftUI
import TunnelServices

struct SessionDetailView: View {
    let sessionId: String

    @State private var selectedTab = 0
    @State private var session: Session?

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("请求").tag(0)
                Text("响应").tag(1)
                Text("概览").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            if let session = session {
                switch selectedTab {
                case 0:
                    SessionRequestView(session: session)
                case 1:
                    SessionResponseView(session: session)
                default:
                    SessionOverviewView(session: session)
                }
            } else {
                ContentUnavailableView(
                    "加载中...",
                    systemImage: "hourglass"
                )
            }

            Spacer(minLength: 0)
        }
        .navigationTitle("会话详情")
        .onAppear {
            loadSession()
        }
    }

    private func loadSession() {
        if let idNum = Int(sessionId) {
            let results = Session.findAll(ids: [idNum])
            session = results.first
        }
    }
}

// MARK: - SessionRequestView

struct SessionRequestView: View {
    let session: Session

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SessionOverviewSection(
                    title: "请求行",
                    items: [
                        ("Method", session.methods?.uppercased() ?? "—"),
                        ("URI", session.uri ?? "/"),
                        ("Version", session.reqHttpVersion ?? "—"),
                    ]
                )

                SessionOverviewSection(
                    title: "请求头",
                    items: parseHeaders(session.reqHeads)
                )

                if !session.reqBody.isEmpty {
                    HStack {
                        Label("请求体", systemImage: "doc.fill")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func parseHeaders(_ raw: String?) -> [(String, String)] {
        guard let raw = raw, !raw.isEmpty else { return [("—", "无")] }
        if raw.hasPrefix("[") {
            if let data = raw.data(using: .utf8),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                return arr.flatMap { dict in
                    dict.map { ($0.key, $0.value) }
                }
            }
        }
        let lines = raw.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        return lines.map { line in
            let parts = line.components(separatedBy: ": ")
            if parts.count >= 2 {
                return (parts[0], parts.dropFirst().joined(separator: ": "))
            }
            return (line, "")
        }
    }
}

// MARK: - SessionResponseView

struct SessionResponseView: View {
    let session: Session

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SessionOverviewSection(
                    title: "响应行",
                    items: [
                        ("Version", session.rspHttpVersion ?? "—"),
                        ("Status", session.state ?? "—"),
                        ("Message", session.rspMessage ?? "—"),
                    ]
                )

                SessionOverviewSection(
                    title: "响应头",
                    items: parseHeaders(session.rspHeads)
                )

                if !session.rspBody.isEmpty || session.downloadFlow.int64Value > 0 {
                    HStack {
                        Label("响应体", systemImage: "doc.fill")
                            .font(.subheadline)
                        Spacer()
                        Text(ByteCountFormatter.string(
                            fromByteCount: session.downloadFlow.int64Value,
                            countStyle: .binary
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func parseHeaders(_ raw: String?) -> [(String, String)] {
        guard let raw = raw, !raw.isEmpty else { return [("—", "无")] }
        if raw.hasPrefix("[") {
            if let data = raw.data(using: .utf8),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                return arr.flatMap { dict in
                    dict.map { ($0.key, $0.value) }
                }
            }
        }
        let lines = raw.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        return lines.map { line in
            let parts = line.components(separatedBy: ": ")
            if parts.count >= 2 {
                return (parts[0], parts.dropFirst().joined(separator: ": "))
            }
            return (line, "")
        }
    }
}

// MARK: - SessionOverviewView

struct SessionOverviewView: View {
    let session: Session

    private let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        f.countStyle = .binary
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SessionOverviewSection(
                    title: "基本信息",
                    items: [
                        ("协议", session.schemes ?? "—"),
                        ("方法", session.methods?.uppercased() ?? "—"),
                        ("状态码", session.state ?? "—"),
                        ("主机", session.host ?? "—"),
                        ("远程地址", session.remoteAddress ?? "—"),
                        ("本地地址", session.localAddress ?? "—"),
                    ]
                )

                SessionOverviewSection(
                    title: "数据",
                    items: [
                        ("上传", byteFormatter.string(fromByteCount: session.uploadTraffic.int64Value)),
                        ("下载", byteFormatter.string(fromByteCount: session.downloadFlow.int64Value)),
                    ]
                )

                VStack(alignment: .leading, spacing: 0) {
                    Text("时间线")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 6)

                    SessionTimelineView(
                        entries: buildTimelineEntries(),
                        totalDuration: totalDuration
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private var totalDuration: Double {
        guard let start = session.startTime?.doubleValue,
              let end = session.endTime?.doubleValue else { return 0 }
        return (end - start) / 1000.0
    }

    private func buildTimelineEntries() -> [TimelineEntry] {
        guard let start = session.startTime?.doubleValue else { return [] }

        let connect = session.connectTime?.doubleValue ?? start
        let connected = session.connectedTime?.doubleValue ?? connect
        let handshake = session.handshakeEndTime?.doubleValue ?? connected
        let reqEnd = session.reqEndTime?.doubleValue ?? handshake
        let rspStart = session.rspStartTime?.doubleValue ?? reqEnd
        let rspEnd = session.rspEndTime?.doubleValue ?? rspStart
        let end = session.endTime?.doubleValue ?? rspEnd

        return [
            TimelineEntry(id: "dns", label: "DNS/连接准备", duration: (connect - start) / 1000.0, color: .blue),
            TimelineEntry(id: "connect", label: "TCP 连接", duration: (connected - connect) / 1000.0, color: .cyan),
            TimelineEntry(id: "tls", label: "TLS 握手", duration: (handshake - connected) / 1000.0, color: .purple),
            TimelineEntry(id: "request", label: "发送请求", duration: (reqEnd - handshake) / 1000.0, color: .orange),
            TimelineEntry(id: "waiting", label: "等待响应", duration: (rspStart - reqEnd) / 1000.0, color: .yellow),
            TimelineEntry(id: "response", label: "接收响应", duration: (rspEnd - rspStart) / 1000.0, color: .green),
            TimelineEntry(id: "close", label: "关闭", duration: (end - rspEnd) / 1000.0, color: .gray),
        ]
    }
}
