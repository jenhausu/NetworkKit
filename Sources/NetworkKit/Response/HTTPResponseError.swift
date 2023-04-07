//
//  HTTPResponseError.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2021/12/21.
//

import Foundation

public enum HTTPResponseError: Error {
    /// typical error format
    ///
    /// - message
    /// - code
    public struct ErrorResponse: Decodable {
        public let code: String
        public let message: String
    }
    
    case nonHTTPResponse
    
    /// 最通用的，把 http status code 傳出來
    case error(statusCode: Int)
    
    case error(error: Error, statusCode: Int)
    
    /// 最通用的 error 回傳格式
    ///
    /// - message
    /// - code
    case error(errorResponse: ErrorResponse, statusCode: Int)
        
    /// 適用 server 只有回傳 code
    case error(errorCode: Int, statusCode: Int)
    
    /// 適用 server 只有回傳 message
    case error(errorMessage: String, statusCode: Int)
    
    /// 提供其他客製化的 error 格式
    case customError(errorResponse: Decodable, statusCode: Int)
    
    case unknown(error: Error)
}


