//
//  RESTFulRequestBuilder.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2022/1/18.
//

import Foundation

public struct RESTFulRequestBuilder: RequestBuilder {
    
    let method: HTTPMethod
    let resource: String
    let id: String
    
    public init(method: HTTPMethod, resource: String, resourceId id: String = "") {
        self.method = method
        self.resource = resource
        self.id = id
    }
    
    public func adapted(_ request: URLRequest) throws -> URLRequest {
        guard let url = request.url else {
            throw RequestError.noURL
        }
        
        var mutableRequest = request
        
        var urlString = url.absoluteString
        urlString.append(resource)
        
        switch method {
            case .get, .patch, .put, .delete:
                urlString.append("/\(id)")
            case .post:
                break
        }
        
        mutableRequest.url = URL(string: urlString)
        
        return mutableRequest
    }
    
}
