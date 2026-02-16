/*
    linkDisplay.js
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
window.MaruReader.linkDisplay = {
    linksActive: false,

    /**
     * Initialize link handling functionality
     */
    initialize: function() {
        var self = this;

        // Use capturing phase to intercept before textScanning
        document.addEventListener('click', function(event) {
            var link = event.target.closest('a.gloss-link');
            if (!link) return;

            // If links not active, let textScanning handle it
            if (!self.linksActive) {
                return;
            }

            // Links are active - handle the click
            event.preventDefault();
            event.stopPropagation();

            var href = link.getAttribute('href');
            var isExternal = link.getAttribute('data-external') === 'true';

            if (isExternal) {
                self.handleExternalLink(href, link);
            } else {
                self.handleInternalLink(href);
            }
        }, true);

        // Handle clicks on span-based image links (used to avoid nested anchors)
        document.addEventListener('click', function(event) {
            var imageSpan = event.target.closest('span.gloss-image-link');
            if (!imageSpan) return;

            // Get the href from data attribute
            var href = imageSpan.getAttribute('data-href');
            if (href) {
                event.preventDefault();
                event.stopPropagation();
                window.open(href, '_blank');
            }
        }, true);
    },

    /**
     * Set links active state (called from Swift)
     */
    setLinksActive: function(active) {
        this.linksActive = active;
        // Update visual styling via body attribute
        document.body.setAttribute('data-links-active', active ? 'true' : 'false');
    },

    /**
     * Handle internal dictionary link
     * Format: ?query=<term>&wildcards=off (wildcards param is ignored)
     */
    handleInternalLink: function(href) {
        if (!href || !href.startsWith('?')) return;

        // Parse query parameter
        var params = new URLSearchParams(href.substring(1));
        var query = params.get('query');

        if (query && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.internalLink) {
            window.webkit.messageHandlers.internalLink.postMessage({
                query: query
            });
        }
    },

    /**
     * Handle external link - request confirmation from Swift
     * @param {string} href - The external URL
     * @param {Element} linkElement - The clicked link element
     */
    handleExternalLink: function(href, linkElement) {
        if (!href) return;

        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.externalLink) {
            // Get the bounding rect of the link for popover positioning
            var rect = linkElement.getBoundingClientRect();
            window.webkit.messageHandlers.externalLink.postMessage({
                url: href,
                anchorRect: {
                    x: rect.x,
                    y: rect.y,
                    width: rect.width,
                    height: rect.height
                }
            });
        }
    }
};
