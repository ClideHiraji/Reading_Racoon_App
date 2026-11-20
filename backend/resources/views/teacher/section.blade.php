@extends('layouts.app')
@section('title', $section->name)

@php
    use App\Support\SectionStats;
    use App\Support\SkillCatalog;
    $tz = config('reading_racoon.access.timezone');
    $count = $stats->students->count();
    $consented = $stats->students->whereNotNull('consent_recorded_at')->count();
    $noConsent = $count - $consented;
    $notPlayed = $stats->students->filter(fn ($s) => ! isset($stats->lastActivity[$s->id]))->count();
    $needCount = $stats->needingHelpCount();
    $avgLevel = $count ? round($stats->students->avg(fn ($s) => SectionStats::highest($s)), 1) : null;
    $skills = SkillCatalog::skills();
    $firstShown = 6;
    $needRows = collect($stats->needsHelp);
    $maxAtLevel = max(1, max($stats->levels ?: [0]));
    $stateOrder = ['got', 'prac', 'help', 'new', 'locked'];
    $short = ['got' => 'Got it', 'prac' => 'Practising', 'help' => 'Needs help', 'new' => 'Not started', 'locked' => 'Not yet'];
@endphp

@section('content')
@include('teacher.partials.login-cards', ['sectionName' => $section->name])

<div class="page-head" style="margin-bottom: 0;">
    <div>
        <h1>{{ $section->name }}</h1>
    </div>
    <div class="actions">
        @if ($otherSections->isNotEmpty())
            <details class="menu">
                <summary class="btn btn-secondary">Switch section</summary>
                <ul class="menu-list">
                    @foreach ($otherSections as $other)
                        <li><a href="{{ route('teacher.sections.show', $other) }}">{{ $other->name }}</a></li>
                    @endforeach
                    <li><a href="{{ route('teacher.home', ['all' => 1]) }}">All sections</a></li>
                </ul>
            </details>
        @endif
        <a class="btn btn-secondary" href="{{ route('teacher.schedule.edit', $section) }}">Play schedule</a>
        <a class="btn" href="#add-learners" data-open="add-learners">Add learners</a>
    </div>
</div>
<ul class="summary" aria-label="Class summary" style="margin: var(--s2) 0 var(--s5);">
    <li><span class="n">{{ $count }}</span> {{ Str::plural('learner', $count) }}</li>
    @if ($count > 0)
        <li><a href="#needs-help"><span class="n">{{ $needCount }}</span> {{ $needCount === 1 ? 'needs' : 'need' }} your help</a></li>
        @if ($notPlayed > 0)
            <li><a href="#learners" data-roster-filter="unplayed"><span class="n">{{ $notPlayed }}</span> {{ $notPlayed === 1 ? "hasn't" : "haven't" }} played yet</a></li>
        @endif
        <li><a href="#learners" data-roster-filter="noconsent"><span class="n">{{ $consented }}/{{ $count }}</span> consent forms</a></li>
        <li><span class="n">{{ $avgLevel }}</span> avg. map level</li>
    @endif
</ul>

@if ($count > 0)
<nav class="local-nav" aria-label="On this page">
    <ul>
        <li><a href="#needs-help">Needs your help <span class="count">{{ $needCount }}</span></a></li>
        <li><a href="#progress">Class progress</a></li>
        <li><a href="#learners">Learners <span class="count">{{ $count }}</span></a></li>
    </ul>
</nav>

