import Foundation
import Observation
import TunnelServices

private let kActiveRuleIdKey = "activeRuleId"
private let kAppGroupSuite = "group.Lojii.NIO1901"

@Observable
public final class RuleViewModel {
    public var rules: [Rule] = []
    public var activeRuleId: String?

    private let defaults = UserDefaults(suiteName: kAppGroupSuite)

    public init() {
        activeRuleId = defaults?.string(forKey: kActiveRuleIdKey)
    }

    public func loadRules() {
        rules = Rule.findRules()
        if activeRuleId == nil, let first = rules.first {
            activeRuleId = first.id as? String
        }
    }

    public func setActive(ruleId: String) {
        activeRuleId = ruleId
        defaults?.set(ruleId, forKey: kActiveRuleIdKey)
        defaults?.synchronize()
    }

    public func deleteRule(_ rule: Rule) {
        // Remove from persistent storage if the rule supports it
        if let idx = rules.firstIndex(where: { $0.subName == rule.subName }) {
            rules.remove(at: idx)
        }
        // If deleted rule was active, clear selection
        if let ruleIdNum = rule.id as? NSNumber, ruleIdNum.stringValue == activeRuleId {
            activeRuleId = nil
            defaults?.removeObject(forKey: kActiveRuleIdKey)
        }
    }
}
