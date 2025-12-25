//
//  GraphQLRequestBuilder.swift
//  
//
//  Created by 蘇健豪 on 2023/4/9.
//

import Foundation

struct GraphQLRequestBuilder: RequestBuilder {
    
    let variables: Encodable
    let operationString: String
    
    init(variables: Encodable, operationString: String) {
        self.variables = variables
        self.operationString = operationString
    }
    
    func adapted(_ request: URLRequest) throws -> URLRequest {
        var mutableRequest = request

        mutableRequest.httpMethod = "POST"
        mutableRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = GraphQLPayOperation(variables: variables, operationString: operationString)
        mutableRequest.httpBody = try JSONEncoder().encode(payload)

        return mutableRequest
    }
    
}

struct GraphQLPayOperation: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case variables
        case query
    }
    
    let variables: Encodable
    let operationString: String
    
    init(variables: Encodable, operationString: String) {
        self.variables = variables
        self.operationString = operationString
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(variables, forKey: .variables)
        try container.encode(operationString, forKey: .query)
    }
    
}
