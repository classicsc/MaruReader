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
    longPressDelay: 500,
    longPressTimer: null,
    longPressTriggered: false,

    /**
     * Initialize audio playback functionality with long-press support
     */
    initialize: function() {
        var self = this;

        // Handle touch start - begin long press detection
        document.addEventListener('touchstart', function(event) {
            var button = event.target.closest('.audio-button');
            if (!button) return;

            // Only handle long-press for main audio buttons (not those inside the sources area)
            if (button.closest('.audio-sources-area')) return;

            self.startLongPress(button, event);
        }, { passive: true });

        // Handle touch end - play audio if not long press
        document.addEventListener('touchend', function(event) {
            var button = event.target.closest('.audio-button');
            if (!button) return;

            // Only handle long-press for main audio buttons
            if (button.closest('.audio-sources-area')) {
                // For buttons inside sources area, just play directly
                self.handleDirectPlay(button);
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

            if (button.closest('.audio-sources-area')) return;

            self.startLongPress(button, event);
        }, true);

        document.addEventListener('mouseup', function(event) {
            var button = event.target.closest('.audio-button');
            if (!button) return;

            if (button.closest('.audio-sources-area')) {
                self.handleDirectPlay(button);
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
        self.handleDirectPlay(button);
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
     * Handle direct audio playback
     */
    handleDirectPlay: function(button) {
        var self = this;

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
    }
};
