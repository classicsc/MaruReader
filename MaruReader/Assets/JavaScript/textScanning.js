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
     * Extracts text at a specific point with forward scanning
     * @param {number} x - X coordinate
     * @param {number} y - Y coordinate
     * @param {number} maxChars - Maximum characters to extract
     * @returns {Object|null} Text extraction result
     */
    extractTextAtPoint: function(x, y, maxChars) {
        // Try to find the most accurate character at the tap point
        var result = this.findCharacterAtPoint(x, y);
        if (!result) {
            this.handleTextResult(x, y, null);
            return null;
        }

        var node = result.node;
        var offset = result.offset;
        var tappedChar = result.character;
        var surroundingText = node.data;
        
        var before = surroundingText.substring(0, offset);
        var after = surroundingText.substring(offset + 1);
        var highlight = tappedChar;
        
        // Generate CSS path and character offset for the text node
        var cssPath = window.MaruReader.domUtilities.generateCSSPath(node);
        var textNodeIndex = window.MaruReader.domUtilities.getTextNodeIndex(node);
        if (textNodeIndex > 0) {
            cssPath += '::text-node(' + textNodeIndex + ')';
        }
        var charOffset = offset;
        
        // Initialize variables
        var hasRubyText = false;
        var htmlOffset = offset;
        var rubyAwareText = surroundingText;
        var originalText = surroundingText;
        
        // Check for ruby context
        var rubyContext = null;
        var startingRubyIndex = -1;
        var rubyParent = window.MaruReader.domUtilities.findRubyParent(node);
        
        if (rubyParent) {
            hasRubyText = true;
            rubyContext = window.MaruReader.domUtilities.findRubyContainer(rubyParent);
            
            if (rubyContext) {
                // Get original text from the entire container
                originalText = rubyContext.textContent || '';
                
                // Get ruby-aware text (excluding rt elements)
                rubyAwareText = this.extractRubyAwareText(rubyContext);
                
                // Find starting ruby index
                var rubyElements = window.MaruReader.domUtilities.getRubyElements(rubyContext);
                for (var i = 0; i < rubyElements.length; i++) {
                    if (rubyElements[i] === rubyParent) {
                        startingRubyIndex = i;
                        break;
                    }
                }
                
                // Calculate offset within the ruby-aware text
                htmlOffset = this.calculateRubyOffset(rubyElements, node, offset);
            }
        }
        
        // Extract forward text
        var forwardText = this.extractForwardText(
            node, offset, maxChars, hasRubyText, rubyContext, startingRubyIndex, tappedChar
        );
        
        var result = { 
            tappedChar: tappedChar, 
            forwardText: forwardText, 
            offset: offset, 
            before: before, 
            highlight: highlight, 
            after: after,
            hasRubyText: hasRubyText,
            htmlOffset: htmlOffset,
            rubyAwareText: rubyAwareText,
            originalText: originalText,
            cssPath: cssPath,
            charOffset: charOffset
        };

        // Send result back to Swift if message handler is available
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.textScanning) {
            window.webkit.messageHandlers.textScanning.postMessage(result);
        }

        return result;
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
     * Extracts forward text from the current position
     * @param {Node} node - Starting text node
     * @param {number} offset - Starting offset
     * @param {number} maxChars - Maximum characters to extract
     * @param {boolean} hasRubyText - Whether text has ruby annotations
     * @param {Element} rubyContext - Ruby container element
     * @param {number} startingRubyIndex - Index of starting ruby element
     * @param {string} tappedChar - The tapped character
     * @returns {string} Extracted text
     */
    extractForwardText: function(node, offset, maxChars, hasRubyText, rubyContext, startingRubyIndex, tappedChar) {
        var text = '';
        var charsCollected = 0;
        
        if (hasRubyText && rubyContext && startingRubyIndex >= 0) {
            text = this.extractRubyForwardText(rubyContext, startingRubyIndex, maxChars, tappedChar);
        } else {
            text = this.extractNormalForwardText(node, offset, maxChars);
        }
        
        // Trim to maxChars and stop at punctuation
        text = text.substring(0, maxChars);
        var punctuationMatch = text.match(/[。、！？.,!?]/);
        if (punctuationMatch) {
            text = text.substring(0, punctuationMatch.index + 1);
        }
        
        var forwardText = text;
        if (!hasRubyText) {
            forwardText = tappedChar + text; // Include tappedChar for non-ruby text
        }
        
        return forwardText;
    },

    /**
     * Extracts forward text from ruby elements
     * @param {Element} rubyContext - Ruby container
     * @param {number} startingRubyIndex - Starting ruby index
     * @param {number} maxChars - Maximum characters
     * @param {string} tappedChar - Tapped character
     * @returns {string} Extracted text
     */
    extractRubyForwardText: function(rubyContext, startingRubyIndex, maxChars, tappedChar) {
        var text = '';
        var charsCollected = 0;
        var rubyElements = window.MaruReader.domUtilities.getRubyElements(rubyContext);
        
        // Start from the current ruby element
        for (var i = startingRubyIndex; i < rubyElements.length && charsCollected < maxChars; i++) {
            var ruby = rubyElements[i];
            var rbElements = window.MaruReader.domUtilities.getRbElements(ruby);

            if (rbElements.length > 0) {
                // Handle ruby with rb elements
                for (var j = 0; j < rbElements.length && charsCollected < maxChars; j++) {
                    var rbText = rbElements[j].textContent || '';

                    if (i === startingRubyIndex && j === 0) {
                        // For the first rb in the starting ruby, start from the tapped character
                        var rbStartIndex = rbText.indexOf(tappedChar);
                        if (rbStartIndex >= 0) {
                            rbText = rbText.substring(rbStartIndex);
                        }
                    }

                    var charsToTake = Math.min(rbText.length, maxChars - charsCollected);
                    if (charsToTake > 0) {
                        text += rbText.substring(0, charsToTake);
                        charsCollected += charsToTake;
                    }
                }
            } else {
                // Handle ruby without rb elements (direct text nodes)
                var rubyText = window.MaruReader.domUtilities.getRubyBaseText(ruby);

                if (i === startingRubyIndex) {
                    // For the starting ruby, start from the tapped character
                    var rubyStartIndex = rubyText.indexOf(tappedChar);
                    if (rubyStartIndex >= 0) {
                        rubyText = rubyText.substring(rubyStartIndex);
                    }
                }

                var charsToTake = Math.min(rubyText.length, maxChars - charsCollected);
                if (charsToTake > 0) {
                    text += rubyText.substring(0, charsToTake);
                    charsCollected += charsToTake;
                }
            }
        }
        
        // Continue with non-ruby text if needed
        if (charsCollected < maxChars && startingRubyIndex < rubyElements.length) {
            text += this.extractPostRubyText(rubyContext, rubyElements, maxChars - charsCollected);
        }
        
        return text;
    },

    /**
     * Extracts text after ruby elements
     * @param {Element} rubyContext - Ruby container
     * @param {HTMLCollection} rubyElements - Ruby elements
     * @param {number} remainingChars - Remaining character count
     * @returns {string} Extracted text
     */
    extractPostRubyText: function(rubyContext, rubyElements, remainingChars) {
        var text = '';
        var lastRuby = rubyElements[rubyElements.length - 1];
        var walker = document.createTreeWalker(
            rubyContext,
            NodeFilter.SHOW_TEXT,
            {
                acceptNode: function(textNode) {
                    // Skip text nodes inside ruby, rt, or rp tags
                    var parent = textNode.parentNode;
                    while (parent && parent !== rubyContext) {
                        if (parent.tagName && ['ruby', 'rt', 'rp'].includes(parent.tagName.toLowerCase())) {
                            return NodeFilter.FILTER_REJECT;
                        }
                        parent = parent.parentNode;
                    }
                    return NodeFilter.FILTER_ACCEPT;
                }
            }
        );
        
        // Position walker after the last ruby element
        walker.currentNode = lastRuby;
        var textNode;
        var charsCollected = 0;
        while ((textNode = walker.nextNode()) && charsCollected < remainingChars) {
            var remainingText = textNode.textContent || '';
            var charsToTake = Math.min(remainingText.length, remainingChars - charsCollected);
            if (charsToTake > 0) {
                text += remainingText.substring(0, charsToTake);
                charsCollected += charsToTake;
            }
        }
        
        return text;
    },

    /**
     * Extracts forward text without ruby elements
     * @param {Node} node - Starting text node
     * @param {number} offset - Starting offset
     * @param {number} maxChars - Maximum characters
     * @returns {string} Extracted text
     */
    extractNormalForwardText: function(node, offset, maxChars) {
        var text = '';
        var charsCollected = 0;
        
        var currentNode = node;
        var currentOffset = offset + 1; // Start after tapped char
        
        while (charsCollected < maxChars) {
            if (currentNode && currentNode.nodeType === 3) {
                // Get remaining text from current node
                var remainingText = currentNode.textContent.substring(currentOffset);
                if (remainingText.length > 0) {
                    var charsToTake = Math.min(remainingText.length, maxChars - charsCollected);
                    text += remainingText.substring(0, charsToTake);
                    charsCollected += charsToTake;
                    
                    if (charsCollected >= maxChars) break;
                }
            }
            
            // Move to next text node
            currentNode = this.getNextTextNode(currentNode);
            currentOffset = 0; // Reset offset for new nodes
            
            if (!currentNode) break;
        }
        
        return text;
    },

    /**
     * Gets the next text node in document order
     * @param {Node} node - Current node
     * @returns {Node|null} Next text node
     */
    getNextTextNode: function(node) {
        var walker = window.MaruReader.domUtilities.createRubyFilteredTreeWalker(document.body);
        walker.currentNode = node;
        return walker.nextNode();
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
