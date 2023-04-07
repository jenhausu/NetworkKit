//
//  DecodeResponseHandler.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2021/12/20.
//

import Foundation

public struct DecodeResponseHandler: ResponseHandler {
    
    public init() { }
    
    public func shouldApply<Req: HTTPRequest>(request: Req, data: Data, response: HTTPURLResponse) -> Bool {
        response.statusCode == 200
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
