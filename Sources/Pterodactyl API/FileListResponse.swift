//
//  FileListResponse.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation

struct FileListResponse: Decodable {
    let files: [File]
    
    enum CodingKeys: String, CodingKey {
        case files = "data"
    }
}

struct File: Decodable {
    let name: String
    let isFile: Bool
    
    init(from decoder: Decoder) throws {
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        let container = try rootContainer.nestedContainer(keyedBy: CodingKeys.self, forKey: .attributes)
        self.name = try container.decode(String.self, forKey: .name)
        self.isFile = try container.decode(Bool.self, forKey: .isFile)
    }
    
    enum RootCodingKeys: CodingKey {
        case attributes
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case isFile = "is_file"
    }
}
