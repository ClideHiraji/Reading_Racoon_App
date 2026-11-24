/*
 * Small progressive enhancements for the teacher dashboard and admin portal.
 * Every page works without this file; it adds confirmations, busy states,
 * printing, the sign-out warning, the learner-list filters and the sticky
 * in-page navigation (CSP: 'self', D-037).
 */
(function () {
    'use strict';

    var $$ = function (selector, root) { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); };

    // ---- Login cards are shown once: warn before leaving until they're copied.
    var guarded = !!document.querySelector('[data-guard-unload]');
    function onBeforeUnload(event) {
        event.preventDefault();
        event.returnValue = '';
    }
    function guardOff() {
        if (guarded) {
            guarded = false;
            window.removeEventListener('beforeunload', onBeforeUnload);
        }
    }
    if (guarded) window.addEventListener('beforeunload', onBeforeUnload);

    // ---- Forms: confirm risky actions, then show they're working and block a second submit.
    document.addEventListener('submit', function (event) {
        var form = event.target;
        var submitter = event.submitter;
        if (form.dataset.busy === '1') {
            event.preventDefault();
            return;
        }
        var text = (submitter && submitter.dataset.confirm) || form.dataset.confirm;
        if (text && !window.confirm(text)) {
            event.preventDefault();
            return;
        }
        guardOff();
        form.dataset.busy = '1';
        form.setAttribute('aria-busy', 'true');
        var uploading = $$('input[type=file]', form).some(function (input) { return input.files && input.files.length; });
        // After the browser has taken the form data (disabling first would drop the button).
        window.setTimeout(function () {
            $$('button[type=submit], button:not([type])', form).forEach(function (button) { button.disabled = true; });
            if (submitter && submitter.tagName === 'BUTTON') {
                submitter.dataset.label = submitter.innerHTML;
                submitter.textContent = uploading ? 'Uploading… keep this page open' : (submitter.dataset.busyLabel || 'Working…');
            }
        }, 0);
    });
    // Coming back with the browser's Back button: undo the busy state.
    window.addEventListener('pageshow', function (event) {
        if (!event.persisted) return;
        $$('form[data-busy="1"]').forEach(function (form) {
            form.dataset.busy = '';
            form.removeAttribute('aria-busy');
            $$('button', form).forEach(function (button) {
                button.disabled = false;
                if (button.dataset.label) button.innerHTML = button.dataset.label;
            });
        });
    });

    // Links that download or leave with consequences ask first too.
    document.addEventListener('click', function (event) {
        var link = event.target.closest && event.target.closest('a[data-confirm]');
        if (link && !window.confirm(link.dataset.confirm)) event.preventDefault();
    });

    // ---- Printing: login cards only, or the whole page with every section open.
    $$('[data-print]').forEach(function (button) {
        button.addEventListener('click', function () {
            document.body.classList.add('printing-cards');
            window.print();
            document.body.classList.remove('printing-cards');
            // Cancelling the print dialog must not switch the leave-page warning off.
        });
    });
    $$('[data-print-page]').forEach(function (button) {
        button.addEventListener('click', function () { window.print(); });
    });
    $$('[data-guard-done]').forEach(function (button) {
        button.addEventListener('click', function () {
            guardOff();
            button.textContent = 'Done';
            button.disabled = true;
        });
    });
    var openedForPrint = [];
    window.addEventListener('beforeprint', function () {
        openedForPrint = $$('details:not([open])');
        openedForPrint.forEach(function (d) { d.open = true; });
    });
    window.addEventListener('afterprint', function () {
        openedForPrint.forEach(function (d) { d.open = false; });
        openedForPrint = [];
    });

    // ---- A link to a collapsed <details> ("Add learners") opens it and moves focus in.
    function openDetails(id) {
        var target = id && document.getElementById(id);
        if (!target || target.tagName !== 'DETAILS') return false;
        target.open = true;
        var field = target.querySelector('textarea, input:not([type=hidden]), select');
        target.scrollIntoView({block: 'start'});
        if (field) field.focus({preventScroll: true});
        return true;
    }
    $$('[data-open]').forEach(function (link) {
        link.addEventListener('click', function (event) {
            if (openDetails(link.dataset.open)) event.preventDefault();
        });
    });
    if (window.location.hash) openDetails(window.location.hash.slice(1));

    // "Show all" for long lists that render their first rows only.
    $$('[data-show-more]').forEach(function (button) {
        button.addEventListener('click', function () {
            var scope = button.closest('section') || document;
            $$('[data-more][hidden]', scope).forEach(function (row) { row.hidden = false; });
            button.parentNode.removeChild(button);
        });
    });

    // ---- Dropdown menus close on a click outside, Escape, or when focus leaves them.
    function closeMenu(menu, focusSummary) {
        menu.removeAttribute('open');
        if (focusSummary) {
            var summary = menu.querySelector('summary');
            if (summary) summary.focus();
        }
    }
    document.addEventListener('click', function (event) {
        $$('details.menu[open]').forEach(function (menu) {
            if (!menu.contains(event.target)) closeMenu(menu, false);
        });
    });
    document.addEventListener('keydown', function (event) {
        if (event.key !== 'Escape') return;
        $$('details.menu[open]').forEach(function (menu) { closeMenu(menu, true); });
    });
    $$('details.menu').forEach(function (menu) {
        menu.addEventListener('focusout', function (event) {
            if (menu.open && event.relatedTarget && !menu.contains(event.relatedTarget)) closeMenu(menu, false);
        });
    });

    // ---- Sticky in-page navigation: mark the section in view (the last one at the bottom).
    var localLinks = $$('.local-nav a[href^="#"]');
    if (localLinks.length) {
        var sections = localLinks.map(function (link) { return document.getElementById(link.getAttribute('href').slice(1)); });
        var mark = function () {
            var current = 0;
            sections.forEach(function (section, i) {
                if (section && section.getBoundingClientRect().top <= window.innerHeight * 0.3) current = i;
            });
            if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4) current = sections.length - 1;
            localLinks.forEach(function (link, i) {
                link.classList.toggle('is-current', i === current);
                if (i === current) link.setAttribute('aria-current', 'location');
                else link.removeAttribute('aria-current');
            });
        };
        var ticking = false;
        window.addEventListener('scroll', function () {
            if (ticking) return;
            ticking = true;
            window.requestAnimationFrame(function () { ticking = false; mark(); });
        }, {passive: true});
        mark();
    }

    // ---- Sign-out warning: the server ends an idle session; say so before it happens.
    var idleMinutes = parseInt(document.body.dataset.idleMinutes || '0', 10);
    if (idleMinutes > 2) {
        var banner = null;
        var warnTimer = null;
        var endTimer = null;
        var show = function (html, withButton) {
            if (!banner) {
                banner = document.createElement('div');
                banner.className = 'session-banner';
                banner.setAttribute('role', 'alert');
                document.body.appendChild(banner);
            }
            banner.innerHTML = '';
            var p = document.createElement('p');
            p.textContent = html;
            banner.appendChild(p);
            if (withButton) {
                var button = document.createElement('button');
                button.type = 'button';
                button.className = 'btn btn-sm';
                button.textContent = 'Stay signed in';
                button.addEventListener('click', function () {
                    fetch(window.location.href, {credentials: 'same-origin', cache: 'no-store'}).then(function () {
                        banner.remove();
                        banner = null;
                        start();
                    });
                });
                banner.appendChild(button);
            }
        };
        var start = function () {
            window.clearTimeout(warnTimer);
            window.clearTimeout(endTimer);
            warnTimer = window.setTimeout(function () {
                show('For safety you will be signed out in 2 minutes. Anything you typed on this page will be lost.', true);
            }, (idleMinutes - 2) * 60000);
            endTimer = window.setTimeout(function () {
                show('You were signed out for safety. Copy anything you typed, then reload the page and sign in again.', false);
            }, idleMinutes * 60000);
        };
        start();
    }

    // ---- The play schedule's day strip follows the time fields as they change.
    var day = document.querySelector('[data-day-strip]');
    if (day) {
        var minutes = function (id) {
            var input = document.getElementById(id);
            if (!input || !/^\d{2}:\d{2}/.test(input.value)) return null;
            return parseInt(input.value.slice(0, 2), 10) * 60 + parseInt(input.value.slice(3, 5), 10);
        };
        var place = function (selector, from, to) {
            var span = day.querySelector(selector);
            var a = minutes(from);
            var b = minutes(to);
            if (!span) return;
            if (a === null || b === null || b <= a) {
                span.hidden = true;
                return;
            }
            span.hidden = false;
            span.style.left = (100 * a / 1440) + '%';
            span.style.width = (100 * (b - a) / 1440) + '%';
        };
        var redraw = function () {
            place('.awake', 'day_start', 'day_end');
            place('.after', 'after_school_start', 'after_school_end');
            place('.class', 'class_start', 'class_end');
        };
        $$('input[type=time]').forEach(function (input) { input.addEventListener('input', redraw); });
    }

    // ---- Learner list: search, show and sort without a page load (FR-06).
    var roster = document.querySelector('table[data-roster]');
    if (!roster) return;
    var body = roster.tBodies[0];
    var rows = Array.prototype.slice.call(body.rows);
    var toolbar = document.querySelector('[data-roster-toolbar]');
    var search = document.querySelector('[data-roster-search]');
    var show = document.querySelector('[data-roster-show]');
    var sort = document.querySelector('[data-roster-sort]');
    var count = document.querySelector('[data-roster-count]');
    var empty = document.querySelector('[data-roster-empty]');
    var clears = $$('[data-roster-clear]');
    if (toolbar) toolbar.hidden = false;

    function matches(row, filter) {
        var d = row.dataset;
        if (filter === 'help') return d.help === '1';
        if (filter === 'unplayed') return d.played === '0';
        if (filter === 'noconsent') return d.consent === '0';
        if (filter.indexOf('level:') === 0) return d.level === filter.slice(6);
        if (filter.indexOf('skill:') === 0) return (' ' + d.helpSkills + ' ').indexOf(' ' + filter.slice(6) + ' ') !== -1;
        return true;
    }

    var sorters = {
        name: function (a, b) { return a.dataset.name.localeCompare(b.dataset.name); },
        need: function (a, b) { return (b.dataset.severity - a.dataset.severity) || sorters.name(a, b); },
        level: function (a, b) { return (a.dataset.level - b.dataset.level) || sorters.name(a, b); },
        last: function (a, b) { return (a.dataset.last - b.dataset.last) || sorters.name(a, b); },
    };

    function apply(updateUrl) {
        var q = (search && search.value || '').trim().toLowerCase();
        var filter = show ? show.value : 'all';
        var order = sort ? sort.value : 'name';
        var visible = 0;
        rows.sort(sorters[order] || sorters.name).forEach(function (row) {
            var ok = matches(row, filter) && (!q || row.dataset.name.indexOf(q) !== -1);
            row.classList.toggle('is-hidden', !ok);
            if (ok) visible++;
            body.appendChild(row);
        });
        var filtered = filter !== 'all' || q !== '';
        if (count) count.textContent = !filtered ? 'Showing all ' + rows.length : 'Showing ' + visible + ' of ' + rows.length;
        if (empty) empty.hidden = visible !== 0;
        roster.hidden = visible === 0;
        clears.forEach(function (button) { button.hidden = !filtered; });
        if (updateUrl && window.history.replaceState) {
            var params = new URLSearchParams(window.location.search);
            if (filter !== 'all') params.set('show', filter); else params.delete('show');
            if (order !== 'name') params.set('sort', order); else params.delete('sort');
            if (q) params.set('q', q); else params.delete('q');
            var query = params.toString();
            window.history.replaceState(null, '', window.location.pathname + (query ? '?' + query : '') + window.location.hash);
        }
    }

    function hasOption(select, value) {
        return Array.prototype.some.call(select.options, function (o) { return o.value === value; });
    }

    var params = new URLSearchParams(window.location.search);
    if (show && params.get('show') && hasOption(show, params.get('show'))) show.value = params.get('show');
    if (sort && params.get('sort') && hasOption(sort, params.get('sort'))) sort.value = params.get('sort');
    if (search && params.get('q')) search.value = params.get('q');

    [search, show, sort].forEach(function (control) {
        if (!control) return;
        control.addEventListener(control === search ? 'input' : 'change', function () { apply(true); });
    });
    clears.forEach(function (button) {
        button.addEventListener('click', function () {
            if (search) search.value = '';
            if (show) show.value = 'all';
            apply(true);
            if (search) search.focus();
        });
    });

    // Links elsewhere on the page ("3 need help", a map world) filter the list.
    $$('[data-roster-filter]').forEach(function (link) {
        link.addEventListener('click', function (event) {
            if (!show || !hasOption(show, link.dataset.rosterFilter)) return;
            event.preventDefault();
            show.value = link.dataset.rosterFilter;
            if (search) search.value = '';
            apply(true);
            var target = document.getElementById('learners');
            if (target) {
                target.scrollIntoView({block: 'start'});
                show.focus({preventScroll: true});
            }
        });
    });

    apply(false);
})();
