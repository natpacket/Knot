import SwiftUI
import TunnelServices

struct RuleDetailView: View {
    let ruleId: String
    @Bindable var nav: NavigationState

    @State private var selectedTab = 0
    @State private var rule: Rule?

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("概览").tag(0)
                Text("规则").tag(1)
                Text("Host").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            if let rule = rule {
                switch selectedTab {
                case 0:
                    ruleOverviewTab(rule)
                case 1:
                    ruleItemsTab(rule)
                default:
                    ruleHostTab(rule)
                }
            } else {
                ContentUnavailableView(
                    "加载中...",
                    systemImage: "hourglass"
                )
            }

            Spacer(minLength: 0)
        }
        .navigationTitle("规则详情")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if selectedTab == 1 {
                    Button {
                        nav.navigate(to: .ruleAdd(ruleId: ruleId))
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            loadRule()
        }
    }

    @ViewBuilder
    private func ruleOverviewTab(_ rule: Rule) -> some View {
        List {
            Section("基本信息") {
                LabeledContent("名称", value: rule.name)
                LabeledContent("作者", value: rule.author ?? "—")
                LabeledContent("创建时间", value: rule.createTime)
            }

            Section("统计") {
                LabeledContent("规则数", value: "\(rule.ruleItems.count)")
                LabeledContent("Host 映射数", value: "\(rule.hosts.count)")
                LabeledContent("默认策略", value: rule.defaultStrategy.rawValue)
            }

            if let note = rule.note, !note.isEmpty {
                Section("备注") {
                    Text(note)
                        .font(.body)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    @ViewBuilder
    private func ruleItemsTab(_ rule: Rule) -> some View {
        if rule.ruleItems.isEmpty {
            ContentUnavailableView(
                "暂无规则项",
                systemImage: "list.bullet",
                description: Text("点击右上角添加规则")
            )
        } else {
            List {
                ForEach(Array(rule.ruleItems.enumerated()), id: \.offset) { _, item in
                    RuleMatchRow(item: item)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func ruleHostTab(_ rule: Rule) -> some View {
        if rule.hosts.isEmpty {
            ContentUnavailableView(
                "暂无 Host 映射",
                systemImage: "network",
                description: Text("该规则没有 Host 映射配置")
            )
        } else {
            List {
                ForEach(Array(rule.hosts.enumerated()), id: \.offset) { _, host in
                    Text(host.line)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .listStyle(.plain)
        }
    }

    private func loadRule() {
        if let idNum = Int(ruleId) {
            let results = Rule.findAll(["id": NSNumber(value: idNum)])
            if let r = results.first {
                _ = r.config
                rule = r
            }
        }
    }
}
