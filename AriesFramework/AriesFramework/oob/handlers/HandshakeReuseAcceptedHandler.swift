
import Foundation

class HandshakeReuseAcceptedHandler: MessageHandler {
    let agent: Agent
    let messageType = HandshakeReuseAcceptedMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        return nil
    }
}
