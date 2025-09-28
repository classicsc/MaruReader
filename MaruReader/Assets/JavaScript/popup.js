/**
 * Dictionary Popup Management for MaruReader
 * Handles popup display, positioning, and state management
 */

window.MaruReader = window.MaruReader || {};
window.MaruReader.popup = {

    // Popup state
    isVisible: false,
    currentElement: null,
    currentData: null,
    isAnimating: false,

    // Configuration
    config: {
        offset: 10,           // Distance from tap point
        minWidth: 250,        // Minimum popup width
        maxWidth: 400,        // Maximum popup width
        maxHeight: 400,       // Maximum popup height
        animationDuration: 300, // Animation duration in ms
        dismissDelay: 100     // Delay before allowing new popups after dismissal
    },

    /**
     * Initializes the popup system
     */
    initialize: function() {
        this.createPopupElement();
        this.attachEventListeners();
        console.log('MaruReader popup system initialized');
    },

    /**
     * Creates the popup DOM element structure
     */
    createPopupElement: function() {
        // Remove existing popup if present
        var existingPopup = document.getElementById('maru-popup');
        if (existingPopup) {
            existingPopup.remove();
        }

        // Create popup structure
        var popup = document.createElement('div');
        popup.id = 'maru-popup';
        popup.className = 'maru-popup';
        popup.innerHTML = `
            <div class="maru-popup-container">
                <div class="maru-popup-header">
                    <h3 class="maru-popup-title">Dictionary</h3>
                    <button class="maru-popup-close" aria-label="Close popup">×</button>
                </div>
                <div class="maru-popup-content">
                    <div class="maru-popup-placeholder">
                        <div class="maru-popup-status">Placeholder Content</div>
                        <div class="maru-popup-debug">
                            <div class="maru-popup-debug-line">
                                <span class="maru-popup-debug-label">Tap Position:</span>
                                <span class="maru-popup-debug-value" id="maru-debug-position">-</span>
                            </div>
                            <div class="maru-popup-debug-line">
                                <span class="maru-popup-debug-label">Scanned Text:</span>
                                <span class="maru-popup-debug-value" id="maru-debug-text">-</span>
                            </div>
                            <div class="maru-popup-debug-line">
                                <span class="maru-popup-debug-label">Text Length:</span>
                                <span class="maru-popup-debug-value" id="maru-debug-length">-</span>
                            </div>
                            <div class="maru-popup-debug-line">
                                <span class="maru-popup-debug-label">Has Ruby:</span>
                                <span class="maru-popup-debug-value" id="maru-debug-ruby">-</span>
                            </div>
                            <div class="maru-popup-debug-line">
                                <span class="maru-popup-debug-label">CSS Path:</span>
                                <span class="maru-popup-debug-value" id="maru-debug-path">-</span>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="maru-popup-footer">
                    <div class="maru-popup-footer-placeholder">
                        Dictionary lookup integration will be added later
                    </div>
                </div>
            </div>
        `;

        // Append to body
        document.body.appendChild(popup);
        this.currentElement = popup;

        // Attach close button handler
        var closeButton = popup.querySelector('.maru-popup-close');
        if (closeButton) {
            closeButton.addEventListener('click', this.hide.bind(this));
        }
    },

    /**
     * Attaches event listeners for popup management
     */
    attachEventListeners: function() {
        // Handle clicks outside popup to dismiss
        document.addEventListener('click', this.handleDocumentClick.bind(this), true);

        // Handle escape key to dismiss
        document.addEventListener('keydown', this.handleKeyDown.bind(this));

        // Handle window resize to reposition
        window.addEventListener('resize', this.handleWindowResize.bind(this));
    },

    /**
     * Shows the popup at specified coordinates with given data
     * @param {number} x - X coordinate for popup positioning
     * @param {number} y - Y coordinate for popup positioning
     * @param {Object} textData - Text scanning data to display
     * @returns {boolean} Success status
     */
    show: function(x, y, textData) {
        if (this.isAnimating) {
            console.log('Popup animation in progress, ignoring show request');
            return false;
        }

        if (this.isVisible) {
            this.hide();
            // Add small delay to allow hiding animation to complete
            setTimeout(() => {
                this.show(x, y, textData);
            }, this.config.dismissDelay);
            return false;
        }

        console.log('Showing popup at coordinates:', x, y, 'with data:', textData);

        // Store current data
        this.currentData = {
            x: x,
            y: y,
            textData: textData
        };

        // Update popup content
        this.updateContent(textData);

        // Position popup
        this.positionPopup(x, y);

        // Show popup with animation
        this.isAnimating = true;
        this.currentElement.classList.add('maru-popup-visible');
        this.isVisible = true;

        // Clear animation flag after animation completes
        setTimeout(() => {
            this.isAnimating = false;
        }, this.config.animationDuration);

        return true;
    },

    /**
     * Hides the popup with animation
     * @returns {boolean} Success status
     */
    hide: function() {
        if (!this.isVisible || this.isAnimating) {
            return false;
        }

        console.log('Hiding popup');

        this.isAnimating = true;
        this.currentElement.classList.remove('maru-popup-visible');

        // Complete hiding after animation
        setTimeout(() => {
            this.isVisible = false;
            this.isAnimating = false;
            this.currentData = null;
        }, this.config.animationDuration);

        return true;
    },

    /**
     * Updates popup content with text scanning data
     * @param {Object} textData - Text scanning result data
     */
    updateContent: function(textData) {
        if (!textData) {
            this.updateDebugInfo('No data', '-', '-', '-', '-');
            return;
        }

        // Update debug information
        var position = `(${this.currentData.x}, ${this.currentData.y})`;
        var text = textData.forwardText || textData.tappedChar || '-';
        var length = text.length.toString();
        var hasRuby = textData.hasRubyText ? 'Yes' : 'No';
        var cssPath = textData.cssPath || '-';

        this.updateDebugInfo(position, text, length, hasRuby, cssPath);
    },

    /**
     * Updates debug information display
     * @param {string} position - Tap position coordinates
     * @param {string} text - Scanned text
     * @param {string} length - Text length
     * @param {string} hasRuby - Ruby text presence
     * @param {string} cssPath - CSS path to element
     */
    updateDebugInfo: function(position, text, length, hasRuby, cssPath) {
        this.setElementText('maru-debug-position', position);
        this.setElementText('maru-debug-text', text.length > 30 ? text.substring(0, 30) + '...' : text);
        this.setElementText('maru-debug-length', length);
        this.setElementText('maru-debug-ruby', hasRuby);
        this.setElementText('maru-debug-path', cssPath.length > 40 ? '...' + cssPath.substring(cssPath.length - 40) : cssPath);
    },

    /**
     * Helper function to safely set element text content
     * @param {string} elementId - Element ID
     * @param {string} text - Text to set
     */
    setElementText: function(elementId, text) {
        var element = document.getElementById(elementId);
        if (element) {
            element.textContent = text;
        }
    },

    /**
     * Positions the popup optimally based on tap coordinates
     * @param {number} x - X coordinate
     * @param {number} y - Y coordinate
     */
    positionPopup: function(x, y) {
        if (!this.currentElement) {
            return;
        }

        // Get viewport dimensions
        var viewportWidth = window.innerWidth;
        var viewportHeight = window.innerHeight;
        var scrollX = window.pageXOffset || document.documentElement.scrollLeft;
        var scrollY = window.pageYOffset || document.documentElement.scrollTop;

        // Get popup dimensions (approximate for initial positioning)
        var popupWidth = this.config.maxWidth;
        var popupHeight = this.config.maxHeight;

        // Calculate initial position (below and to the right of tap)
        var popupX = x + this.config.offset;
        var popupY = y + this.config.offset;

        // Adjust for viewport boundaries
        // Check right edge
        if (popupX + popupWidth > viewportWidth + scrollX) {
            popupX = x - popupWidth - this.config.offset; // Position to the left
        }

        // Check bottom edge
        if (popupY + popupHeight > viewportHeight + scrollY) {
            popupY = y - popupHeight - this.config.offset; // Position above
        }

        // Ensure popup doesn't go off left edge
        if (popupX < scrollX) {
            popupX = scrollX + this.config.offset;
        }

        // Ensure popup doesn't go off top edge
        if (popupY < scrollY) {
            popupY = scrollY + this.config.offset;
        }

        // Apply positioning
        this.currentElement.style.left = popupX + 'px';
        this.currentElement.style.top = popupY + 'px';

        console.log('Positioned popup at:', popupX, popupY, 'from tap:', x, y);
    },

    /**
     * Handles clicks outside the popup to dismiss it
     * @param {Event} event - Click event
     */
    handleDocumentClick: function(event) {
        if (!this.isVisible) {
            return;
        }

        // Check if click is inside popup
        if (this.currentElement && this.currentElement.contains(event.target)) {
            return; // Click is inside popup, don't dismiss
        }

        // Click is outside popup, dismiss it
        event.preventDefault();
        event.stopPropagation();
        this.hide();
    },

    /**
     * Handles keyboard events for popup control
     * @param {Event} event - Keyboard event
     */
    handleKeyDown: function(event) {
        if (!this.isVisible) {
            return;
        }

        if (event.key === 'Escape') {
            event.preventDefault();
            this.hide();
        }
    },

    /**
     * Handles window resize to reposition popup
     */
    handleWindowResize: function() {
        if (!this.isVisible || !this.currentData) {
            return;
        }

        // Reposition popup based on stored coordinates
        this.positionPopup(this.currentData.x, this.currentData.y);
    },

    /**
     * Checks if popup is currently visible
     * @returns {boolean} Visibility status
     */
    getVisibilityStatus: function() {
        return this.isVisible;
    },

    /**
     * Forces popup to hide without animation (for emergency cleanup)
     */
    forceHide: function() {
        if (this.currentElement) {
            this.currentElement.classList.remove('maru-popup-visible');
        }
        this.isVisible = false;
        this.isAnimating = false;
        this.currentData = null;
    },

    /**
     * Toggles popup visibility at specified coordinates
     * @param {number} x - X coordinate
     * @param {number} y - Y coordinate
     * @param {Object} textData - Text data
     * @returns {boolean} New visibility status
     */
    toggle: function(x, y, textData) {
        if (this.isVisible) {
            this.hide();
            return false;
        } else {
            return this.show(x, y, textData);
        }
    }
};

// Initialize popup system when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
        window.MaruReader.popup.initialize();
    });
} else {
    window.MaruReader.popup.initialize();
}
