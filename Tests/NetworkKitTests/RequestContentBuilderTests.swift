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

    /// 迴歸測試：FLO-41 —— top-level 是 array 時，過去會靜默送出 {}，現在應該 throw
    func testTopLevelArrayThrowsInsteadOfSilentlyEmptyBody() {
        let builder = RequestContentBuilder(
            method: .put,
            contentType: .json,
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
