@extends('layouts.admin')
@section('title', 'Privacy audit')

@php($tz = config('reading_racoon.access.timezone'))

@section('content')
<div class="page-head">
    <div>
        <h1>Data privacy audit</h1>
        <p class="muted">Republic Act 10173 (Data Privacy Act of 2012). Learners are minors: collect only what the study needs, with parental consent.</p>
    </div>
</div>

<section class="card">
    <h2>Checks</h2>
    <div class="table-wrap">
        <table>
            <thead><tr><th>Check</th><th>Status</th><th>Details</th></tr></thead>
            <tbody>
            @foreach ($checks as [$name, $status, $detail])
                <tr @class(['anomaly' => $status === 'fail'])>
                    <td><strong>{{ $name }}</strong></td>
                    <td class="status-{{ $status }}">{{ strtoupper($status) }}</td>
                    <td class="small">{{ $detail }}</td>
                </tr>
            @endforeach
            </tbody>
        </table>
    </div>
</section>

<div class="grid grid-2">
    <section class="card">
        <h2>Consent by section</h2>
        <table class="small">
            <thead><tr><th>Section</th><th>Teacher</th><th>Consent on file</th></tr></thead>
            <tbody>
            @forelse ($sections as $section)
                <tr>
                    <td>{{ $section->name }}</td>
                    <td>{{ $section->teacher?->name ?? 'no teacher' }}</td>
                    <td>
                        {{ $section->consented_count }}/{{ $section->students_count }}
                        @if ($section->students_count > $section->consented_count)
                            <span class="badge badge-amber">{{ $section->students_count - $section->consented_count }} missing</span>
                        @endif
                    </td>
                </tr>
            @empty
                <tr><td colspan="3" class="muted">No sections.</td></tr>
            @endforelse
            </tbody>
        </table>
        <p class="muted small">Sections without a teacher: {{ $orphanSections }}. Teachers waiting for approval: {{ $pendingTeachers }}.</p>
    </section>

    <section class="card">
        <h2>Personal data stored</h2>
        <table class="small">
            <thead><tr><th>Data</th><th>Where</th><th>Rows</th><th>Why / how</th></tr></thead>
            <tbody>
            @foreach ($inventory as [$data, $where, $rows, $why])
                <tr><td>{{ $data }}</td><td><code>{{ $where }}</code></td><td>{{ $rows }}</td><td>{{ $why }}</td></tr>
            @endforeach
            </tbody>
        </table>
        <p class="muted small">Oldest synced event: {{ $oldestEvent ? \Carbon\CarbonImmutable::parse($oldestEvent)->setTimezone($tz)->format('M j, Y') : 'none' }}. Removing a learner deletes all their rows.</p>
    </section>
</div>

<section class="card">
    <h2>Who opened learner data (last 30 days)</h2>
    @if ($access->isEmpty())
        <p class="muted">No access recorded.</p>
    @else
        <table class="small">
            <thead><tr><th>Who</th><th>Role</th><th>What</th><th>Times</th><th>Last</th></tr></thead>
            <tbody>
            @foreach ($access as $row)
                <tr @class(['anomaly' => str_starts_with($row->action, 'export.')])>
                    <td>{{ $row->actor_label }}</td><td>{{ $row->actor_role }}</td><td>{{ $row->action }}</td><td>{{ $row->n }}</td>
                    <td>{{ \Carbon\CarbonImmutable::parse($row->last_at)->setTimezone($tz)->format('M j, g:i A') }}</td>
                </tr>
            @endforeach
            </tbody>
        </table>
    @endif
</section>
@endsection