{{-- 1. Who needs help today (FR-17): one row per child, most urgent first. --}}
<section id="needs-help" class="panel" aria-labelledby="needs-title">
    <div class="panel-head">
        <div>
            <h2 id="needs-title">Needs your help</h2>
            <p class="muted small">Children with open flags, most urgent first. Open a child to see which skill to practise with them.</p>
        </div>
        <ul class="legend" aria-label="Flag types">
            @foreach (SectionStats::FLAG_STYLES as [$badge, $color, $label])
                <li><span class="flag-dot" style="background: {{ $color }}" aria-hidden="true"></span>{{ $label }}</li>
            @endforeach
        </ul>
    </div>

    @if ($needRows->isEmpty())
        <div class="empty">
            <div>
                <p class="big">Nobody needs extra help right now.</p>
                <p class="muted small">A child shows up here when a skill stays under 30% after 5 answers, or when Racoon's Rescue doesn't go well.</p>
            </div>
        </div>
    @else
        <ol class="need-list">
            @foreach ($needRows->take($firstShown) as $row)
                @include('teacher.partials.need-row', ['row' => $row])
            @endforeach
        </ol>
        @if ($needRows->count() > $firstShown)
            <details class="disclosure">
                <summary>Show {{ $needRows->count() - $firstShown }} more {{ Str::plural('child', $needRows->count() - $firstShown) }}</summary>
                <ol class="need-list disclosure-body" start="{{ $firstShown + 1 }}">
                    @foreach ($needRows->slice($firstShown) as $row)
                        @include('teacher.partials.need-row', ['row' => $row])
                    @endforeach
                </ol>
            </details>
        @endif
    @endif

    <details class="disclosure">
        <summary>What do these mean?</summary>
        <dl class="disclosure-body small measure">
            @foreach (SectionStats::FLAG_STYLES as $type => [$badge, $color, $label])
                <dt><span class="badge {{ $badge }}"><span class="flag-dot" style="background: {{ $color }}" aria-hidden="true"></span>{{ $label }}</span></dt>
                <dd class="muted" style="margin: .3rem 0 .8rem;">{{ SectionStats::FLAG_HELP[$type] }}</dd>
            @endforeach
            <dt><span class="better">Looks better now</span></dt>
            <dd class="muted" style="margin: .3rem 0 0;">The child has since mastered that skill-level, or their mastery climbed back to 50% or more. Check with them, then mark it resolved. Flags never close by themselves: you decide.</dd>
        </dl>
    </details>
</section>

{{-- 2. Class progress: the class on the reading map, then each sub-skill. --}}
<section id="progress" class="panel" aria-labelledby="progress-title">
    <div class="panel-head">
        <h2 id="progress-title">Class progress</h2>
    </div>

    <h3 id="map-title">Where the class is on the reading map</h3>
    <p class="muted small">Each learner is shown at the highest world they have unlocked. Each world is an ARAL band. Click a world to list its learners.</p>
    <ol class="map" aria-labelledby="map-title">
        @foreach ($stats->levels as $level => $n)
            @php($world = SkillCatalog::level($level))
            @php($pct = round(100 * $n / $maxAtLevel))
            <li class="map-stop" style="--w: {{ max(1, $pct) }}%">
                <span @class(['map-bar', 'is-empty' => $n === 0]) style="height: {{ max(2, round($pct * 0.78)) }}%"><span class="map-count">{{ $n }}</span></span>
                <span class="map-route" aria-hidden="true"></span>
                <span class="map-name">{{ $world['world'] }}</span>
                <span class="map-band">L{{ $level }} · {{ $world['band'] }}</span>
                @if ($n > 0)
                    <a class="map-hit" href="#learners" data-roster-filter="level:{{ $level }}"><span class="sr-only">Show the {{ $n }} {{ Str::plural('learner', $n) }} at L{{ $level }}, {{ $world['world'] }}</span></a>
                @endif
            </li>
        @endforeach
    </ol>
    @if ($stats->finished > 0)
        <p class="map-note small">{{ $stats->finished }} {{ Str::plural('learner', $stats->finished) }} finished the whole map ({{ SkillCatalog::level(5)['band'] }}, complete).</p>
    @endif

    <div class="sub">
        <div class="panel-head" style="margin-bottom: var(--s3);">
            <h3>Skills across the class</h3>
            <ul class="legend" aria-label="States">
                <li><span class="swatch" style="background: var(--got)"></span>Got it</li>
                <li><span class="swatch" style="background: var(--prac)"></span>Practising</li>
                <li><span class="swatch" style="background: var(--help)"></span>Needs help</li>
                <li><span class="swatch" style="background: var(--line-strong)"></span>Not started</li>
                <li><span class="swatch" style="background: var(--track)"></span>Not reached yet</li>
            </ul>
        </div>
        <p class="muted small">Each learner counts once per skill, at the level they are working on now.</p>
        <ul class="meters">
            @foreach ($skills as $skill)
                @php($c = $stats->skillStates[$skill])
                <li class="meter">
                    <span class="meter-name">{{ SkillCatalog::label($skill) }}</span>
                    <span class="seg" role="img" aria-label="{{ SkillCatalog::label($skill) }}: {{ $c['got'] }} got it, {{ $c['prac'] }} practising, {{ $c['help'] }} need help, {{ $c['new'] }} not started, {{ $c['locked'] }} not reached yet">
                        @foreach ($stateOrder as $key)
                            @if ($c[$key] > 0)<span class="s-{{ $key }}" style="flex: {{ $c[$key] }}"></span>@endif
                        @endforeach
                    </span>
                    <span class="meter-figs">
                        <strong>{{ $c['got'] }}</strong> got it<span class="sep" aria-hidden="true">·</span>{{ $c['prac'] }} practising<span class="sep" aria-hidden="true">·</span>@if ($c['help'] > 0)<a href="#learners" data-roster-filter="skill:{{ $skill }}">{{ $c['help'] }} need help</a>@else 0 need help @endif
                        @if ($c['locked'] > 0)<span class="sep" aria-hidden="true">·</span><span class="muted">{{ $c['locked'] }} not reached</span>@endif
                    </span>
                </li>
            @endforeach
        </ul>

        <details class="disclosure">
            <summary>Show the mastery numbers</summary>
            <div class="disclosure-body table-wrap">
                <table class="compact">
                    <caption class="muted small" style="padding-bottom: .5rem;">P(L) is the game's estimate (0–100%) that a child has mastered a skill-level; a level counts as mastered at 95% after at least 5 answers.</caption>
                    <thead><tr><th>Sub-skill</th><th class="num">Skill-levels mastered</th><th class="num">Average P(L) now</th><th class="num">Learners practising</th></tr></thead>
                    <tbody>
                    @foreach ($stats->skills as $row)
                        <tr>
                            <td>{{ $row['label'] }}</td>
                            <td class="num">{{ $row['mastered_pct'] }}%</td>
                            <td class="num">{{ $row['avg_p'] === null ? '-' : $row['avg_p'].'%' }}</td>
                            <td class="num">{{ $row['learners'] }}</td>
                        </tr>
                    @endforeach
                    </tbody>
                </table>
            </div>
        </details>
    </div>
