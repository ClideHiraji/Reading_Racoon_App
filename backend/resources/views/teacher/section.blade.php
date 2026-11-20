@extends('layouts.app')
@section('title', $section->name)

@php
    use App\Support\SectionStats;
    use App\Support\SkillCatalog;
    $tz = config('reading_racoon.access.timezone');
    $count = $stats->students->count();
    $consented = $stats->students->whereNotNull('consent_recorded_at')->count();
    $avgLevel = $count ? round($stats->students->avg(fn ($s) => SectionStats::highest($s)), 1) : null;
@endphp

@section('content')
<div class="page-head">
    <div>
        <h1>{{ $section->name }}</h1>
        <p class="muted">Class reading dashboard · {{ $count }} {{ Str::plural('learner', $count) }}</p>
    </div>
    <div class="row">
        <a class="btn btn-light" href="{{ route('teacher.schedule.edit', $section) }}">Play schedule</a>
        <a class="btn btn-light" href="{{ route('teacher.content.index') }}">Library &amp; Videos</a>
        @if ($otherSections->isNotEmpty())
            <a class="btn btn-light" href="{{ route('teacher.home', ['all' => 1]) }}">All sections</a>
        @endif
    </div>
</div>

@if ($cards = session('login_cards'))
    {{-- Shown once (FR-16, D-036): only a scrambled copy of each code is kept. --}}
    <section id="login-cards" class="card" aria-labelledby="cards-title" style="border-color: var(--teal);">
        <div class="page-head no-print" style="margin-bottom: .5rem;">
            <h2 id="cards-title">{{ count($cards) === 1 ? 'Login card for '.$cards[0]['name'] : 'Login cards for '.count($cards).' learners' }}</h2>
            <button class="btn" type="button" data-print>Print {{ count($cards) === 1 ? 'card' : 'cards' }}</button>
        </div>
        <p class="muted small no-print">Print them now, or copy each code onto the child's card. For privacy the codes are stored only in scrambled form and <strong>won't be shown again</strong>: once you leave or reload this page, a lost card needs "New login code". Student IDs (RR-...) are only for reports and are not login codes.</p>
        <div class="login-cards">
            @foreach ($cards as $card)
                <div class="login-card">
                    <div class="login-card-head"><span class="brand-mark" aria-hidden="true">RR</span> Reading Racoon &middot; {{ $section->name }}</div>
                    <div class="login-card-name">{{ $card['name'] }}</div>
                    <div class="login-card-code" aria-label="Login code {{ $card['login_code'] }}">
                        @foreach (str_split(str_replace('-', '', $card['login_code'])) as $i => $char)
                            @if ($i === 4)<span class="gap" aria-hidden="true"></span>@endif
                            <span class="box">{{ $char }}</span>
                        @endforeach
                    </div>
                    <div class="login-card-plain">{{ $card['login_code'] }}</div>
                    <div class="login-card-help">Type these 8 letters and numbers in the game, then tap LET'S GO!</div>
                </div>
            @endforeach
        </div>
    </section>
@endif

<div class="grid grid-4" style="margin-bottom: 1rem;">
    <div class="tile"><div class="value">{{ $count }}</div><div class="label">Learners</div></div>
    <div class="tile"><div class="value">{{ $avgLevel ?? '-' }}</div><div class="label">Average map level</div></div>
    <div class="tile"><div class="value" style="color: {{ $stats->openFlags->isEmpty() ? 'var(--green)' : 'var(--red)' }}">{{ $stats->openFlags->count() }}</div><div class="label">Open intervention flags</div></div>
    <div class="tile"><div class="value">{{ $consented }}/{{ $count }}</div><div class="label">Parental consent on file</div></div>
</div>

