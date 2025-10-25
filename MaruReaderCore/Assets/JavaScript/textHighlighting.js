/**
 * Text Highlighting Functions for MaruReader
 * Handles text highlighting using CSS Custom Highlights API with ruby text support
 */

window.MaruReader = window.MaruReader || {};
window.MaruReader.textHighlighting = {

    // Counter for generating unique highlight IDs
    highlightCounter: 0,

    /**
     * Highlights text using character offsets within a context
     * @param {string} cssSelector - CSS selector path (may include ::text-node(N))
     * @param {number} contextStartOffset - Where the context starts in the full element text
     * @param {number} matchStartInContext - Start offset of match within context
     * @param {number} matchEndInContext - End offset of match within context
     * @param {Object} styles - Styles object with properties like backgroundColor, color, etc.
     * @returns {Object} Object with highlightId and boundingRects array
     */
    highlightTextByContextRange: function(cssSelector, contextStartOffset, matchStartInContext, matchEndInContext, styles) {
        console.log('highlightTextByContextRange called with:', cssSelector, contextStartOffset, matchStartInContext, matchEndInContext, styles);
        if (!cssSelector || contextStartOffset === undefined || matchStartInContext === undefined || matchEndInContext === undefined) {
            console.error('highlightTextByContextRange: missing required parameters');
            return null;
        }

        // Parse the CSS selector to extract element selector and text node index
        var selectorInfo = this.parseCSSSelector(cssSelector);
        if (!selectorInfo) {
            console.error('highlightTextByContextRange: failed to parse CSS selector:', cssSelector);
            return null;
        }

        // Find the target element
        var element = this.findElementBySelector(selectorInfo.selector);
        if (!element) {
            console.error('highlightTextByContextRange: element not found for selector:', selectorInfo.selector);
            return null;
        }

        // Get all text nodes, filtering out ruby annotations
        var textNodes = [];
        var walker = window.MaruReader.domUtilities.createRubyFilteredTreeWalker(element);
        var node;

        while (node = walker.nextNode()) {
            textNodes.push(node);
        }

        if (textNodes.length === 0) {
            console.error('highlightTextByContextRange: no text nodes found');
            return null;
        }

        // Build the continuous text from text nodes and track node offsets
        var fullText = '';
        var nodeOffsets = []; // Track where each node starts in fullText

        for (var i = 0; i < textNodes.length; i++) {
            nodeOffsets.push(fullText.length);
            fullText += textNodes[i].textContent;
        }

        // Calculate absolute offsets in full text
        var matchStart = contextStartOffset + matchStartInContext;
        var matchEnd = contextStartOffset + matchEndInContext;

        console.log('Full text length:', fullText.length, 'Match range:', matchStart, '-', matchEnd);

        // Validate offsets
        if (matchStart < 0 || matchEnd > fullText.length || matchStart >= matchEnd) {
            console.error('highlightTextByContextRange: invalid offsets', matchStart, matchEnd, fullText.length);
            return null;
        }

        // Create ranges for the matching text
        var ranges = this.createRangesFromOffsets(textNodes, nodeOffsets, matchStart, matchEnd);
        if (!ranges || ranges.length === 0) {
            console.error('highlightTextByContextRange: failed to create ranges');
            return null;
        }

        // Create a unique highlight ID
        var highlightId = 'marureader-highlight-' + (++this.highlightCounter);

        // Create the highlight using CSS Custom Highlights API
        var highlight = this.createHighlight(ranges, styles, highlightId);
        if (!highlight) {
            console.error('highlightTextByContextRange: failed to create highlight');
            return null;
        }

        // Register the highlight
        CSS.highlights.set(highlightId, highlight);

        // Get bounding rectangles for all ranges
        var boundingRects = this.getRangeBoundingRects(ranges);

        return {
            highlightId: highlightId,
            boundingRects: boundingRects
        };
    },

    /**
     * Creates Range objects from absolute character offsets
     * @param {Array<Node>} textNodes - Array of text nodes
     * @param {Array<number>} nodeOffsets - Array of offsets where each node starts
     * @param {number} matchStart - Start offset in full text
     * @param {number} matchEnd - End offset in full text
     * @returns {Array<Range>} Array of Range objects
     */
    createRangesFromOffsets: function(textNodes, nodeOffsets, matchStart, matchEnd) {
        var ranges = [];
        var currentOffset = matchStart;
        var remainingLength = matchEnd - matchStart;

        for (var i = 0; i < textNodes.length && remainingLength > 0; i++) {
            var nodeStart = nodeOffsets[i];
            var nodeEnd = (i + 1 < nodeOffsets.length) ? nodeOffsets[i + 1] : nodeStart + textNodes[i].textContent.length;
            var nodeLength = nodeEnd - nodeStart;

            // Check if this node contains part of the text to highlight
            if (nodeEnd > currentOffset && nodeStart < matchEnd) {
                var rangeStart = Math.max(0, currentOffset - nodeStart);
                var rangeEnd = Math.min(nodeLength, rangeStart + remainingLength);

                var range = document.createRange();
                range.setStart(textNodes[i], rangeStart);
                range.setEnd(textNodes[i], rangeEnd);
                ranges.push(range);

                remainingLength -= (rangeEnd - rangeStart);
                currentOffset = nodeEnd;
            }
        }

        return ranges;
    },

    /**
     * Clears all highlights from the registry
     */
    clearAllHighlights: function() {
        // Get all highlight keys from the registry
        var highlightKeys = Array.from(CSS.highlights.keys());

        // Delete each highlight
        for (var i = 0; i < highlightKeys.length; i++) {
            var key = highlightKeys[i];
            var highlight = CSS.highlights.get(key);
            if (highlight) {
                highlight.clear();
            }
            CSS.highlights.delete(key);
        }

        // Reset counter
        this.highlightCounter = 0;

        console.log('Cleared all highlights');
    },

    /**
     * Clears a specific highlight by ID
     * @param {string} highlightId - The highlight ID to clear
     */
    clearHighlight: function(highlightId) {
        var highlight = CSS.highlights.get(highlightId);
        if (highlight) {
            highlight.clear();
            CSS.highlights.delete(highlightId);
            console.log('Cleared highlight:', highlightId);
            return true;
        }
        return false;
    },

    /**
     * Parses CSS selector to extract element selector and text node index
     * @param {string} cssSelector - CSS selector (may include ::text-node(N))
     * @returns {Object|null} Object with selector and textNodeIndex, or null
     */
    parseCSSSelector: function(cssSelector) {
        if (!cssSelector) return null;

        // Check for custom ::text-node(N) pseudo-element
        var textNodeMatch = cssSelector.match(/::text-node\((\d+)\)$/);
        var textNodeIndex = 0;
        var elementSelector = cssSelector;

        if (textNodeMatch) {
            textNodeIndex = parseInt(textNodeMatch[1], 10);
            elementSelector = cssSelector.substring(0, textNodeMatch.index);
        }

        return {
            selector: elementSelector,
            textNodeIndex: textNodeIndex
        };
    },

    /**
     * Finds an element by CSS selector
     * @param {string} selector - CSS selector
     * @returns {Element|null} Found element or null
     */
    findElementBySelector: function(selector) {
        try {
            return document.querySelector(selector);
        } catch (e) {
            console.error('findElementBySelector: invalid selector:', selector, e);
            return null;
        }
    },

    /**
     * Creates a CSS Highlight from ranges and applies styles
     * @param {Array<Range>} ranges - Array of Range objects
     * @param {Object} styles - Styles object
     * @param {string} highlightId - Unique highlight ID
     * @returns {Highlight|null} Highlight object or null
     */
    createHighlight: function(ranges, styles, highlightId) {
        if (!ranges || ranges.length === 0) return null;

        try {
            // Create a Highlight object with the ranges
            var highlight = new Highlight(...ranges);

            // Apply styles via CSS custom properties
            // Note: CSS Custom Highlights styles are applied via CSS, not inline
            // We'll inject a style tag with the highlight styles
            this.injectHighlightStyles(highlightId, styles);

            return highlight;
        } catch (e) {
            console.error('createHighlight: failed to create Highlight:', e);
            return null;
        }
    },

    /**
     * Injects CSS styles for a highlight
     * @param {string} highlightId - Highlight ID
     * @param {Object} styles - Styles object with camelCase properties
     */
    injectHighlightStyles: function(highlightId, styles) {
        if (!styles) return;

        // Convert camelCase to kebab-case for CSS
        var cssProperties = [];
        for (var key in styles) {
            if (styles.hasOwnProperty(key)) {
                var cssKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
                cssProperties.push(cssKey + ': ' + styles[key]);
            }
        }

        var cssRule = '::highlight(' + highlightId + ') { ' + cssProperties.join('; ') + '; }';

        // Find or create a style element for highlights
        var styleId = 'marureader-highlight-styles';
        var styleElement = document.getElementById(styleId);

        if (!styleElement) {
            styleElement = document.createElement('style');
            styleElement.id = styleId;
            document.head.appendChild(styleElement);
        }

        // Append the new rule
        styleElement.textContent += '\n' + cssRule;
    },

    /**
     * Gets bounding rectangles for all ranges
     * @param {Array<Range>} ranges - Array of Range objects
     * @returns {Array<Object>} Array of bounding rect objects {x, y, width, height}
     */
    getRangeBoundingRects: function(ranges) {
        var rects = [];

        for (var i = 0; i < ranges.length; i++) {
            var range = ranges[i];
            var clientRects = range.getClientRects();

            // A single range might produce multiple client rects (e.g., line wrapping)
            for (var j = 0; j < clientRects.length; j++) {
                var rect = clientRects[j];
                rects.push({
                    x: rect.x,
                    y: rect.y,
                    width: rect.width,
                    height: rect.height,
                    left: rect.left,
                    top: rect.top,
                    right: rect.right,
                    bottom: rect.bottom
                });
            }
        }

        return rects;
    }
};
