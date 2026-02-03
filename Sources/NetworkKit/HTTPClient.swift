//
//  HTTPClient.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2021/12/20.
//

import Foundation

public protocol HTTPClientProtocol {
    func send<Req: HTTPRequest>(_ request: Req) async -> Result<Req.ResponseType, Error>
    func sendTask<Req: HTTPRequest>(_ request: Req) -> NetworkTask<Req.ResponseType>
    func addEventMonitor(_ monitor: EventMonitor)
}

public class HTTPClient: NSObject, HTTPClientProtocol {

    /// 全域共享的 HTTPClient 實例
    public static let shared = HTTPClient()

    private let session: URLSession
    private var eventMonitors: [EventMonitor] = []

    /// 初始化 HTTPClient
    /// - Parameter session: URLSession 實例，預設使用 URLSession.shared
    public init(session: URLSession = .shared) {
        self.session = session
        super.init()
    }

    /// 添加事件監控器
    /// - Parameter monitor: EventMonitor 實例
    public func addEventMonitor(_ monitor: EventMonitor) {
        eventMonitors.append(monitor)
    }

    /// 發送可取消的網路請求
    /// - Parameter request: HTTP 請求
    /// - Returns: 可取消的 NetworkTask
    public func sendTask<Req: HTTPRequest>(_ request: Req) -> NetworkTask<Req.ResponseType> {
        let task = Task<Result<Req.ResponseType, Error>, Never> {
            await self.send(request)
        }
        return NetworkTask(task: task)
    }

    /// 發送 HTTP 請求
    /// - Parameter request: HTTP 請求
    /// - Returns: 請求結果
    public func send<Req: HTTPRequest>(_ request: Req) async -> Result<Req.ResponseType, Error> {
        let urlRequest: URLRequest
        do {
            urlRequest = try request.buildRequest()
        } catch {
            return .failure(error)
        }

        eventMonitors.forEach { $0.requestWillStart(urlRequest) }

        let result: (data: Data, response: URLResponse)
        do {
            if #available(iOS 15, *) {
                result = try await session.data(for: urlRequest, delegate: self)
            } else {
                result = try await session.data(for: urlRequest)
            }
        } catch {
            if Task.isCancelled {
                let cancelError = URLError(.cancelled)
                eventMonitors.forEach {
                    $0.requestDidFinish(urlRequest, response: nil, data: nil, error: cancelError, metrics: nil)
                }
                return .failure(cancelError)
            }
            eventMonitors.forEach {
                $0.requestDidFinish(urlRequest, response: nil, data: nil, error: error, metrics: nil)
            }
            return .failure(error)
        }

        guard let response = result.response as? HTTPURLResponse else {
            let error = HTTPResponseError.nonHTTPResponse
            eventMonitors.forEach {
                $0.requestDidFinish(urlRequest, response: nil, data: result.data, error: error, metrics: nil)
            }
            return .failure(error)
        }

        eventMonitors.forEach {
            $0.requestDidFinish(urlRequest, response: response, data: result.data, error: nil, metrics: nil)
        }

        return await handleResponse(request.responseHandlers, request: request, data: result.data, response: response)
    }
    
    private func handleResponse<Req: HTTPRequest>(_ handlers: [ResponseHandler],
                                                  request: Req,
                                                  data: Data,
                                                  response: HTTPURLResponse) async -> Result<Req.ResponseType, Error> {
        guard !handlers.isEmpty else {
            fatalError("No handler left but did not reach a stop.")
        }
        
        var mutableHandlers = handlers
        let currentHandler = mutableHandlers.removeFirst()
        
        guard currentHandler.shouldApply(request: request, data: data, response: response) else {
            return await handleResponse(mutableHandlers, request: request, data: data, response: response)
        }
        
        let action = await currentHandler.apply(request: request, data: data, response: response)
        switch action {
            case .continue(let data, let response):
                return await handleResponse(mutableHandlers, request: request, data: data, response: response)
                
            case .restart:
                return await send(request)
                
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
        var dataTask: URLSessionDataTask?

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
                dataTask = self.dataTask(with: request) { data, response, error in
                    guard let data = data, let response = response else {
                        let error = error ?? URLError(.badServerResponse)
                        return continuation.resume(throwing: error)
                    }

                    continuation.resume(returning: (data, response))
                }

                dataTask?.resume()
            }
        } onCancel: {
            dataTask?.cancel()
        }
    }
}
