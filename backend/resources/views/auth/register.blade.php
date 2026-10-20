@extends('layouts.app')
@section('title', 'Register')

@section('content')
<div class="narrow">
    <div class="card">
        <h1>Teacher registration</h1>
        <p class="muted">Your account will be checked and approved by an administrator before you can sign in.</p>
        <form method="POST" action="{{ route('register') }}">
            @csrf
            <label for="name">Full name</label>
            <input id="name" type="text" name="name" value="{{ old('name') }}" required maxlength="100" autocomplete="name">
            <label for="email">School email</label>
            <input id="email" type="email" name="email" value="{{ old('email') }}" required autocomplete="email">
            <label for="school">School</label>
            <input id="school" type="text" name="school" value="{{ old('school') }}" maxlength="150" placeholder="e.g. Butuan Central Elementary School">
            <label for="section_name">Your Grade 1 section</label>
            <input id="section_name" type="text" name="section_name" value="{{ old('section_name') }}" required maxlength="100" placeholder="e.g. Grade 1 - Sampaguita">
            <label for="password">Password (at least 10 characters)</label>
            <input id="password" type="password" name="password" required autocomplete="new-password">
            <label for="password_confirmation">Repeat password</label>
            <input id="password_confirmation" type="password" name="password_confirmation" required autocomplete="new-password">
            <p class="muted small">Reading Racoon processes learners' reading data under the Data Privacy Act of 2012 (RA 10173). Only you can see your section's learners.</p>
            <button class="btn" type="submit">Send registration</button>
        </form>
    </div>
    <p class="muted small">Already approved? <a href="{{ route('login') }}">Sign in</a>.</p>
</div>
@endsection
