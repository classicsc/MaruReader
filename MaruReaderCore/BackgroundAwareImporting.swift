// BackgroundAwareImporting.swift
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

/// Protocol for import managers that can gracefully cancel work when the app
/// enters background, preventing `0xdead10cc` crashes from held SQLite locks.
public protocol BackgroundAwareImporting: Actor {
    /// Whether this manager currently has an import task running.
    var hasActiveImport: Bool { get }

    /// Cancel all active and queued imports for app backgrounding, then wait
    /// for in-flight cleanup to complete so Core Data contexts are flushed
    /// and SQLite locks released before iOS suspends the process.
    func cancelForBackgrounding() async
}
