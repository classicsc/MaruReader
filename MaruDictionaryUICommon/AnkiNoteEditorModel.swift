// AnkiNoteEditorModel.swift
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

import AVFoundation
import Foundation
import MaruAnki
import MaruReaderCore
import Observation
import SwiftUI

/// Holds one note draft while the user edits it, and submits it through the scheme handler that built it.
@MainActor
@Observable
final class AnkiNoteEditorModel {
    private(set) var draft: AnkiNoteDraft
    let termGroup: GroupedSearchResults
    /// Anki would reject the note as a duplicate; submitting adds it anyway.
    let isDuplicate: Bool
    private(set) var isSubmitting = false
    var errorMessage: String?
    private(set) var audioSources: [AudioLookupSource] = []
    private(set) var isLoadingAudioSources = false
    let audioPlayer = AudioPreviewPlayer()

    private let resolver: any TemplateValueResolver
    private let submitDraft: @Sendable (AnkiNoteDraft) async -> String
    private let onFinished: @MainActor (String) -> Void
    private let audioLookup = AudioURLSchemeHandler()
    private var audioSourcesTask: Task<Void, Never>?

    /// - Parameter onFinished: Called with the add button state once the note was added or found to exist.
    init(context: AnkiNoteEditorContext, onFinished: @escaping @MainActor (String) -> Void) {
        draft = context.draft
        termGroup = context.termGroup
        isDuplicate = context.isDuplicate
        resolver = context.resolver
        submitDraft = context.submit
        self.onFinished = onFinished
    }

    var editableFields: [AnkiNoteDraftField] {
        draft.fields.filter { !$0.isAutomatic }
    }

    /// Fields whose values have no editing interface of their own, such as frequency and pitch lists.
    var automaticFields: [AnkiNoteDraftField] {
        draft.fields.filter(\.isAutomatic)
    }

    func field(_ name: String) -> AnkiNoteDraftField? {
        draft.field(named: name)
    }

    func value(_ id: UUID, in fieldName: String) -> AnkiNoteDraftValue? {
        field(fieldName)?.values.first { $0.id == id }
    }

    func restore(field name: String) {
        draft.update(field: name) { $0.restore() }
    }

    func moveValues(in fieldName: String, from source: IndexSet, to destination: Int) {
        draft.update(field: fieldName) { $0.values.move(fromOffsets: source, toOffset: destination) }
    }

    func removeValues(in fieldName: String, at offsets: IndexSet) {
        draft.update(field: fieldName) { $0.values.remove(atOffsets: offsets) }
    }

    func setText(_ text: String, in fieldName: String, value id: UUID) {
        var editedReading = false
        draft.update(field: fieldName, value: id) { value in
            value.resolved = .text(text)
            if case .customHTMLValue = value.template {
                value.template = .customHTMLValue(value: text)
            }
            editedReading = value.template == .reading
        }
        if editedReading {
            draft.clearPitchAccentValues()
        }
    }

    func addCustomHTML(_ html: String, to fieldName: String) {
        draft.update(field: fieldName) {
            $0.values.append(AnkiNoteDraftValue(template: .customHTMLValue(value: html), resolved: .text(html)))
        }
    }

    /// Swaps the template behind a value (another dictionary, another format) and resolves it again.
    func setTemplate(_ template: TemplateValue, in fieldName: String, value id: UUID) async {
        let resolved = await resolver.resolve(template)
        draft.update(field: fieldName, value: id) {
            $0.template = template
            $0.resolved = resolved
        }
    }

    func resolve(_ template: TemplateValue) async -> TemplateResolvedValue {
        await resolver.resolve(template)
    }

    func setAudio(_ url: URL?, in fieldName: String, value id: UUID) {
        draft.update(field: fieldName, value: id) {
            $0.resolved = url.map { .media(["audio_\(UUID().uuidString)": $0]) } ?? .empty
        }
    }

    func loadAudioSources() {
        guard audioSourcesTask == nil else { return }
        isLoadingAudioSources = true
        audioSourcesTask = Task {
            let sources = try? await audioLookup.lookupSources(term: termGroup.expression, reading: termGroup.reading)
            audioSources = sources ?? []
            isLoadingAudioSources = false
        }
    }

    /// The clip a resolved audio value refers to, once the sources are known.
    func audioSource(for value: AnkiNoteDraftValue) -> AudioLookupSource? {
        guard let url = value.resolved.mediaFiles.values.first?.absoluteString else { return nil }
        return audioSources.first { $0.url == url }
    }

