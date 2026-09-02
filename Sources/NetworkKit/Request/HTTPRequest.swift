//
//  HTTPEndPoint.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2021/12/20.
//

import Foundation

public protocol HTTPRequest {
    var baseURL: URL? { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var contentType: ContentType { get }
    var header: HTTPHeader { get }
    
    associatedtype ResponseType: Decodable
    var decoder: JSONDecoder { get }
    
    var requestBuilders: [RequestBuilder] { get }
    var responseHandlers: [ResponseHandler] { get }
}

// MARK: - Default

public extension HTTPRequest {
    var contentType: ContentType {
        .json
    }
    
    var header: HTTPHeader {
        HTTPHeader()
    }
    
    var requestBuilders: [RequestBuilder] {[
        PathBuilder(baseURL: baseURL, path: path),
        method.builder,
        header.builder,
    ]}
    
    var responseHandlers: [ResponseHandler] {[
        ServerErrorResponseHandler(),
        RequestFormatErrorResponseHandler(),
        TimeoutResponseHandler(),
        BadResponseHandler(),
        DataMappingHandler(
            condition: { $0.isEmpty },
            transform: { _ in "{}".data(using: .utf8)! }
        ),
        DecodeResponseHandler()
    ]}
    
    var decoder: JSONDecoder {
        JSONDecoder()
    }
}
