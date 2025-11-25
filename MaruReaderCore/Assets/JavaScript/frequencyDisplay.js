window.MaruReader.frequencyDisplay = {
    /**
     * Initialize frequency toggle functionality
     */
    initialize: function() {
        document.addEventListener('click', function(event) {
            if (event.target.matches('.freq-toggle')) {
                event.preventDefault();
                event.stopPropagation();

                const toggle = event.target;
                const display = toggle.closest('.frequency-display');
                if (!display) return;

                const expanded = display.querySelector('.freq-expanded');
                if (!expanded) return;

                if (expanded.style.display === 'none' || expanded.style.display === '') {
                    expanded.style.display = 'inline-flex';
                    toggle.textContent = '−';
                    toggle.setAttribute('aria-label', 'Hide frequency details');
                } else {
                    expanded.style.display = 'none';
                    toggle.textContent = '+';
                    toggle.setAttribute('aria-label', 'Toggle frequency details');
                }
            }
        }, true);
    }
};