<div class="grid grid-2">
    <section class="card" aria-labelledby="mastery-title">
        <h2 id="mastery-title">Mastery by sub-skill</h2>
        <div class="chart-box"><canvas id="masteryChart" role="img" aria-label="Mastery by sub-skill"></canvas></div>
        <table class="small" style="margin-top: .75rem;">
            <thead><tr><th>Sub-skill</th><th>Skill-levels mastered</th><th>Avg P(L) now</th></tr></thead>
            <tbody>
            @foreach ($stats->skills as $skill)
                <tr>
                    <td>{{ $skill['label'] }}</td>
                    <td>{{ $skill['mastered_pct'] }}%</td>
                    <td>{{ $skill['avg_p'] === null ? '-' : $skill['avg_p'].'%' }} <span class="muted">({{ $skill['learners'] }} working on it)</span></td>
                </tr>
            @endforeach
            </tbody>
        </table>
    </section>
    <section class="card" aria-labelledby="bands-title">
        <h2 id="bands-title">ARAL bands</h2>
        <p class="muted small">From each learner's highest unlocked map level.</p>
        <div class="chart-box"><canvas id="bandChart" role="img" aria-label="Learners per ARAL band"></canvas></div>
    </section>
</div>

<section class="card" aria-labelledby="flags-title">
    <div class="page-head" style="margin-bottom: .5rem;">
        <h2 id="flags-title">Open intervention flags</h2>
        <div class="legend">
            @foreach (SectionStats::FLAG_STYLES as [$badge, $color, $label])
                <span><span class="flag-dot" style="background: {{ $color }}"></span>{{ $label }}</span>
            @endforeach
        </div>
    </div>
    @if ($stats->openFlags->isEmpty())
        <p class="muted">No open flags. Learners who fail Racoon's Rescue or stay below P(L) 0.30 after 5 tries show up here.</p>
    @else
        <div class="table-wrap">
            <table>
                <thead><tr><th>Learner</th><th>Flag</th><th>Sub-skill</th><th>Raised</th><th></th></tr></thead>
                <tbody>
                @foreach ($stats->openFlags as $flag)
                    @php([$badge, $color, $label] = SectionStats::FLAG_STYLES[$flag->type] ?? ['badge', '#6b6b78', ucfirst(str_replace('_', ' ', $flag->type))])
                    <tr>
                        <td><a href="{{ route('teacher.students.show', $flag->student) }}">{{ $flag->student->displayName() }}</a></td>
                        <td><span class="badge {{ $badge }}"><span class="flag-dot" style="background: {{ $color }}"></span>{{ $label }}</span></td>
                        <td>{{ $flag->sub_skill ? SkillCatalog::label($flag->sub_skill) : '-' }}{{ $flag->level ? ' · L'.$flag->level : '' }}</td>
                        <td class="small">{{ $flag->raised_at->setTimezone($tz)->format('M j, g:i A') }}</td>
                        <td>
                            <form method="POST" action="{{ route('teacher.flags.resolve', $flag) }}">
                                @csrf
                                <button class="btn btn-light btn-sm" type="submit">Mark resolved</button>
                            </form>
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
    @endif
</section>

