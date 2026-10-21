<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>@yield('title', 'Teacher') · Reading Racoon</title>
    @include('partials.styles')
    @stack('head')
</head>
<body>
<header class="topbar">
    <div class="topbar-inner">
        <a class="brand" href="{{ auth()->check() ? route('teacher.home') : route('login') }}">
            <span class="brand-mark" aria-hidden="true">RR</span>
            Reading Racoon <small>Teacher</small>
        </a>
        <nav class="nav" aria-label="Main">
            @auth
                <a href="{{ route('teacher.home') }}" @class(['active' => request()->routeIs('teacher.home')])>My sections</a>
                <span class="muted small">{{ auth()->user()->name }}</span>
                <form method="POST" action="{{ route('logout') }}" class="inline">
                    @csrf
                    <button type="submit">Sign out</button>
                </form>
            @else
                <a href="{{ route('login') }}" @class(['active' => request()->routeIs('login')])>Sign in</a>
                <a href="{{ route('register') }}" @class(['active' => request()->routeIs('register')])>Register</a>
            @endauth
        </nav>
    </div>
</header>
<main>
    @include('partials.flash')
    @yield('content')
</main>
<script>
    // Confirm dialogs read their text from data-confirm (escaped HTML, never inline JS).
    document.querySelectorAll('form[data-confirm]').forEach(function (form) {
        form.addEventListener('submit', function (event) {
            if (!window.confirm(form.dataset.confirm)) event.preventDefault();
        });
    });
</script>
@stack('scripts')
</body>
</html>
