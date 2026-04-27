// MaruReaderAppStartupPolicyTests.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

@testable import MaruReader
import Testing

struct MaruReaderAppStartupPolicyTests {
    @Test func webFilterMaintenance_DisabledUnderXCTest() {
        let shouldStart = MaruReaderApp.shouldStartWebFilterMaintenance(
            arguments: ["MaruReader"],
            environment: ["XCTestConfigurationFilePath": "/tmp/MaruReaderTests.xctestconfiguration"]
        )

        #expect(!shouldStart)
    }

    @Test func webFilterMaintenance_DisabledByLaunchArgument() {
        let shouldStart = MaruReaderApp.shouldStartWebFilterMaintenance(
            arguments: ["MaruReader", "--disableWebFilterMaintenance"],
            environment: [:]
        )

        #expect(!shouldStart)
    }

    @Test func webFilterMaintenance_EnabledByDefault() {
        let shouldStart = MaruReaderApp.shouldStartWebFilterMaintenance(
            arguments: ["MaruReader"],
            environment: [:]
        )

        #expect(shouldStart)
    }
}
