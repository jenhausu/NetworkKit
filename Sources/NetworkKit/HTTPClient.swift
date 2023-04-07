//
//  HTTPClient.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2021/12/20.
//

import Foundation

public protocol HTTPClientProtocol {
    func send<Req: HTTPRequest>(_ request: Req) async -> Result<Req.ResponseType, Error>
    func send<Req: HTTPRequest>(_ request: Req, handlers: [ResponseHandler]) async -> Result<Req.ResponseType, Error>
}

public class HTTPClient: NSObject, HTTPClientProtocol {
    
    private let session: URLSession = URLSession.shared
        
    public func send<Req>(_ request: Req) async -> Result<Req.ResponseType, Error> where Req : HTTPRequest {
        await self.send(request, handlers: [])
    }
    
    public func send<Req: HTTPRequest>(_ request: Req,
                                       handlers: [ResponseHandler] = []) async -> Result<Req.ResponseType, Error> {
        let urlRequest: URLRequest
        do {
            urlRequest = try request.buildRequest()
        } catch {
            return .failure(error)
        }
        
        do {
            let result: (data: Data, response: URLResponse)
            if #available(iOS 15, *) {
                result = try await session.data(for: urlRequest, delegate: self)
            } else {
                result = try await session.data(for: urlRequest)
            }
            
            guard let response = result.response as? HTTPURLResponse else {
                return .failure(ResponseError.nonHTTPResponse)
            }
            
            var handlers = handlers
            if handlers.isEmpty {
                handlers = request.responseHandlers
            }
            
            return await handleResponse(handlers, request: request, data: result.data, response: response)
        } catch {
            return .failure(error)
        }
    }
    
    private func handleResponse<Req: HTTPRequest>(_ handlers: [ResponseHandler],
                                                  request: Req,
                                                  data: Data,
                                                  response: HTTPURLResponse) async -> Result<Req.ResponseType, Error> {
        guard !handlers.isEmpty else {
            fatalError("No decision left but did not reach a stop.")
        }
        
        var handlers = handlers
        let current = handlers.removeFirst()
        
        guard current.shouldApply(request: request, data: data, response: response) else {
            return await handleResponse(handlers, request: request, data: data, response: response)
        }
        
        let action = await current.apply(request: request, data: data, response: response)
        switch action {
            case .continue(let data, let response):
                return await handleResponse(handlers, request: request, data: data, response: response)
                
                return await send(request, handlers: handlers)
            case .restart(let handlers):
                
            case .error(let error):
                return .failure(error)
                
            case .done(let value):
                return .success(value)
        }
    }
    
}

extension HTTPClient: URLSessionTaskDelegate {
    
}

@available(iOS, deprecated: 15.0, message: "Use the built-in API instead")
private extension URLSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: request) { data, response, error in
                guard let data = data, let response = response else {
                    let error = error ?? URLError(.badServerResponse)
                    return continuation.resume(throwing: error)
                }
                
                continuation.resume(returning: (data, response))
            }
            
            task.resume()
        }
    }
}
