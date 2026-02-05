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
window.MaruReader.ankiDisplay = {
    /**
     * Initialize Anki button functionality
     */
    initialize: function() {
        var self = this;
        document.addEventListener('click', function(event) {
            var button = event.target.closest('.anki-button');
            if (!button) return;

            event.preventDefault();
            event.stopPropagation();

            // Get term data from data attributes
            var termKey = button.getAttribute('data-term-key');
            var expression = button.getAttribute('data-expression');
            var reading = button.getAttribute('data-reading');
            var currentState = button.getAttribute('data-state');

            // Don't process if already loading
            if (currentState === 'loading') {
                return;
            }

            // Allow re-adding even if exists (per user preference)
            // Just send the message to native code
            var audioURL = self.getPrimaryAudioURL(button, termKey);
            self.postAnkiAdd(termKey, expression, reading, audioURL);
        }, true);
    },

    /**
     * Send add note request to native code
     */
    postAnkiAdd: function(termKey, expression, reading, audioURL) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ankiAdd) {
            window.webkit.messageHandlers.ankiAdd.postMessage({
                termKey: termKey,
                expression: expression,
                reading: reading || '',
                audioURL: audioURL || ''
            });
        }
    },

    getPrimaryAudioURL: function(button, termKey) {
        var container = button.closest('.term-group, .popup-term-group');
        if (!container) {
            return '';
        }

        var explicitURL = container.getAttribute('data-audio-primary-url');
        if (explicitURL) {
            return explicitURL;
        }

        var primaryButton = container.querySelector('.audio-button[data-audio-role="primary"]');
        if (!primaryButton) {
            return '';
        }

        var sourcesJSON = primaryButton.getAttribute('data-audio-sources');
        if (!sourcesJSON) {
            return '';
        }

        try {
            var sources = JSON.parse(sourcesJSON);
            if (sources && sources.length > 0 && sources[0].url) {
                return sources[0].url;
            }
        } catch (e) {
            return '';
        }

        return '';
    },

    /**
     * Update button visual state for a specific term
     * Called from native code after note creation attempt
     */
    setButtonState: function(termKey, state) {
        var buttons = document.querySelectorAll('.anki-button[data-term-key="' + termKey + '"]');
        buttons.forEach(function(button) {
            button.setAttribute('data-state', state);
        });
    },

    /**
     * Update button states for multiple terms at once
     * Called from native code when loading results with existing notes
     */
    setButtonStates: function(termKeyStates) {
        for (var termKey in termKeyStates) {
            if (termKeyStates.hasOwnProperty(termKey)) {
                this.setButtonState(termKey, termKeyStates[termKey]);
            }
        }
    }
};
