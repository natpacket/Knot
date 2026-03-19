import SwiftUI
import TunnelServices
import KnotCore

struct SessionListView: View {
    let taskId: String
    @Bindable var nav: NavigationState

    @State private var vm: SessionListViewModel

    init(taskId: String, nav: NavigationState) {
        self.taskId = taskId
        self.nav = nav
        self._vm = State(initialValue: SessionListViewModel(taskId: taskId))
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $vm.searchText) {
                vm.loadSessions()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            if vm.isEditing {
                EditToolbar(
                    selectedCount: vm.selectedIds.count,
                    onSelectAll: { vm.selectAll() },
                    onDeselectAll: { vm.deselectAll() },
                    onExport: { _ in },
                    onDelete: { }
                )
            }

            if vm.sessions.isEmpty {
                ContentUnavailableView(
                    "暂无会话",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("没有找到匹配的会话")
                )
            } else {
                List {
                    ForEach(vm.sessions, id: \.id) { session in
                        SessionCell(session: session)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if vm.isEditing {
                                    vm.toggleSelection(session)
                                } else if let sid = session.id {
                                    nav.navigate(to: .sessionDetail(sessionId: sid.stringValue))
                                }
                            }
                            .listRowBackground(
                                vm.isEditing && session.id != nil && vm.selectedIds.contains(session.id!.int64Value)
                                    ? Color.accentColor.opacity(0.1)
                                    : Color.clear
                            )
                            .onAppear {
                                if session.id == vm.sessions.last?.id {
                                    vm.loadMore()
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    vm.refresh()
                }
            }
        }
        .navigationTitle("会话列表")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button(vm.isEditing ? "完成" : "编辑") {
                        vm.isEditing.toggle()
                        if !vm.isEditing {
                            vm.deselectAll()
                        }
                    }

                    if !vm.isEditing {
                        ExportMenu { _ in }
                    }
                }
            }
        }
        .onAppear {
            vm.loadSessions()
        }
    }
}
