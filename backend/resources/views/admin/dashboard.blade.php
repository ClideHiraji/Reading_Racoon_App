@extends('layouts.admin')
@section('title', 'Overview')

@php($tz = config('reading_racoon.access.timezone'))

@section('content')
<div class="page-head">
    <div>
        <h1>Overview</h1>
        <p class="muted">Signed in as {{ auth('admin')->user()->email }}. Every page you open here is written to the audit log.</p>
    </div>
</div>

<div class="grid grid-4" style="margin-bottom: 1rem;">
    <a class="tile" href="{{ route('admin.registrations') }}" style="text-decoration: none; color: inherit;">
        <div class="value" style="color: {{ $pending ? 'var(--orange)' : 'inherit' }}">{{ $pending }}</div><div class="label">Teacher registrations waiting</div>
    </a>
    <a class="tile" href="{{ route('admin.logs', ['anomaly' => 1]) }}" style="text-decoration: none; color: inherit;">
        <div class="value" style="color: {{ $anomalies24h ? 'var(--red)' : 'var(--green)' }}">{{ $anomalies24h }}</div><div class="label">Anomalies in the last 24 h</div>
    </a>
    <div class="tile"><div class="value">{{ $failedLogins24h }}</div><div class="label">Failed sign-ins (24 h)</div></div>
    <div class="tile"><div class="value">{{ $errors24h }}</div><div class="label">Server errors (24 h)</div></div>
    <div class="tile"><div class="value">{{ $teachers }}</div><div class="label">Approved teachers</div></div>
    <div class="tile"><div class="value">{{ $sections }}</div><div class="label">Sections</div></div>
    <div class="tile"><div class="value">{{ $students }}</div><div class="label">Learners</div></div>
</div>

<div class="grid grid-2">
    <section class="card">
        <h2>Latest anomalies</h2>
        @forelse ($recentAnomalies as $log)
            <p class="small"><span class="badge badge-red">{{ $log->event }}</span> {{ $log->created_at->setTimezone($tz)->format('M j, g:i A') }} · {{ $log->ip }}</p>
        @empty
            <p class="muted">None.</p>
        @endforelse
        <p><a href="{{ route('admin.logs', ['anomaly' => 1]) }}">All anomalies</a></p>
    </section>
    <section class="card">
        <h2>Latest actions</h2>
        @forelse ($recentAudit as $log)
            <p class="small"><span class="badge">{{ $log->action }}</span> {{ $log->actor_label ?? 'system' }} · {{ $log->created_at->setTimezone($tz)->format('M j, g:i A') }}</p>
        @empty
            <p class="muted">None.</p>
        @endforelse
        <p><a href="{{ route('admin.logs', ['kind' => 'audit']) }}">Audit log</a></p>
    </section>
</div>
@endsection
