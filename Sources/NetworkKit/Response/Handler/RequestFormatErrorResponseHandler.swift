//
//  RequestFormatErrorResponseHandler.swift
//  ObjectCaptureCamera
//
//  Created by 蘇健豪 on 2022/1/5.
//

import Foundation

private struct RequestFormatErrorResponse: Decodable {
    let code: Int
}

struct RequestFormatErrorResponseHandler: ResponseHandler {
    
    func shouldApply<Req>(request: Req, data: Data, response: HTTPURLResponse) -> Bool where Req : HTTPRequest {
        response.statusCode == 400
    }
    
    func apply<Req>(request: Req, data: Data, response: HTTPURLResponse) async -> ResponseAction<Req> where Req : HTTPRequest {
        do {
            printJSON(data: data)
            let value = try request.decoder.decode(RequestFormatErrorResponse.self, from: data)
            
            return .error(HTTPResponseError.error(errorCode: value.code, statusCode: response.statusCode))
        } catch {
            return .error(HTTPResponseError.error(error: error, statusCode: response.statusCode))
        }
    }
    
}
