
import XCTest
@testable import AriesFramework

class DIDParserTest: XCTestCase {
    func testParse() throws {
        var did = "did:aries:did.example.com"
        XCTAssertEqual(try DIDParser.getMethodId(did: did), "did.example.com")
        
        did = "did:example:123456/path"
        XCTAssertEqual(try DIDParser.getMethodId(did: did), "123456")

        did = "did:example:123456?versionId=1"
        XCTAssertEqual(try DIDParser.getMethodId(did: did), "123456")

        did = "did:example:123?service=agent&relativeRef=/credentials#degree"
        XCTAssertEqual(try DIDParser.getMethodId(did: did), "123")
    }
}
