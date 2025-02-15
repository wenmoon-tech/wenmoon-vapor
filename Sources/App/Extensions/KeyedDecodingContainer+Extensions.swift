//
//  File.swift
//  wenmoon-vapor
//
//  Created by Artur Tkachenko on 15.02.25.
//

import Foundation

extension KeyedDecodingContainer {
    func decodeSafeURL(forKey key: KeyedDecodingContainer<K>.Key) -> URL? {
        if let urlString = try? decodeIfPresent(String.self, forKey: key),
           !urlString.isEmpty {
            return URL(string: urlString)
        }
        return nil
    }

    func decodeSafeURLArray(forKey key: KeyedDecodingContainer<K>.Key) -> [URL]? {
        if let urlStrings = try? decodeIfPresent([String].self, forKey: key) {
            let urls = urlStrings.compactMap { URL(string: $0).flatMap { $0.absoluteString.isEmpty ? nil : $0 } }
            return urls.isEmpty ? nil : urls
        }
        return nil
    }
}
