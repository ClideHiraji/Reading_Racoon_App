{{-- Error pages in the paper style, with a way back. Static on purpose: nothing here depends
on the session or who is signed in, so a refused admin request looks exactly like any other 404. --}}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>@yield('title') · Reading Racoon</title>
    @include('partials.styles')
</head>
<body>
<header class="topbar">
    <div class="topbar-inner">
        <a class="brand" href="{{ url('/') }}"><span class="brand-mark" aria-hidden="true">RR</span> Reading Racoon</a>
    </div>
</header>
<main id="main">
    <div class="narrow">
        <div class="panel">
            <p class="muted small" style="margin-bottom: var(--s2);">Error @yield('code')</p>
            <h1>@yield('heading')</h1>
            <div class="measure">@yield('message')</div>
            <div class="form-actions">
                <a class="btn" href="{{ url('/') }}">Go to Reading Racoon</a>
            </div>
        </div>
    </div>
</main>
</body>
</html>
