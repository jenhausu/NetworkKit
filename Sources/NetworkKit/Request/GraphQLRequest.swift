//
//  GraphQLRequest.swift
//  
//
//  Created by 蘇健豪 on 2023/4/9.
//

import Foundation

public protocol GraphQLRequest: HTTPRequest {
    associatedtype VariableType: Encodable
    var variables: VariableType { get }
    var operationString: String { get }
}

public extension GraphQLRequest {

    var path: String {
        ""
    }

    var method: HTTPMethod {
        .post
    }

    var requestBuilders: [RequestBuilder] {[
        header.builder,
        GraphQLRequestBuilder(variables: variables, operationString: operationString)
    ]}

    var responseHandlers: [ResponseHandler] {[
        TimeoutResponseHandler(),
        ClientErrorResponseHandler(),
        ServerErrorResponseHandler(),
        BadResponseHandler(),
        GraphQLResponseHandler()
    ]}

    var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return decoder
    }
}
