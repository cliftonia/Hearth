/// The addresses the app starts with before the user has saved any of their own.
public struct AppDefaults: Sendable {
    public let ollamaAddress: String
    public let searchAddress: String
    public let speechAddress: String
    /// Where pictures are made. Empty means the app offers none until an address is typed in Settings.
    public let imageAddress: String
    /// The sync hub the Sync page starts with. Sync itself stays off until the user turns it on.
    public let hubAddress: String
    /// The model the app starts with, by its name on the server. Empty means the first one the server offers.
    public let modelName: String

    public init(
        ollamaAddress: String = "",
        searchAddress: String = "",
        speechAddress: String = "",
        imageAddress: String = "",
        hubAddress: String = "",
        modelName: String = ""
    ) {
        self.ollamaAddress = ollamaAddress
        self.searchAddress = searchAddress
        self.speechAddress = speechAddress
        self.imageAddress = imageAddress
        self.hubAddress = hubAddress
        self.modelName = modelName
    }
}
