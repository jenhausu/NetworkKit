//
//  RequestError.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2021/12/20.
//

import Foundation

public enum RequestError: Error, Equatable {
    case baseURLInvalid
    case noURL
    case paramEncodingFailed
}
