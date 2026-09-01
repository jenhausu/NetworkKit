//
//  NoContentResponseHandler.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2026/9/2.
//

import Foundation

/// status code: 204 No Content
///
/// 204 依規範保證沒有 response body，因此直接視為成功。
/// 少了這個 handler 的話，`DELETE` 這類慣例回 204 的請求會穿過整條 handler 鏈
/// （`BadResponseHandler` 只接非 2xx、`DecodeResponseHandler` 只接 200），
/// 最後在 `HTTPClient` 撞上 `fatalError`。
///
/// 前面的 `DataMappingHandler` 已把空 body 補成 `{}`，所以這裡照樣走 decode，
/// 對應到呼叫端宣告的空回應型別；decode 失敗代表 204 被配了需要 body 的 `ResponseType`。
struct NoContentResponseHandler: ResponseHandler {

    func shouldApply<Req>(request: Req, data: Data, response: HTTPURLResponse) -> Bool where Req : HTTPRequest {
        response.statusCode == 204
    }

    func apply<Req>(request: Req, data: Data, response: HTTPURLResponse) async -> ResponseAction<Req> where Req : HTTPRequest {
        do {
            let value = try request.decoder.decode(Req.ResponseType.self, from: data)
            return .done(value)
        } catch {
            return .error(HTTPResponseError.error(error: error, statusCode: response.statusCode))
        }
    }

}
