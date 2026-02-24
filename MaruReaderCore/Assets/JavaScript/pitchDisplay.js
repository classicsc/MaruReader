/*
    pitchDisplay.js
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
                    toggle.setAttribute('aria-label', window.MaruReader.localizedStrings.showMorePitchResults);
                } else {
                    // Expand: show all items
                    collapsedItems.forEach(function(item) {
                        item.style.display = 'flex';
                    });
                    toggle.textContent = '−';
                    toggle.setAttribute('data-expanded', 'true');
                    toggle.setAttribute('aria-label', window.MaruReader.localizedStrings.showFewerPitchResults);
                }
            }
        }, true);
    }
};
