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
    $activeRows = collect($stats->activeRows());
    $betterRows = collect($stats->betterRows());
    $betterIds = $stats->betterFlagIds();
    $lastSync = $stats->lastSectionSync();
    $skills = SkillCatalog::skills();
    $maxAtLevel = max(1, max($stats->levels ?: [0]));
    $stateOrder = ['got', 'slip', 'prac', 'help', 'new', 'locked'];
    $short = ['got' => 'Got it', 'slip' => 'Slipping', 'prac' => 'Practising', 'help' => 'Needs help', 'new' => 'Not started', 'locked' => 'Not reached'];
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
{{-- data-sync: after an in-place action, portal.js copies these parts from the fresh page (D-039). --}}
<ul class="summary" aria-label="Class summary" style="margin: var(--s2) 0 0;" data-sync="summary">
    <li><span class="n">{{ $count }}</span> {{ Str::plural('learner', $count) }}</li>
    @if ($count > 0)
        <li><a href="#needs-help"><span class="n">{{ $needCount }}</span> {{ $needCount === 1 ? 'needs' : 'need' }} your help</a></li>
        @if ($notPlayed > 0)
            <li><a href="#learners" data-roster-filter="unplayed"><span class="n">{{ $notPlayed }}</span> {{ $notPlayed === 1 ? "hasn't" : "haven't" }} played yet</a></li>
        @endif
        <li><a href="#learners" data-roster-filter="noconsent"><span class="n">{{ $consented }}</span> of {{ $count }} consent forms in</a></li>
    @endif
