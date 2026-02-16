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
    stateCache: Object.create(null),

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

            if (button.hasAttribute('hidden')) {
                return;
            }

            // Get term data from data attributes
            var termKey = button.getAttribute('data-term-key');
            var expression = button.getAttribute('data-expression');
            var reading = button.getAttribute('data-reading');
            var currentState = button.getAttribute('data-state');

            // Don't process if already loading or disabled
            if (currentState === 'loading' || currentState === 'disabled') {
                return;
            }

            var audioURL = self.getPrimaryAudioURL(button, termKey);
            self.addNote(termKey, expression, reading, audioURL);
        }, true);

        self.refresh();
    },

    requestId: function() {
        if (document.body && document.body.dataset && document.body.dataset.ankiRequestId) {
            return document.body.dataset.ankiRequestId;
        }
        return '';
    },

    /**
     * Fetch Anki state for all terms on the page.
     */
    refresh: function() {
        var self = this;
        var terms = self.collectTermsToFetch();

        if (terms.length === 0) {
            self.applyCachedStates();
            return;
        }

        fetch('marureader-anki://state', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ requestId: self.requestId(), terms: terms })
        })
            .then(function(response) {
                if (!response.ok) {
                    throw new Error('Anki state request failed');
                }
                return response.json();
            })
            .then(function(data) {
                if (!data || !data.enabled) {
                    self.stateCache = Object.create(null);
                    self.setButtonsHidden(true);
                    return;
                }

                self.setButtonsHidden(false);
                var states = data.states || {};
                Object.keys(states).forEach(function(termKey) {
                    self.stateCache[termKey] = states[termKey];
                });
                self.applyCachedStates();
            })
            .catch(function() {
                self.stateCache = Object.create(null);
                self.setButtonsHidden(true);
            });
    },

    collectTermsToFetch: function() {
        var self = this;
        var buttons = document.querySelectorAll('.anki-button[data-term-key]');
        var seen = Object.create(null);
        var terms = [];

        buttons.forEach(function(button) {
            var termKey = button.getAttribute('data-term-key');
            if (!termKey) return;

            if (self.stateCache[termKey]) {
                return;
            }

            if (seen[termKey]) {
                return;
            }

            var expression = button.getAttribute('data-expression') || '';
            var reading = button.getAttribute('data-reading') || '';
            terms.push({ termKey: termKey, expression: expression, reading: reading });
            seen[termKey] = true;
        });

        return terms;
    },

    applyCachedStates: function() {
        var self = this;
        Object.keys(self.stateCache).forEach(function(termKey) {
            self.setButtonState(termKey, self.stateCache[termKey]);
        });
    },

    addNote: function(termKey, expression, reading, audioURL) {
        var self = this;

        self.setButtonState(termKey, 'loading');

        fetch('marureader-anki://add', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                requestId: self.requestId(),
                termKey: termKey,
                expression: expression,
                reading: reading || '',
                audioURL: audioURL || ''
            })
        })
            .then(function(response) {
                if (!response.ok) {
                    throw new Error('Anki add request failed');
                }
                return response.json();
            })
            .then(function(data) {
                var state = data && data.state ? data.state : 'error';
                self.stateCache[termKey] = state;
                self.setButtonState(termKey, state);
            })
            .catch(function() {
                self.stateCache[termKey] = 'error';
                self.setButtonState(termKey, 'error');
            });
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

    setButtonsHidden: function(hidden) {
        var buttons = document.querySelectorAll('.anki-button');
        buttons.forEach(function(button) {
            if (hidden) {
                button.setAttribute('hidden', '');
                button.setAttribute('data-state', 'disabled');
                button.setAttribute('aria-disabled', 'true');
            } else {
                button.removeAttribute('hidden');
            }
        });
    },

    /**
     * Update button visual state for a specific term
     */
    setButtonState: function(termKey, state) {
        var buttons = document.querySelectorAll('.anki-button[data-term-key="' + termKey + '"]');
        var self = this;
        buttons.forEach(function(button) {
            self.setButtonStateForElement(button, state);
        });
    },

    setButtonStateForElement: function(button, state) {
        button.setAttribute('data-state', state);
        if (state === 'disabled') {
            button.setAttribute('hidden', '');
        } else {
            button.removeAttribute('hidden');
        }
        if (state === 'disabled' || state === 'loading') {
            button.setAttribute('aria-disabled', 'true');
        } else {
            button.setAttribute('aria-disabled', 'false');
        }
    },

    /**
     * Update button states for multiple terms at once
     */
    setButtonStates: function(termKeyStates) {
        for (var termKey in termKeyStates) {
            if (termKeyStates.hasOwnProperty(termKey)) {
                this.setButtonState(termKey, termKeyStates[termKey]);
            }
        }
    }
};
