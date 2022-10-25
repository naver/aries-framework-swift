
import Foundation

class HandshakeReuseHandler: MessageHandler {
    let agent: Agent
    let messageType = HandshakeReuseMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        return nil
    }
}
