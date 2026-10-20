<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    {{-- D-013: never indexed, never sends the secret path in a Referer, loads nothing from other hosts. --}}
    <meta name="robots" content="noindex, nofollow, noarchive">
    <meta name="referrer" content="no-referrer">
    <title>@yield('title', 'Console') · RR</title>
    @include('partials.styles')
    <style>
        .topbar { background: #2b2a33; border-bottom: 0; }
        .topbar .brand, .topbar .nav a, .topbar .nav button { color: #fff; }
        .topbar .nav a:hover, .topbar .nav a.active, .topbar .nav button:hover { background: rgba(255,255,255,.12); }
        .brand-mark { background: var(--orange); }
        .status-ok { color: var(--green); font-weight: 700; }
        .status-warn { color: #a36a0f; font-weight: 700; }
        .status-fail { color: var(--red); font-weight: 700; }
        .spark { display: flex; align-items: flex-end; gap: 3px; height: 48px; }
        .spark span { flex: 1; background: var(--red); border-radius: 2px 2px 0 0; min-height: 2px; opacity: .8; }
        .pager { display: flex; gap: .5rem; align-items: center; margin-top: .75rem; }
    </style>
</head>
<body>
<header class="topbar">
    <div class="topbar-inner">
        <span class="brand"><span class="brand-mark" aria-hidden="true">RR</span> Console</span>
        @auth('admin')
            <nav class="nav" aria-label="Admin">
                <a href="{{ route('admin.dashboard') }}" @class(['active' => request()->routeIs('admin.dashboard')])>Overview</a>
                <a href="{{ route('admin.registrations') }}" @class(['active' => request()->routeIs('admin.registrations')])>Registrations</a>
                <a href="{{ route('admin.logs') }}" @class(['active' => request()->routeIs('admin.logs')])>Logs</a>
                <a href="{{ route('admin.privacy') }}" @class(['active' => request()->routeIs('admin.privacy')])>Privacy audit</a>
                <a href="{{ route('admin.export') }}" @class(['active' => request()->routeIs('admin.export')])>Research export</a>
                <form method="POST" action="{{ route('admin.logout') }}" class="inline">
                    @csrf
                    <button type="submit">Sign out</button>
                </form>
            </nav>
        @endauth
    </div>
</header>
<main>
    @include('partials.flash')
    @yield('content')
</main>
</body>
</html>
