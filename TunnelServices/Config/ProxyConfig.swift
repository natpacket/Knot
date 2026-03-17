//
//  ProxyConfig.swift
//  TunnelServices
//
//  Centralized configuration for proxy service, network, and file paths.
//  All previously hardcoded values are managed here.
//

import Foundation

public enum ProxyConfig {

    // MARK: - App Identifiers

    public static let appGroupIdentifier = "group.Lojii.NIO1901"
    public static let extensionBundleIdentifier = "Lojii.NIO1901.PacketTunnel"

    // MARK: - Local Proxy Server

    public enum LocalProxy {
        public static let host = "127.0.0.1"
        public static let port: Int = 8034
        public static var endpoint: String { "\(host):\(port)" }
    }

    // MARK: - WiFi Proxy (default)

    public enum WiFiProxy {
        public static let defaultPort: Int = 8034
    }

    // MARK: - VPN Tunnel

    public enum VPN {
        public static let tunnelAddress = "127.0.0.1"
        public static let ipv4Address = "192.169.89.1"
        public static let subnetMask = "255.255.255.0"
        public static let mtu: NSNumber = 1500
        public static let dnsServers = "8.8.8.8,8.4.4.4"
    }

    // MARK: - SSL/TLS

    public enum SSL {
        public static let handshakeTimeout: Int64 = 10  // seconds
        public static let connectTimeout: Int64 = 10    // seconds
        public static let checkHost = "www.localhost.com"
        public static let checkPort: Int = 4433
    }

    // MARK: - HTTP Server

    public enum HTTPServer {
        public static let defaultHost = "::1"
        public static let defaultPort: Int = 80
    }

    // MARK: - IPC (Inter-Process Communication)

    public enum IPC {
        public static let udpHost = "127.0.0.1"
        public static let udpPort: UInt16 = 60001
    }

    // MARK: - Certificate Files

    public enum CertFiles {
        public static let caCert = "cacert.pem"
        public static let caCertDER = "cacert.der"
        public static let caKey = "cakey.pem"
        public static let rsaKey = "rsakey.pem"
        public static let blackList = "DefaultBlackLisk.conf"
    }

    // MARK: - Certificate Subject (for dynamic cert generation)

    public enum CertSubject {
        public static let country = "SE"
        public static let organization = "Company"
    }

    // MARK: - Database

    public enum Database {
        public static let fileName = "nio.db"
        public static let sessionTableName = "Session"
    }

    // MARK: - File Storage

    public enum Storage {
        public static let taskFolder = "Task"
        public static let certFolder = "Cert"
        public static let tunnelLogFolder = "Tunnel"
        public static let httpRootFolder = "Root"
        public static let wormholeDirectory = "wormhole"
        public static let indexHTML = "index.html"
    }
}
