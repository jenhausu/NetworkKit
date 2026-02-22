//
//  MultipartFormData.swift
//  NetworkKit
//
//  Created by Claude on 2026/2/2.
//

import Foundation

/// 用於建構 multipart/form-data 請求 body
/// 支援文字欄位、Data 與 File URL
public final class MultipartFormData {

    /// multipart boundary 字串
    public let boundary: String

    private var parts: [Part] = []

    public init(boundary: String = "Boundary+\(UUID().uuidString)") {
        self.boundary = boundary
    }

    // MARK: - Append

    /// 附加文字欄位
    /// - Parameters:
    ///   - value: 欄位值
    ///   - name: 欄位名稱
    public func append(_ value: String, withName name: String) {
        guard let data = value.data(using: .utf8) else { return }
        let headers = "Content-Disposition: form-data; name=\"\(name)\""
        parts.append(Part(headers: headers, data: data))
    }

    /// 附加二進位資料（如圖片）
    /// - Parameters:
    ///   - data: 原始資料
    ///   - name: 欄位名稱
    ///   - fileName: 檔案名稱
    ///   - mimeType: MIME 類型，如 "image/jpeg"
    public func append(_ data: Data, withName name: String, fileName: String, mimeType: String) {
        let headers = "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\nContent-Type: \(mimeType)"
        parts.append(Part(headers: headers, data: data))
    }

    /// 附加本地檔案
    /// - Parameters:
    ///   - fileURL: 本地檔案路徑
    ///   - name: 欄位名稱
    ///   - mimeType: MIME 類型，nil 時自動推斷
    /// - Throws: 讀取檔案失敗時拋出錯誤
    public func append(fileURL: URL, withName name: String, mimeType: String? = nil) throws {
        let data = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let resolvedMimeType = mimeType ?? fileURL.mimeType
        append(data, withName: name, fileName: fileName, mimeType: resolvedMimeType)
    }

    // MARK: - Build

    /// 建構最終的 Data
    public func encode() -> Data {
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"

        for part in parts {
            body.append(boundaryPrefix)
            body.append("\(part.headers)\r\n\r\n")
            body.append(part.data)
            body.append("\r\n")
        }

        body.append("--\(boundary)--\r\n")
        return body
    }

    /// Content-Type header 值
    public var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    // MARK: - Private

    private struct Part {
        let headers: String
        let data: Data
    }
}

// MARK: - Data Helper

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - URL MIME Type

private extension URL {
    var mimeType: String {
        switch pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png":         return "image/png"
        case "gif":         return "image/gif"
        case "webp":        return "image/webp"
        case "heic":        return "image/heic"
        case "pdf":         return "application/pdf"
        case "mp4":         return "video/mp4"
        case "mov":         return "video/quicktime"
        case "mp3":         return "audio/mpeg"
        case "txt":         return "text/plain"
        case "json":        return "application/json"
        case "zip":         return "application/zip"
        default:            return "application/octet-stream"
        }
    }
}
