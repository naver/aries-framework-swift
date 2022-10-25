
import Foundation

public struct RequestedAttribute {
    public let credentialId: String
    public let timestamp: Int?
    public let revealed: Bool
    public var credentialInfo: IndyCredentialInfo? = nil
    public var revoked: Bool? = nil
}

extension RequestedAttribute: Codable {
    enum CodingKeys: String, CodingKey {
        case credentialId = "cred_id", timestamp, revealed
    }

    mutating func setCredentialInfo(_ credentialInfo: IndyCredentialInfo) {
        self.credentialInfo = credentialInfo
    }
}
