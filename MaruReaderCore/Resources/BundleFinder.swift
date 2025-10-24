//
//  BundleFinder.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/23/25.
//

import Foundation

private class BundleFinder {}

public extension Bundle {
    static let framework: Bundle = {
        let bundle = Bundle(for: BundleFinder.self)
        let bundleName = "MaruResources"
        let url = bundle.resourceURL?.appendingPathComponent(bundleName + ".bundle")
        return url.flatMap(Bundle.init(url:)) ?? bundle
    }()
}
