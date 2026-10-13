import Foundation

/// JSON values in the App Group defaults, readable by the app and every extension.
struct SharedStore {
    var defaults: UserDefaults = AppGroup.defaults

    func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    func remove(_ key: String) { defaults.removeObject(forKey: key) }
}
