/*
    domUtilities.js
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
window.MaruReader.domUtilities = {

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
     * Generates a CSS selector path for an element
     * @param {Element} element - The element to generate a path for
     * @returns {string} CSS selector path
     */
    generateContainerCSSPath: function(element) {
        if (!element || element.nodeType !== 1) return '';

        var path = [];
        var current = element;

        while (current && current !== document.body) {
            var selector = current.tagName.toLowerCase();

            if (current.id) {
                selector += '#' + current.id;
                path.unshift(selector);
                break;
            } else {
                var siblings = Array.from(current.parentNode.children);
                var sameTagSiblings = siblings.filter(function(sibling) {
                    return sibling.tagName === current.tagName;
                });

                if (sameTagSiblings.length > 1) {
                    var index = sameTagSiblings.indexOf(current) + 1;
                    selector += ':nth-of-type(' + index + ')';
                }

                path.unshift(selector);
                current = current.parentElement;
            }
        }

        return path.join(' > ');
    }
};
