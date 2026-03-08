// AudioLookupRequest.swift
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

struct AudioLookupRequest {
    let term: String
    let reading: String?
    let downstepPosition: String? // e.g. "0" for no downstep, "3" for downstep after 3rd mora, "1-1-1" for compound patterns
    let language: String

    init(term: String, reading: String?, downstepPosition: String?, language: String = "ja") {
        self.term = term
        self.reading = reading
        self.language = language
        self.downstepPosition = downstepPosition
    }
}
