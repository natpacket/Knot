import Foundation
import Observation
import TunnelServices

@Observable
public final class SessionListViewModel {
    public var sessions: [Session] = []
    public var searchText: String = ""
    public var focusHost: String?
    public var focusMethod: String?
    public var focusStatusCode: String?
    public var isEditing: Bool = false
    public var selectedIds: Set<Int64> = []
    public var currentPage: Int = 0
    public var hasMore: Bool = false
    public let taskId: String

    private let pageSize: Int = 50

    public init(taskId: String) {
        self.taskId = taskId
    }

    public func loadSessions() {
        currentPage = 0
        let params = buildParams()
        let keyword = searchText.isEmpty ? nil : searchText
        let result = Session.findAll(
            taskID: taskId,
            keyWord: keyword,
            params: params,
            pageSize: pageSize,
            pageIndex: 0,
            orderBy: nil
        )
        sessions = result
        hasMore = result.count == pageSize
    }

    public func loadMore() {
        guard hasMore else { return }
        currentPage += 1
        let params = buildParams()
        let keyword = searchText.isEmpty ? nil : searchText
        let result = Session.findAll(
            taskID: taskId,
            keyWord: keyword,
            params: params,
            pageSize: pageSize,
            pageIndex: currentPage,
            orderBy: nil
        )
        sessions.append(contentsOf: result)
        hasMore = result.count == pageSize
    }

    public func refresh() {
        loadSessions()
    }

    public func toggleSelection(_ session: Session) {
        guard let idNumber = session.id else { return }
        let id = idNumber.int64Value
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    public func selectAll() {
        for session in sessions {
            if let idNumber = session.id {
                selectedIds.insert(idNumber.int64Value)
            }
        }
    }

    public func deselectAll() {
        selectedIds.removeAll()
    }

    // MARK: - Private

    private func buildParams() -> [String: [String]]? {
        var params: [String: [String]] = [:]
        if let host = focusHost { params["host"] = [host] }
        if let method = focusMethod { params["methods"] = [method] }
        if let code = focusStatusCode { params["state"] = [code] }
        return params.isEmpty ? nil : params
    }
}