    /// Returns true once the note was added or found to exist; the editor then closes itself.
    func submit() async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        audioPlayer.stop()
        let state = await submitDraft(draft)
        isSubmitting = false
        if state == "error" {
            errorMessage = String(localized: "The note could not be added. Check the Anki connection and try again.", bundle: .dictionaryUICommon)
            return false
        }
        onFinished(state)
        return true
    }
}

/// Plays one clip at a time for the audio picker.
@MainActor
@Observable
final class AudioPreviewPlayer {
    private(set) var playingURL: URL?
    private var player: AVPlayer?
    private var completionTask: Task<Void, Never>?

    func toggle(_ url: URL) {
        if playingURL == url {
            stop()
            return
        }
        stop()
        let item = AVPlayerItem(url: AnkiMediaURLResolver.localFileURL(for: url) ?? url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        playingURL = url
        player.play()
        completionTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .AVPlayerItemDidPlayToEndTime, object: item) {
                self?.stop()
                return
            }
        }
    }

    func stop() {
        completionTask?.cancel()
        completionTask = nil
        player?.pause()
        player = nil
        playingURL = nil
    }
}

/// How the editor lets the user change a value.
enum TemplateValueEditorKind {
    case text
    case html
    case audio
    case glossary
    case pitch
    case readOnly
}

extension TemplateValue {
    var editorKind: TemplateValueEditorKind {
        switch self {
        case .expression, .reading, .selectionText, .sentence, .contextInfo, .furigana, .sentenceFurigana,
             .clozePrefix, .clozeBody, .clozeSuffix, .clozeFuriganaPrefix, .clozeFuriganaBody, .clozeFuriganaSuffix:
            .text
        case .customHTMLValue:
            .html
        case .pronunciationAudio:
            .audio
        case .singleDictionaryGlossary, .singleDictionaryGlossaryNoDictionary, .singleDictionaryGlossaryPlain,
             .singleDictionaryGlossaryPlainNoDictionary, .singleGlossary, .singleGlossaryPlain,
             .singleGlossaryPlainNoDictionary, .glossaryNoDictionary, .multiDictionaryGlossary,
             .multiDictionaryGlossaryNoDictionary, .multiDictionaryGlossaryPlain, .multiDictionaryGlossaryPlainNoDictionary:
            .glossary
        case .singlePitchAccent, .singlePitchAccentDictionary:
            .pitch
        default:
            .readOnly
        }
    }

    var editorIcon: String {
        switch editorKind {
        case .text: "textformat"
        case .html: "chevron.left.forwardslash.chevron.right"
        case .audio: "speaker.wave.2"
        case .glossary: "book"
        case .pitch: "waveform"
        case .readOnly: "lock"
        }
    }

    /// The display name, naming the dictionary when the term's results identify it.
    func displayName(in termGroup: GroupedSearchResults) -> String {
        guard let dictionaryID else { return displayName }
        let title = termGroup.dictionariesResults.first { $0.dictionaryUUID == dictionaryID }?.dictionaryTitle
            ?? termGroup.pitchAccentResults.first { $0.dictionaryID == dictionaryID }?.dictionaryTitle
        return title.map { displayName(dictionaryTitle: $0) } ?? displayName
    }
}

extension AnkiNoteDraftField {
    var isAutomatic: Bool {
        values.allSatisfy { $0.template.editorKind == .readOnly }
    }

    /// The field as it will read in Anki, with markup removed.
    var previewText: String {
        values.map(\.resolved.previewText).joined().condensedWhitespace
    }
}

extension TemplateResolvedValue {
    /// Text with markup removed, or a label for media-only values.
    var previewText: String {
        if let text, !text.isEmpty {
            return text.strippingHTML
        }
        guard let media = mediaFiles.values.first else { return "" }
        let isAudio = media.pathExtension.isEmpty
            ? mediaFiles.keys.first?.hasPrefix("audio") == true
            : ["mp3", "m4a", "aac", "wav", "ogg", "opus", "flac", "caf"].contains(media.pathExtension.lowercased())
        return isAudio ? String(localized: "Audio clip", bundle: .dictionaryUICommon) : String(localized: "Image", bundle: .dictionaryUICommon)
    }
}

private extension String {
    var strippingHTML: String {
        var text = replacingOccurrences(of: #"(?is)<(style|script|rp)\b[^>]*>.*?</\1>"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)<(br|/li|/p|/div|/tr)\b[^>]*>"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
        for (entity, character) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text.condensedWhitespace
    }

    var condensedWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
