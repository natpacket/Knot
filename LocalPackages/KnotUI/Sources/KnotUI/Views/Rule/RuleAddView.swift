import SwiftUI
import TunnelServices

struct RuleAddView: View {
    let ruleId: String

    @Environment(\.dismiss) private var dismiss

    @State private var matchType: MatchRule = .DOMAIN
    @State private var value: String = ""
    @State private var strategy: Strategy = .DIRECT
    @State private var note: String = ""

    private let matchTypes: [MatchRule] = [
        .DOMAIN, .DOMAINKEYWORD, .DOMAINSUFFIX, .IPCIDR, .USERAGENT, .URLREGEX
    ]

    private let strategies: [Strategy] = [.DIRECT, .REJECT, .COPY]

    var body: some View {
        Form {
            Section("匹配类型") {
                Picker("类型", selection: $matchType) {
                    ForEach(matchTypes, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }

            Section("匹配值") {
                TextField("例如: example.com", text: $value)
                    .autocorrectionDisabled()
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
            }

            Section("策略") {
                Picker("策略", selection: $strategy) {
                    ForEach(strategies, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
            }

            Section("备注") {
                TextField("可选备注", text: $note)
            }
        }
        .navigationTitle("添加规则")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveRule()
                    dismiss()
                }
                .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func saveRule() {
        guard let idNum = Int(ruleId) else { return }
        let results = Rule.findAll(["id": NSNumber(value: idNum)])
        guard let rule = results.first else { return }

        var lineStr = "\(matchType.rawValue), \(value.trimmingCharacters(in: .whitespaces)), \(strategy.rawValue)"
        if !note.isEmpty {
            lineStr += " //\(note)"
        }

        RuleItem.fromLine(lineStr, rule.lines.count, success: { item in
            rule.lines.append(item)
            try? rule.saveToDB()
        }, failure: { _ in })
    }
}
