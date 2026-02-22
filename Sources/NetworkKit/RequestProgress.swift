//
//  RequestProgress.swift
//  NetworkKit
//
//  Created by Claude on 2026/2/2.
//

import Foundation

/// 請求進度資訊
public struct RequestProgress {
    /// 已傳輸的位元組數
    public let bytes: Int64
    /// 預期總位元組數（未知時為 -1）
    public let totalBytes: Int64

    /// 完成比例（0.0 ~ 1.0），總大小未知時回傳 nil
    public var fractionCompleted: Double? {
        guard totalBytes > 0 else { return nil }
        return Double(bytes) / Double(totalBytes)
    }
}

// MARK: - Internal Progress Delegate

/// 用於追蹤單次請求進度的 Delegate
final class TaskProgressDelegate: NSObject, URLSessionTaskDelegate {
    var uploadProgressHandler: ((RequestProgress) -> Void)?

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = RequestProgress(bytes: totalBytesSent, totalBytes: totalBytesExpectedToSend)
        uploadProgressHandler?(progress)
    }
}
