import Foundation

enum DataError: LocalizedError {
    case notFound
    case invalidState(String)
    case saveFailed(String)
    case cloudUnavailable
    case permissionDenied
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Requested item not found."
        case .invalidState(let message):
            return message
        case .saveFailed(let message):
            return message
        case .cloudUnavailable:
            return "iCloud is unavailable."
        case .permissionDenied:
            return "Permission denied."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}
