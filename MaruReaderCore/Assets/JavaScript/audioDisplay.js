/*
*  Copyright (c) 2025  Sam Smoker
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
* This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
window.MaruReader = window.MaruReader || {};
window.MaruReader.audioDisplay = {
    currentAudio: null,
    currentButton: null,

    /**
     * Initialize audio playback functionality
     */
    initialize: function() {
        var self = this;
        document.addEventListener('click', function(event) {
            var button = event.target.closest('.audio-button');
            if (!button) return;

            event.preventDefault();
            event.stopPropagation();

            // Get audio sources from data attribute
            var sourcesJSON = button.getAttribute('data-audio-sources');
            if (!sourcesJSON) return;

            var sources;
            try {
                sources = JSON.parse(sourcesJSON);
            } catch (e) {
                console.error('Failed to parse audio sources:', e);
                return;
            }

            if (!sources || sources.length === 0) return;

            self.playWithFallback(sources, 0, button);
        }, true);
    },

    /**
     * Play audio with fallback to next source on error
     */
    playWithFallback: function(sources, index, button) {
        var self = this;

        if (index >= sources.length) {
            // All sources exhausted
            self.setButtonState(button, 'error');
            return;
        }

        // Stop any currently playing audio
        if (self.currentAudio) {
            self.currentAudio.pause();
            self.currentAudio.src = '';
            self.currentAudio = null;
        }

        // Reset previous button if different
        if (self.currentButton && self.currentButton !== button) {
            self.setButtonState(self.currentButton, 'ready');
        }

        var source = sources[index];
        var audio = new Audio();
        self.currentAudio = audio;
        self.currentButton = button;

        self.setButtonState(button, 'loading');

        audio.addEventListener('canplaythrough', function() {
            self.setButtonState(button, 'playing');
            audio.play().catch(function(err) {
                console.error('Play failed:', err);
                self.playWithFallback(sources, index + 1, button);
            });
        }, { once: true });

        audio.addEventListener('ended', function() {
            self.setButtonState(button, 'ready');
            self.currentAudio = null;
            self.currentButton = null;
        }, { once: true });

        audio.addEventListener('error', function(e) {
            console.log('Audio error for source ' + index + ':', source.url, e);
            // Try next source on error (404 common with URL pattern sources)
            self.playWithFallback(sources, index + 1, button);
        }, { once: true });

        audio.src = source.url;
        audio.load();
    },

    /**
     * Update button visual state
     */
    setButtonState: function(button, state) {
        button.setAttribute('data-state', state);
    }
};
