//
//  ResponseAction.swift
//  NetworkKit
//
//  Created by 蘇健豪 on 2021/12/20.
//

import Foundation

public enum ResponseAction<Req: HTTPRequest> {
    case `continue`(Data, HTTPURLResponse)
    case restart([ResponseHandler])
    case error(Error)
    case done(Req.ResponseType)
}
