/// The addresses the app starts with before the user has saved any of their own.
public struct AppDefaults: Sendable {
    public let ollamaAddress: String
    public let searchAddress: String
    public let speechAddress: String
    /// The model the app starts with, by its name on the server. Empty means the first one the server offers.
    public let modelName: String

    public init(ollamaAddress: String = "", searchAddress: String = "", speechAddress: String = "", modelName: String = "") {
        self.ollamaAddress = ollamaAddress
        self.searchAddress = searchAddress
        self.speechAddress = speechAddress
        self.modelName = modelName
    }
}
