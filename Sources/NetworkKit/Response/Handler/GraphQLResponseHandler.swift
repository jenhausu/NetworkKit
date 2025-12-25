//
//  GraphQLResponseHandler.swift
//  
//
//  Created by 蘇健豪 on 2023/4/9.
//

import Foundation

struct GraphQLResponseHandler: ResponseHandler {
    
    func shouldApply<Req>(request: Req, data: Data, response: HTTPURLResponse) -> Bool where Req : HTTPRequest {
        true
    }
    
    func apply<Req>(request: Req, data: Data, response: HTTPURLResponse) async -> ResponseAction<Req> where Req : HTTPRequest {
        let result: GraphQLResult<Req.ResponseType>
        do {
            result = try request.decoder.decode(GraphQLResult<Req.ResponseType>.self, from: data)
        } catch {
            return .error(HTTPResponseError.error(error: error, statusCode: response.statusCode))
        }
        
        if let object = result.object {
            return .done(object)
        } else {
            print(result.errorMessages.joined(separator: "\n"))
            return .error(HTTPResponseError.customError(errorResponse: result.errorMessages, statusCode: response.statusCode))
        }
    }
    
}

fileprivate struct GraphQLResult<T: Decodable>: Decodable {
    let object: T?
    let errorMessages: [String]
    
    enum CodingKeys: String, CodingKey {
        case data
        case errors
    }
    
    struct Error: Decodable {
        let message: String
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let dataDict = try container.decodeIfPresent([String: T].self, forKey: .data)
        self.object = dataDict?.values.first
        
        var errorMessages: [String] = []
        if let errors = try container.decodeIfPresent([Error].self, forKey: .errors) {
            errorMessages.append(contentsOf: errors.map { $0.message })
        }
        self.errorMessages = errorMessages
    }
}
