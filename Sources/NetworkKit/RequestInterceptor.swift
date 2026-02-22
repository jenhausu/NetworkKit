//
//  RequestInterceptor.swift
//  NetworkKit
//
//  Created by Claude on 2026/2/2.
//

import Foundation

/// 請求攔截器協定
/// 用於在請求發送前修改 URLRequest，適合用於添加認證、版本號、通用 headers 等
public protocol RequestInterceptor {
    /// 修改請求
    /// - Parameter request: 原始的 URLRequest
    /// - Returns: 修改後的 URLRequest
    /// - Throws: 如果無法修改請求則拋出錯誤
    func adapt(_ request: URLRequest) async throws -> URLRequest
}

// MARK: - 常用的 Interceptor 實作

/// 認證攔截器 - 自動添加 Authorization header
public final class AuthInterceptor: RequestInterceptor {
    private let tokenProvider: () -> String?

    /// 初始化認證攔截器
    /// - Parameter tokenProvider: 提供 token 的閉包
    public init(tokenProvider: @escaping () -> String?) {
        self.tokenProvider = tokenProvider
    }

    /// 便利初始化 - 直接提供固定 token
    /// - Parameter token: 固定的 token 字串
    public convenience init(token: String) {
        self.init(tokenProvider: { token })
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

/// API 版本攔截器 - 自動添加 API version header
public final class APIVersionInterceptor: RequestInterceptor {
    private let version: String
    private let headerName: String

    /// 初始化 API 版本攔截器
    /// - Parameters:
    ///   - version: API 版本號
    ///   - headerName: Header 名稱，預設為 "API-Version"
    public init(version: String, headerName: String = "API-Version") {
        self.version = version
        self.headerName = headerName
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        request.setValue(version, forHTTPHeaderField: headerName)
        return request
    }
}

/// 通用 Header 攔截器 - 添加自訂 headers
public final class HeaderInterceptor: RequestInterceptor {
    private let headers: [String: String]

    /// 初始化 Header 攔截器
    /// - Parameter headers: 要添加的 headers 字典
    public init(headers: [String: String]) {
        self.headers = headers
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

/// User-Agent 攔截器
public final class UserAgentInterceptor: RequestInterceptor {
    private let userAgent: String

    /// 初始化 User-Agent 攔截器
    /// - Parameter userAgent: User-Agent 字串，如 "MyApp/1.0 (iOS 15.0)"
    public init(userAgent: String) {
        self.userAgent = userAgent
    }

    /// 便利初始化 - 自動產生 User-Agent
    /// - Parameters:
    ///   - appName: App 名稱
    ///   - version: App 版本
    public convenience init(appName: String, version: String) {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let userAgent = "\(appName)/\(version) (\(osVersion))"
        self.init(userAgent: userAgent)
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }
}

/// 組合攔截器 - 組合多個攔截器
public final class CompositeInterceptor: RequestInterceptor {
    private let interceptors: [RequestInterceptor]

    /// 初始化組合攔截器
    /// - Parameter interceptors: 攔截器陣列（依序執行）
    public init(interceptors: [RequestInterceptor]) {
        self.interceptors = interceptors
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var currentRequest = request
        for interceptor in interceptors {
            currentRequest = try await interceptor.adapt(currentRequest)
        }
        return currentRequest
    }
}
