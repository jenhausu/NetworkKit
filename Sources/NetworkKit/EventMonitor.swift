//
//  EventMonitor.swift
//  NetworkKit
//
//  Created by Claude on 2026/2/2.
//

import Foundation

/// 網路事件監控協定
/// 用於追蹤請求的生命週期，適合用於日誌記錄、分析、除錯等場景
public protocol EventMonitor {
    /// 請求即將開始
    /// - Parameters:
    ///   - request: URLRequest 物件
    func requestWillStart(_ request: URLRequest)

    /// 請求已完成（成功或失敗）
    /// - Parameters:
    ///   - request: URLRequest 物件
    ///   - response: HTTPURLResponse（如果有）
    ///   - data: 回應資料（如果有）
    ///   - error: 錯誤（如果有）
    ///   - metrics: 效能指標（如果有）
    func requestDidFinish(
        _ request: URLRequest,
        response: HTTPURLResponse?,
        data: Data?,
        error: Error?,
        metrics: URLSessionTaskMetrics?
    )
}

// MARK: - Default Implementations

public extension EventMonitor {
    func requestWillStart(_ request: URLRequest) { }

    func requestDidFinish(
        _ request: URLRequest,
        response: HTTPURLResponse?,
        data: Data?,
        error: Error?,
        metrics: URLSessionTaskMetrics?
    ) { }
}

// MARK: - Network Event

/// 網路事件封裝
public struct NetworkEvent {
    public let request: URLRequest
    public let response: HTTPURLResponse?
    public let data: Data?
    public let error: Error?
    public let metrics: URLSessionTaskMetrics?
    public let startTime: Date
    public let endTime: Date

    /// 請求耗時（秒）
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// 是否成功
    public var isSuccess: Bool {
        error == nil && (response?.statusCode ?? 0) < 400
    }
}
