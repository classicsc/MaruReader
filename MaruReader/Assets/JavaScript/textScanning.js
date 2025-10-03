/**
 * Text Scanning Functions for MaruReader
 * Handles text extraction from DOM elements with ruby text support
 */

window.MaruReader = window.MaruReader || {};
window.MaruReader.textScanning = {

    /**
     * Initializes text scanning by adding tap event listeners
     */
    initialize: function() {
        document.addEventListener('click', this.handleTap.bind(this), true);
        this.initializeSearch();
    },

    /**
     * Extracts text at a specific point with context-based extraction
     * @param {number} x - X coordinate
     * @param {number} y - Y coordinate
     * @param {number} contextLevel - Context level (0=sentence, 1=sentence+neighbors, etc.)
     * @param {number} maxContextChars - Maximum total context characters
     * @returns {Object|null} Text extraction result matching TextLookupRequest structure
     */
    extractTextAtPoint: function(x, y, contextLevel, maxContextChars) {
        // Try to find the most accurate character at the tap point
        var charResult = this.findCharacterAtPoint(x, y);
        if (!charResult) {
            return null;
        }

        var node = charResult.node;
        var offset = charResult.offset;

        // Check for ruby context
        var rubyContext = null;
        var rubyParent = window.MaruReader.domUtilities.findRubyParent(node);

        if (rubyParent) {
            rubyContext = window.MaruReader.domUtilities.findRubyContainer(rubyParent);
        }

        // Extract context based on contextLevel
        var contextResult = this.extractContext(
            node, offset, contextLevel, maxContextChars, rubyContext
        );

        // Generate CSS path for the text node
        var cssPath = window.MaruReader.domUtilities.generateCSSPath(node);
        var textNodeIndex = window.MaruReader.domUtilities.getTextNodeIndex(node);
        if (textNodeIndex > 0) {
            cssPath += '::text-node(' + textNodeIndex + ')';
        }

        // Build result matching TextLookupRequest structure
        var result = {
            offset: contextResult.offset, // Offset of tapped character within context
            context: contextResult.context, // Surrounding text
            rubyContext: contextResult.rubyContext, // RubyText if available
            cssSelector: cssPath // CSS selector
        };
        return result;
    },

    /**
     * Extracts context around a character with configurable sentence context
     * @param {Node} node - Text node containing the tapped character
     * @param {number} offset - Offset within the text node
     * @param {number} contextLevel - Number of surrounding sentences (0=current only)
     * @param {number} maxContextChars - Maximum total context characters
     * @param {Element} rubyContainer - Ruby container element if applicable
     * @returns {Object} Context extraction result
     */
    extractContext: function(node, offset, contextLevel, maxContextChars, rubyContainer) {
        var context = '';
        var contextOffset = 0;
        var rubyContextObj = null;

        if (rubyContainer) {
            // Extract ruby-aware context
            var rubyResult = this.extractRubyContext(
                node, offset, contextLevel, maxContextChars, rubyContainer
            );
            context = rubyResult.context;
            contextOffset = rubyResult.offset;
            rubyContextObj = rubyResult.rubyContext;
        } else {
            // Extract plain text context
            var plainResult = this.extractPlainContext(
                node, offset, contextLevel, maxContextChars
            );
            context = plainResult.context;
            contextOffset = plainResult.offset;
        }

        return {
            context: context,
            offset: contextOffset,
            rubyContext: rubyContextObj
        };
    },

    /**
     * Extracts plain text context with sentence boundaries
     * @param {Node} node - Text node
     * @param {number} offset - Character offset
     * @param {number} contextLevel - Context level
     * @param {number} maxContextChars - Maximum characters
     * @returns {Object} Context and offset
     */
    extractPlainContext: function(node, offset, contextLevel, maxContextChars) {
        // Get all text from the paragraph or container
        var container = this.findTextContainer(node);
        var fullText = this.extractFullText(container);

        // Find the offset of the tapped character in the full text
        var fullTextOffset = this.findOffsetInFullText(container, node, offset);

        // Find sentence boundaries
        var sentences = this.findSentences(fullText);
        var currentSentenceIndex = this.findSentenceAtOffset(sentences, fullTextOffset);

        if (currentSentenceIndex === -1) {
            // Fallback: return surrounding text up to maxContextChars
            var start = Math.max(0, fullTextOffset - Math.floor(maxContextChars / 2));
            var end = Math.min(fullText.length, start + maxContextChars);
            var context = fullText.substring(start, end);
            return {
                context: context,
                offset: fullTextOffset - start
            };
        }

        // Extract sentences based on contextLevel
        var startSentence = Math.max(0, currentSentenceIndex - contextLevel);
        var endSentence = Math.min(sentences.length - 1, currentSentenceIndex + contextLevel);

        var contextStart = sentences[startSentence].start;
        var contextEnd = sentences[endSentence].end;
        var context = fullText.substring(contextStart, contextEnd);

        // Truncate if exceeds maxContextChars
        if (context.length > maxContextChars) {
            var charOffset = fullTextOffset - contextStart;
            var halfMax = Math.floor(maxContextChars / 2);

            var newStart = Math.max(0, charOffset - halfMax);
            var newEnd = Math.min(context.length, newStart + maxContextChars);

            context = context.substring(newStart, newEnd);
            charOffset = charOffset - newStart;

            return {
                context: context,
                offset: charOffset
            };
        }

        return {
            context: context,
            offset: fullTextOffset - contextStart
        };
    },

    /**
     * Extracts ruby-aware context with sentence boundaries
     * @param {Node} node - Text node
     * @param {number} offset - Character offset
     * @param {number} contextLevel - Context level
     * @param {number} maxContextChars - Maximum characters
     * @param {Element} rubyContainer - Ruby container element
     * @returns {Object} Context, offset, and ruby context
     */
    extractRubyContext: function(node, offset, contextLevel, maxContextChars, rubyContainer) {
        // Get ruby-aware text (base text without annotations)
        var rubyAwareText = this.extractRubyAwareText(rubyContainer);

        // Get original text with ruby annotations
        var originalText = rubyContainer.textContent || '';

        // Find the offset in ruby-aware text
        var rubyElements = window.MaruReader.domUtilities.getRubyElements(rubyContainer);
        var rubyAwareOffset = this.calculateRubyOffset(rubyElements, node, offset);

        // Find sentence boundaries in ruby-aware text
        var sentences = this.findSentences(rubyAwareText);
        var currentSentenceIndex = this.findSentenceAtOffset(sentences, rubyAwareOffset);

        if (currentSentenceIndex === -1) {
            // Fallback: return surrounding text
            var start = Math.max(0, rubyAwareOffset - Math.floor(maxContextChars / 2));
            var end = Math.min(rubyAwareText.length, start + maxContextChars);
            return {
                context: rubyAwareText.substring(start, end),
                offset: rubyAwareOffset - start,
                rubyContext: {
                    baseText: rubyAwareText.substring(start, end),
                    originalText: originalText
                }
            };
        }

        // Extract sentences based on contextLevel
        var startSentence = Math.max(0, currentSentenceIndex - contextLevel);
        var endSentence = Math.min(sentences.length - 1, currentSentenceIndex + contextLevel);

        var contextStart = sentences[startSentence].start;
        var contextEnd = sentences[endSentence].end;
        var context = rubyAwareText.substring(contextStart, contextEnd);
        var contextOffset = rubyAwareOffset - contextStart;

        // Truncate if exceeds maxContextChars
        if (context.length > maxContextChars) {
            var halfMax = Math.floor(maxContextChars / 2);
            var newStart = Math.max(0, contextOffset - halfMax);
            var newEnd = Math.min(context.length, newStart + maxContextChars);

            context = context.substring(newStart, newEnd);
            contextOffset = contextOffset - newStart;
        }

        return {
            context: context,
            offset: contextOffset,
            rubyContext: {
                baseText: context,
                originalText: originalText
            }
        };
    },

    /**
     * Finds the text container (paragraph or similar) for a node
     * @param {Node} node - Text node
     * @returns {Element} Container element
     */
    findTextContainer: function(node) {
        var current = node.parentElement;
        while (current) {
            var tagName = current.tagName.toLowerCase();
            if (['p', 'div', 'article', 'section', 'body'].includes(tagName)) {
                return current;
            }
            current = current.parentElement;
        }
        return document.body;
    },

    /**
     * Extracts full text from a container
     * @param {Element} container - Container element
     * @returns {string} Full text content
     */
    extractFullText: function(container) {
        var walker = window.MaruReader.domUtilities.createRubyFilteredTreeWalker(container);
        var textParts = [];
        var textNode;
        while (textNode = walker.nextNode()) {
            textParts.push(textNode.textContent);
        }
        return textParts.join('');
    },

    /**
     * Finds the offset of a character within the full text of a container
     * @param {Element} container - Container element
     * @param {Node} targetNode - Target text node
     * @param {number} targetOffset - Offset within target node
     * @returns {number} Offset in full text
     */
    findOffsetInFullText: function(container, targetNode, targetOffset) {
        var walker = window.MaruReader.domUtilities.createRubyFilteredTreeWalker(container);
        var offset = 0;
        var textNode;

        while (textNode = walker.nextNode()) {
            if (textNode === targetNode) {
                return offset + targetOffset;
            }
            offset += textNode.textContent.length;
        }

        return 0; // Fallback
    },

    /**
     * Finds sentence boundaries in text
     * Japanese sentence delimiters: 。！？
     * Also handles Western punctuation: . ! ?
     * @param {string} text - Text to analyze
     * @returns {Array} Array of {start, end} sentence positions
     */
    findSentences: function(text) {
        var sentences = [];
        var sentenceDelimiters = /[。！？.!?]/g;
        var match;
        var lastEnd = 0;

        while ((match = sentenceDelimiters.exec(text)) !== null) {
            var end = match.index + 1;
            sentences.push({
                start: lastEnd,
                end: end
            });
            lastEnd = end;
        }

        // Add final sentence if text doesn't end with delimiter
        if (lastEnd < text.length) {
            sentences.push({
                start: lastEnd,
                end: text.length
            });
        }

        // If no sentences found, treat entire text as one sentence
        if (sentences.length === 0) {
            sentences.push({
                start: 0,
                end: text.length
            });
        }

        return sentences;
    },

    /**
     * Finds which sentence contains a given offset
     * @param {Array} sentences - Array of sentence objects
     * @param {number} offset - Character offset
     * @returns {number} Sentence index, or -1 if not found
     */
    findSentenceAtOffset: function(sentences, offset) {
        for (var i = 0; i < sentences.length; i++) {
            if (offset >= sentences[i].start && offset < sentences[i].end) {
                return i;
            }
        }
        return -1;
    },

    /**
     * Extracts ruby-aware text excluding rt and rp elements
     * @param {Element} container - Container element
     * @returns {string} Clean text without ruby annotations
     */
    extractRubyAwareText: function(container) {
        var walker = document.createTreeWalker(
            container,
            NodeFilter.SHOW_TEXT,
            {
                acceptNode: function(textNode) {
                    // Use the domUtilities helper to check for ruby annotations
                    return window.MaruReader.domUtilities.isInsideRubyAnnotation(textNode)
                        ? NodeFilter.FILTER_REJECT
                        : NodeFilter.FILTER_ACCEPT;
                }
            }
        );

        var cleanTextParts = [];
        var textNode;
        while (textNode = walker.nextNode()) {
            cleanTextParts.push(textNode.textContent);
        }
        return cleanTextParts.join('');
    },

    /**
     * Calculates the offset within ruby-aware text
     * @param {HTMLCollection} rubyElements - Ruby elements collection
     * @param {Node} targetNode - Target text node
     * @param {number} offset - Offset within the text node
     * @returns {number} Calculated HTML offset
     */
    calculateRubyOffset: function(rubyElements, targetNode, offset) {
        var beforeText = '';
        var found = false;
        
        for (var i = 0; i < rubyElements.length && !found; i++) {
            var ruby = rubyElements[i];
            var rbElements = window.MaruReader.domUtilities.getRbElements(ruby);

            if (rbElements.length > 0) {
                for (var j = 0; j < rbElements.length && !found; j++) {
                    var rbElement = rbElements[j];
                    var rbText = rbElement.textContent || '';

                    // Check if this rb contains our tapped text node
                    var rbTextNode = rbElement.firstChild;
                    if (rbTextNode && rbTextNode.nodeType === 3 && rbTextNode === targetNode) {
                        return beforeText.length + offset;
                    }

                    beforeText += rbText;
                }
            } else {
                // Handle ruby elements without rb children (direct text nodes)
                var rubyText = window.MaruReader.domUtilities.getRubyBaseText(ruby);

                // Check if this ruby contains our tapped text node
                var walker = document.createTreeWalker(
                    ruby,
                    NodeFilter.SHOW_TEXT,
                    {
                        acceptNode: function(textNode) {
                            return !window.MaruReader.domUtilities.isInsideRubyAnnotation(textNode)
                                ? NodeFilter.FILTER_ACCEPT
                                : NodeFilter.FILTER_REJECT;
                        }
                    }
                );

                var textNode;
                while ((textNode = walker.nextNode()) && !found) {
                    if (textNode === targetNode) {
                        return beforeText.length + offset;
                    }
                }

                beforeText += rubyText;
            }
        }
        
        return offset; // fallback
    },


    /**
     * Finds the most accurate character at the given point using multiple methods
     * @param {number} x - X coordinate
     * @param {number} y - Y coordinate
     * @returns {Object|null} Object with node, offset, and character, or null if not found
     */
    findCharacterAtPoint: function(x, y) {
        // Method 1: Try caretRangeFromPoint first
        var range = document.caretRangeFromPoint(x, y);
        if (range && range.startContainer.nodeType === 3) {
            var node = range.startContainer;
            var offset = range.startOffset;

            // Validate and adjust offset
            if (offset >= node.data.length) {
                offset = Math.max(0, node.data.length - 1);
            }

            // For more accurate character detection, we'll use character boundary detection
            var accurateResult = this.findAccurateCharacterOffset(node, offset, x, y);
            if (accurateResult) {
                return accurateResult;
            }

            // Fallback to basic offset
            var character = node.data.substring(offset, offset + 1);
            if (character) {
                return {
                    node: node,
                    offset: offset,
                    character: character
                };
            }
        }

        // Method 2: Element-based search as fallback
        var element = document.elementFromPoint(x, y);
        if (element) {
            var textResult = this.findCharacterInElement(element, x, y);
            if (textResult) {
                return textResult;
            }
        }

        return null;
    },

    /**
     * Finds accurate character offset by checking character boundaries
     * @param {Node} node - Text node
     * @param {number} initialOffset - Initial offset from caretRangeFromPoint
     * @param {number} x - X coordinate
     * @param {number} y - Y coordinate
     * @returns {Object|null} Accurate character result or null
     */
    findAccurateCharacterOffset: function(node, initialOffset, x, y) {
        var text = node.data;
        if (!text || text.length === 0) {
            return null;
        }

        // Check a range around the initial offset to find the most accurate character
        var startCheck = Math.max(0, initialOffset - 2);
        var endCheck = Math.min(text.length, initialOffset + 3);

        var bestMatch = null;
        var bestDistance = Infinity;

        for (var i = startCheck; i < endCheck; i++) {
            if (i >= text.length) break;

            // Create a range for this character
            var testRange = document.createRange();
            testRange.setStart(node, i);
            testRange.setEnd(node, i + 1);

            var rect = testRange.getBoundingClientRect();
            if (rect.width === 0 && rect.height === 0) {
                continue; // Skip invisible characters
            }

            // Check if the tap point is within or very close to this character's bounds
            var charCenterX = rect.left + rect.width / 2;
            var charCenterY = rect.top + rect.height / 2;

            // Calculate distance from tap point to character center
            var distance = Math.sqrt(
                Math.pow(x - charCenterX, 2) + Math.pow(y - charCenterY, 2)
            );

            // Also check if tap is within the character bounds
            var withinBounds = (
                x >= rect.left && x <= rect.right &&
                y >= rect.top && y <= rect.bottom
            );

            if (withinBounds || distance < bestDistance) {
                bestDistance = distance;
                bestMatch = {
                    node: node,
                    offset: i,
                    character: text.substring(i, i + 1),
                    distance: distance,
                    withinBounds: withinBounds
                };
            }
        }

        // Return the best match if it's within reasonable bounds
        if (bestMatch && (bestMatch.withinBounds || bestMatch.distance < 20)) {
            return bestMatch;
        }

        return null;
    },

    /**
     * Searches for character within an element by examining text nodes
     * @param {Element} element - Element to search within
     * @param {number} x - X coordinate
     * @param {number} y - Y coordinate
     * @returns {Object|null} Character result or null
     */
    findCharacterInElement: function(element, x, y) {
        var walker = document.createTreeWalker(
            element,
            NodeFilter.SHOW_TEXT,
            {
                acceptNode: function(textNode) {
                    // Skip empty text nodes and ruby annotations
                    if (!textNode.textContent.trim()) {
                        return NodeFilter.FILTER_REJECT;
                    }
                    return window.MaruReader.domUtilities &&
                           window.MaruReader.domUtilities.isInsideRubyAnnotation &&
                           window.MaruReader.domUtilities.isInsideRubyAnnotation(textNode)
                        ? NodeFilter.FILTER_REJECT
                        : NodeFilter.FILTER_ACCEPT;
                }
            }
        );

        var textNode;
        while (textNode = walker.nextNode()) {
            var result = this.findAccurateCharacterOffset(textNode, 0, x, y);
            if (result && result.withinBounds) {
                return result;
            }
        }

        return null;
    }
};

// Initialize text scanning when the DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
        window.MaruReader.textScanning.initialize();
    });
} else {
    window.MaruReader.textScanning.initialize();
}
