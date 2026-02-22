//
//  MultipartFormDataRequest.swift
//  NetworkKit
//
//  Created by Claude on 2026/2/2.
//

import Foundation

/// 支援檔案上傳的請求協定
/// 使用 multipart/form-data 格式，適合混合上傳文字欄位與檔案
///
/// 使用範例：
/// ```swift
/// struct UploadAvatarRequest: MultipartFormDataRequest {
///     typealias ResponseType = UploadResponse
///
///     let baseURL = URL(string: "https://api.example.com")!
///     let method: HTTPMethod = .post
///     let path = "/users/avatar"
///     let header = HTTPHeader()
///     let decoder = JSONDecoder()
///
///     let imageData: Data
///     let userId: String
///
///     func buildFormData() -> MultipartFormData {
///         let form = MultipartFormData()
///         form.append(userId, withName: "user_id")
///         form.append(imageData, withName: "avatar", fileName: "avatar.jpg", mimeType: "image/jpeg")
///         return form
///     }
/// }
/// ```
public protocol MultipartFormDataRequest: HTTPRequest {
    /// 建構 multipart/form-data 內容
    func buildFormData() -> MultipartFormData
}

public extension MultipartFormDataRequest {
    var contentType: ContentType { .formData }

    var requestBuilders: [RequestBuilder] {[
        PathBuilder(baseURL: baseURL, path: path),
        method.builder,
        header.builder,
        MultipartFormDataBuilder(formDataProvider: buildFormData)
    ]}
}