<section class="card" aria-labelledby="roster-title">
    <div class="page-head" style="margin-bottom: .5rem;">
        <h2 id="roster-title">Roster</h2>
    </div>
    <form method="POST" action="{{ route('teacher.students.store', $section) }}" class="add-learners">
        @csrf
        <label for="new-names" class="small">Add learners: one first name or nickname per line (up to {{ \App\Http\Controllers\Teacher\RosterController::MAX_NAMES }} at once)</label>
        <textarea id="new-names" name="names" rows="3" required placeholder="One first name per line">{{ old('names') }}</textarea>
        <button class="btn" type="submit">Add and make login cards</button>
    </form>
    <p class="muted small">Use a first name or nickname only (RA 10173). Reports and exports use the student ID instead.</p>
    @if ($count === 0)
        <p class="muted">No learners yet. Add your class above; each learner gets a login code for the tablet.</p>
    @else
        <div class="table-wrap">
            <table>
                <thead>
                <tr><th>Learner</th><th>Level · ARAL band</th><th>Sub-skills (current level)</th><th>XP / coins</th><th>Last played</th><th>Consent</th><th></th></tr>
                </thead>
                <tbody>
                @foreach ($stats->students as $student)
                    @php($last = $stats->lastActivity[$student->id] ?? null)
                    <tr>
                        <td>
                            <a href="{{ route('teacher.students.show', $student) }}"><strong>{{ $student->displayName() }}</strong></a>
                            <div class="muted small" title="A private ID for reports and exports. Children sign in with their login code; New login code makes one.">Student ID {{ $student->code }} · not the login code</div>
                            @if ($student->open_flags_count > 0)
                                <span class="badge badge-red">{{ $student->open_flags_count }} {{ Str::plural('flag', $student->open_flags_count) }}</span>
                            @endif
                        </td>
                        <td>{{ SectionStats::band($student) }}</td>
                        <td style="min-width: 250px;">
                            @foreach (SkillCatalog::skills() as $skill)
                                @php($state = SectionStats::currentState($student, $skill))
                                <div class="skill-row small" title="{{ SkillCatalog::label($skill) }}">
                                    <span class="skill-name">{{ SkillCatalog::label($skill) }}</span>
                                    @if ($state)
                                        <span class="bar"><span style="width: {{ $state->mastered_at ? 100 : round($state->p_mastery * 100) }}%; background: {{ $state->mastered_at ? 'var(--green)' : ($state->p_mastery < 0.3 && $state->attempts >= 5 ? 'var(--amber)' : 'var(--teal)') }}"></span></span>
                                        <span class="muted">L{{ $state->level }}</span>
                                    @else
                                        <span class="muted">not yet</span>
                                    @endif
                                </div>
                            @endforeach
                        </td>
                        <td>{{ $student->wallet?->xp ?? 0 }} / {{ $student->wallet?->coins ?? 0 }}</td>
                        <td class="small">{{ $last ? \Carbon\CarbonImmutable::parse($last)->setTimezone($tz)->format('M j, g:i A') : 'never' }}</td>
                        <td>
                            <form method="POST" action="{{ route('teacher.students.consent', $student) }}">
                                @csrf
                                <input type="hidden" name="consent" value="{{ $student->consent_recorded_at ? 0 : 1 }}">
                                <button class="btn btn-sm {{ $student->consent_recorded_at ? 'btn-light' : '' }}" type="submit" title="Parental consent form received">
                                    {{ $student->consent_recorded_at ? 'On file' : 'Record' }}
                                </button>
                            </form>
                        </td>
                        <td>
                            <div class="row">
                                <a class="btn btn-light btn-sm" href="{{ route('teacher.students.report', $student) }}">Report</a>
                                <form method="POST" action="{{ route('teacher.students.code', $student) }}" data-confirm="Give {{ $student->displayName() }} a new login code? The old code stops working.">
                                    @csrf
                                    <button class="btn btn-light btn-sm" type="submit">New login code</button>
                                </form>
                                <form method="POST" action="{{ route('teacher.students.destroy', $student) }}" data-confirm="Remove {{ $student->displayName() }} and delete all their reading data? This cannot be undone.">
                                    @csrf
                                    @method('DELETE')
                                    <button class="btn btn-danger btn-sm" type="submit">Remove</button>
                                </form>
                            </div>
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
    @endif
</section>
@endsection

@push('scripts')
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.js" integrity="sha384-dug+JxfBvklEQdJ4AYuBBAIScUz0bVN73xpy273gcAwHjb3qI0fXmuYNaNfdyYJG" crossorigin="anonymous"></script>
<script nonce="{{ Vite::cspNonce() }}">
    (function () {
        if (!window.Chart) return; // offline: the tables above still show every number
        const skills = @json(array_values($stats->skills));
        new Chart(document.getElementById('masteryChart'), {
            type: 'bar',
            data: {
                labels: skills.map(s => s.label),
                datasets: [
                    {label: 'Skill-levels mastered (%)', data: skills.map(s => s.mastered_pct), backgroundColor: '#4f9a3f'},
                    {label: 'Average P(L) at current level (%)', data: skills.map(s => s.avg_p), backgroundColor: '#2a9d8f'},
                ],
            },
            options: {maintainAspectRatio: false, scales: {y: {min: 0, max: 100, ticks: {callback: v => v + '%'}}}},
        });
        const bands = @json($stats->bands);
        new Chart(document.getElementById('bandChart'), {
            type: 'bar',
            data: {
                labels: Object.keys(bands),
                datasets: [{label: 'Learners', data: Object.values(bands),
                    backgroundColor: ['#e9a23b', '#e76f51', '#3f80aa', '#6a4c93', '#2a9d8f', '#4f9a3f']}],
            },
            options: {indexAxis: 'y', maintainAspectRatio: false, plugins: {legend: {display: false}},
                scales: {x: {beginAtZero: true, ticks: {precision: 0}}}},
        });
    })();
</script>
@endpush
