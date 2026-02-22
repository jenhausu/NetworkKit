//
//  MultipartFormDataBuilder.swift
//  NetworkKit
//
//  Created by Claude on 2026/2/2.
//

import Foundation

/// 將 MultipartFormData 內容編碼為 URLRequest body
struct MultipartFormDataBuilder: RequestBuilder {
    let formDataProvider: () -> MultipartFormData

    func adapted(_ request: URLRequest) throws -> URLRequest {
        var request = request
        let formData = formDataProvider()
        request.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = formData.encode()
        return request
    }
}
