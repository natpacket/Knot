import Foundation
import Observation
import KnotCore
import TunnelServices

@Observable
public final class AppState {
    public var vpnStatus: TunnelStatus = .disconnected
    public var currentTask: CaptureTask?
    public var certificateStatus: CertTrustStatus = .notInstalled
    public var networkType: String = "WiFi"
    public var activeRuleId: String?

    public var isCapturing: Bool {
        if case .connected = vpnStatus { return true }
        return false
    }

    public init() {}
}
