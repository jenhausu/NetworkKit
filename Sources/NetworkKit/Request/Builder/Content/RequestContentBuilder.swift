//
//  RequestContentBuilder.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2021/12/20.
//

import Foundation

struct RequestContentBuilder: RequestBuilder {
    
    let method: HTTPMethod
    let contentType: ContentType
    let param: Encodable
    let encoder: JSONEncoder
    
    func adapted(_ req: URLRequest) throws -> URLRequest {
        let dict = param.dictValue(encoder: encoder)
        
        switch method {
            case .get, .delete:
                return try URLQueryDataBuilder(data: dict).adapted(req)
            case .post, .put, .patch:
                var request = req
                
                let headerBuilder = contentType.headerBuilder
                request = try headerBuilder.adapted(request)
                
                let dataBuilder = contentType.dataBuilder(for: dict)
                request = try dataBuilder.adapted(request)
                
                return request
        }
    }
    
}

fileprivate extension Encodable {
    func dictValue(encoder: JSONEncoder) -> [String: Any] {
        do {
            let data = try encoder.encode(self)
            let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] ?? [:]
            return dict
        } catch {
            return [:]
        }
    }
}

fileprivate extension ContentType {
    
    var headerBuilder: AnyBuilder {
        AnyBuilder { req in
            var request = req
            
            let value: String
            switch self {
                case .json, .url:
                    value = self.rawValue
                case .formData:
                    let boundary = "Boundary+\(UUID().uuidString)"
                    value = "\(self.rawValue); boundary=\(boundary)"
            }
            request.setValue(value, forHTTPHeaderField: "Content-Type")
            
            return request
        }
    }
    
    func dataBuilder(for parameters: [String: Any]) -> RequestBuilder {
        switch self {
            case .json:
                return JSONRequestDataBuilder(param: parameters)
            case .url:
                return URLRequestDataBuilder(data: parameters)
            case .formData:
                return FormDataRequestDataBuilder(param: parameters)
        }
    }
    
}
