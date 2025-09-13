//
//  TermMetaParsingTests.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/7/25.
//

import Foundation
@testable import MaruReader
import Testing

struct TermMetaParsingTests {
    @Test func parseTermMetaData_ValidRow_ReturnsTermMetaData() throws {
        // Purpose: Ensure term metadata rows are parsed correctly.
        // Input: Sample term metadata row.
        // Expected: TermMetaData with term, mode, and data matching input.
        let jsonString = """
        [
            ["食べる", "freq", {"value": 5000, "displayValue": "5000㋕"}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let metaDataArray = try decoder.decode([TermMetaBankV3Entry].self, from: data)

        #expect(metaDataArray.count == 1)
        #expect(metaDataArray[0].term == "食べる")
        #expect(metaDataArray[0].kind == .freq)
        switch metaDataArray[0].data {
        case let .frequency(freqData):
            #expect(freqData.value == 5000)
            #expect(freqData.displayValue == "5000㋕")
        default:
            #expect(Bool(false), "Expected frequency data")
        }
    }

    @Test func parseTermMetaData_FrequencyWithReading_ParsesCorrectly() throws {
        // Purpose: Test frequency data with reading field.
        // Input: Frequency metadata with reading and frequency object.
        // Expected: Parsed freqReading, freqDisplayValue, and freqValue.
        let jsonString = """
        [
            ["食べる", "freq", {"reading": "たべる", "frequency": {"value": 3000, "displayValue": "3k"}}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let metaDataArray = try decoder.decode([TermMetaBankV3Entry].self, from: data)

        #expect(metaDataArray.count == 1)
        #expect(metaDataArray[0].term == "食べる")
        #expect(metaDataArray[0].kind == .freq)
        switch metaDataArray[0].data {
        case let .frequencyWithReading(freqData):
            #expect(freqData.reading == "たべる")
            #expect(freqData.frequency.value == 3000)
            #expect(freqData.frequency.displayValue == "3k")
        default:
            #expect(Bool(false), "Expected frequency with reading data")
        }
    }

    @Test func parseTermMetaData_FrequencyAsNumber_ParsesCorrectly() throws {
        // Purpose: Test frequency data as simple number.
        // Input: Frequency as direct number value.
        // Expected: Parsed FrequencyData with value 1500 and no displayValue.
        let jsonString = """
        [
            ["食べる", "freq", 1500]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let metaDataArray = try decoder.decode([TermMetaBankV3Entry].self, from: data)

        #expect(metaDataArray.count == 1)
        let entry = metaDataArray[0]
        #expect(entry.term == "食べる")
        #expect(entry.kind == .freq)
        switch entry.data {
        case let .frequency(freq):
            #expect(freq.value == 1500)
            #expect(freq.displayValue == nil)
        default:
            #expect(Bool(false), "Expected simple frequency data")
        }
    }

    @Test func parseTermMetaData_FrequencyAsString_ParsesNumber() throws {
        // Purpose: Test frequency data as string with number.
        // Input: Frequency as string "2500".
        // Expected: Parsed FrequencyData with value 2500 and displayValue "2500".
        let jsonString = """
        [
            ["食べる", "freq", "2500"]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let metaDataArray = try decoder.decode([TermMetaBankV3Entry].self, from: data)

        #expect(metaDataArray.count == 1)
        let entry = metaDataArray[0]
        switch entry.data {
        case let .frequency(freq):
            #expect(freq.value == 2500)
            #expect(freq.displayValue == "2500")
        default:
            #expect(Bool(false), "Expected frequency data from string")
        }
    }

    @Test func parseTermMetaData_FrequencyScientificNotation_ParsesCorrectly() throws {
        // Purpose: Test frequency data with scientific notation.
        // Input: Frequency as string "3.14e2".
        // Expected: Parsed value 314 and displayValue preserved.
        let jsonString = """
        [
            ["食べる", "freq", "3.14e2"]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let metaDataArray = try decoder.decode([TermMetaBankV3Entry].self, from: data)

        #expect(metaDataArray.count == 1)
        switch metaDataArray[0].data {
        case let .frequency(freq):
            #expect(freq.value == 314)
            #expect(freq.displayValue == "3.14e2")
        default:
            #expect(Bool(false), "Expected frequency data")
        }
    }

    @Test func parseTermMetaData_FrequencyInvalidString_Throws() throws {
        // Purpose: Test invalid frequency string now results in decoding error (strict schema).
        // Input: Frequency as string "invalid".
        // Expected: Decoding throws.
        let jsonString = """
        [
            ["食べる", "freq", "invalid"]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()

        #expect(throws: Error.self) {
            _ = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        }
    }

    @Test func parseTermMetaData_NonFrequencyMode_NoFrequencyData() throws {
        // Purpose: Ensure pitch metadata isn't misinterpreted as frequency data.
        let jsonString = """
        [
            ["食べる", "pitch", {"reading": "たべる", "pitches": [{"position": 2}]}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let metaDataArray = try decoder.decode([TermMetaBankV3Entry].self, from: data)

        #expect(metaDataArray.count == 1)
        let entry = metaDataArray[0]
        #expect(entry.kind == .pitch)
        switch entry.data {
        case let .pitch(pitchData):
            #expect(pitchData.reading == "たべる")
        default:
            #expect(Bool(false), "Expected pitch data")
        }
    }

    @Test func parseTermMetaData_PitchWithIntegerPosition_ParsesCorrectly() throws {
        let jsonString = """
        [
            ["食べる", "pitch", {"reading": "たべる", "pitches": [{"position": 2}]}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        #expect(entries.count == 1)
        switch entries[0].data {
        case let .pitch(pitch):
            #expect(pitch.reading == "たべる")
            #expect(pitch.pitches.count == 1)
            switch pitch.pitches[0].position {
            case let .mora(n): #expect(n == 2)
            default: #expect(Bool(false), "Expected mora position")
            }
            #expect(pitch.pitches[0].nasal == nil)
            #expect(pitch.pitches[0].devoice == nil)
            #expect(pitch.pitches[0].tags == nil)
        default:
            #expect(Bool(false), "Expected pitch data")
        }
    }

    @Test func parseTermMetaData_PitchWithPatternPosition_ParsesCorrectly() throws {
        let jsonString = """
        [
            ["美しい", "pitch", {"reading": "うつくしい", "pitches": [{"position": "HLLL"}]}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        #expect(entries.count == 1)
        switch entries[0].data {
        case let .pitch(pitch):
            #expect(pitch.reading == "うつくしい")
            #expect(pitch.pitches.count == 1)
            switch pitch.pitches[0].position {
            case let .pattern(s): #expect(s == "HLLL")
            default: #expect(Bool(false), "Expected pattern position")
            }
        default:
            #expect(Bool(false), "Expected pitch data")
        }
    }

    @Test func parseTermMetaData_PitchWithNasalSingle_ParsesCorrectly() throws {
        let jsonString = """
        [
            ["本", "pitch", {"reading": "ほん", "pitches": [{"position": 1, "nasal": 2}]}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        switch entries[0].data {
        case let .pitch(pitch):
            #expect(pitch.pitches.count == 1)
            if case let .mora(n) = pitch.pitches[0].position { #expect(n == 1) } else { #expect(Bool(false)) }
            #expect(pitch.pitches[0].nasal == [2])
            #expect(pitch.pitches[0].devoice == nil)
        default: #expect(Bool(false), "Expected pitch data")
        }
    }

    @Test func parseTermMetaData_PitchWithNasalArray_ParsesCorrectly() throws {
        let jsonString = """
        [
            ["本", "pitch", {"reading": "ほん", "pitches": [{"position": 1, "nasal": [1, 3]}]}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        switch entries[0].data {
        case let .pitch(pitch):
            #expect(pitch.pitches[0].nasal == [1, 3])
        default: #expect(Bool(false), "Expected pitch data")
        }
    }

    @Test func parseTermMetaData_PitchWithDevoiceArray_ParsesCorrectly() throws {
        let jsonString = """
        [
            ["本", "pitch", {"reading": "ほん", "pitches": [{"position": 1, "devoice": [2, 4]}]}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        switch entries[0].data {
        case let .pitch(pitch):
            #expect(pitch.pitches[0].devoice == [2, 4])
            #expect(pitch.pitches[0].nasal == nil)
        default: #expect(Bool(false), "Expected pitch data")
        }
    }

    @Test func parseTermMetaData_PitchWithTags_ParsesCorrectly() throws {
        let jsonString = """
        [
            ["食べる", "pitch", {"reading": "たべる", "pitches": [{"position": 2, "tags": ["v1", "common"]}]}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        switch entries[0].data {
        case let .pitch(pitch):
            #expect(pitch.pitches[0].tags == ["v1", "common"])
        default: #expect(Bool(false), "Expected pitch data")
        }
    }

    @Test func parseTermMetaData_PitchMultipleAccents_ParsesCorrectly() throws {
        let jsonString = """
        [
            ["本", "pitch", {
                "reading": "ほん", 
                "pitches": [
                    {"position": 0, "tags": ["heiban"]},
                    {"position": 1, "tags": ["odaka"]}
                ]
            }]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        switch entries[0].data {
        case let .pitch(pitch):
            #expect(pitch.pitches.count == 2)
            if case let .mora(n0) = pitch.pitches[0].position { #expect(n0 == 0) } else { #expect(Bool(false)) }
            if case let .mora(n1) = pitch.pitches[1].position { #expect(n1 == 1) } else { #expect(Bool(false)) }
            #expect(pitch.pitches[0].tags == ["heiban"])
            #expect(pitch.pitches[1].tags == ["odaka"])
        default: #expect(Bool(false), "Expected pitch data")
        }
    }

    @Test func parseTermMetaData_PitchComplexExample_ParsesAllFields() throws {
        let jsonString = """
        [
            ["歩く", "pitch", {
                "reading": "あるく", 
                "pitches": [{
                    "position": "HLL",
                    "nasal": [1],
                    "devoice": [2, 3],
                    "tags": ["v5k", "intransitive"]
                }]
            }]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        switch entries[0].data {
        case let .pitch(pitch):
            #expect(pitch.reading == "あるく")
            #expect(pitch.pitches.count == 1)
            if case let .pattern(p) = pitch.pitches[0].position { #expect(p == "HLL") } else { #expect(Bool(false)) }
            #expect(pitch.pitches[0].nasal == [1])
            #expect(pitch.pitches[0].devoice == [2, 3])
            #expect(pitch.pitches[0].tags == ["v5k", "intransitive"])
        default: #expect(Bool(false), "Expected pitch data")
        }
    }

    @Test func parseTermMetaData_PitchInvalidFormat_Throws() throws {
        // Purpose: Missing required 'pitches' now throws.
        let jsonString = """
        [
            ["食べる", "pitch", {"reading": "たべる"}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        #expect(throws: Error.self) {
            _ = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        }
    }

    @Test func parseTermMetaData_PitchHeiban_ParsesZeroPosition() throws {
        let jsonString = """
        [
            ["猫", "pitch", {"reading": "ねこ", "pitches": [{"position": 0}]}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        switch entries[0].data {
        case let .pitch(pitch):
            if case let .mora(n) = pitch.pitches[0].position { #expect(n == 0) } else { #expect(Bool(false)) }
        default: #expect(Bool(false), "Expected pitch data")
        }
    }

    @Test func parseTermMetaData_ValidIPA_ReturnsCorrectData() throws {
        let jsonString = """
        [
            ["食べる", "ipa", {"reading": "たべる", "transcriptions": [{"ipa": "/taberu/"}]}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        switch entries[0].data {
        case let .ipa(ipa):
            #expect(ipa.reading == "たべる")
            #expect(ipa.transcriptions.count == 1)
            #expect(ipa.transcriptions[0].ipa == "/taberu/")
            #expect(ipa.transcriptions[0].tags == nil)
        default: #expect(Bool(false), "Expected IPA data")
        }
    }

    @Test func parseTermMetaData_IPAWithTags_ReturnsCorrectData() throws {
        let jsonString = """
        [
            ["美しい", "ipa", {"reading": "うつくしい", "transcriptions": [{"ipa": "/utsukʊʃiː/", "tags": ["adjective", "formal"]}]}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        switch entries[0].data {
        case let .ipa(ipa):
            #expect(ipa.reading == "うつくしい")
            #expect(ipa.transcriptions.count == 1)
            #expect(ipa.transcriptions[0].ipa == "/utsukʊʃiː/")
            #expect(ipa.transcriptions[0].tags == ["adjective", "formal"])
        default: #expect(Bool(false), "Expected IPA data")
        }
    }

    @Test func parseTermMetaData_IPAMultipleTranscriptions_ReturnsAll() throws {
        let jsonString = """
        [
            ["歩く", "ipa", {"reading": "あるく", "transcriptions": [
                {"ipa": "/aruku/", "tags": ["standard"]},
                {"ipa": "/aɾuku/", "tags": ["precise"]},
                {"ipa": "/aɹuku/"}
            ]}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        switch entries[0].data {
        case let .ipa(ipa):
            #expect(ipa.reading == "あるく")
            #expect(ipa.transcriptions.count == 3)
            #expect(ipa.transcriptions[0].ipa == "/aruku/")
            #expect(ipa.transcriptions[0].tags == ["standard"])
            #expect(ipa.transcriptions[1].ipa == "/aɾuku/")
            #expect(ipa.transcriptions[1].tags == ["precise"])
            #expect(ipa.transcriptions[2].ipa == "/aɹuku/")
            #expect(ipa.transcriptions[2].tags == nil)
        default: #expect(Bool(false), "Expected IPA data")
        }
    }

    @Test func parseTermMetaData_InvalidIPA_Throws() throws {
        // Purpose: Malformed IPA data should now throw.
        let jsonString = """
        [
            ["食べる", "ipa", {"invalid": "data"}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        #expect(throws: Error.self) {
            _ = try decoder.decode([TermMetaBankV3Entry].self, from: data)
        }
    }

    @Test func parseTermMetaData_UnsupportedMode_ThrowsUnsupportedMetaMode() throws {
        // Purpose: Test that unsupported metadata mode throws appropriate error.
        // Input: Metadata with invalid mode "unknown".
        // Expected: Throws ParserError.unsupportedMetaMode.
        let jsonString = """
        [
            ["食べる", "unknown", "some data"]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            try decoder.decode([TermMetaBankV3Entry].self, from: data)
        }
    }
}
