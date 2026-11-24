@extends('layouts.admin')
@section('title', 'Overview')

@php
    $tz = config('reading_racoon.access.timezone');
    $failing = collect($checks)->where(1, 'fail');
    $warning = collect($checks)->where(1, 'warn');
    $allClear = $pending === 0 && $anomalies7d === 0 && $errors7d === 0 && $failing->isEmpty() && $warning->isEmpty() && $failedLogins7d === 0;
@endphp

@section('content')
<div class="page-head">
    <div>
        <h1>Overview</h1>
        <p class="meta">Signed in as {{ auth('admin')->user()->email }}. Every page you open here is written to the audit log. Alerts cover the last 7 days.</p>
    </div>
</div>

<div class="grid grid-2 grid-gap-bottom" style="align-items: start;">
    <section class="panel" aria-labelledby="attention-title" style="margin: 0;">
        <h2 id="attention-title">Needs your attention</h2>
        @if ($allClear)
            <div class="empty"><div><p class="big">All clear.</p><p class="muted small">No registrations waiting, no anomalies, errors or failed sign-ins in the last 7 days, and every privacy check passes.</p></div></div>
        @else
            {{-- Most severe first: a failing security check, then decisions, then events (D-037). --}}
            <ul class="attention">
                @if ($failing->isNotEmpty())
                    <li class="is-red"><a href="{{ route('admin.privacy') }}"><span class="n">{{ $failing->count() }}</span><span>Security {{ Str::plural('check', $failing->count()) }} not met: {{ $failing->pluck(0)->join(', ') }}</span><span class="go">View</span></a></li>
                @endif
                @if ($pending > 0)
                    <li class="is-orange"><a href="{{ route('admin.registrations') }}"><span class="n">{{ $pending }}</span><span>Teacher {{ Str::plural('registration', $pending) }} waiting for a decision</span><span class="go">View</span></a></li>
                @endif
                @if ($anomalies7d > 0)
                    <li class="is-red"><a href="{{ route('admin.logs', ['anomaly' => 1]) }}"><span class="n">{{ $anomalies7d }}</span><span>{{ Str::plural('Anomaly', $anomalies7d) }} (something unusual, like a tablet clock far ahead or a blocked address)</span><span class="go">View</span></a></li>
                @endif
                @if ($errors7d > 0)
                    <li class="is-red"><a href="{{ route('admin.logs', ['kind' => 'system', 'level' => 'error']) }}"><span class="n">{{ $errors7d }}</span><span>Server {{ Str::plural('error', $errors7d) }}</span><span class="go">View</span></a></li>
                @endif
                @if ($failedLogins7d > 0)
                    <li><a href="{{ route('admin.logs', ['kind' => 'system']) }}"><span class="n">{{ $failedLogins7d }}</span><span>Failed {{ Str::plural('sign-in', $failedLogins7d) }}</span><span class="go">View</span></a></li>
                @endif
                @if ($warning->isNotEmpty())
                    <li><a href="{{ route('admin.privacy') }}"><span class="n">{{ $warning->count() }}</span><span>Privacy {{ Str::plural('check', $warning->count()) }} to review: {{ $warning->pluck(0)->join(', ') }}</span><span class="go">View</span></a></li>
                @endif
            </ul>
        @endif
    </section>

    <section class="panel" aria-labelledby="glance-title" style="margin: 0;">
        <h2 id="glance-title">At a glance</h2>
        <dl class="facts" style="margin-top: 0;">
            <div><dt>Approved teachers</dt><dd>{{ $teachers }}</dd></div>
            <div><dt>Sections</dt><dd>{{ $sections }}</dd></div>
            <div><dt>Learners</dt><dd>{{ $students }}</dd></div>
        </dl>
    </section>
</div>

<div class="grid grid-2">
    <section class="panel" aria-labelledby="anomalies-title">
        <div class="panel-head"><h2 id="anomalies-title">Latest anomalies</h2><a class="small" href="{{ route('admin.logs', ['anomaly' => 1]) }}">All anomalies</a></div>
        @forelse ($recentAnomalies as $log)
            <p class="small"><span class="badge badge-red">{{ $log->event }}</span> {{ $log->created_at->setTimezone($tz)->format('M j, g:i A') }}@if ($log->ip) · {{ $log->ip }}@endif</p>
        @empty
            <p class="muted">None.</p>
        @endforelse
    </section>
    <section class="panel" aria-labelledby="actions-title">
        <div class="panel-head"><h2 id="actions-title">Latest decisions and changes</h2><a class="small" href="{{ route('admin.logs', ['kind' => 'audit']) }}">Audit log</a></div>
        @forelse ($recentAudit as $log)
            <p class="small"><span class="badge">{{ $log->action }}</span> {{ $log->actor_label ?? 'system' }} · {{ $log->created_at->setTimezone($tz)->format('M j, g:i A') }}</p>
        @empty
            <p class="muted">None yet.</p>
        @endforelse
    </section>
</div>
@endsection
