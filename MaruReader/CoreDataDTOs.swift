//
//  CoreDataDTOs.swift
//  MaruReader
//
//  Created by Claude on 9/21/25.
//
//  Sendable DTOs for Core Data entities to enable safe data transfer
//  across actor boundaries while maintaining Swift 6 concurrency safety.

import Foundation

// MARK: - Dictionary DTO

struct DictionaryDTO: Sendable, Identifiable {
    let id: UUID
    let title: String
    let author: String?
    let attribution: String?
    let displayDescription: String?
    let displayOrder: Int64
    let downloadURL: String?
    let termResultsEnabled: Bool
    let pitchAccentEnabled: Bool
    let termFrequencyEnabled: Bool
    let kanjiResultsEnabled: Bool
    let kanjiFrequencyEnabled: Bool
    let ipaEnabled: Bool
    let format: Int64
    let frequencyMode: String?
    let indexURL: String?
    let isComplete: Bool
    let isUpdatable: Bool?
    let minimumYomitanVersion: String?
    let revision: String?
    let sequenced: Bool?
    let sourceLanguage: String?
    let targetLanguage: String?
    let url: String?

    // Derived counts (computed on Core Data side)
    let termCount: Int64?
    let kanjiCount: Int64?
    let tagCount: Int64?
    let termFrequencyCount: Int64?
    let kanjiFrequencyCount: Int64?
    let pitchesCount: Int64?
    let ipaCount: Int64?

    init(from dictionary: Dictionary) {
        self.id = dictionary.id ?? UUID()
        self.title = dictionary.title ?? ""
        self.author = dictionary.author
        self.attribution = dictionary.attribution
        self.displayDescription = dictionary.displayDescription
        self.displayOrder = dictionary.displayOrder
        self.downloadURL = dictionary.downloadURL
        self.termResultsEnabled = dictionary.termResultsEnabled
        self.pitchAccentEnabled = dictionary.pitchAccentEnabled
        self.termFrequencyEnabled = dictionary.termFrequencyEnabled
        self.kanjiResultsEnabled = dictionary.kanjiResultsEnabled
        self.kanjiFrequencyEnabled = dictionary.kanjiFrequencyEnabled
        self.ipaEnabled = dictionary.ipaEnabled
        self.format = dictionary.format
        self.frequencyMode = dictionary.frequencyMode
        self.indexURL = dictionary.indexURL
        self.isComplete = dictionary.isComplete
        self.isUpdatable = dictionary.isUpdatable
        self.minimumYomitanVersion = dictionary.minimumYomitanVersion
        self.revision = dictionary.revision
        self.sequenced = dictionary.sequenced
        self.sourceLanguage = dictionary.sourceLanguage
        self.targetLanguage = dictionary.targetLanguage
        self.url = dictionary.url
        self.termCount = dictionary.termCount
        self.kanjiCount = dictionary.kanjiCount
        self.tagCount = dictionary.tagCount
        self.termFrequencyCount = dictionary.termFrequencyCount
        self.kanjiFrequencyCount = dictionary.kanjiFrequencyCount
        self.pitchesCount = dictionary.pitchesCount
        self.ipaCount = dictionary.ipaCount
    }
}

// MARK: - DictionaryTagMeta DTO

struct DictionaryTagMetaDTO: Sendable, Identifiable {
    let id: UUID
    let name: String
    let category: String
    let notes: String
    let order: Double
    let score: Double
    let dictionaryID: UUID?

    init(from tagMeta: DictionaryTagMeta) {
        self.id = tagMeta.id ?? UUID()
        self.name = tagMeta.name ?? ""
        self.category = tagMeta.category ?? ""
        self.notes = tagMeta.notes ?? ""
        self.order = tagMeta.order
        self.score = tagMeta.score
        self.dictionaryID = tagMeta.dictionary?.id
    }
}

// MARK: - DictionaryZIPFileImport DTO

struct DictionaryZIPFileImportDTO: Sendable, Identifiable {
    let id: UUID
    let file: URL
    let index: URL?
    let workingDirectory: URL
    let timeQueued: Date
    let timeStarted: Date?
    let timeCompleted: Date?
    let timeCancelled: Date?
    let timeFailed: Date?
    let displayProgressMessage: String?
    let archiveExtracted: Bool
    let indexProcessed: Bool
    let mediaImported: Bool
    let isStarted: Bool
    let isComplete: Bool
    let isCancelled: Bool
    let isFailed: Bool
    let dictionaryID: UUID?