</section>
@endif

{{-- 3. Learners: filter, sort, open one (FR-06, FR-16). --}}
<section id="learners" class="panel" aria-labelledby="roster-title">
    <div class="panel-head">
        <div>
            <h2 id="roster-title">Learners</h2>
            <p class="muted small">Student IDs (RR-...) are for reports, not login codes. Lost a login card? Open the learner and choose <strong>New login code</strong>.</p>
        </div>
    </div>

    <details class="disclosure" id="add-learners" style="margin-top: 0; margin-bottom: var(--s4);" @if ($count === 0 || $errors->has('names') || $errors->has('name')) open @endif>
        <summary>Add learners</summary>
        <form method="POST" action="{{ route('teacher.students.store', $section) }}" class="add-learners disclosure-body">
            @csrf
            <label for="new-names" style="margin-top: 0;">First names or nicknames, one per line</label>
            <textarea id="new-names" name="names" rows="4" required placeholder="One name per line" aria-describedby="names-hint @error('names') names-error @enderror" @error('names') aria-invalid="true" @enderror>{{ old('names') }}</textarea>
            <p class="hint" id="names-hint">Up to {{ \App\Http\Controllers\Teacher\RosterController::MAX_NAMES }} at once. A first name or nickname only (RA 10173); reports and exports use the student ID instead. Each child gets a login card to print.</p>
            @include('partials.field-error', ['field' => 'names'])
            <div class="form-actions" style="margin-top: var(--s3);"><button class="btn" type="submit">Add and make login cards</button></div>
        </form>
    </details>

    @if ($count === 0)
        <div class="empty">
            <div>
                <p class="big">No learners yet.</p>
                <p class="muted small">Add your class above. Each child gets a login code for the game; their reading progress shows here after they play and the tablet syncs.</p>
            </div>
        </div>
    @else
        <div class="toolbar" data-roster-toolbar hidden>
            <div class="field search">
                <label for="roster-q">Find a learner</label>
                <input id="roster-q" type="search" placeholder="Type a name" data-roster-search autocomplete="off">
            </div>
            <div class="field">
                <label for="roster-show">Show</label>
                <select id="roster-show" data-roster-show>
                    <option value="all">All learners</option>
                    <option value="help">Need your help ({{ $needCount }})</option>
                    <option value="unplayed">Haven't played yet ({{ $notPlayed }})</option>
                    <option value="noconsent">Consent form missing ({{ $noConsent }})</option>
                    <optgroup label="On the map">
                        @foreach ($stats->levels as $level => $n)
                            <option value="level:{{ $level }}">L{{ $level }} · {{ SkillCatalog::level($level)['world'] }} ({{ $n }})</option>
                        @endforeach
                    </optgroup>
                    <optgroup label="Needs help in">
                        @foreach ($skills as $skill)
                            <option value="skill:{{ $skill }}">{{ SkillCatalog::label($skill) }} ({{ $stats->skillStates[$skill]['help'] }})</option>
                        @endforeach
                    </optgroup>
                </select>
            </div>
            <div class="field">
                <label for="roster-sort">Sort by</label>
                <select id="roster-sort" data-roster-sort>
                    <option value="name">Name (A to Z)</option>
                    <option value="need">Needs help first</option>
                    <option value="level">Map level (lowest first)</option>
                    <option value="last">Last played (longest ago first)</option>
                </select>
            </div>
            <p class="toolbar-count" data-roster-count aria-live="polite"></p>
        </div>

        <div class="table-wrap">
            <table class="roster table-cards" data-roster>
                <caption class="sr-only">Learners in {{ $section->name }}, with each sub-skill's state at the level they are working on</caption>
                <thead>
                <tr>
                    <th scope="col">Learner</th>
                    <th scope="col">Map level</th>
                    @foreach ($skills as $skill)
                        <th scope="col" class="skill-col">{{ SkillCatalog::label($skill) }}</th>
                    @endforeach
                    <th scope="col">Last played</th>
                    <th scope="col">Consent</th>
                    <th scope="col"><span class="sr-only">Report</span></th>
                </tr>
                </thead>
                <tbody>
                @foreach ($stats->students as $student)
                    @php($last = $stats->lastActivity[$student->id] ?? null)
                    @php($states = $stats->states[$student->id])
                    @php($name = $student->displayName())
                    @php($level = SectionStats::highest($student))
                    <tr data-name="{{ mb_strtolower($name) }}" data-level="{{ $level }}" data-help="{{ $stats->needsHelpNow($student) ? 1 : 0 }}"
                        data-played="{{ $last ? 1 : 0 }}" data-consent="{{ $student->consent_recorded_at ? 1 : 0 }}"
                        data-last="{{ $last ? \Carbon\CarbonImmutable::parse($last)->getTimestamp() : 0 }}" data-severity="{{ $stats->severity[$student->id] ?? 0 }}"
                        data-help-skills="{{ collect($states)->filter(fn ($s) => $s['key'] === 'help')->keys()->join(' ') }}">
                        <td data-label="">
                            <a class="learner" href="{{ route('teacher.students.show', $student) }}">{{ $name }}</a>
                            <div class="id">Student ID {{ $student->code }} · not the login code</div>
                            @if ($student->open_flags_count > 0)
                                <span class="badge badge-red" style="margin-top: .3rem;">{{ $student->open_flags_count }} open {{ Str::plural('flag', $student->open_flags_count) }}</span>
                            @endif
                        </td>
                        <td data-label="Map level" class="level-cell"><div><strong>L{{ $level }}</strong> {{ SkillCatalog::level($level)['world'] }}<div class="muted xsmall">{{ SectionStats::band($student) }}</div></div></td>
                        @foreach ($skills as $skill)
                            @php($s = $states[$skill])
                            <td data-label="{{ SkillCatalog::label($skill) }}">
                                @if ($s['key'] === 'locked')
                                    <span class="state state-locked">Not yet<span class="sr-only"> reached</span></span>
                                @else
                                    <span class="state state-{{ $s['key'] }}">{{ $short[$s['key']] }} <span class="lvl">L{{ $s['level'] }}</span></span>
                                @endif
                            </td>
                        @endforeach
                        <td data-label="Last played" class="small nowrap">{{ $last ? \Carbon\CarbonImmutable::parse($last)->diffForHumans() : 'Not yet' }}</td>
                        <td data-label="Consent">
                            @if ($student->consent_recorded_at)
                                <span class="badge badge-green">On file</span>
                            @else
                                <form method="POST" action="{{ route('teacher.students.consent', $student) }}">
                                    @csrf
                                    <input type="hidden" name="consent" value="1">
                                    <button class="btn btn-secondary btn-sm" type="submit">Record<span class="sr-only"> consent for {{ $name }}</span></button>
                                </form>
                            @endif
                        </td>
                        <td data-label="">
                            <a class="btn btn-quiet btn-sm" href="{{ route('teacher.students.report', $student) }}">Report<span class="sr-only"> for {{ $name }}</span></a>
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
    @endif
</section>
@endsection
