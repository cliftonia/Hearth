import Foundation

/// The shared test vectors in the repository's `Spec` folder, which the Android app's tests read too.
///
/// They are read where they stand, found from this file's own path: the tests run on this Mac, in the simulator or
/// not, and can read the source tree, so there is no copy to fall out of step with the folder.
enum Spec {
    /// The `Spec` folder: four levels above this file (`HearthKit/Tests/HearthDomainTests/Spec.swift`).
    static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Spec")

    /// One file of the folder, read as the given shape.
    static func load<Value: Decodable>(_ type: Value.Type, _ path: String) throws -> Value {
        try JSONDecoder().decode(type, from: Data(contentsOf: folder.appendingPathComponent(path)))
    }

    /// The names of the files in one of the folder's subfolders, in order.
    static func files(in subfolder: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent(subfolder).path)
            .filter { $0.hasSuffix(".json") }
            .sorted()
    }
}

/// A file of vectors: what it covers, and its cases.
struct SpecFile<Case: Decodable>: Decodable {
    let about: String
    let cases: [Case]
}

/// A case that turns one text into another.
struct SpecTextCase: Decodable {
    let input: String?
    let expected: String?
}
