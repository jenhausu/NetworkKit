//
//  TimeoutResponseHandler.swift
//  
//
//  Created by 蘇健豪 on 2023/4/8.
//

import Foundation

/// status code: 408
struct TimeoutResponseHandler: ResponseHandler {
    func shouldApply<Req>(request: Req, data: Data, response: HTTPURLResponse) -> Bool where Req : HTTPRequest {
        response.statusCode == 408
    }
    
    func apply<Req>(request: Req, data: Data, response: HTTPURLResponse) async -> ResponseAction<Req> where Req : HTTPRequest {
        .restart
    }
}
