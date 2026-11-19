@extends('layouts.app')
@section('title', $student->displayName())

@php
    use App\Support\SectionStats;
    use App\Support\SkillCatalog;
    $colors = ['phonological_awareness' => '#2a9d8f', 'phonics' => '#e76f51', 'vocabulary' => '#6a4c93', 'fluency' => '#3f80aa', 'literal_comprehension' => '#c9a227'];
    $fmt = fn ($t) => $t->setTimezone($timezone)->format('M j, Y g:i A');
    // Lessons and Racoon's Rescue outcomes, newest first. (Keep every @php block above
    // the inline @php(...) calls: Blade would otherwise merge them into one block.)
    $sessions = collect($replay->lessons)->map(fn ($l) => ['kind' => 'lesson'] + $l)
        ->merge(collect($replay->rescues)->map(fn ($r) => ['kind' => 'rescue'] + $r))
        ->sortByDesc(fn ($r) => $r['time']->getTimestamp())->take(40);
@endphp

@section('content')
<p class="small"><a href="{{ route('teacher.sections.show', $student->section) }}">&larr; {{ $student->section->name }}</a></p>
<div class="page-head">
    <div>
        <h1>{{ $student->displayName() }}</h1>
        <p class="muted">Student code {{ $student->code }} · {{ $band }}</p>
    </div>
    <div class="row">
        <a class="btn" href="{{ route('teacher.students.report', $student) }}">Diagnostic report</a>
        <a class="btn btn-light" href="{{ route('teacher.students.report.pdf', $student) }}">Download PDF</a>
    </div>
</div>

<div class="grid grid-4" style="margin-bottom: 1rem;">
    <div class="tile"><div class="value">L{{ SectionStats::highest($student) }}</div><div class="label">{{ SkillCatalog::level(SectionStats::highest($student))['world'] }}</div></div>
    <div class="tile"><div class="value">{{ $replay->responses ? round(100 * $replay->correctResponses / $replay->responses).'%' : '-' }}</div><div class="label">Accuracy over {{ $replay->responses }} answers</div></div>
    <div class="tile"><div class="value">{{ count($replay->lessons) }}</div><div class="label">Lessons played</div></div>
    <div class="tile"><div class="value">{{ $student->wallet?->xp ?? 0 }}</div><div class="label">XP · {{ $student->wallet?->coins ?? 0 }} coins</div></div>
</div>

<section class="card" aria-labelledby="chart-title">
    <h2 id="chart-title">Mastery over time</h2>
    <p class="muted small">P(L) after each answer: one line per sub-skill and level (solid L1, dashed for higher levels). The grey line is mastery (0.95, after at least 5 answers at that level).</p>
    @if ($replay->history === [])
        <p class="muted">No answers synced yet.</p>
    @else
        <div class="chart-box" style="height: 320px;"><canvas id="bktChart" role="img" aria-label="Mastery probability over time per sub-skill"></canvas></div>
    @endif
</section>

<div class="grid grid-2">
    <section class="card" aria-labelledby="states-title">
        <h2 id="states-title">Skill-levels</h2>
        <div class="table-wrap">
            <table class="small">
                <thead><tr><th>Sub-skill</th><th>Level</th><th>P(L)</th><th>Answers</th><th>Status</th></tr></thead>
                <tbody>
                @foreach ($states as $state)
                    <tr>
                        <td>{{ SkillCatalog::label($state->sub_skill) }}</td>
                        <td>L{{ $state->level }}</td>
                        <td style="min-width: 110px;">
                            <div class="row"><span class="bar" style="flex: 1;"><span style="width: {{ round($state->p_mastery * 100) }}%; background: {{ $colors[$state->sub_skill] }}"></span></span>{{ round($state->p_mastery * 100) }}%</div>
                        </td>
                        <td>{{ $state->attempts }}</td>
                        <td>
                            @if ($state->mastered_at)
                                <span class="badge badge-green">Mastered</span>
                            @elseif ($state->review)
                                <span class="badge badge-orange">Review</span>
                            @elseif ($state->p_mastery < 0.3 && $state->attempts >= 5)
                                <span class="badge badge-amber">Needs support</span>
                            @elseif ($state->attempts > 0)
                                <span class="badge badge-teal">Practising</span>
                            @else
                                <span class="muted">Not started</span>
                            @endif
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
    </section>

    <section class="card" aria-labelledby="flags-title">
        <h2 id="flags-title">Intervention flags</h2>
        @forelse ($flags as $flag)
            @php([$badge, $color, $label] = SectionStats::FLAG_STYLES[$flag->type] ?? ['badge', '#6b6b78', ucfirst(str_replace('_', ' ', $flag->type))])
            <div class="row" style="margin-bottom: .5rem;">
                <span class="badge {{ $flag->status === 'open' ? $badge : '' }}"><span class="flag-dot" style="background: {{ $flag->status === 'open' ? $color : '#bbb' }}"></span>{{ $label }}</span>
                <span class="small">{{ $flag->sub_skill ? SkillCatalog::label($flag->sub_skill) : '' }}{{ $flag->level ? ' L'.$flag->level : '' }} · {{ $fmt($flag->raised_at) }}</span>
                @if ($flag->status === 'open')
                    <form method="POST" action="{{ route('teacher.flags.resolve', $flag) }}">
                        @csrf
                        <button class="btn btn-light btn-sm" type="submit">Mark resolved</button>
                    </form>
                @else
                    <span class="muted small">resolved</span>
                @endif
            </div>
        @empty
            <p class="muted">No flags.</p>
        @endforelse

        <h2 style="margin-top: 1.25rem;">Play time (last 14 days)</h2>
        @if ($usage->isEmpty())
            <p class="muted">No play time synced yet.</p>
        @else
            <table class="small">
                <thead><tr><th>Date</th><th>After school / weekend</th></tr></thead>
                <tbody>
                @foreach ($usage as $day)
                    <tr><td>{{ $day->date->format('D, M j') }}</td><td>{{ $day->minutes }} min</td></tr>
                @endforeach
                </tbody>
            </table>
        @endif
    </section>
