//
//  ServerErrorResponseHandler.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2022/1/15.
//

import Foundation

struct ServerErrorResponseHandler: ResponseHandler {
    func shouldApply<Req>(request: Req, data: Data, response: HTTPURLResponse) -> Bool where Req : HTTPRequest {
        (500...599).contains(response.statusCode)
    }
    
    func apply<Req>(request: Req, data: Data, response: HTTPURLResponse) async -> ResponseAction<Req> where Req : HTTPRequest {
        do {
            let value = try request.decoder.decode(HTTPResponseError.ErrorResponse.self, from: data)
            return .error(HTTPResponseError.error(errorResponse: value, statusCode: response.statusCode))
        } catch {
            return .error(HTTPResponseError.error(error: error, statusCode: response.statusCode))
        }
    }
    
}
