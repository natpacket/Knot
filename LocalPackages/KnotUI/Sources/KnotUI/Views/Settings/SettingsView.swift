import SwiftUI

struct SettingsView: View {
    @Bindable var nav: NavigationState

    var body: some View {
        List {
            Section("证书") {
                Button {
                    nav.navigate(to: .settingCertificate)
                } label: {
                    Label("证书管理", systemImage: "lock.shield")
                        .foregroundStyle(.primary)
                }
            }

            Section("条款与隐私") {
                Button {
                    nav.navigate(to: .settingWeb(type: .terms))
                } label: {
                    Label("使用条款", systemImage: "doc.text")
                        .foregroundStyle(.primary)
                }

                Button {
                    nav.navigate(to: .settingWeb(type: .privacy))
                } label: {
                    Label("隐私政策", systemImage: "hand.raised")
                        .foregroundStyle(.primary)
                }
            }

            Section("关于") {
                Button {
                    nav.navigate(to: .settingAbout)
                } label: {
                    Label("关于 Knot", systemImage: "info.circle")
                        .foregroundStyle(.primary)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("设置")
    }
}
