//
//  NetworkTask.swift
//  NetworkKit
//
//  Created by Claude on 2026/2/1.
//

import Foundation

/// 代表一個可取消的網路請求任務
public final class NetworkTask<T> {
    private let task: Task<Result<T, Error>, Never>

    /// 取得請求結果（會等待直到請求完成）
    public var result: Result<T, Error> {
        get async {
            await task.value
        }
    }

    /// 請求是否已被取消
    public var isCancelled: Bool {
        task.isCancelled
    }

    init(task: Task<Result<T, Error>, Never>) {
        self.task = task
    }

    /// 取消此請求
    /// - Note: 取消後，底層的 URLSessionTask 會被中止，result 會回傳 URLError.cancelled
    public func cancel() {
        task.cancel()
    }
}

// MARK: - Convenience

public extension NetworkTask {
    /// 以 async/await 方式取得結果並拋出錯誤
    func value() async throws -> T {
        let result = await self.result
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
