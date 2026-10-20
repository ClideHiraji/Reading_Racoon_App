@extends('layouts.app')
@section('title', 'Registration sent')

@section('content')
<div class="narrow">
    <div class="card">
        <h1>Thank you!</h1>
        <p>Your registration was sent. An administrator will review it. Once it is approved you can <a href="{{ route('login') }}">sign in</a> with your email and password.</p>
        <p class="muted small">If you are not approved after a few school days, please contact your school's system administrator.</p>
    </div>
</div>
@endsection
