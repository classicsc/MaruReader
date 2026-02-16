/*
    audioDisplay.js
    MaruReader
    Copyright (c) 2026  Samuel Smoker

    MaruReader is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    MaruReader is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.
*/
window.MaruReader = window.MaruReader || {};
window.MaruReader.audioDisplay = {
    currentAudio: null,
    currentButton: null,
    longPressDelay: 500,
    longPressTimer: null,
    longPressTriggered: false,
    audioCache: Object.create(null),

    /**
     * Initialize audio playback functionality with long-press support
     */
    initialize: function() {
        var self = this;

        // Handle touch start - begin long press detection
        document.addEventListener('touchstart', function(event) {
            var button = event.target.closest('.audio-button');
            if (!button) return;
            if (!self.isButtonReady(button)) return;

            // Only handle long-press for main audio buttons (not those inside the sources area)
            if (button.closest('.audio-sources-area')) return;

            self.startLongPress(button, event);
        }, { passive: true });

        // Handle touch end - play audio if not long press
        document.addEventListener('touchend', function(event) {
            var button = event.target.closest('.audio-button');
            if (!button) return;
            if (!self.isButtonReady(button)) return;

            // Only handle long-press for main audio buttons
            if (button.closest('.audio-sources-area')) {
                // For buttons inside sources area, just play directly
                self.handleDirectPlay(button, event);
                return;
            }

            self.endLongPress(button, event);
        }, true);

        // Handle touch cancel
        document.addEventListener('touchcancel', function(event) {
            self.cancelLongPress();
        }, true);

        // Handle mouse events for non-touch devices
        document.addEventListener('mousedown', function(event) {
            var button = event.target.closest('.audio-button');
            if (!button) return;
            if (!self.isButtonReady(button)) return;

            if (button.closest('.audio-sources-area')) return;

            self.startLongPress(button, event);
        }, true);

        document.addEventListener('mouseup', function(event) {
            var button = event.target.closest('.audio-button');
            if (!button) return;
            if (!self.isButtonReady(button)) return;

            if (button.closest('.audio-sources-area')) {
                self.handleDirectPlay(button, event);
                return;
            }

            self.endLongPress(button, event);
        }, true);

        // Prevent context menu on long press
        document.addEventListener('contextmenu', function(event) {
            var button = event.target.closest('.audio-button');
            if (button && self.longPressTriggered) {
                event.preventDefault();
            }
        }, true);

        // Click outside to close sources area
        document.addEventListener('click', function(event) {
            // If clicking outside any audio-sources-area, hide all
            if (!event.target.closest('.audio-sources-area') && !event.target.closest('.audio-button')) {
                self.hideAllSourcesAreas();
            }
        }, true);

        // Prevent click propagation on audio buttons (catches synthetic clicks after touch events)
        document.addEventListener('click', function(event) {
            var button = event.target.closest('.audio-button');
            if (button) {
                event.stopPropagation();
            }
        }, true);

        self.loadAudioSources();
    },

    /**
     * Start long press timer
     */
    startLongPress: function(button, event) {
        var self = this;
        self.longPressTriggered = false;
        self.cancelLongPress();

        self.longPressTimer = setTimeout(function() {
            self.longPressTriggered = true;
            self.toggleSourcesArea(button);
        }, self.longPressDelay);
    },

    /**
     * End long press - play audio if it wasn't a long press
     */
    endLongPress: function(button, event) {
        var self = this;

        if (self.longPressTriggered) {
            // Long press was triggered, don't play
            self.longPressTriggered = false;
            event.preventDefault();
            event.stopPropagation();
            return;
        }

        self.cancelLongPress();
        self.handleDirectPlay(button, event);
    },

    /**
     * Cancel long press timer
     */
    cancelLongPress: function() {
        if (this.longPressTimer) {
            clearTimeout(this.longPressTimer);
            this.longPressTimer = null;
        }
    },

    /**
     * Load audio sources for all buttons on the page.
     */
    loadAudioSources: function() {
        var self = this;
        var buttons = document.querySelectorAll('.audio-button[data-audio-term]');
        var seen = Object.create(null);

        buttons.forEach(function(button) {
            var term = button.getAttribute('data-audio-term');
            if (!term) return;
            var reading = self.normalizeReading(button.getAttribute('data-audio-reading'));
            var key = self.audioKey(term, reading);
            if (!seen[key]) {
                seen[key] = { term: term, reading: reading };
            }
        });

        Object.keys(seen).forEach(function(key) {
            var entry = seen[key];
            self.fetchAudioSources(entry.term, entry.reading);
        });
    },

    buildLookupURL: function(term, reading) {
        var url = 'marureader-audio://lookup?term=' + encodeURIComponent(term);
        if (reading) {
            url += '&reading=' + encodeURIComponent(reading);
        }
        url += '&language=ja';
        return url;
    },

    normalizeReading: function(reading) {
        if (!reading) return '';
        return reading;
    },

    audioKey: function(term, reading) {
        return term + '\u0000' + (reading || '');
    },

    fetchAudioSources: function(term, reading) {
        var self = this;
        var key = self.audioKey(term, reading);
        var cached = self.audioCache[key];

        if (cached) {
            if (cached.status === 'done') {
                self.applySourcesToButtons(term, reading, cached.sources);
            }
            return;
        }

        self.audioCache[key] = { status: 'pending', sources: [] };

        fetch(self.buildLookupURL(term, reading))
            .then(function(response) {
                if (!response.ok) {
                    return { sources: [] };
                }
                return response.json();
            })
            .then(function(data) {
                var sources = Array.isArray(data.sources) ? data.sources : [];
                self.audioCache[key] = { status: 'done', sources: sources };
                self.applySourcesToButtons(term, reading, sources);
            })
            .catch(function() {
                self.audioCache[key] = { status: 'done', sources: [] };
                self.applySourcesToButtons(term, reading, []);
            });
    },

    applySourcesToButtons: function(term, reading, sources) {
        var self = this;
        var buttons = document.querySelectorAll('.audio-button[data-audio-term]');

        buttons.forEach(function(button) {
            var buttonTerm = button.getAttribute('data-audio-term');
            if (buttonTerm !== term) return;

            var buttonReading = self.normalizeReading(button.getAttribute('data-audio-reading'));
            if (buttonReading !== (reading || '')) return;

            var filteredSources = self.filterSourcesForButton(button, sources);

            if (filteredSources.length > 0) {
                self.setButtonSources(button, filteredSources);
                self.setButtonState(button, 'ready');
                if (button.getAttribute('data-audio-role') === 'primary') {
                    self.setPrimaryAudioURL(button, filteredSources[0].url);
                }
            } else {
                button.removeAttribute('data-audio-sources');
                if (sources.length == 0) {
                    self.setButtonState(button, 'unavailable');
                } else {
                    self.setButtonState(button, 'disabled');
                }
            }
        });

        self.populateSourcesAreas(term, reading, sources);
    },

    filterSourcesForButton: function(button, sources) {
        var pitch = button.getAttribute('data-audio-pitch');
        var requireExact = button.getAttribute('data-audio-require-exact') === 'true';

        if (requireExact) {
            if (!pitch) return [];
            return sources.filter(function(source) {
                return source.pitch === pitch;
            });
        }

        if (!pitch) return sources;

        var matching = sources.filter(function(source) {
            return source.pitch === pitch;
        });

        return matching.length > 0 ? matching : sources;
    },

    populateSourcesAreas: function(term, reading, sources) {
        var self = this;
        var areas = document.querySelectorAll('.audio-sources-area[data-audio-term]');

        areas.forEach(function(area) {
            var areaTerm = area.getAttribute('data-audio-term');
            if (areaTerm !== term) return;

            var areaReading = self.normalizeReading(area.getAttribute('data-audio-reading'));
            if (areaReading !== (reading || '')) return;

            var list = area.querySelector('.audio-sources-list');
            if (!list) {
                list = document.createElement('div');
                list.className = 'audio-sources-list';
                area.appendChild(list);
            }

            list.innerHTML = '';

            if (!sources || sources.length <= 1) {
                area.setAttribute('hidden', '');
                area.setAttribute('data-has-sources', 'false');
                return;
            }

            sources.forEach(function(source) {
                var item = document.createElement('div');
                item.className = 'audio-source-item';

                var provider = document.createElement('span');
                provider.className = 'audio-source-provider';
                provider.textContent = source.providerName || '';
                item.appendChild(provider);

                if (source.itemName) {
                    var itemName = document.createElement('span');
                    itemName.className = 'audio-source-item-name';
                    itemName.textContent = source.itemName;
                    item.appendChild(itemName);
                }

                if (source.pitch) {
                    var pitch = document.createElement('span');
                    pitch.className = 'audio-source-pitch';
                    pitch.textContent = '[' + source.pitch + ']';
                    item.appendChild(pitch);
                }

                var button = document.createElement('button');
                button.type = 'button';
                button.className = 'audio-button audio-button-small';
                button.setAttribute('data-audio-sources', JSON.stringify([source]));
                button.setAttribute('data-state', 'ready');
                button.setAttribute('aria-disabled', 'false');
                button.setAttribute('aria-label', 'Play audio');
                item.appendChild(button);

                list.appendChild(item);
            });

            area.setAttribute('hidden', '');
            area.setAttribute('data-has-sources', 'true');
        });
    },

    setButtonSources: function(button, sources) {
        button.setAttribute('data-audio-sources', JSON.stringify(sources));
    },

    isButtonReady: function(button) {
        return button.getAttribute('data-state') === 'ready';
    },

    /**
     * Handle direct audio playback
     */
    handleDirectPlay: function(button, event) {
        var self = this;

        if (!self.isButtonReady(button)) {
            return;
        }

        // Stop event propagation to prevent parent handlers (e.g., navigation in popups)
        if (event) {
            event.stopPropagation();
            event.preventDefault();
        }

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
    },

    /**
     * Toggle the audio sources area visibility
     */
    toggleSourcesArea: function(button) {
        var self = this;
        var container = button.closest('.term-header-container');
        if (!container) return;

        var sourcesArea = container.querySelector('.audio-sources-area');
        if (!sourcesArea) return;
        if (sourcesArea.getAttribute('data-has-sources') !== 'true') return;

        // Hide all other sources areas first
        self.hideAllSourcesAreas(sourcesArea);

        // Toggle this one
        if (sourcesArea.hasAttribute('hidden')) {
            sourcesArea.removeAttribute('hidden');
        } else {
            sourcesArea.setAttribute('hidden', '');
        }
    },

    /**
     * Hide all audio sources areas
     */
    hideAllSourcesAreas: function(except) {
        var areas = document.querySelectorAll('.audio-sources-area:not([hidden])');
        areas.forEach(function(area) {
            if (area !== except) {
                area.setAttribute('hidden', '');
            }
        });
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
        self.setPrimaryAudioURL(button, source.url);

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
            // Ignore spurious errors if audio is already playing or has been replaced
            var currentState = button.getAttribute('data-state');
            if (currentState === 'playing' || currentState === 'ready' || self.currentAudio !== audio) {
                return;
            }
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
        button.setAttribute('aria-disabled', state === 'ready' ? 'false' : 'true');
    },

    setPrimaryAudioURL: function(button, url) {
        if (!url) return;
        var container = this.findAudioContainer(button);
        if (!container) return;
        container.setAttribute('data-audio-primary-url', url);
    },

    findAudioContainer: function(element) {
        return element.closest('.term-group, .popup-term-group');
    }
};
