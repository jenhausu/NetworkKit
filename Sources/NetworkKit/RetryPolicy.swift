//
//  RetryPolicy.swift
//  NetworkKit
//
//  Created by Claude on 2026/2/2.
//

import Foundation

/// 重試延遲策略
public enum DelayStrategy {
    /// 固定延遲
    case fixed(TimeInterval)
    /// 指數退避：delay = base * 2^retryCount，並設上限
    case exponential(base: TimeInterval, maxDelay: TimeInterval)

    func delay(for retryCount: Int) -> TimeInterval {
        switch self {
        case .fixed(let interval):
            return interval
        case .exponential(let base, let maxDelay):
            let delay = base * pow(2.0, Double(retryCount))
            return min(delay, maxDelay)
        }
    }
}

/// 重試策略配置
public struct RetryPolicy {
    /// 最大重試次數
    public let maxRetries: Int
    /// 可重試的 HTTP 狀態碼
    public let retryableStatusCodes: Set<Int>
    /// 可重試的 URLError 代碼
    public let retryableURLErrorCodes: Set<URLError.Code>
    /// 延遲策略
    public let delayStrategy: DelayStrategy

    /// 初始化重試策略
    public init(
        maxRetries: Int = 3,
        retryableStatusCodes: Set<Int> = [408, 500, 502, 503, 504],
        retryableURLErrorCodes: Set<URLError.Code> = [
            .timedOut,
            .networkConnectionLost,
            .notConnectedToInternet,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed
        ],
        delayStrategy: DelayStrategy = .exponential(base: 1.0, maxDelay: 30.0)
    ) {
        self.maxRetries = maxRetries
        self.retryableStatusCodes = retryableStatusCodes
        self.retryableURLErrorCodes = retryableURLErrorCodes
        self.delayStrategy = delayStrategy
    }

    /// 判斷是否應該重試網路錯誤
    func shouldRetry(error: Error, retryCount: Int) -> Bool {
        guard retryCount < maxRetries else { return false }
        if let urlError = error as? URLError {
            return retryableURLErrorCodes.contains(urlError.code)
        }
        return false
    }

    /// 判斷是否應該重試 HTTP 狀態碼錯誤
    func shouldRetry(statusCode: Int, retryCount: Int) -> Bool {
        guard retryCount < maxRetries else { return false }
        return retryableStatusCodes.contains(statusCode)
    }

    /// 計算重試前的等待時間
    func delay(for retryCount: Int) -> TimeInterval {
        delayStrategy.delay(for: retryCount)
    }
}