</div>

<section class="card" aria-labelledby="sessions-title">
    <h2 id="sessions-title">Session history</h2>
    @if ($sessions->isEmpty())
        <p class="muted">No lessons synced yet.</p>
    @else
        <div class="table-wrap">
            <table class="small">
                <thead><tr><th>When</th><th>What</th><th>Result</th></tr></thead>
                <tbody>
                @foreach ($sessions as $row)
                    <tr>
                        <td>{{ $fmt($row['time']) }}</td>
                        @if ($row['kind'] === 'lesson')
                            <td>Lesson {{ $row['node'] + 1 }} · L{{ $row['level'] }} {{ SkillCatalog::level($row['level'])['world'] }}</td>
                            <td>
                                {{ $row['correct'] }}/{{ $row['total'] }} correct · {{ str_repeat('★', $row['stars']) }}{{ str_repeat('☆', 3 - $row['stars']) }} · +{{ $row['xp'] }} XP, +{{ $row['coins'] }} coins
                                @if ($row['level_up']) <span class="badge badge-green">Level up</span> @endif
                            </td>
                        @else
                            <td>Racoon's Rescue · {{ SkillCatalog::label($row['skill']) }} L{{ $row['from_level'] }}</td>
                            <td>
                                {{ $row['correct'] }}/3 recovered
                                @if ($row['full'])
                                    <span class="badge badge-green">Full recovery</span>
                                @else
                                    <span class="badge badge-orange">Partial{{ $row['demoted_level'] ? ' · L'.$row['demoted_level'].' back to review' : '' }}</span>
                                @endif
                            </td>
                        @endif
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
    @endif
</section>
@endsection

@if ($replay->history !== [])
@push('scripts')
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<script>
    (function () {
        if (!window.Chart) return;
        const series = @json($series);
        const labels = @json(collect(SkillCatalog::skills())->mapWithKeys(fn ($s) => [$s => SkillCatalog::label($s)]));
        const colors = @json($colors);
        const dashes = {1: [], 2: [6, 3], 3: [2, 3], 4: [8, 3, 2, 3], 5: [1, 2]};
        const datasets = Object.keys(series).map(key => {
            const [skill, level] = key.split(':');
            return {
                label: `${labels[skill]} L${level}`, data: series[key], borderColor: colors[skill], backgroundColor: colors[skill],
                borderDash: dashes[level], pointRadius: 3, tension: 0.15, spanGaps: true,
            };
        });
        const last = Math.max(...Object.values(series).flat().map(p => p.x));
        datasets.push({label: 'Mastery 0.95', data: [{x: 1, y: 0.95}, {x: last, y: 0.95}], borderColor: '#999',
            borderDash: [6, 4], pointRadius: 0, borderWidth: 1});
        new Chart(document.getElementById('bktChart'), {
            type: 'line',
            data: {datasets},
            options: {
                maintainAspectRatio: false, parsing: false,
                scales: {x: {type: 'linear', title: {display: true, text: 'Answer number'}, ticks: {precision: 0}},
                    y: {min: 0, max: 1, title: {display: true, text: 'P(L)'}}},
                plugins: {tooltip: {callbacks: {label: c => c.raw.level
                    ? `${c.dataset.label}: ${Math.round(c.raw.y * 100)}% (${c.raw.correct ? 'correct' : 'wrong'})`
                    : c.dataset.label}}},
            },
        });
    })();
</script>
@endpush
@endif
