//
//  PterodactylAPIError.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import Foundation

enum PterodactylAPIError: Error {
    case invalidURL(String)
    case invalidHTTPResponse(Data)
    case invalidResponseCode(Int)
}
