/*
    dictionaryResults.js
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
window.MaruReader.dictionaryResults = {
    requestId: '',
    mode: 'results',
    cursor: 0,
    batchSize: 10,
    isLoading: false,
    hasMore: true,
    hasError: false,
    root: null,
    loadingEl: null,
    emptyEl: null,
    errorEl: null,
    sentinel: null,
    observer: null,

    init: function() {
        this.root = document.getElementById('dictionary-results-root');
        this.loadingEl = document.getElementById('dictionary-results-loading');
        this.emptyEl = document.getElementById('dictionary-results-empty');
        this.errorEl = document.getElementById('dictionary-results-error');
        this.sentinel = document.getElementById('dictionary-results-sentinel');

        var strings = window.MaruReader.localizedStrings;
        this.loadingEl.textContent = strings.loadingResults;
        this.emptyEl.textContent = strings.noResultsFound;
        this.errorEl.textContent = strings.unableToLoadResults;

        this.parseConfig();
        this.applyModeClass();
        this.initializeModules();
        this.fetchState()
            .then(this.loadMore.bind(this))
            .catch(function() {
                this.showError();
            }.bind(this));

        this.setupObserver();
    },

    parseConfig: function() {
        var params = new URLSearchParams(window.location.search || '');
        this.requestId = params.get('requestId') || '';
        var mode = params.get('mode');
        this.mode = mode === 'popup' ? 'popup' : 'results';
        this.batchSize = this.mode === 'popup' ? 4 : 10;
    },

    applyModeClass: function() {
        if (!document.body) return;
        if (this.mode === 'popup') {
            document.body.classList.add('popup-results-body');
        } else {
            document.body.classList.remove('popup-results-body');
        }
    },

    initializeModules: function() {
        if (this.mode === 'results') {
            if (window.MaruReader.textScanning) {
                window.MaruReader.textScanning.initialize();
            }
            if (window.MaruReader.frequencyDisplay) {
                window.MaruReader.frequencyDisplay.initialize();
            }
            if (window.MaruReader.pitchDisplay) {
                window.MaruReader.pitchDisplay.initialize();
            }
            if (window.MaruReader.linkDisplay) {
                window.MaruReader.linkDisplay.initialize();
            }
        } else {
            this.initializePopupNavigation();
        }

        if (window.MaruReader.audioDisplay) {
            window.MaruReader.audioDisplay.initialize();
        }
        if (window.MaruReader.ankiDisplay) {
            window.MaruReader.ankiDisplay.initialize();
        }
    },

    initializePopupNavigation: function() {
        document.addEventListener('click', function(event) {
            var group = event.target.closest('.popup-term-group');
            if (!group) return;

            if (event.target.closest('.audio-button, .anki-button, .freq-button, .pitch-toggle, .audio-sources-area')) {
                return;
            }

            var expression = group.getAttribute('data-expression');
            if (!expression) {
                var termKey = group.getAttribute('data-term-key') || '';
                expression = termKey.split('|')[0] || '';
            }

            if (!expression) return;

            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.navigateToTerm) {
                window.webkit.messageHandlers.navigateToTerm.postMessage(expression);
            }
        }, true);
    },

    fetchState: function() {
        var url = 'marureader-lookup://state?requestId=' + encodeURIComponent(this.requestId);
        return fetch(url)
            .then(function(response) {
                if (!response.ok) {
                    throw new Error('State request failed');
                }
                return response.json();
            })
            .then(function(data) {
                if (!data) {
                    throw new Error('Invalid state response');
                }
                this.applyState(data);
                return data;
            }.bind(this));
    },

    applyState: function(state) {
        if (document.body && state.requestId) {
            document.body.dataset.ankiRequestId = state.requestId;
        }

        if (state.dictionaryStyles) {
            var styleEl = document.getElementById('dictionary-styles');
            if (styleEl) {
                styleEl.textContent = state.dictionaryStyles;
            }
        }

        if (state.webTheme) {
            this.applyWebTheme(state.webTheme);
        }

        if (state.styles) {
            this.applyDisplayStyles(state.styles);
        }
    },

    applyWebTheme: function(theme) {
        if (!theme || !document.documentElement) return;

        if (theme.colorScheme) {
            document.documentElement.style.colorScheme = theme.colorScheme;
        }
        if (theme.textColor) {
            document.documentElement.style.setProperty('--text-color', theme.textColor);
        }
        if (theme.backgroundColor) {
            document.documentElement.style.setProperty('--background-color', theme.backgroundColor);
        }
        if (theme.interfaceBackgroundColor) {
            document.documentElement.style.setProperty('--interface-background-color', theme.interfaceBackgroundColor);
        }
        if (theme.accentColor) {
            document.documentElement.style.setProperty('--accent-color', theme.accentColor);
        }
        if (theme.linkColor) {
            document.documentElement.style.setProperty('--link-color', theme.linkColor);
        }
        if (theme.glossImageBackgroundColor) {
            document.documentElement.style.setProperty('--gloss-image-background-color', theme.glossImageBackgroundColor);
        }
    },

    applyDisplayStyles: function(styles) {
        if (!styles || !document.documentElement) return;
        document.documentElement.style.setProperty('--font-family', styles.fontFamily || '');
        if (styles.contentFontSize) {
            document.documentElement.style.setProperty('--content-font-size-multiplier', String(styles.contentFontSize));
            document.documentElement.style.setProperty('--font-size-no-units', String(16 * styles.contentFontSize));
        }
        if (styles.popupFontSize) {
            document.documentElement.style.setProperty('--popup-font-size-multiplier', String(styles.popupFontSize));
        }
        document.documentElement.style.setProperty('--deinflection-display', styles.showDeinflection ? 'inline-block' : 'none');
    },

    setupObserver: function() {
        if (!this.sentinel) return;
        if (!('IntersectionObserver' in window)) {
            window.addEventListener('scroll', this.onScroll.bind(this));
            return;
        }

        this.observer = new IntersectionObserver(function(entries) {
            entries.forEach(function(entry) {
                if (entry.isIntersecting) {
                    this.loadMore();
                }
            }.bind(this));
        }.bind(this), {
            root: null,
            rootMargin: '200px',
            threshold: 0.1
        });

        this.observer.observe(this.sentinel);
    },

    onScroll: function() {
        if (!this.sentinel) return;
        var rect = this.sentinel.getBoundingClientRect();
        if (rect.top < window.innerHeight + 200) {
            this.loadMore();
        }
    },

    loadMore: function() {
        if (this.isLoading || !this.hasMore || this.hasError) {
            this.updateStatus();
            return;
        }

        this.isLoading = true;
        this.updateStatus();

        var url = 'marureader-lookup://results?requestId=' + encodeURIComponent(this.requestId) +
            '&cursor=' + encodeURIComponent(String(this.cursor)) +
            '&limit=' + encodeURIComponent(String(this.batchSize)) +
            '&mode=' + encodeURIComponent(this.mode);

        fetch(url)
            .then(function(response) {
                if (!response.ok) {
                    throw new Error('Results request failed');
                }
                return response.json();
            })
            .then(function(data) {
                if (!data) {
                    throw new Error('Invalid results response');
                }
                this.appendHTML(data.html || '');
                this.cursor = typeof data.nextCursor === 'number' ? data.nextCursor : this.cursor;
                this.hasMore = data.hasMore !== false;
                this.isLoading = false;
                this.updateStatus();
                this.postAppend();
            }.bind(this))
            .catch(function() {
                this.isLoading = false;
                this.showError();
            }.bind(this));
    },

    appendHTML: function(html) {
        if (!this.root || !html) {
            return;
        }
        this.root.insertAdjacentHTML('beforeend', html);
    },

    postAppend: function() {
        if (window.MaruReader.audioDisplay && window.MaruReader.audioDisplay.loadAudioSources) {
            window.MaruReader.audioDisplay.loadAudioSources();
        }
        if (window.MaruReader.ankiDisplay && window.MaruReader.ankiDisplay.refresh) {
            window.MaruReader.ankiDisplay.refresh();
        }
    },

    updateStatus: function() {
        var hasContent = this.root && this.root.children && this.root.children.length > 0;

        if (this.loadingEl) {
            this.loadingEl.hidden = !this.isLoading;
        }

        if (this.emptyEl) {
            this.emptyEl.hidden = !(!hasContent && !this.isLoading && !this.hasMore && !this.hasError);
        }

        if (this.errorEl) {
            this.errorEl.hidden = !this.hasError;
        }
    },

    showError: function() {
        this.hasError = true;
        this.hasMore = false;
        this.updateStatus();
    }
};

document.addEventListener('DOMContentLoaded', function() {
    window.MaruReader.dictionaryResults.init();
});
