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
                    <div class="maru-popup-loading" id="maru-popup-loading">
                        <div class="maru-popup-spinner"></div>
                        <div class="maru-popup-loading-text">Searching dictionary...</div>
                    </div>
                    <iframe class="maru-popup-results-frame" id="maru-popup-results-frame"></iframe>
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
            this.showError('No text found at this location');
            return;
        }

        // Extract search text from the scanned data
        var searchText = textData.forwardText || textData.tappedChar || '';
        if (!searchText.trim()) {
            this.showError('No text found to search');
            return;
        }

        this.performDictionaryLookup(searchText);
    },

    /**
     * Performs dictionary lookup for the given text
     * @param {string} searchText - Text to search for
     */
    performDictionaryLookup: function(searchText) {
        // Show loading state
        this.showLoading();

        // Perform the dictionary lookup via iframe
        var iframe = document.getElementById('maru-popup-results-frame');
        if (iframe) {
            var encodedQuery = encodeURIComponent(searchText);
            var url = 'marureader-lookup://dictionarysearch/popup.html?query=' + encodedQuery;

            // Set up load handler to hide loading state when content loads
            iframe.onload = this.handleResultsLoaded.bind(this);
            iframe.onerror = this.handleResultsError.bind(this);

            iframe.src = url;
        } else {
            this.showError('Could not load dictionary results');
        }
    },

    /**
     * Shows loading state in popup
     */
    showLoading: function() {
        var loading = document.getElementById('maru-popup-loading');
        var iframe = document.getElementById('maru-popup-results-frame');

        if (loading) loading.style.display = 'flex';
        if (iframe) iframe.style.display = 'none';
    },

    /**
     * Shows error state in popup
     * @param {string} message - Error message to display
     */
    showError: function(message) {
        var iframe = document.getElementById('maru-popup-results-frame');
        var loading = document.getElementById('maru-popup-loading');

        if (loading) loading.style.display = 'none';
        if (iframe) {
            iframe.style.display = 'block';
            iframe.srcdoc = `
                <html>
                    <head>
                        <link rel="stylesheet" href="marureader-resource://popup.css">
                    </head>
                    <body class="popup-results-body">
                        <div class="popup-error-state">
                            <p>${message}</p>
                        </div>
                    </body>
                </html>
            `;
        }
    },

    /**
     * Handles successful loading of dictionary results
     */
    handleResultsLoaded: function() {
        var loading = document.getElementById('maru-popup-loading');
        var iframe = document.getElementById('maru-popup-results-frame');

        if (loading) loading.style.display = 'none';
        if (iframe) iframe.style.display = 'block';
    },

    /**
     * Handles error loading dictionary results
     */
    handleResultsError: function() {
        this.showError('Failed to load dictionary results');
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
