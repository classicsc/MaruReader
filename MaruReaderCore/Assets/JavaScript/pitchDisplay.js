window.MaruReader.pitchDisplay = {
    /**
     * Initialize pitch toggle functionality
     */
    initialize: function() {
        document.addEventListener('click', function(event) {
            if (event.target.matches('.pitch-toggle')) {
                event.preventDefault();
                event.stopPropagation();

                const toggle = event.target;
                const pitchArea = toggle.closest('.pitch-results-area');
                if (!pitchArea) return;

                const collapsedItems = pitchArea.querySelectorAll('.pitch-result-collapsed');
                const isExpanded = toggle.getAttribute('data-expanded') === 'true';

                if (isExpanded) {
                    // Collapse: hide additional items
                    collapsedItems.forEach(function(item) {
                        item.style.display = 'none';
                    });
                    toggle.textContent = '+';
                    toggle.setAttribute('data-expanded', 'false');
                    toggle.setAttribute('aria-label', 'Show more pitch results');
                } else {
                    // Expand: show all items
                    collapsedItems.forEach(function(item) {
                        item.style.display = 'flex';
                    });
                    toggle.textContent = '−';
                    toggle.setAttribute('data-expanded', 'true');
                    toggle.setAttribute('aria-label', 'Show fewer pitch results');
                }
            }
        }, true);
    }
};
