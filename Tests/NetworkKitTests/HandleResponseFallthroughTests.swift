import XCTest
@testable import NetworkKit

/// 迴歸測試：handler 鏈跑完沒有終點時，`HTTPClient` 應回 `.failure` 而不是 `fatalError`。
final class HandleResponseFallthroughTests: XCTestCase {

    private struct Body: Decodable {}

    /// responseHandlers 只留一個永遠不 apply 的 handler，強制走到「鏈跑完」的分支
    private struct NoTerminalHandlerRequest: HTTPRequest {
        typealias ResponseType = Body
        var baseURL: URL? { URL(string: "https://example.com") }
        var path: String { "/resource" }
        var method: HTTPMethod { .get }
        var responseHandlers: [ResponseHandler] { [NeverApplyHandler()] }
    }

    private struct NeverApplyHandler: ResponseHandler {
        func shouldApply<Req>(request: Req, data: Data, response: HTTPURLResponse) -> Bool where Req : HTTPRequest { false }
        func apply<Req>(request: Req, data: Data, response: HTTPURLResponse) async -> ResponseAction<Req> where Req : HTTPRequest {
            .error(HTTPResponseError.error(statusCode: response.statusCode))
        }
    }

    private func makeClient(statusCode: Int) -> HTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.statusCode = statusCode
        return HTTPClient(configuration: configuration)
    }

    func testFallthroughReturnsFailureNotCrash() async {
        let client = makeClient(statusCode: 299)
        let result = await client.send(NoTerminalHandlerRequest())

        switch result {
        case .success:
            XCTFail("預期 .failure")
        case .failure(let error):
            guard let responseError = error as? HTTPResponseError else {
                return XCTFail("預期 HTTPResponseError，實際 \(error)")
            }
            XCTAssertEqual(String(describing: responseError), "error(statusCode: 299)")
        }
    }
}

private final class StubURLProtocol: URLProtocol {
    static var statusCode = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
