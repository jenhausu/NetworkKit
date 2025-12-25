//
//  ClientErrorResponseHandler.swift
//  
//
//  Created by 蘇健豪 on 2023/4/8.
//

import Foundation

/// status code 400 ~ 499
struct ClientErrorResponseHandler: ResponseHandler {
    
    func shouldApply<Req>(request: Req, data: Data, response: HTTPURLResponse) -> Bool where Req : HTTPRequest {
        (400...499).contains(response.statusCode)
    }
    
    func apply<Req>(request: Req, data: Data, response: HTTPURLResponse) async -> ResponseAction<Req> where Req : HTTPRequest {
        .error(HTTPResponseError.error(statusCode: response.statusCode))
    }
}
