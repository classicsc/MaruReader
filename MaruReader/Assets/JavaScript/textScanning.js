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
    },

    /**
     * Handles tap events and triggers text scanning
     * @param {Event} event - The tap/click event
     */
    handleTap: function(event) {
        // Check if popup is visible - if so, this tap should be handled by popup system
        if (window.MaruReader.popup && window.MaruReader.popup.getVisibilityStatus()) {
            // Popup is visible, let popup system handle the event
            return;
        }

        // Prevent default behavior to avoid interfering with text scanning
        event.preventDefault();
        event.stopPropagation();

        var x = event.clientX;
        var y = event.clientY;
        var maxChars = 50; // Default max characters to extract

        this.extractTextAtPoint(x, y, maxChars);
    },

    /**
     * Handles text scanning result - shows popup or sends to Swift
     * @param {number} x - X coordinate of tap
     * @param {number} y - Y coordinate of tap
     * @param {Object|null} result - Text extraction result or null
     */
    handleTextResult: function(x, y, result) {
        // Check if popup system is available
        if (window.MaruReader.popup) {
            // Show popup with the result
            window.MaruReader.popup.show(x, y, result);
        } else {
            // Fallback to sending to Swift (original behavior)
            this.sendResultToSwift(result);
        }
    },

    /**
     * Sends text scan result to Swift via URL scheme
     * @param {Object|null} result - Text extraction result or null
     */
    sendResultToSwift: function(result) {
        try {
            var jsonData = JSON.stringify(result);
            var encodedData = encodeURIComponent(jsonData);
            var url = 'marureader-textscan://scan?data=' + encodedData;

            // Create a hidden iframe to trigger the URL scheme
            var iframe = document.createElement('iframe');
            iframe.style.display = 'none';
            iframe.src = url;
            document.body.appendChild(iframe);

            // Clean up the iframe after a short delay
            setTimeout(function() {
                document.body.removeChild(iframe);
            }, 100);
        } catch (error) {
            console.error('Error sending text scan result to Swift:', error);
        }
    },

    /**
     * Extracts text at a specific point with forward scanning
     * @param {number} x - X coordinate
     * @param {number} y - Y coordinate
     * @param {number} maxChars - Maximum characters to extract
     * @returns {Object|null} Text extraction result
     */
    extractTextAtPoint: function(x, y, maxChars) {
        var range = document.caretRangeFromPoint(x, y);
        if (!range || range.startContainer.nodeType !== 3) {
            // No valid text found - show popup with null result or return null
            this.handleTextResult(x, y, null);
            return null;
        }

        var node = range.startContainer;
        var offset = range.startOffset;

        // Handle case where we might be getting an empty text node or wrong offset
        // This can happen with ruby elements
        if (offset >= node.data.length) {
            offset = Math.max(0, node.data.length - 1);
        }

        var tappedChar = node.data.substring(offset, offset + 1);
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

        // Handle the text result (show popup or send to Swift)
        this.handleTextResult(x, y, result);

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
