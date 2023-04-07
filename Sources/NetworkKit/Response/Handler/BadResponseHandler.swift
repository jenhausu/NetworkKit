//
//  BadResponseHandler.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2021/12/20.
//

import Foundation

public struct BadResponseHandler: ResponseHandler {
    
    public init() { }
    
    public func shouldApply<Req: HTTPRequest>(request: Req, data: Data, response: HTTPURLResponse) -> Bool {
        !(200...299).contains(response.statusCode)
    }
    
    public func apply<Req>(request: Req, data: Data, response: HTTPURLResponse) async -> ResponseAction<Req> where Req : HTTPRequest {
        do {
            printJSON(data: data)
            let value = try request.decoder.decode(HTTPResponseError.ErrorResponse.self, from: data)
            return .error(HTTPResponseError.error(errorResponse: value, statusCode: response.statusCode))
        } catch {
            return .error(HTTPResponseError.error(error: error, statusCode: response.statusCode))
        }
    }
    
}
