/*
    ankiDisplay.js
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
window.MaruReader.ankiDisplay = {
    stateCache: Object.create(null),
    pendingSelectionButton: null,
    pendingSelectionText: '',
    /** What a short press does: 'add' submits directly, 'edit' opens the note editor. */
    tapAction: 'add',
    longPressDelay: 500,
    longPressTimer: null,
    longPressTriggered: false,
    menuSelectionText: '',

    /**
     * Initialize Anki button functionality
     */
    initialize: function() {
        var self = this;
        var captureSelection = function(event) {
            var button = event.target.closest('.anki-button');
            if (!button) return;

            var text = self.getSelectionText(button);
            if (!text && self.pendingSelectionButton === button && self.pendingSelectionText) {
                return;
            }

            self.pendingSelectionButton = button;
            self.pendingSelectionText = text;
        };

        document.addEventListener('pointerdown', captureSelection, true);
        document.addEventListener('touchstart', captureSelection, true);
        document.addEventListener('mousedown', captureSelection, true);

        // Long press reveals a menu with both actions, mirroring the audio sources long press.
        var startPress = function(event) {
            var button = event.target.closest('.anki-button');
            if (!button || !self.isButtonActionable(button)) return;
            self.startLongPress(button);
        };
        var endPress = function() {
            self.cancelLongPress();
        };
        document.addEventListener('touchstart', startPress, { passive: true, capture: true });
        document.addEventListener('mousedown', startPress, true);
        document.addEventListener('touchend', endPress, true);
        document.addEventListener('touchcancel', endPress, true);
        document.addEventListener('touchmove', endPress, true);
        document.addEventListener('mouseup', endPress, true);
        document.addEventListener('mouseleave', endPress, true);

        document.addEventListener('contextmenu', function(event) {
            if (event.target.closest('.anki-button')) {
                event.preventDefault();
            }
        }, true);

        document.addEventListener('click', function(event) {
            var menuItem = event.target.closest('.anki-menu-item');
            if (menuItem) {
                event.preventDefault();
                event.stopPropagation();
                self.handleMenuItem(menuItem);
                return;
            }

            var button = event.target.closest('.anki-button');
            if (!button) {
                self.hideMenus();
                return;
            }

            event.preventDefault();
            event.stopPropagation();

            if (self.longPressTriggered) {
                // The synthetic click that follows a long press is not a tap.
                self.longPressTriggered = false;
                return;
            }

            self.hideMenus();
            if (!self.isButtonActionable(button)) {
                return;
            }

            var selectionText = self.consumeSelectionText(button);
            self.performAction(self.tapAction, button, selectionText);
        }, true);

        self.refresh();
    },

    requestId: function() {
        if (document.body && document.body.dataset && document.body.dataset.ankiRequestId) {
            return document.body.dataset.ankiRequestId;
        }
        return '';
    },

    isButtonActionable: function(button) {
        if (button.hasAttribute('hidden')) return false;
        var state = button.getAttribute('data-state');
        return state !== 'loading' && state !== 'disabled';
    },

    startLongPress: function(button) {
        var self = this;
        self.longPressTriggered = false;
        self.cancelLongPress();
        self.longPressTimer = setTimeout(function() {
            self.longPressTimer = null;
            self.longPressTriggered = true;
            self.menuSelectionText = self.consumeSelectionText(button);
            self.showMenu(button);
        }, self.longPressDelay);
    },

    cancelLongPress: function() {
        if (this.longPressTimer) {
            clearTimeout(this.longPressTimer);
            this.longPressTimer = null;
        }
    },

    showMenu: function(button) {
        var self = this;
        var container = button.closest('.term-header-container, .popup-term-header-wrapper');
        if (!container) return;

        self.hideMenus();

        var strings = window.MaruReader.localizedStrings || {};
        var menu = document.createElement('div');
        menu.className = 'anki-menu';
        menu.setAttribute('role', 'menu');

        [
            { action: 'add', label: strings.ankiAddNow || 'Add now', icon: 'add' },
            { action: 'edit', label: strings.ankiEditAndAdd || 'Edit and add', icon: 'edit' }
        ].forEach(function(entry) {
            var item = document.createElement('button');
            item.type = 'button';
            item.className = 'anki-menu-item';
            item.setAttribute('role', 'menuitem');
            item.setAttribute('data-action', entry.action);

            var label = document.createElement('span');
            label.className = 'anki-menu-label';
            label.textContent = entry.label;
            item.appendChild(label);

            var icon = document.createElement('span');
            icon.className = 'anki-menu-icon';
            icon.setAttribute('aria-hidden', 'true');
            icon.textContent = entry.icon;
            item.appendChild(icon);

            menu.appendChild(item);
        });

        menu.ankiButton = button;
        container.appendChild(menu);
    },

    hideMenus: function() {
        document.querySelectorAll('.anki-menu').forEach(function(menu) {
            menu.remove();
        });
    },

    handleMenuItem: function(menuItem) {
        var menu = menuItem.closest('.anki-menu');
        var button = menu ? menu.ankiButton : null;
        var action = menuItem.getAttribute('data-action');
        var selectionText = this.menuSelectionText;
        this.menuSelectionText = '';
        this.hideMenus();
        if (!button || !this.isButtonActionable(button)) return;
        this.performAction(action, button, selectionText);
    },

    performAction: function(action, button, selectionText) {
        var termKey = button.getAttribute('data-term-key');
        var expression = button.getAttribute('data-expression');
        var reading = button.getAttribute('data-reading');
        var audioURL = this.getPrimaryAudioURL(button, termKey);

        if (action === 'edit') {
            this.editNote(termKey, expression, reading, audioURL, selectionText);
        } else {
            this.addNote(termKey, expression, reading, audioURL, selectionText);
        }
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

                self.tapAction = data.tapAction === 'edit' ? 'edit' : 'add';
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

    requestBody: function(termKey, expression, reading, audioURL, selectionText) {
        return JSON.stringify({
            requestId: this.requestId(),
            termKey: termKey,
            expression: expression,
            reading: reading || '',
            audioURL: audioURL || '',
            selectionText: selectionText || ''
        });
    },

    addNote: function(termKey, expression, reading, audioURL, selectionText) {
        var self = this;

        self.setButtonState(termKey, 'loading');

        fetch('marureader-anki://add', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: self.requestBody(termKey, expression, reading, audioURL, selectionText)
        })
            .then(function(response) {
                if (!response.ok) {
                    throw new Error('Anki add request failed');
                }
                return response.json();
            })
            .then(function(data) {
                var state = data && data.state ? data.state : 'error';
                self.applyExternalState(termKey, state);
            })
            .catch(function() {
                self.applyExternalState(termKey, 'error');
            });
    },

    /**
     * Ask the app to open the note editor. The button goes back to its previous state once the
     * editor is open; the app reports the final state when the note is added.
     */
    editNote: function(termKey, expression, reading, audioURL, selectionText) {
        var self = this;
        var previousState = self.stateCache[termKey] || 'ready';

        self.setButtonState(termKey, 'loading');

        fetch('marureader-anki://edit', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: self.requestBody(termKey, expression, reading, audioURL, selectionText)
        })
            .then(function(response) {
                if (!response.ok) {
                    throw new Error('Anki edit request failed');
                }
                return response.json();
            })
            .then(function(data) {
                var state = data && data.state ? data.state : 'error';
                if (state === 'error') {
                    self.applyExternalState(termKey, 'error');
                } else {
                    self.setButtonState(termKey, previousState);
                }
            })
            .catch(function() {
                self.applyExternalState(termKey, 'error');
            });
    },

    /**
     * Apply a state decided outside this page, such as the result of the note editor.
     */
    applyExternalState: function(termKey, state) {
        this.stateCache[termKey] = state;
        this.setButtonState(termKey, state);
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

    consumeSelectionText: function(button) {
        if (this.pendingSelectionButton === button) {
            var text = this.pendingSelectionText;
            this.pendingSelectionButton = null;
            this.pendingSelectionText = '';
            return text;
        }

        return this.getSelectionText(button);
    },

    getSelectionText: function(button) {
        var selection = window.getSelection();
        if (!selection || selection.rangeCount === 0 || selection.isCollapsed) {
            return '';
        }

        var container = document.getElementById('dictionary-results-root');
        if (!container || button.closest('.popup-term-group')) {
            return '';
        }

        for (var index = 0; index < selection.rangeCount; index++) {
            var range = selection.getRangeAt(index);
            if (container.contains(range.commonAncestorContainer) || range.intersectsNode(container)) {
                return selection.toString();
            }
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
