//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  Created by LiuJie on 2019/3/30.
//  Copyright © 2019 Lojii. All rights reserved.
//

import NetworkExtension
import TunnelServices
import Network

class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: Properties

    open var connection: NWTCPConnection!
    var mitmServer: MitmService!
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.knot.tunnel.network")

    /// The completion handler to call when the tunnel is fully established.
    var pendingStartCompletion: ((Error?) -> Void)!

    /// The completion handler to call when the tunnel is fully disconnected.
    var pendingStopCompletion: (() -> Void)?

    // MARK: NEPacketTunnelProvider

    /// Begin the process of establishing the tunnel.
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {

        pendingStartCompletion = completionHandler
        if StartInExtension {
            guard let server = MitmService.prepare() else {
                NSLog("Start Tunel Failed! MitmService create Failed !")
                self.pendingStartCompletion(nil)
                return
            }
            mitmServer = server
            mitmServer.run({ (result) in
                switch result {
                case .success( _):
                    let endpoint = NWHostEndpoint(hostname:"127.0.0.1", port:"8034")
                    self.connection = self.createTCPConnection(to: endpoint, enableTLS:false, tlsParameters:nil, delegate:nil)
                    self.startVPNWithOptions(options: nil) { (error) in
                        if error == nil {
                            NSLog("***************** Start Tunel Success !")
                            self.readPakcets()
                            self.pendingStartCompletion(nil)
                        } else {
                            NSLog("***************** Start Tunel Failed! %@", error!.localizedDescription)
                            self.pendingStartCompletion(error)
                        }
                    }
                case .failure(let error):
                    NSLog("***************** MitmService Run Failed! \(error.localizedDescription)")
                    self.pendingStartCompletion(error)
                }
            })
        } else {
            let endpoint = NWHostEndpoint(hostname:"127.0.0.1", port:"8034")
            self.connection = self.createTCPConnection(to: endpoint, enableTLS:false, tlsParameters:nil, delegate:nil)
            self.startVPNWithOptions(options: nil) { (error) in
                if error == nil {
                    NSLog("Start Tunel Success !")
                    self.readPakcets()
                    self.pendingStartCompletion(nil)
                } else {
                    NSLog("Start Tunel Failed! %@", error!.localizedDescription)
                    self.pendingStartCompletion(error)
                }
            }
        }

        // 网络监控 (NWPathMonitor)
        pathMonitor.pathUpdateHandler = { [weak self] path in
            // Network change handling placeholder
            // mitmServer?.wifiNetWorkChanged(isOpen: path.usesInterfaceType(.wifi))
            _ = path
            _ = self
        }
        pathMonitor.start(queue: monitorQueue)
    }

    func startVPNWithOptions(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        networkSettings.mtu = 1500

        let proxySettings = NEProxySettings()
        proxySettings.httpServer = NEProxyServer(address: "127.0.0.1", port: 8034)
        proxySettings.httpEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: "127.0.0.1", port: 8034)
        proxySettings.httpsEnabled = true
        proxySettings.matchDomains = [""]
        networkSettings.proxySettings = proxySettings

        let ipv4Settings = NEIPv4Settings(addresses: ["192.169.89.1"], subnetMasks: ["255.255.255.0"])
        networkSettings.ipv4Settings = ipv4Settings
        setTunnelNetworkSettings(networkSettings) { (error) in
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        pendingStartCompletion = nil
        pendingStopCompletion = completionHandler
        pathMonitor.cancel()
        if StartInExtension {
            mitmServer.close(completionHandler)
        }
    }

    func readPakcets() -> Void {
        packetFlow.readPackets { (packets, protocols) in
            for packet in packets {
                NSLog("Read Packet: %@", String(data: packet, encoding: .utf8) ?? "unknow")
                self.connection.write(packet, completionHandler: { (error) in
                    if let e = error {
                        NSLog("write packet error: %@", e.localizedDescription)
                    }
                })
            }
            self.readPakcets()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {

    }
}
