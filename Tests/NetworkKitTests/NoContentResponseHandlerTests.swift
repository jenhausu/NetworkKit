import XCTest
@testable import NetworkKit

final class NoContentResponseHandlerTests: XCTestCase {

    private struct EmptyBody: Decodable, Equatable {}

    private struct StubRequest: HTTPRequest {
        typealias ResponseType = EmptyBody
        var baseURL: URL? { URL(string: "https://example.com") }
        var path: String { "/resource" }
        var method: HTTPMethod { .delete }
    }

    private func response(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com/resource")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    func testAppliesTo204() {
        let handler = NoContentResponseHandler()
        XCTAssertTrue(handler.shouldApply(request: StubRequest(), data: Data(), response: response(status: 204)))
    }

    func testDoesNotApplyTo200() {
        let handler = NoContentResponseHandler()
        XCTAssertFalse(handler.shouldApply(request: StubRequest(), data: Data(), response: response(status: 200)))
    }

    func testEmptyBodyMappedByPreviousHandlerDecodesToDone() async {
        // DataMappingHandler 會把空 body 補成 "{}"，這裡模擬它已經跑過
        let handler = NoContentResponseHandler()
        let action = await handler.apply(
            request: StubRequest(),
            data: Data("{}".utf8),
            response: response(status: 204)
        )

        switch action {
        case .done(let value):
            XCTAssertEqual(value, EmptyBody())
        default:
            XCTFail("預期 .done，實際為 \(action)")
        }
    }

    func testWholeChainNoLongerFallsThroughOn204() async {
        // 迴歸測試：整條預設 handler 鏈處理 204 時不應該用光 handler
        let request = StubRequest()
        var handlers = request.responseHandlers
        let resp = response(status: 204)
        var data = Data() // 204 no content

        while !handlers.isEmpty {
            let handler = handlers.removeFirst()
            guard handler.shouldApply(request: request, data: data, response: resp) else { continue }

            let action = await handler.apply(request: request, data: data, response: resp)
            switch action {
            case .done:
                return // 成功走到終點
            case .continue(let newData, _):
                data = newData
            case .error(let error):
                XCTFail("預期 204 視為成功，實際回 error: \(error)")
                return
            case .restart:
                XCTFail("預期 204 視為成功，實際要求 restart")
                return
            }
        }

        XCTFail("整條 handler 鏈用光仍未處理 204")
    }
}
