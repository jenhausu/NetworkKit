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
        switch method {
            case .get, .delete:
                let dict = try param.dictValue(encoder: encoder)
                return try URLQueryDataBuilder(data: dict).adapted(req)
            case .post, .put, .patch:
                var request = req

                let headerBuilder = contentType.headerBuilder
                request = try headerBuilder.adapted(request)

                switch contentType {
                    case .json:
                        request.httpBody = try encoder.encode(param)
                    case .url:
                        let dict = try param.dictValue(encoder: encoder)
                        request = try URLRequestDataBuilder(data: dict).adapted(request)
                    case .formData:
                        let dict = try param.dictValue(encoder: encoder)
                        request = try FormDataRequestDataBuilder(param: dict).adapted(request)
                }

                return request
        }
    }
    
}

fileprivate extension Encodable {
    func dictValue(encoder: JSONEncoder) throws -> [String: Any] {
        let data = try encoder.encode(self)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RequestError.paramEncodingFailed
        }
        return dict
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
    
}
