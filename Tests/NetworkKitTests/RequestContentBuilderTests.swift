import XCTest
@testable import NetworkKit

final class RequestContentBuilderTests: XCTestCase {

    private struct Params: Encodable {
        let name: String
    }

    private func makeRequest() -> URLRequest {
        URLRequest(url: URL(string: "https://example.com")!)
    }

    func testTopLevelObjectBuildsBodyContainingParams() throws {
        let builder = RequestContentBuilder(
            method: .post,
            contentType: .json,
            param: Params(name: "abc"),
            encoder: JSONEncoder()
        )

        let request = try builder.adapted(makeRequest())

        let body = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["name"] as? String, "abc")
    }

    /// FLO-42：.json 不再繞經 Dictionary 往返，top-level array 應該能正常送出
    func testJSONTopLevelArrayEncodesDirectlyWithoutDictionaryRoundTrip() throws {
        let ids = [UUID(), UUID()]
        let builder = RequestContentBuilder(
            method: .put,
            contentType: .json,
            param: ids,
            encoder: JSONEncoder()
        )

        let request = try builder.adapted(makeRequest())

        let body = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String]
        XCTAssertEqual(json, ids.map { $0.uuidString })
    }

    /// 迴歸測試：FLO-41 —— `.url` / `.formData` 仍需要 key-value，top-level 是 array 時應該 throw
    func testTopLevelArrayThrowsForURLEncodedContentType() {
        let builder = RequestContentBuilder(
            method: .put,
            contentType: .url,
            param: [UUID(), UUID()],
            encoder: JSONEncoder()
        )

        XCTAssertThrowsError(try builder.adapted(makeRequest())) { error in
            XCTAssertEqual(error as? RequestError, .paramEncodingFailed)
        }
    }

    private struct FailingEncodable: Encodable {
        struct EncodingFailure: Error {}
        func encode(to encoder: Encoder) throws {
            throw EncodingFailure()
        }
    }

    func testEncodingFailurePropagatesInsteadOfSilentlyEmptyBody() {
        let builder = RequestContentBuilder(
            method: .post,
            contentType: .json,
            param: FailingEncodable(),
            encoder: JSONEncoder()
        )

        XCTAssertThrowsError(try builder.adapted(makeRequest()))
    }
}
