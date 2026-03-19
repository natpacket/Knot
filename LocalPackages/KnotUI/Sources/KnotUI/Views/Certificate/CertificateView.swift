import SwiftUI
import KnotCore

struct CertificateView: View {
    @State private var vm = CertificateViewModel()
    @State private var serverPort = "8879"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CertStatusCard(status: vm.trustStatus) {
                    let svc = ServiceContainer.shared.resolve(CertificateServiceProtocol.self)
                    if let svc = svc {
                        Task {
                            try? await svc.installCertificate()
                            vm.checkStatus()
                        }
                    }
                }
                .padding(.horizontal)

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("本机安装", systemImage: "iphone")
                            .font(.headline)

                        Text("1. 点击上方「安装」按钮下载证书")
                            .font(.callout)
                        Text("2. 前往 设置 → 通用 → VPN与设备管理，安装证书")
                            .font(.callout)
                        Text("3. 前往 设置 → 通用 → 关于本机 → 证书信任设置，启用完全信任")
                            .font(.callout)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("其他设备安装", systemImage: "wifi")
                            .font(.headline)

                        Text("启动本地服务器，其他设备通过浏览器访问以下地址下载证书。")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        HStack {
                            TextField("端口", text: $serverPort)
                                .frame(width: 80)
                            #if os(iOS)
                                .keyboardType(.numberPad)
                            #endif

                            Spacer()

                            if vm.isServerRunning {
                                Button("停止") {
                                    vm.stopServer()
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            } else {
                                Button("启动") {
                                    vm.startServer(port: Int(serverPort) ?? 8879)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        if vm.isServerRunning, let ip = vm.localIP {
                            HStack {
                                Text("http://\(ip):\(serverPort)")
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("证书")
        .onAppear {
            vm.checkStatus()
        }
    }
}
