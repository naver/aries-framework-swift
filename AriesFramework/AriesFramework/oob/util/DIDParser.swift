
import Foundation

let PCT_ENCODED = "(?:%[0-9a-fA-F]{2})"
let ID_CHAR = "(?:[a-zA-Z0-9._-]|\(PCT_ENCODED))"
let METHOD = "([a-z0-9]+)"
let METHOD_ID = "((?:\(ID_CHAR)*:)*(\(ID_CHAR)+))"
let PARAM_CHAR = "[a-zA-Z0-9_.:%-]"
let PARAM = ";\(PARAM_CHAR)=\(PARAM_CHAR)*"
let PARAMS = "((\(PARAM))*)"
let PATH = "(/[^#?]*)?"
let QUERY = "([?][^#]*)?"
let FRAGMENT = "(#.*)?"
let DID_URL = "^did:\(METHOD):\(METHOD_ID)\(PARAMS)\(PATH)\(QUERY)\(FRAGMENT)$"

public class DIDParser {
    public static func getMethodId(did: String) throws -> String {
        let regex = try NSRegularExpression(pattern: DID_URL, options: [])
        let matches = regex.matches(in: did, options: [], range: NSRange(location: 0, length: did.count))
        guard matches.count == 1 else {
            throw AriesFrameworkError.frameworkError("Invalid DID: \(did)")
        }
        let match = matches[0]
        let methodId = did[Range(match.range(at: 2), in:did)!]
        return String(methodId)
    }
}
