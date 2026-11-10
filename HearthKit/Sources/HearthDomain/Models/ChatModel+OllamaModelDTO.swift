import HearthData

extension ChatModel {
    /// Fails for models that cannot hold a conversation, such as embedding models.
    init?(from dto: OllamaModelDTO) {
        let capabilities = Set(dto.capabilities ?? ["completion"])
        guard capabilities.contains("completion") else {
            return nil
        }
        self.init(
            id: ID(dto.name),
            isCloud: dto.remoteHost != nil,
            parameterSize: dto.details?.parameterSize,
            canThink: capabilities.contains("thinking"),
            canSee: capabilities.contains("vision"),
            canUseTools: capabilities.contains("tools")
        )
    }
}
