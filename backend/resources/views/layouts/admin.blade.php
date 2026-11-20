<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    {{-- D-013: never indexed, never sends the secret path in a Referer, loads nothing from other hosts. --}}
    <meta name="robots" content="noindex, nofollow, noarchive">
    <meta name="referrer" content="no-referrer">
    <meta name="theme-color" content="#2b2a33">
    <title>@yield('title', 'Console') · RR</title>
    @include('partials.styles')
</head>
<body class="admin">
<a class="skip-link" href="#main">Skip to main content</a>
<header class="topbar">
    <div class="topbar-inner">
        <span class="brand"><span class="brand-mark" aria-hidden="true">RR</span> Console</span>
        @auth('admin')
            {{-- Counts come from App\Providers\AppServiceProvider (a view composer). --}}
            <nav class="nav" aria-label="Admin">
                <a href="{{ route('admin.dashboard') }}" @if (request()->routeIs('admin.dashboard')) aria-current="page" @endif>Overview</a>
                <a href="{{ route('admin.registrations') }}" @if (request()->routeIs('admin.registrations*')) aria-current="page" @endif>
                    Registrations
                    @if (($navCounts['pending'] ?? 0) > 0)<span class="nav-count" aria-label="{{ $navCounts['pending'] }} waiting">{{ $navCounts['pending'] }}</span>@endif
                </a>
                <a href="{{ route('admin.logs') }}" @if (request()->routeIs('admin.logs')) aria-current="page" @endif>
                    Logs
                    @if (($navCounts['anomalies'] ?? 0) > 0)<span class="nav-count is-red" aria-label="{{ $navCounts['anomalies'] }} anomalies in 24 hours">{{ $navCounts['anomalies'] }}</span>@endif
                </a>
                <a href="{{ route('admin.content') }}" @if (request()->routeIs('admin.content*')) aria-current="page" @endif>Library</a>
                <a href="{{ route('admin.privacy') }}" @if (request()->routeIs('admin.privacy')) aria-current="page" @endif>Privacy audit</a>
                <a href="{{ route('admin.export') }}" @if (request()->routeIs('admin.export*')) aria-current="page" @endif>Research export</a>
                <form method="POST" action="{{ route('admin.logout') }}" class="inline account">
                    @csrf
                    <button type="submit">Sign out</button>
                </form>
            </nav>
        @endauth
    </div>
</header>
<main id="main" tabindex="-1">
    @include('partials.flash')
    @yield('content')
</main>
</body>
</html>
