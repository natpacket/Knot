import Foundation
import Observation
import KnotCore

@Observable
public final class CertificateViewModel {
    public var trustStatus: CertTrustStatus = .notInstalled
    public var isServerRunning: Bool = false
    public var localIP: String?

    private var service: (any CertificateServiceProtocol)? {
        ServiceContainer.shared.resolve(CertificateServiceProtocol.self)
    }

    public init() {}

    public func checkStatus() {
        guard let svc = service else { return }
        trustStatus = svc.checkTrustStatus()
    }

    public func startServer(port: Int) {
        guard let svc = service else { return }
        Task { @MainActor in
            do {
                try await svc.startLocalServer(port: port)
                isServerRunning = true
            } catch {
                isServerRunning = false
            }
        }
    }

    public func stopServer() {
        guard let svc = service else { return }
        svc.stopLocalServer()
        isServerRunning = false
    }
}
