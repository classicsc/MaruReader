// CoreDataTestSupport.swift
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

import Foundation
import MaruAnki
import MaruManga
@testable import MaruReader
import MaruReaderCore

func makeBookPersistenceController(
    storeKind: CoreDataTestStoreKind = .inMemory
) -> BookDataPersistenceController {
    CoreDataTransformers.register()
    let container = CoreDataTestFactory.makePersistentContainer(
        name: "MaruBookData",
        bundle: Bundle(for: BookDataPersistenceController.self),
        storeKind: storeKind
    )

    return BookDataPersistenceController(container: container)
}

func makeMangaPersistenceController(
    storeKind: CoreDataTestStoreKind = .inMemory
) -> MangaDataPersistenceController {
    let container = CoreDataTestFactory.makePersistentContainer(
        name: "MaruMangaData",
        bundle: Bundle(for: MangaDataPersistenceController.self),
        storeKind: storeKind
    )

    return MangaDataPersistenceController(container: container)
}

func makeAnkiPersistenceController(
    storeKind: CoreDataTestStoreKind = .temporarySQLite
) -> AnkiPersistenceController {
    let container = CoreDataTestFactory.makePersistentContainer(
        name: "MaruAnki",
        bundle: Bundle(for: AnkiPersistenceController.self),
        storeKind: storeKind
    )

    return AnkiPersistenceController(container: container)
}
