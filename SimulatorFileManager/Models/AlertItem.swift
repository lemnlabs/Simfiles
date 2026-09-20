import Foundation

struct AlertItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let message: String

    init(id: UUID = UUID(), title: String, message: String) {
        self.id = id
        self.title = title
        self.message = message
    }
}

extension AlertItem {
    static func error(_ error: Error, title: String = "오류 발생") -> AlertItem {
        AlertItem(title: title, message: error.localizedDescription)
    }
}
