
import Foundation

public struct RequestedPredicate {
    public let credentialId: String
    public let timestamp: Int?
    public var credentialInfo: IndyCredentialInfo? = nil
    public var revoked: Bool? = nil
}

extension RequestedPredicate: Codable {
    enum CodingKeys: String, CodingKey {
        case credentialId = "cred_id", timestamp
    }

    mutating func setCredentialInfo(_ credentialInfo: IndyCredentialInfo) {
        self.credentialInfo = credentialInfo
    }
}