    // Bank URLs (stored as transformable arrays)
    let tagBanks: [URL]?
    let termBanks: [URL]?
    let kanjiBanks: [URL]?
    let termMetaBanks: [URL]?
    let kanjiMetaBanks: [URL]?
    let processedTagBanks: [URL]?
    let processedTermBanks: [URL]?
    let processedKanjiBanks: [URL]?
    let processedTermMetaBanks: [URL]?
    let processedKanjiMetaBanks: [URL]?

    init(from importJob: DictionaryZIPFileImport) {
        self.id = importJob.id ?? UUID()
        self.file = importJob.file ?? URL(fileURLWithPath: "")
        self.index = importJob.index
        self.workingDirectory = importJob.workingDirectory ?? URL(fileURLWithPath: "")
        self.timeQueued = importJob.timeQueued ?? Date()
        self.timeStarted = importJob.timeStarted
        self.timeCompleted = importJob.timeCompleted
        self.timeCancelled = importJob.timeCancelled
        self.timeFailed = importJob.timeFailed
        self.displayProgressMessage = importJob.displayProgressMessage
        self.archiveExtracted = importJob.archiveExtracted
        self.indexProcessed = importJob.indexProcessed
        self.mediaImported = importJob.mediaImported
        self.isStarted = importJob.isStarted
        self.isComplete = importJob.isComplete
        self.isCancelled = importJob.isCancelled
        self.isFailed = importJob.isFailed
        self.dictionaryID = importJob.dictionary?.id
        self.tagBanks = importJob.tagBanks as? [URL]
        self.termBanks = importJob.termBanks as? [URL]
        self.kanjiBanks = importJob.kanjiBanks as? [URL]
        self.termMetaBanks = importJob.termMetaBanks as? [URL]
        self.kanjiMetaBanks = importJob.kanjiMetaBanks as? [URL]
        self.processedTagBanks = importJob.processedTagBanks as? [URL]
        self.processedTermBanks = importJob.processedTermBanks as? [URL]
        self.processedKanjiBanks = importJob.processedKanjiBanks as? [URL]
        self.processedTermMetaBanks = importJob.processedTermMetaBanks as? [URL]
        self.processedKanjiMetaBanks = importJob.processedKanjiMetaBanks as? [URL]
    }
}

// MARK: - Term DTO

struct TermDTO: Sendable, Identifiable {
    let id: UUID
    let expression: String
    let reading: String

    init(from term: Term) {
        self.id = term.id ?? UUID()
        self.expression = term.expression ?? ""
        self.reading = term.reading ?? ""
    }
}

// MARK: - TermEntry DTO

struct TermEntryDTO: Sendable, Identifiable {
    let id: UUID
    let score: Double
    let sequence: Int64
    let termTags: [String]
    let definitionTags: [String]
    let glossary: [Definition]
    let rules: [String]
    let termID: UUID?
    let dictionaryID: UUID?

    init(from termEntry: TermEntry) {
        self.id = termEntry.id ?? UUID()
        self.score = termEntry.score
        self.sequence = termEntry.sequence
        self.termTags = (termEntry.termTags as? [String]) ?? []
        self.definitionTags = (termEntry.definitionTags as? [String]) ?? []
        self.glossary = (termEntry.glossary as? [Definition]) ?? []
        self.rules = (termEntry.rules as? [String]) ?? []
        self.termID = termEntry.term?.id
        self.dictionaryID = termEntry.dictionary?.id
    }
}

// MARK: - TermFrequencyEntry DTO

struct TermFrequencyEntryDTO: Sendable, Identifiable {
    let id: UUID
    let value: Double
    let displayValue: String?
    let termID: UUID?
    let dictionaryID: UUID?

    init(from frequency: TermFrequencyEntry) {
        self.id = frequency.id ?? UUID()
        self.value = frequency.value
        self.displayValue = frequency.displayValue
        self.termID = frequency.term?.id
        self.dictionaryID = frequency.dictionary?.id
    }
}

// MARK: - Kanji DTO

struct KanjiDTO: Sendable, Identifiable {
    let id: UUID
    let character: String
    let entryCount: Int64?
    let frequencyCount: Int64?

    init(from kanji: Kanji) {
        self.id = kanji.id ?? UUID()
        self.character = kanji.character ?? ""
        self.entryCount = kanji.entryCount
        self.frequencyCount = kanji.frequencyCount
    }
}

// MARK: - KanjiEntry DTO

struct KanjiEntryDTO: Sendable, Identifiable {
    let id: UUID
    let kunyomi: [String]
    let onyomi: [String]
    let meanings: [String]
    let tags: [String]
    let stats: [String: String]
    let kanjiID: UUID?
    let dictionaryID: UUID?

