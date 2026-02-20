import Foundation

public protocol Generatable: Codable {
    static var jsonSchema: String { get }
}

public extension Generatable where Self: CaseIterable & RawRepresentable, Self.RawValue == String {
    static var jsonSchema: String {
        let object: [String: Any] = [
            "type": "string",
            "enum": allCases.map(\.rawValue)
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
            let json = String(data: data, encoding: .utf8)
        else {
            return "{\"type\":\"string\",\"enum\":[]}"
        }
        return json
    }
}
