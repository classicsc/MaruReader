// YouTubeTranscriptToolbar.swift
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

import SwiftUI

struct YouTubeTranscriptToolbar: View {
    @Bindable var model: YouTubeTranscriptViewModel
    @Binding var fontScale: Double
    @Binding var showsTimestamps: Bool

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 0) {
                    Button { model.skip(by: -5) } label: {
                        Label("Back 5 Seconds", systemImage: "gobackward.5")
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityIdentifier("web.transcriptSkipBackward")
                    Button { model.togglePlayback() } label: {
                        Label {
                            if model.isPlaying {
                                Text("Pause")
                            } else {
                                Text("Play")
                            }
                        } icon: {
                            Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                    }
                    .disabled(model.playbackCommandPending)
                    .accessibilityIdentifier("web.transcriptPlayPause")
                    Button { model.skip(by: 5) } label: {
                        Label("Forward 5 Seconds", systemImage: "goforward.5")
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityIdentifier("web.transcriptSkipForward")
                }
                .disabled(!model.canControlPlayback)
                .padding(.horizontal, 4)
                .glassEffect(in: Capsule())

                Button { model.followPlayback.toggle() } label: {
                    Label("Follow Playback", systemImage: model.followPlayback ? "location.fill" : "location")
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .foregroundStyle(model.followPlayback ? Color.accentColor : .primary)
                .glassEffect(in: Circle())
                .accessibilityValue(model.followPlayback ? Text("On") : Text("Off"))
                .accessibilityAddTraits(model.followPlayback ? .isSelected : [])
                .disabled(model.cues.isEmpty)
                .accessibilityIdentifier("web.transcriptFollow")

                Menu {
                    Stepper("Font Size", value: $fontScale, in: 0.75 ... 2.0, step: 0.25)
                    Toggle("Show Timestamps", isOn: $showsTimestamps)
                    Button("Refresh Transcript", systemImage: "arrow.clockwise", action: model.refresh)
                } label: {
                    Label("Transcript Options", systemImage: "ellipsis")
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .glassEffect(in: Circle())
                .accessibilityIdentifier("web.transcriptOptions")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.body)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}
