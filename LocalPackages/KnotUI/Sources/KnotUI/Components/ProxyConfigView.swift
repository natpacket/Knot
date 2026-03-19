import SwiftUI

struct ProxyConfigView: View {
    @Binding var localEnabled: Bool
    @Binding var localPort: String
    @Binding var wifiEnabled: Bool
    @Binding var wifiPort: String
    let wifiIP: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Local proxy
            GroupBox {
                HStack {
                    Toggle("本机代理", isOn: $localEnabled)
                    Spacer()
                    TextField("端口", text: $localPort)
                        .frame(width: 70)
                        .disabled(!localEnabled)
                }
            }

            // WiFi proxy
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Toggle("WiFi 代理", isOn: $wifiEnabled)
                        Spacer()
                        TextField("端口", text: $wifiPort)
                            .frame(width: 70)
                            .disabled(!wifiEnabled)
                    }
                    if let ip = wifiIP, wifiEnabled {
                        Text("地址: \(ip)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
