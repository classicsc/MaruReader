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
     * Creates a tree walker that filters out ruby text (rt elements)
     * @param {Node} root - Root node to walk from
     * @returns {TreeWalker} Configured tree walker
     */
    createRubyFilteredTreeWalker: function(root) {
        return document.createTreeWalker(
            root,
            NodeFilter.SHOW_TEXT,
            {
                acceptNode: function(node) {
                    // Skip text nodes inside <rt> tags
                    return node.parentElement?.tagName?.toLowerCase() === 'rt' 
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
        // Start from the text node and walk up the DOM tree
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
    }
};