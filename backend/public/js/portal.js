/*
 * Small progressive enhancements for the teacher dashboard and admin portal.
 * Every page works without this file; it only adds confirmations, printing,
 * the learner-list filters and the sticky in-page navigation (CSP: 'self').
 */
(function () {
    'use strict';

    // Confirm before risky actions. The text comes from data-confirm on the
    // button that submitted the form, else on the form (escaped by Blade).
    document.addEventListener('submit', function (event) {
        var form = event.target;
        var submitter = event.submitter;
        var text = (submitter && submitter.dataset.confirm) || form.dataset.confirm;
        if (text && !window.confirm(text)) {
            event.preventDefault();
            return;
        }
        guardOff();
    });

    // Login cards are shown once: warn before leaving until they are printed.
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

    document.querySelectorAll('[data-print]').forEach(function (button) {
        button.addEventListener('click', function () {
            document.body.classList.add('printing-cards');
            window.print();
            document.body.classList.remove('printing-cards');
            guardOff();
        });
    });
    document.querySelectorAll('[data-guard-done]').forEach(function (button) {
        button.addEventListener('click', guardOff);
    });

    // A link to a collapsed <details> ("Add learners") opens it and moves focus in.
    function openDetails(id) {
        var target = id && document.getElementById(id);
        if (!target || target.tagName !== 'DETAILS') return false;
        target.open = true;
        var field = target.querySelector('textarea, input:not([type=hidden]), select');
        target.scrollIntoView({block: 'start'});
        if (field) field.focus({preventScroll: true});
        return true;
    }
    document.querySelectorAll('[data-open]').forEach(function (link) {
        link.addEventListener('click', function (event) {
            if (openDetails(link.dataset.open)) event.preventDefault();
        });
    });
    if (window.location.hash) openDetails(window.location.hash.slice(1));

    // "Show all" for long lists that render their first rows only.
    document.querySelectorAll('[data-show-more]').forEach(function (button) {
        button.addEventListener('click', function () {
            var scope = button.closest('section') || document;
            scope.querySelectorAll('[data-more][hidden]').forEach(function (row) { row.hidden = false; });
            button.parentNode.removeChild(button);
        });
    });

    // Close an open dropdown menu on Escape or a click outside it.
    document.addEventListener('click', function (event) {
        document.querySelectorAll('details.menu[open]').forEach(function (menu) {
            if (!menu.contains(event.target)) menu.removeAttribute('open');
        });
    });
    document.addEventListener('keydown', function (event) {
        if (event.key !== 'Escape') return;
        document.querySelectorAll('details.menu[open]').forEach(function (menu) {
            menu.removeAttribute('open');
            var summary = menu.querySelector('summary');
            if (summary) summary.focus();
        });
    });

    // Sticky in-page navigation: mark the section in view.
    var localLinks = Array.prototype.slice.call(document.querySelectorAll('.local-nav a[href^="#"]'));
    if (localLinks.length && 'IntersectionObserver' in window) {
        var byId = {};
        localLinks.forEach(function (link) { byId[link.getAttribute('href').slice(1)] = link; });
        var observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (!entry.isIntersecting) return;
                localLinks.forEach(function (link) {
                    link.classList.remove('is-current');
                    link.removeAttribute('aria-current');
                });
                var link = byId[entry.target.id];
                if (link) {
                    link.classList.add('is-current');
                    link.setAttribute('aria-current', 'location');
                }
            });
        }, {rootMargin: '-15% 0px -70% 0px'});
        Object.keys(byId).forEach(function (id) {
            var section = document.getElementById(id);
            if (section) observer.observe(section);
        });
    }

    // Learner list: search, show and sort without a page load (FR-06).
    var roster = document.querySelector('table[data-roster]');
    if (!roster) return;
    var body = roster.tBodies[0];
    var rows = Array.prototype.slice.call(body.rows);
    var toolbar = document.querySelector('[data-roster-toolbar]');
    var search = document.querySelector('[data-roster-search]');
    var show = document.querySelector('[data-roster-show]');
    var sort = document.querySelector('[data-roster-sort]');
    var count = document.querySelector('[data-roster-count]');
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
        if (count) count.textContent = visible === rows.length
            ? 'Showing all ' + rows.length
            : 'Showing ' + visible + ' of ' + rows.length;
        if (updateUrl && window.history.replaceState) {
            var params = new URLSearchParams(window.location.search);
            filter !== 'all' ? params.set('show', filter) : params.delete('show');
            order !== 'name' ? params.set('sort', order) : params.delete('sort');
            q ? params.set('q', q) : params.delete('q');
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

    // Links elsewhere on the page ("3 need help", a map stop) filter the list.
    document.querySelectorAll('[data-roster-filter]').forEach(function (link) {
        link.addEventListener('click', function (event) {
            if (!show || !hasOption(show, link.dataset.rosterFilter)) return;
            event.preventDefault();
            show.value = link.dataset.rosterFilter;
            if (search) search.value = '';
            apply(true);
            var target = document.getElementById('learners');
            if (target) {
                target.scrollIntoView({block: 'start'});
                if (show) show.focus({preventScroll: true});
            }
        });
    });

    apply(false);
})();
