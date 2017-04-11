//
//  Package.swift
//  GPX Namer
//
//  Created by Wade Tregaskis on 9/4/17.
//  Copyright © 2017 Wade Tregaskis. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "GPX Namer",
    dependencies: [
        .Package(url: "https://github.com/tadija/AEXML.git", majorVersion: 4),
        .Package(url: "https://github.com/rbdr/CommandLineKit.git", majorVersion: 4),
        .Package(url: "https://github.com/DaveWoodCom/XCGLogger.git", majorVersion: 5)
    ]
)
