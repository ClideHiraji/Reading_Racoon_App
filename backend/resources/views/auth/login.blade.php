@extends('layouts.app')
@section('title', 'Sign in')

@section('content')
<div class="narrow">
    <div class="panel">
        <h1>Teacher sign in</h1>
        <p class="meta">See who needs help with reading today, your class's progress and each learner's report.</p>
        <form method="POST" action="{{ route('login') }}">
            @csrf
            <label for="email">Email</label>
            <input id="email" type="email" name="email" value="{{ old('email') }}" required autofocus autocomplete="username" @error('email') aria-invalid="true" aria-describedby="email-error" @enderror>
            @include('partials.field-error', ['field' => 'email'])
            <label for="password">Password</label>
            <input id="password" type="password" name="password" required autocomplete="current-password">
            <label class="check is-plain"><input type="checkbox" name="remember" value="1"> Keep me signed in on this computer</label>
            <div class="form-actions" style="margin-top: var(--s3);"><button class="btn" type="submit">Sign in</button></div>
        </form>
    </div>
    <p class="muted small">New teacher? <a href="{{ route('register') }}">Register here</a>. An administrator approves new accounts.</p>
</div>
@endsection
