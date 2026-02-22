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
    func addInterceptor(_ interceptor: RequestInterceptor)
}

public class HTTPClient: NSObject, HTTPClientProtocol {

    /// 全域共享的 HTTPClient 實例
    /// 可在 app 啟動時替換為自訂配置的實例
    public static var shared = HTTPClient()

    private let session: URLSession
    private var eventMonitors: [EventMonitor] = []
    private var interceptors: [RequestInterceptor] = []
    /// 重試策略，nil 表示不重試
    public var retryPolicy: RetryPolicy?

    /// 初始化 HTTPClient
    /// - Parameter session: URLSession 實例，預設使用 URLSession.shared
    public init(session: URLSession = .shared) {
        self.session = session
        super.init()
    }

    /// 便利初始化 - 以 URLSessionConfiguration 建立 HTTPClient
    /// - Parameter configuration: URLSessionConfiguration 實例
    public convenience init(configuration: URLSessionConfiguration) {
        self.init(session: URLSession(configuration: configuration))
    }

    /// 添加事件監控器
    /// - Parameter monitor: EventMonitor 實例
    public func addEventMonitor(_ monitor: EventMonitor) {
        eventMonitors.append(monitor)
    }

    /// 添加請求攔截器
    /// - Parameter interceptor: RequestInterceptor 實例
    public func addInterceptor(_ interceptor: RequestInterceptor) {
        interceptors.append(interceptor)
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
        await performSend(request, retryCount: 0)
    }

    private func performSend<Req: HTTPRequest>(_ request: Req, retryCount: Int) async -> Result<Req.ResponseType, Error> {
        let urlRequest: URLRequest
        do {
            var builtRequest = try request.buildRequest()
            for interceptor in interceptors {
                builtRequest = try await interceptor.adapt(builtRequest)
            }
            urlRequest = builtRequest
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
            // 網路錯誤重試
            if let policy = retryPolicy, policy.shouldRetry(error: error, retryCount: retryCount) {
                try? await Task.sleep(nanoseconds: UInt64(policy.delay(for: retryCount) * 1_000_000_000))
                return await performSend(request, retryCount: retryCount + 1)
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

        // HTTP 狀態碼重試（在 response handler 處理前）
        if let policy = retryPolicy, policy.shouldRetry(statusCode: response.statusCode, retryCount: retryCount) {
            try? await Task.sleep(nanoseconds: UInt64(policy.delay(for: retryCount) * 1_000_000_000))
            return await performSend(request, retryCount: retryCount + 1)
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
                return await performSend(request, retryCount: 0)

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
