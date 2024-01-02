//
//  FileDownloadLinkResponse.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import Foundation

struct FileDownloadLinkResponse: Decodable {
    let url: String
    
    enum RootCodingKeys: CodingKey {
        case attributes
    }
    
    enum CodingKeys: CodingKey {
        case url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RootCodingKeys.self)
            .nestedContainer(keyedBy: CodingKeys.self, forKey: .attributes)
        self.url = try container.decode(String.self, forKey: .url)
    }
}
