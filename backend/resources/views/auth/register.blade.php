@extends('layouts.app')
@section('title', 'Register')

@php($invalid = fn (string $name) => $errors->has($name) ? 'aria-invalid=true aria-describedby='.$name.'-error' : '')

@section('content')
<div class="narrow">
    <div class="panel">
        <h1>Teacher registration</h1>
        <p class="meta">An administrator checks and approves your account before you can sign in.</p>
        <form method="POST" action="{{ route('register') }}">
            @csrf
            <label for="name">Full name</label>
            <input id="name" type="text" name="name" value="{{ old('name') }}" required maxlength="100" autocomplete="name" {!! $invalid('name') !!}>
            @include('partials.field-error', ['field' => 'name'])
            <label for="email">School email</label>
            <input id="email" type="email" name="email" value="{{ old('email') }}" required autocomplete="email" {!! $invalid('email') !!}>
            @include('partials.field-error', ['field' => 'email'])
            <label for="school">School</label>
            <input id="school" type="text" name="school" value="{{ old('school') }}" maxlength="150" placeholder="e.g. Butuan Central Elementary School" {!! $invalid('school') !!}>
            @include('partials.field-error', ['field' => 'school'])
            <label for="section_name">Your Grade 1 section</label>
            <input id="section_name" type="text" name="section_name" value="{{ old('section_name') }}" required maxlength="100" placeholder="e.g. Grade 1 - Sampaguita" {!! $invalid('section_name') !!}>
            @include('partials.field-error', ['field' => 'section_name'])
            <label for="password">Password</label>
            <input id="password" type="password" name="password" required autocomplete="new-password" aria-describedby="password-hint" {!! $invalid('password') !!}>
            <p class="hint" id="password-hint">At least 10 characters.</p>
            @include('partials.field-error', ['field' => 'password'])
            <label for="password_confirmation">Repeat password</label>
            <input id="password_confirmation" type="password" name="password_confirmation" required autocomplete="new-password">
            <p class="hint" style="margin-top: var(--s4);">Reading Racoon processes learners' reading data under the Data Privacy Act of 2012 (RA 10173). Only you can see your section's learners.</p>
            <div class="form-actions" style="margin-top: var(--s3);"><button class="btn" type="submit">Send registration</button></div>
        </form>
    </div>
    <p class="muted small">Already approved? <a href="{{ route('login') }}">Sign in</a>.</p>
</div>
@endsection
