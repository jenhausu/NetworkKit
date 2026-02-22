//
//  NetworkLogger.swift
//  NetworkKit
//
//  Created by Claude on 2026/2/2.
//

import Foundation

/// 網路日誌級別
public enum LogLevel: Int, Comparable {
    /// 不輸出任何日誌
    case none = 0
    /// 基本資訊：method、URL、status code、耗時
    case basic = 1
    /// 基本 + headers
    case headers = 2
    /// 全部資訊：包含 request/response body
    case verbose = 3

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 預設的網路日誌監控器
/// 實作 EventMonitor 協定，將請求/回應資訊輸出到控制台
public final class NetworkLogger: EventMonitor {

    private let level: LogLevel

    /// 初始化 NetworkLogger
    /// - Parameter level: 日誌級別，預設為 `.basic`
    public init(level: LogLevel = .basic) {
        self.level = level
    }

    // MARK: - EventMonitor

    public func requestWillStart(_ request: URLRequest) {
        guard level >= .basic else { return }

        var lines: [String] = []
        lines.append("")
        lines.append("📤 [\(request.httpMethod ?? "UNKNOWN")] \(request.url?.absoluteString ?? "unknown")")

        if level >= .headers {
            if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                lines.append("   Headers: \(formatHeaders(headers))")
            }
        }

        if level >= .verbose {
            if let body = request.httpBody, let bodyString = formatBody(body) {
                lines.append("   Body: \(bodyString)")
            }
        }

        print(lines.joined(separator: "\n"))
    }

    public func requestDidFinish(
        _ request: URLRequest,
        response: HTTPURLResponse?,
        data: Data?,
        error: Error?,
        metrics: URLSessionTaskMetrics?
    ) {
        guard level >= .basic else { return }

        let duration = metrics.map { formatDuration($0.taskInterval.duration) } ?? "unknown"

        var lines: [String] = []

        if let error = error {
            lines.append("❌ [\(request.httpMethod ?? "UNKNOWN")] \(request.url?.absoluteString ?? "unknown")")
            lines.append("   Error: \(error.localizedDescription) | Duration: \(duration)")
        } else if let response = response {
            let icon = response.statusCode < 400 ? "📥" : "⚠️"
            lines.append("\(icon) [\(response.statusCode)] \(request.url?.absoluteString ?? "unknown") | Duration: \(duration)")

            if level >= .headers {
                let headers: [String: String] = response.allHeaderFields.reduce(into: [:]) { result, pair in
                    if let key = pair.key as? String, let value = pair.value as? String {
                        result[key] = value
                    }
                }
                if !headers.isEmpty {
                    lines.append("   Headers: \(formatHeaders(headers))")
                }
            }

            if level >= .verbose, let data = data, let bodyString = formatBody(data) {
                lines.append("   Body: \(bodyString)")
            }
        }

        lines.append("")
        print(lines.joined(separator: "\n"))
    }

    // MARK: - Private

    private func formatHeaders(_ headers: [String: String]) -> String {
        let sorted = headers.sorted { $0.key < $1.key }
        return "[\(sorted.map { "\($0.key): \($0.value)" }.joined(separator: ", "))]"
    }

    private func formatBody(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let string = String(data: pretty, encoding: .utf8) else {
            return String(data: data, encoding: .utf8)
        }
        return string
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return "\(Int(duration * 1000))ms"
        }
        return String(format: "%.2fs", duration)
    }
}
