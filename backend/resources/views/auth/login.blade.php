@extends('layouts.app')
@section('title', 'Sign in')

@section('content')
<div class="narrow">
    <div class="card">
        <h1>Teacher sign in</h1>
        <p class="muted">See your class's reading progress, intervention flags and reports.</p>
        <form method="POST" action="{{ route('login') }}">
            @csrf
            <label for="email">Email</label>
            <input id="email" type="email" name="email" value="{{ old('email') }}" required autofocus autocomplete="username">
            <label for="password">Password</label>
            <input id="password" type="password" name="password" required autocomplete="current-password">
            <label class="check"><input type="checkbox" name="remember" value="1"> Keep me signed in on this computer</label>
            <button class="btn" type="submit">Sign in</button>
        </form>
    </div>
    <p class="muted small">New teacher? <a href="{{ route('register') }}">Register here</a>. An administrator approves new accounts.</p>
</div>
@endsection
