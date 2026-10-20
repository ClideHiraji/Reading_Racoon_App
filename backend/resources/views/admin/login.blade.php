@extends('layouts.admin')
@section('title', 'Sign in')

@section('content')
<div class="narrow">
    <div class="card">
        <h1>Sign in</h1>
        <form method="POST" action="{{ route('admin.login') }}" autocomplete="off">
            @csrf
            <label for="email">Email</label>
            <input id="email" type="email" name="email" value="{{ old('email') }}" required autofocus autocomplete="username">
            <label for="password">Password</label>
            <input id="password" type="password" name="password" required autocomplete="current-password">
            <label for="code">Authenticator code</label>
            <input id="code" type="text" name="code" required inputmode="numeric" pattern="[0-9 ]{6,7}" maxlength="7" autocomplete="one-time-code" placeholder="6 digits">
            <p><button class="btn" type="submit">Sign in</button></p>
        </form>
    </div>
</div>
@endsection
