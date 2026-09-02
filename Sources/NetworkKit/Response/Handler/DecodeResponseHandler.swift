//
//  DecodeResponseHandler.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2021/12/20.
//

import Foundation

/// 責任鏈的終端：把 2xx 回應 decode 成 `ResponseType`。
///
/// 接受整個 2xx 區間，而非只有 200：201 Created、202 Accepted、206 Partial Content…
/// 對函式庫來說處理方式都一樣——「成功且帶 body，decode 成 `ResponseType`」，
/// 不需要為個別狀態碼各開一個 handler。
///
/// 204 No Content 規範保證沒有 body，本身沒有特殊分支：鏈中在前的
/// `DataMappingHandler` 已把空 body 補成 `{}`，這裡照常 decode，
/// 對應到呼叫端宣告的空回應型別（decode 失敗代表 204 被配了需要 body 的 `ResponseType`）。
public struct DecodeResponseHandler: ResponseHandler {

    public init() { }

    public func shouldApply<Req: HTTPRequest>(request: Req, data: Data, response: HTTPURLResponse) -> Bool {
        (200...299).contains(response.statusCode)
    }
    
    public func apply<Req>(request: Req, data: Data, response: HTTPURLResponse) async -> ResponseAction<Req> where Req : HTTPRequest {
        do {
            let value = try request.decoder.decode(Req.ResponseType.self, from: data)
            return .done(value)
        } catch {
            printJSON(data: data)
            return .error(HTTPResponseError.error(error: error, statusCode: response.statusCode))
        }
    }
    
}
