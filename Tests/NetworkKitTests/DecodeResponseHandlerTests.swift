import XCTest
@testable import NetworkKit

final class DecodeResponseHandlerTests: XCTestCase {

    private struct Item: Decodable, Equatable {
        let id: String
    }

    private struct EmptyBody: Decodable, Equatable {}

    private struct StubRequest: HTTPRequest {
        typealias ResponseType = Item
        var baseURL: URL? { URL(string: "https://example.com") }
        var path: String { "/items" }
        var method: HTTPMethod { .post }
    }

    private struct EmptyBodyRequest: HTTPRequest {
        typealias ResponseType = EmptyBody
        var baseURL: URL? { URL(string: "https://example.com") }
        var path: String { "/resource" }
        var method: HTTPMethod { .delete }
    }

    private func response(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com/items")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    func testAppliesToWhole2xxRange() {
        let handler = DecodeResponseHandler()
        for status in [200, 201, 202, 204, 206, 299] {
            XCTAssertTrue(
                handler.shouldApply(request: StubRequest(), data: Data(), response: response(status: status)),
                "應處理 \(status)"
            )
        }
    }

    func testDoesNotApplyOutside2xx() {
        let handler = DecodeResponseHandler()
        for status in [199, 300, 404, 500] {
            XCTAssertFalse(
                handler.shouldApply(request: StubRequest(), data: Data(), response: response(status: status)),
                "不應處理 \(status)"
            )
        }
    }

    func testDecodes201Body() async {
        let handler = DecodeResponseHandler()
        let action = await handler.apply(
            request: StubRequest(),
            data: Data(#"{"id":"abc"}"#.utf8),
            response: response(status: 201)
        )

        switch action {
        case .done(let value):
            XCTAssertEqual(value, Item(id: "abc"))
        default:
            XCTFail("預期 .done，實際為 \(action)")
        }
    }

    /// 204 沒有特殊分支：DataMappingHandler 把空 body 補成 "{}" 後，這裡照常 decode
    func test204EmptyBodyMappedByPreviousHandlerDecodesToDone() async {
        let handler = DecodeResponseHandler()
        let action = await handler.apply(
            request: EmptyBodyRequest(),
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

    /// 迴歸測試：整條預設 handler 鏈處理 204 時不應該用光 handler
    func testWholeChainHandles204() async {
        let request = EmptyBodyRequest()
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
                return XCTFail("預期 204 視為成功，實際回 error: \(error)")
            case .restart:
                return XCTFail("預期 204 視為成功，實際要求 restart")
            }
        }

        XCTFail("整條 handler 鏈用光仍未處理 204")
    }
}
