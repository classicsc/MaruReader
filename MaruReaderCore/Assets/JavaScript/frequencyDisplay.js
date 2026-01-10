/*
*  Copyright (c) 2025  Sam Smoker
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
* This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
window.MaruReader.frequencyDisplay = {
    /**
     * Initialize frequency toggle functionality
     */
    initialize: function() {
        document.addEventListener('click', function(event) {
            var button = event.target.closest('.freq-button');
            if (!button || button.disabled) return;

            event.preventDefault();
            event.stopPropagation();

            var display = button.closest('.frequency-display');
            if (!display) return;

            var expanded = display.querySelector('.freq-expanded');
            if (!expanded) return;

            var isExpanded = button.getAttribute('aria-expanded') === 'true';

            if (isExpanded) {
                expanded.classList.remove('visible');
                button.setAttribute('aria-expanded', 'false');
                button.setAttribute('aria-label', 'Show frequency details');
            } else {
                expanded.classList.add('visible');
                button.setAttribute('aria-expanded', 'true');
                button.setAttribute('aria-label', 'Hide frequency details');
            }
        }, true);
    }
};
