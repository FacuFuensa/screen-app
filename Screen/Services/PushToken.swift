import Foundation

enum PushToken {
    private static let key = "apnsToken"
    static var current: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
