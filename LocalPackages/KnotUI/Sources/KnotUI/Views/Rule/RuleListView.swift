import SwiftUI
import TunnelServices

struct RuleListView: View {
    @Bindable var nav: NavigationState

    @State private var vm = RuleViewModel()
    @State private var showDownloadAlert = false
    @State private var downloadURL = ""

    var body: some View {
        Group {
            if vm.rules.isEmpty {
                ContentUnavailableView(
                    "暂无规则",
                    systemImage: "list.bullet.rectangle",
                    description: Text("点击右上角添加规则配置")
                )
            } else {
                List {
                    ForEach(vm.rules, id: \.subName) { rule in
                        RuleCell(
                            rule: rule,
                            isActive: isActive(rule)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let ruleId = rule.id {
                                nav.navigate(to: .ruleDetail(ruleId: ruleId.stringValue))
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                vm.deleteRule(rule)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if let ruleId = rule.id {
                                Button {
                                    vm.setActive(ruleId: ruleId.stringValue)
                                } label: {
                                    Label("启用", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("规则")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        let rule = Rule.defaultRule()
                        do {
                            try rule.saveToDB()
                            vm.loadRules()
                        } catch {}
                    } label: {
                        Label("新建配置", systemImage: "plus")
                    }

                    Button {
                        showDownloadAlert = true
                    } label: {
                        Label("从 URL 下载", systemImage: "arrow.down.circle")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("从 URL 下载规则", isPresented: $showDownloadAlert) {
            TextField("输入 URL", text: $downloadURL)
            Button("取消", role: .cancel) { }
            Button("下载") {
                downloadURL = ""
            }
        }
        .onAppear {
            vm.loadRules()
        }
    }

    private func isActive(_ rule: Rule) -> Bool {
        guard let ruleId = rule.id else { return false }
        return ruleId.stringValue == vm.activeRuleId
    }
}