    init(from kanjiEntry: KanjiEntry) {
        self.id = kanjiEntry.id ?? UUID()
        self.kunyomi = (kanjiEntry.kunyomi as? [String]) ?? []
        self.onyomi = (kanjiEntry.onyomi as? [String]) ?? []
        self.meanings = (kanjiEntry.meanings as? [String]) ?? []
        self.tags = (kanjiEntry.tags as? [String]) ?? []
        self.stats = (kanjiEntry.stats as? [String: String]) ?? [:]
        self.kanjiID = kanjiEntry.kanji?.id
        self.dictionaryID = kanjiEntry.dictionary?.id
    }
}

// MARK: - KanjiFrequencyEntry DTO

struct KanjiFrequencyEntryDTO: Sendable, Identifiable {
    let id: UUID
    let frequencyValue: Double
    let displayFrequency: String?
    let kanjiID: UUID?
    let dictionaryID: UUID?

    init(from frequency: KanjiFrequencyEntry) {
        self.id = frequency.id ?? UUID()
        self.frequencyValue = frequency.frequencyValue
        self.displayFrequency = frequency.displayFrequency
        self.kanjiID = frequency.kanji?.id
        self.dictionaryID = frequency.dictionary?.id
    }
}

// MARK: - PitchAccentEntry DTO

struct PitchAccentEntryDTO: Sendable, Identifiable {
    let id: UUID
    let mora: Int64?
    let pattern: String?
    let nasal: [Int]?
    let devoice: [Int]?
    let tags: [String]?
    let termID: UUID?
    let dictionaryID: UUID?

    init(from pitchEntry: PitchAccentEntry) {
        self.id = pitchEntry.id ?? UUID()
        self.mora = pitchEntry.mora
        self.pattern = pitchEntry.pattern
        self.nasal = pitchEntry.nasal as? [Int]
        self.devoice = pitchEntry.devoice as? [Int]
        self.tags = pitchEntry.tags as? [String]
        self.termID = pitchEntry.term?.id
        self.dictionaryID = pitchEntry.dictionary?.id
    }
}

// MARK: - IPAEntry DTO

struct IPAEntryDTO: Sendable, Identifiable {
    let id: UUID
    let transcription: String
    let tags: [String]?
    let termID: UUID?
    let dictionaryID: UUID?

    init(from ipaEntry: IPAEntry) {
        self.id = ipaEntry.id ?? UUID()
        self.transcription = ipaEntry.transcription ?? ""
        self.tags = ipaEntry.tags as? [String]
        self.termID = ipaEntry.term?.id
        self.dictionaryID = ipaEntry.dictionary?.id
    }
}

// MARK: - Collection Extensions

extension [Dictionary] {
    func toDTOs() -> [DictionaryDTO] {
        map { DictionaryDTO(from: $0) }
    }
}

extension [DictionaryTagMeta] {
    func toDTOs() -> [DictionaryTagMetaDTO] {
        map { DictionaryTagMetaDTO(from: $0) }
    }
}

extension [DictionaryZIPFileImport] {
    func toDTOs() -> [DictionaryZIPFileImportDTO] {
        map { DictionaryZIPFileImportDTO(from: $0) }
    }
}

extension [Term] {
    func toDTOs() -> [TermDTO] {
        map { TermDTO(from: $0) }
    }
}

extension [TermEntry] {
    func toDTOs() -> [TermEntryDTO] {
        map { TermEntryDTO(from: $0) }
    }
}

extension [TermFrequencyEntry] {
    func toDTOs() -> [TermFrequencyEntryDTO] {
        map { TermFrequencyEntryDTO(from: $0) }
    }
}

extension [Kanji] {
    func toDTOs() -> [KanjiDTO] {
        map { KanjiDTO(from: $0) }
    }
}

extension [KanjiEntry] {
    func toDTOs() -> [KanjiEntryDTO] {
        map { KanjiEntryDTO(from: $0) }
    }
}

extension [KanjiFrequencyEntry] {
    func toDTOs() -> [KanjiFrequencyEntryDTO] {
        map { KanjiFrequencyEntryDTO(from: $0) }
    }
}

extension [PitchAccentEntry] {
    func toDTOs() -> [PitchAccentEntryDTO] {
        map { PitchAccentEntryDTO(from: $0) }
    }
}

extension [IPAEntry] {
    func toDTOs() -> [IPAEntryDTO] {
        map { IPAEntryDTO(from: $0) }
    }
}
