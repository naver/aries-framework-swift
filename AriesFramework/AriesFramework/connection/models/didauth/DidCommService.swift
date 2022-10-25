
import Foundation

public struct DidCommService: Codable {
    static var type: String = "did-communication"
    var type: String = DidCommService.type
    var id: String
    var serviceEndpoint: String
    var recipientKeys: [String]
    var routingKeys: [String]?
    var accept: [String]? = nil
    var priority: Int? = 0
}
