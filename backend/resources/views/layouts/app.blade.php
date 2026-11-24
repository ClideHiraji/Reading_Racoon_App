<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <meta name="theme-color" content="#fbf6ec">
    <title>@yield('title', 'Teacher') · Reading Racoon</title>
    @include('partials.styles')
    @stack('head')
</head>
<body class="teacher" @auth data-idle-minutes="{{ (int) config('session.lifetime') }}" @endauth>
<a class="skip-link" href="#main">Skip to main content</a>
<header class="topbar">
    <div class="topbar-inner">
        <a class="brand" href="{{ auth()->check() ? route('teacher.home') : route('login') }}">
            <span class="brand-mark" aria-hidden="true">RR</span>
            Reading Racoon <span class="brand-tag">Teacher</span>
        </a>
        <nav class="nav" aria-label="Main">
            @auth
                {{-- A class's pages (learners, reports, schedule) all live under "My sections". --}}
                @php($inClass = request()->routeIs('teacher.home', 'teacher.sections.*', 'teacher.students.*', 'teacher.schedule.*'))
                <a href="{{ route('teacher.home', ['all' => 1]) }}" @if ($inClass) aria-current="page" @endif>My sections</a>
                <a href="{{ route('teacher.content.index') }}" @if (request()->routeIs('teacher.content.*')) aria-current="page" @endif>Library &amp; Videos</a>
                <span class="who">{{ auth()->user()->name }}</span>
                <form method="POST" action="{{ route('logout') }}" class="inline account">
                    @csrf
                    <button type="submit">Sign out</button>
                </form>
            @else
                <a href="{{ route('login') }}" @if (request()->routeIs('login')) aria-current="page" @endif>Sign in</a>
                <a href="{{ route('register') }}" @if (request()->routeIs('register')) aria-current="page" @endif>Register</a>
            @endauth
        </nav>
    </div>
</header>
<main id="main" tabindex="-1">
    @include('partials.flash')
    @yield('content')
</main>
@stack('scripts')
</body>
</html>
