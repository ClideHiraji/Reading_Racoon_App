@extends('layouts.admin')
@section('title', 'Overview')

@php
    $tz = config('reading_racoon.access.timezone');
    $failing = collect($checks)->where(1, 'fail')->count();
    $warning = collect($checks)->where(1, 'warn')->count();
    $allClear = $pending === 0 && $anomalies24h === 0 && $errors24h === 0 && $failing === 0;
@endphp

@section('content')
<div class="page-head">
    <div>
        <h1>Overview</h1>
        <p class="meta">Signed in as {{ auth('admin')->user()->email }}. Every page you open here is written to the audit log.</p>
    </div>
</div>

<div class="grid grid-2 grid-gap-bottom" style="align-items: start;">
    <section class="panel" aria-labelledby="attention-title" style="margin: 0;">
        <h2 id="attention-title">Needs your attention</h2>
        @if ($allClear && $warning === 0 && $failedLogins24h === 0)
            <div class="empty"><div><p class="big">All clear.</p><p class="muted small">No registrations waiting, no anomalies or server errors in the last 24 hours, and every privacy check passes.</p></div></div>
        @else
            <ul class="attention">
                @if ($pending > 0)
                    <li class="is-orange"><a href="{{ route('admin.registrations') }}"><span class="n">{{ $pending }}</span><span>Teacher {{ Str::plural('registration', $pending) }} waiting for a decision</span><span class="go">Review</span></a></li>
                @endif
                @if ($failing > 0)
                    <li class="is-red"><a href="{{ route('admin.privacy') }}"><span class="n">{{ $failing }}</span><span>Privacy or security {{ Str::plural('check', $failing) }} failing: {{ collect($checks)->where(1, 'fail')->pluck(0)->join(', ') }}</span><span class="go">Fix</span></a></li>
                @endif
                @if ($anomalies24h > 0)
                    <li class="is-red"><a href="{{ route('admin.logs', ['anomaly' => 1]) }}"><span class="n">{{ $anomalies24h }}</span><span>{{ Str::plural('Anomaly', $anomalies24h) }} in the last 24 hours</span><span class="go">Look</span></a></li>
                @endif
                @if ($errors24h > 0)
                    <li class="is-red"><a href="{{ route('admin.logs', ['kind' => 'system', 'level' => 'error']) }}"><span class="n">{{ $errors24h }}</span><span>Server {{ Str::plural('error', $errors24h) }} in the last 24 hours</span><span class="go">Look</span></a></li>
                @endif
                @if ($failedLogins24h > 0)
                    <li><a href="{{ route('admin.logs', ['kind' => 'system']) }}"><span class="n">{{ $failedLogins24h }}</span><span>Failed sign-ins in the last 24 hours</span><span class="go">Look</span></a></li>
                @endif
                @if ($warning > 0)
                    <li><a href="{{ route('admin.privacy') }}"><span class="n">{{ $warning }}</span><span>Privacy {{ Str::plural('warning', $warning) }}: {{ collect($checks)->where(1, 'warn')->pluck(0)->join(', ') }}</span><span class="go">Check</span></a></li>
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
            <div><dt>Failed sign-ins (24 h)</dt><dd>{{ $failedLogins24h }}</dd></div>
            <div><dt>Server errors (24 h)</dt><dd>{{ $errors24h }}</dd></div>
        </dl>
    </section>
</div>

<div class="grid grid-2">
    <section class="panel" aria-labelledby="anomalies-title">
        <div class="panel-head"><h2 id="anomalies-title">Latest anomalies</h2><a class="small" href="{{ route('admin.logs', ['anomaly' => 1]) }}">All anomalies</a></div>
        @forelse ($recentAnomalies as $log)
            <p class="small"><span class="badge badge-red">{{ $log->event }}</span> {{ $log->created_at->setTimezone($tz)->format('M j, g:i A') }} · {{ $log->ip }}</p>
        @empty
            <p class="muted">None.</p>
        @endforelse
    </section>
    <section class="panel" aria-labelledby="actions-title">
        <div class="panel-head"><h2 id="actions-title">Latest decisions and changes</h2><a class="small" href="{{ route('admin.logs', ['kind' => 'audit']) }}">Audit log</a></div>
        @forelse ($recentAudit as $log)
            <p class="small"><span class="badge">{{ $log->action }}</span> {{ $log->actor_label ?? 'system' }} · {{ $log->created_at->setTimezone($tz)->format('M j, g:i A') }}</p>
        @empty
            <p class="muted">None.</p>
        @endforelse
    </section>
</div>
@endsection
