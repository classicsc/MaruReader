/**
 * DOM Utility Functions for MaruReader
 * Shared helper functions for DOM manipulation and traversal
 */

window.MaruReader = window.MaruReader || {};
window.MaruReader.domUtilities = {

    /**
     * Generates a CSS selector path for a given node
     * @param {Node} node - The text node to generate a path for
     * @returns {string} CSS selector path
     */
    generateCSSPath: function(node) {
        if (node.nodeType !== 3) return '';
        
        var element = node.parentElement;
        if (!element) return '';
        
        var path = [];
        
        while (element && element !== document.body) {
            var selector = element.tagName.toLowerCase();
            
            if (element.id) {
                selector += '#' + element.id;
                path.unshift(selector);
                break;
            } else {
                var siblings = Array.from(element.parentNode.children);
                var sameTagSiblings = siblings.filter(function(sibling) {
                    return sibling.tagName === element.tagName;
                });
                
                if (sameTagSiblings.length > 1) {
                    var index = sameTagSiblings.indexOf(element) + 1;
                    selector += ':nth-of-type(' + index + ')';
                }
                
                path.unshift(selector);
                element = element.parentElement;
            }
        }
        
        return path.join(' > ');
    },

    /**
     * Gets the index of a text node among its siblings
     * @param {Node} textNode - The text node
     * @returns {number} Index of the text node
     */
    getTextNodeIndex: function(textNode) {
        var parent = textNode.parentNode;
        if (!parent) return 0;
        
        var textNodes = Array.from(parent.childNodes).filter(function(node) {
            return node.nodeType === 3;
        });
        
        return textNodes.indexOf(textNode);
    },

    /**
     * Checks if a node is inside ruby annotation elements (rt or rp)
     * @param {Node} node - Node to check
     * @returns {boolean} True if inside rt or rp element
     */
    isInsideRubyAnnotation: function(node) {
        var current = node;
        while (current && current.parentElement) {
            var tagName = current.parentElement.tagName?.toLowerCase();
            if (tagName === 'rt' || tagName === 'rp') {
                return true;
            }
            current = current.parentElement;
        }
        return false;
    },

    /**
     * Creates a tree walker that filters out ruby text (rt and rp elements)
     * @param {Node} root - Root node to walk from
     * @returns {TreeWalker} Configured tree walker
     */
    createRubyFilteredTreeWalker: function(root) {
        var self = this;
        return document.createTreeWalker(
            root,
            NodeFilter.SHOW_TEXT,
            {
                acceptNode: function(node) {
                    // Skip text nodes inside <rt> or <rp> tags
                    return self.isInsideRubyAnnotation(node)
                        ? NodeFilter.FILTER_REJECT
                        : NodeFilter.FILTER_ACCEPT;
                }
            }
        );
    },

    /**
     * Finds the nearest ruby parent element
     * @param {Node} node - Starting node
     * @returns {Element|null} Ruby element or null
     */
    findRubyParent: function(node) {
        var current = node;

        // If it's a text node, start from its parent
        if (current.nodeType === 3) {
            current = current.parentNode;
        }

        // Walk up the DOM tree
        while (current) {
            if (current.tagName) {
                var tagName = current.tagName.toLowerCase();
                if (tagName === 'ruby') {
                    return current;
                }
                if (tagName === 'rb') {
                    // If we're in an rb, check if its parent is ruby
                    var parent = current.parentNode;
                    if (parent && parent.tagName && parent.tagName.toLowerCase() === 'ruby') {
                        return parent;
                    }
                }
            }
            current = current.parentNode;
        }
        return null;
    },

    /**
     * Finds the container element that holds ruby elements
     * @param {Element} rubyElement - A ruby element
     * @returns {Element|null} Container element
     */
    findRubyContainer: function(rubyElement) {
        var container = rubyElement.parentNode;
        while (container && container.tagName && 
               !['p', 'div', 'span', 'body'].includes(container.tagName.toLowerCase())) {
            container = container.parentNode;
        }
        return container;
    },

    /**
     * Gets all ruby elements within a container
     * @param {Element} container - Container element
     * @returns {HTMLCollection} Collection of ruby elements
     */
    getRubyElements: function(container) {
        return container.getElementsByTagName('ruby');
    },

    /**
     * Gets the rb elements within a ruby element
     * @param {Element} rubyElement - Ruby element
     * @returns {HTMLCollection} Collection of rb elements
     */
    getRbElements: function(rubyElement) {
        return rubyElement.getElementsByTagName('rb');
    },

    /**
     * Gets the base text content of a ruby element (excluding rt and rp)
     * @param {Element} rubyElement - Ruby element
     * @returns {string} Base text content
     */
    getRubyBaseText: function(rubyElement) {
        var rbElements = this.getRbElements(rubyElement);
        if (rbElements.length > 0) {
            // If rb elements exist, use their text content
            var text = '';
            for (var i = 0; i < rbElements.length; i++) {
                text += rbElements[i].textContent || '';
            }
            return text;
        } else {
            // If no rb elements, extract direct text nodes (excluding rt/rp)
            var walker = document.createTreeWalker(
                rubyElement,
                NodeFilter.SHOW_TEXT,
                {
                    acceptNode: function(textNode) {
                        return window.MaruReader.domUtilities.isInsideRubyAnnotation(textNode)
                            ? NodeFilter.FILTER_REJECT
                            : NodeFilter.FILTER_ACCEPT;
                    }
                }
            );

            var text = '';
            var textNode;
            while (textNode = walker.nextNode()) {
                text += textNode.textContent;
            }
            return text;
        }
    }
};