</ul>
@if ($count > 0)
    {{-- How fresh the numbers are, from the server's own clock (D-037). --}}
    <p class="freshness" style="margin-bottom: var(--s5);" data-sync="freshness">
        @if ($lastSync) Tablets last synced @include('partials.when', ['at' => $lastSync]). @else No tablet has synced yet. @endif
        Page updated {{ now()->setTimezone($tz)->format('g:i A') }}.
    </p>
@else
    <div style="margin-bottom: var(--s5);"></div>
@endif

@if ($count > 0)
<nav class="local-nav" aria-label="On this page">
    <ul>
        <li><a href="#needs-help">Needs <span class="wide-only">your </span>help <span class="count" data-sync="nav-need">{{ $needCount }}</span></a></li>
        <li><a href="#progress"><span class="wide-only">Class progress</span><span class="phone-only">Progress</span></a></li>
        <li><a href="#learners">Learners <span class="count" data-roster-navcount>{{ $count }}</span></a></li>
    </ul>
</nav>

{{-- 1. Who needs help today (FR-17): one row per child, most urgent first; then the flags that look better, to check and close. --}}
<section id="needs-help" class="panel" aria-labelledby="needs-title">
    <div class="panel-head">
        <div>
            <h2 id="needs-title">Needs your help <span class="muted" data-sync="need-title">({{ $needCount }})</span></h2>
            <p class="muted small">Most urgent first. Open a child to see which skill to practise with them.</p>
        </div>
        <ul class="legend" aria-label="Flag types">
            @foreach (SectionStats::FLAG_STYLES as [$badge, $color, $label])
                <li><span class="flag-dot" style="background: {{ $color }}" aria-hidden="true"></span>{{ $label }}</li>
            @endforeach
        </ul>
    </div>

    @if ($activeRows->isEmpty())
        <div class="empty">
            <div>
                <p class="big">Nobody needs extra help right now.</p>
                <p class="muted small">A child shows up here when a skill stays under 30% after 5 answers, or when Racoon's Rescue doesn't go well.</p>
            </div>
        </div>
    @else
        <ol class="need-list">
            @foreach ($activeRows as $row)
                @include('teacher.partials.need-row', ['row' => $row, 'anchor' => 'needs-help'])
            @endforeach
        </ol>
    @endif

    @if ($betterRows->isNotEmpty())
        <div data-inline-scope>
        <div class="group-head" data-sync="better-head">
            <div>
                <h3>Looks better: check and close <span class="muted">({{ $betterRows->count() }} {{ Str::plural('child', $betterRows->count()) }})</span></h3>
                <p class="muted small" style="margin: .2rem 0 0;">These children have since done well on the flagged skill. Check with them, then close the flags.</p>
            </div>
            <form method="POST" action="{{ route('teacher.flags.resolve-many') }}" data-inline
                  data-confirm="Close {{ count($betterIds) }} {{ Str::plural('flag', count($betterIds)) }} for {{ $betterRows->count() }} {{ Str::plural('child', $betterRows->count()) }} who look better? You can undo this right after.">
                @csrf
                <input type="hidden" name="anchor" value="needs-help">
                @foreach ($betterIds as $id)
                    <input type="hidden" name="ids[]" value="{{ $id }}">
                @endforeach
                <button class="btn btn-secondary btn-sm" type="submit">{{ count($betterIds) === 1 ? 'Close 1 flag' : 'Close all '.count($betterIds).' flags' }}</button>
            </form>
        </div>
        {{-- The id sits on the <details>, so returning to #looks-better after a reload opens it again. --}}
        <details class="disclosure" id="looks-better" @if ($activeRows->isEmpty()) open @endif>
            <summary><span class="when-closed">Show the {{ $betterRows->count() }} {{ Str::plural('child', $betterRows->count()) }}</span><span class="when-open">Hide them</span></summary>
            <ol class="need-list disclosure-body">
                @foreach ($betterRows as $row)
                    @include('teacher.partials.need-row', ['row' => $row, 'anchor' => 'looks-better'])
                @endforeach
            </ol>
        </details>
        </div>
    @endif

    <details class="disclosure">
        <summary>What do these mean?</summary>
        <dl class="disclosure-body small measure">
            @foreach (SectionStats::FLAG_STYLES as $type => [$badge, $color, $label])
                <dt><span class="badge {{ $badge }}"><span class="flag-dot" style="background: {{ $color }}" aria-hidden="true"></span>{{ $label }}</span></dt>
                <dd class="muted" style="margin: .3rem 0 .8rem;">{{ SectionStats::FLAG_HELP[$type] }}</dd>
            @endforeach
            <dt><span class="better">Looks better now</span></dt>
            <dd class="muted" style="margin: .3rem 0 .8rem;">The child has since mastered that skill-level, or their mastery climbed back to 50% or more. Flags never close by themselves: you decide.</dd>
            <dt><strong>Mark resolved</strong></dt>
            <dd class="muted" style="margin: .3rem 0 0;">Only clears the flag from your list. It changes nothing in the child's game, and you can undo it right after.</dd>
        </dl>
    </details>
</section>

{{-- 2. Class progress: the class on the reading map, then each sub-skill. --}}
<section id="progress" class="panel" aria-labelledby="progress-title">
    <div class="panel-head">
        <h2 id="progress-title">Class progress</h2>
    </div>

    <h3 id="map-title">Where the class is on the reading map</h3>
    <p class="muted small">Each learner is shown at the highest world they have unlocked. Each world is an ARAL band. Choose a world to list its learners.</p>
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
                <li><span class="swatch" style="background: var(--orange)"></span>Slipping</li>
                <li><span class="swatch" style="background: var(--prac)"></span>Practising</li>
                <li><span class="swatch" style="background: var(--help)"></span>Needs help</li>
                <li><span class="swatch" style="background: var(--line-strong)"></span>Not started</li>
                <li><span class="swatch" style="background: var(--track); box-shadow: inset 0 0 0 1px var(--line-strong)"></span>Not reached</li>
            </ul>
        </div>
        <p class="muted small">Each learner counts once per skill, at the level they are working on now. "Slipping" means mastered earlier, but the estimate has fallen under 50%.</p>
        <ul class="meters">
            @foreach ($skills as $skill)
                @php($c = $stats->skillStates[$skill])
                <li class="meter">
                    <span class="meter-name">{{ SkillCatalog::label($skill) }}</span>
                    <span class="seg" role="img" aria-label="{{ SkillCatalog::label($skill) }}: {{ $c['got'] }} got it, {{ $c['slip'] }} slipping, {{ $c['prac'] }} practising, {{ $c['help'] }} {{ $c['help'] === 1 ? 'needs' : 'need' }} help, {{ $c['new'] }} not started, {{ $c['locked'] }} not reached">
                        @foreach ($stateOrder as $key)
                            @if ($c[$key] > 0)<span class="s-{{ $key }}" style="flex: {{ $c[$key] }}"></span>@endif
                        @endforeach
                    </span>
                    <span class="meter-figs">
                        <span><strong>{{ $c['got'] }}</strong> got it</span>
                        @if ($c['slip'] > 0)<span class="sep" aria-hidden="true">·</span><span>{{ $c['slip'] }} slipping</span>@endif
                        <span class="sep" aria-hidden="true">·</span><span>{{ $c['prac'] }} practising</span>
                        <span class="sep" aria-hidden="true">·</span>
                        @if ($c['help'] > 0)
                            <a href="#learners" data-roster-filter="skill:{{ $skill }}">{{ $c['help'] }} {{ $c['help'] === 1 ? 'needs' : 'need' }} help</a>
                        @else
                            <span>0 need help</span>
                        @endif
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
            @if ($count > 0)
                <p class="muted small">Student IDs (RR-...) are for reports, not login codes. Lost a login card? Open the learner and choose <strong>New login code</strong>.</p>
            @endif
        </div>
    </div>

    @if ($count === 0)
        <div class="empty" style="margin-bottom: var(--s4);">
            <div>
                <p class="big">Your first day with {{ $section->name }}</p>
                <ol class="checklist small">
                    <li><strong>Add your learners</strong> below: first names or nicknames, one per line.</li>
                    <li><strong>Print their login cards</strong> right away: each code is shown only once.</li>
                    <li><strong>Check the <a href="{{ route('teacher.schedule.edit', $section) }}">play schedule</a></strong>: when the game opens for class, after school and at bedtime.</li>
                    <li><strong>Record each parental consent form</strong> once it is signed (RA 10173).</li>
                </ol>
            </div>
        </div>
    @endif

    <details class="disclosure" id="add-learners" style="margin-top: 0; margin-bottom: var(--s4);" @if ($count === 0 || $errors->has('names') || $errors->has('name')) open @endif>
        <summary>Add learners</summary>
        <form method="POST" action="{{ route('teacher.students.store', $section) }}" class="add-learners disclosure-body">
            @csrf
            <label for="new-names" style="margin-top: 0;">First names or nicknames, one per line</label>
            <textarea id="new-names" name="names" rows="4" required autocapitalize="words" spellcheck="false" placeholder="One name per line" aria-describedby="names-hint @error('names') names-error @enderror" @error('names') aria-invalid="true" @enderror>{{ old('names') }}</textarea>
            <p class="hint" id="names-hint">Up to {{ \App\Http\Controllers\Teacher\RosterController::MAX_NAMES }} at once. A first name or nickname only (RA 10173); reports and exports use the student ID instead. Each child gets a login card to print.</p>
            @include('partials.field-error', ['field' => 'names'])
            <div class="form-actions" style="margin-top: var(--s3);"><button class="btn" type="submit" data-busy-label="Adding and making cards…">Add and make login cards</button></div>
        </form>
    </details>

    @if ($count > 0)
        <div class="toolbar" data-roster-toolbar hidden>
            <div class="field search">
                <label for="roster-q">Find a learner</label>
                <input id="roster-q" type="search" placeholder="Type a name" data-roster-search autocomplete="off">
            </div>
            <div class="field">
                <label for="roster-show">Show</label>
                <select id="roster-show" data-roster-show data-sync="roster-show">
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
                    <option value="last">Activity (playing now first)</option>
                </select>
            </div>
            <button class="btn btn-quiet btn-sm" type="button" data-roster-clear hidden>Clear filters</button>
            <p class="toolbar-count" data-roster-count aria-live="polite"></p>
        </div>

        <div class="no-match" data-roster-empty hidden>
            <p><strong>No learners match.</strong> <span class="muted">Try another name, or show everyone.</span></p>
            <button class="btn btn-secondary btn-sm" type="button" data-roster-clear>Show all learners</button>
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
                    <th scope="col">Activity</th>
                    <th scope="col">Consent</th>
                </tr>
                </thead>
                <tbody>
                @foreach ($stats->students as $student)
                    @php($last = $stats->lastActivity[$student->id] ?? null)
                    @php($states = $stats->states[$student->id])
                    @php($name = $student->displayName())
                    @php($level = SectionStats::highest($student))
                    @php($flagCount = $stats->flagCounts[$student->id] ?? ['active' => 0, 'better' => 0])
                    @php($complete = str_ends_with(SectionStats::band($student), '(complete)'))
                    @php($byState = collect($states)->reject(fn ($s) => $s['key'] === 'locked')->groupBy('key', true)->map->keys())
                    <tr data-sync="learner-{{ $student->id }}" data-name="{{ mb_strtolower($name) }}" data-level="{{ $level }}" data-help="{{ $stats->needsHelpNow($student) ? 1 : 0 }}"
                        data-played="{{ $last ? 1 : 0 }}" data-consent="{{ $student->consent_recorded_at ? 1 : 0 }}"
                        data-last="{{ isset($stats->activeNow[$student->id]) ? now()->getTimestamp() : ($last ? \Carbon\CarbonImmutable::parse($last)->getTimestamp() : 0) }}" data-severity="{{ $stats->severity[$student->id] ?? 0 }}"
                        data-help-skills="{{ ($byState['help'] ?? collect())->join(' ') }}">
                        <td data-label="" class="learner-cell">
                            <a class="learner" href="{{ route('teacher.students.show', $student) }}">{{ $name }}</a>
                            <div class="id">Student ID {{ $student->code }}</div>
                            @if ($flagCount['active'] > 0)
                                <span class="badge badge-red">{{ $flagCount['active'] }} open {{ Str::plural('flag', $flagCount['active']) }}</span>
                            @elseif ($flagCount['better'] > 0)
                                <span class="badge badge-amber">{{ $flagCount['better'] }} to check and close</span>
                            @endif
                            <div class="row-links wide-only"><a href="{{ route('teacher.students.report', $student) }}">Report<span class="sr-only"> for {{ $name }}</span></a></div>
                        </td>
                        <td data-label="Map level" class="level-cell"><div><strong>L{{ $level }}</strong> {{ SkillCatalog::level($level)['world'] }}<div class="muted xsmall">{{ SkillCatalog::level($level)['band'] }}{{ $complete ? ' (complete)' : '' }}</div></div></td>
                        @foreach ($skills as $skill)
                            @php($s = $states[$skill])
                            @php($max = SkillCatalog::maxLevel($skill))
                            <td data-label="{{ SkillCatalog::label($skill) }}" class="skill-cell">
                                @if ($s['key'] === 'locked')
                                    <span class="state state-locked">Not reached</span>
                                @elseif ($s['key'] === 'got' && $s['level'] === $max)
                                    <span class="state state-got">Got it <span class="lvl">all</span><span class="sr-only"> levels</span></span>
                                @else
                                    <span class="state state-{{ $s['key'] }}">{{ $short[$s['key']] }} <span class="lvl" aria-hidden="true">L{{ $s['level'] }}/{{ $max }}</span><span class="sr-only"> level {{ $s['level'] }} of {{ $max }}</span></span>
                                @endif
                            </td>
                        @endforeach
                        <td data-label="Activity" class="small nowrap activity-cell">@if (isset($stats->activeNow[$student->id]))<span class="active-now">Active now</span>@elseif ($last) Played @include('partials.when', ['at' => $last]) @else Never played @endif</td>
                        <td data-label="Consent" @class(['consent-cell', 'is-on-file' => $student->consent_recorded_at])>
                            @if ($student->consent_recorded_at)
                                <span class="badge badge-green">On file</span>
                            @else
                                <div class="consent-missing" data-inline-scope>
                                    <span class="phone-only small">Consent form missing</span>
                                    <form method="POST" action="{{ route('teacher.students.consent', $student) }}" data-inline data-done-label="Consent on file">
                                        @csrf
                                        <input type="hidden" name="consent" value="1">
                                        <button class="btn btn-secondary btn-sm" type="submit">Record<span class="sr-only"> consent for {{ $name }}</span></button>
                                    </form>
                                </div>
                            @endif
                        </td>
                        {{-- Phones (D-039): the skill columns fold into these lines; last, so hiding it on wide screens moves no column. --}}
                        <td data-label="" class="phone-sum">
                            <p>L{{ $level }} {{ SkillCatalog::level($level)['world'] }} · {{ count($byState['got'] ?? []) }} got it @if (isset($byState['prac'])) · {{ count($byState['prac']) }} practising @endif @if (isset($byState['new'])) · {{ count($byState['new']) }} not started @endif</p>
                            @foreach (['help' => 'Needs help', 'slip' => 'Slipping'] as $key => $label)
                                @if (isset($byState[$key]))
                                    <p><span class="state state-{{ $key }}">{{ $label }}</span> {{ $byState[$key]->map(fn ($skill) => SkillCatalog::label($skill))->join(', ') }}</p>
                                @endif
                            @endforeach
                            <p class="row-links"><a href="{{ route('teacher.students.report', $student) }}">Report<span class="sr-only"> for {{ $name }}</span></a></p>
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
    @endif
</section>
@endsection
