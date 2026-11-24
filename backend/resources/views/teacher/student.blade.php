@extends('layouts.app')
@section('title', $student->displayName().' · '.$student->section->name)

@php
    use App\Support\SectionStats;
    use App\Support\SkillCatalog;
    use App\Support\SkillHistory;
    $name = $student->displayName();
    $fmt = fn ($t) => $t->setTimezone($timezone)->format('M j, Y g:i A');
    $highest = SectionStats::highest($student);
    $openFlags = $flags->where('status', 'open')->map(fn ($f) => SectionStats::flagRow($student, $f));
    $flagGroups = SectionStats::bySkill($openFlags->values()->all());
    $skillStates = collect(SkillCatalog::skills())->mapWithKeys(fn ($skill) => [$skill => SectionStats::skillState($student, $skill)]);
    $locked = $skillStates->filter(fn ($s) => $s['key'] === 'locked');
    $pastFlags = $flags->where('status', '!=', 'open');
    $mastered = $states->whereNotNull('mastered_at')->count();
    // Lessons and Racoon's Rescue outcomes, newest first. (Keep every @php block above
    // the inline @php(...) calls: Blade would otherwise merge them into one block.)
    $sessions = collect($replay->lessons)->map(fn ($l) => ['kind' => 'lesson'] + $l)
        ->merge(collect($replay->rescues)->map(fn ($r) => ['kind' => 'rescue'] + $r))
        ->sortByDesc(fn ($r) => $r['time']->getTimestamp())->take(40)->values();
    $chevron = fn (string $d) => '<svg viewBox="0 0 16 16" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="'.$d.'"/></svg>';
@endphp

@section('content')
@include('teacher.partials.login-cards', ['sectionName' => $student->section->name])

<nav class="crumbs" aria-label="Breadcrumb">
    <ol>
        <li><a href="{{ route('teacher.sections.show', $student->section) }}">{{ $student->section->name }}</a></li>
        <li aria-current="page">{{ $name }}</li>
    </ol>
</nav>

<div class="page-head">
    <div>
        <h1>{{ $name }}</h1>
        <p class="meta">Student ID {{ $student->code }} (for reports, not the login code) · {{ $band }}</p>
        <dl class="facts">
            <div><dt>Map level</dt><dd>L{{ $highest }} <small>{{ SkillCatalog::level($highest)['world'] }}</small></dd></div>
            <div><dt>Skill-levels mastered</dt><dd>{{ $mastered }} <small>of {{ $states->count() }}</small></dd></div>
            <div><dt>Right answers</dt><dd>@if ($replay->responses){{ round(100 * $replay->correctResponses / $replay->responses) }}% <small>of {{ $replay->responses }} {{ Str::plural('answer', $replay->responses) }}</small>@else<small>No answers yet</small>@endif</dd></div>
            <div><dt>Lessons played</dt><dd>{{ count($replay->lessons) }}</dd></div>
            <div><dt>Last played</dt><dd>@if ($lastPlayed) @include('partials.when', ['at' => $lastPlayed]) @else <small>Never</small> @endif</dd></div>
            <div><dt>Last synced</dt><dd>@if ($lastSynced) @include('partials.when', ['at' => $lastSynced]) @else <small>Never</small> @endif</dd></div>
            <div><dt>Rewards</dt><dd>{{ $student->wallet?->xp ?? 0 }} <small>XP · {{ $student->wallet?->coins ?? 0 }} coins</small></dd></div>
        </dl>
    </div>
    <div class="actions">
        <a class="btn" href="{{ route('teacher.students.report', $student) }}">Diagnostic report</a>
        <a class="btn btn-secondary" href="{{ route('teacher.students.report.pdf', $student) }}">Download PDF</a>
    </div>
</div>

@if ($previous || $next)
    <nav class="row" aria-label="Other learners" style="margin: calc(-1 * var(--s3)) 0 var(--s4); justify-content: space-between;">
        @if ($previous)
            <a class="btn btn-quiet btn-sm" href="{{ route('teacher.students.show', $previous) }}" rel="prev">{!! $chevron('M10 3 5 8l5 5') !!}<span><span class="sr-only">Previous learner: </span>{{ $previous->displayName() }}</span></a>
        @else
            <span></span>
        @endif
        @if ($next)
            <a class="btn btn-quiet btn-sm" href="{{ route('teacher.students.show', $next) }}" rel="next"><span><span class="sr-only">Next learner: </span>{{ $next->displayName() }}</span>{!! $chevron('m6 3 5 5-5 5') !!}</a>
        @endif
    </nav>
@endif

@if (! $lastSynced)
    <div class="alert alert-warn">
        <p><strong>{{ $name }} hasn't played yet</strong>, or their tablet hasn't synced. Check that {{ $name }} has a login card, and that the tablet has been online since they played.</p>
    </div>
@endif

@if ($openFlags->isNotEmpty())
    <section class="panel" id="flags" aria-labelledby="flags-title">
        <div class="panel-head">
            <div>
                <h2 id="flags-title">Needs your help</h2>
                <p class="muted small">Practise these with {{ $name }}. Mark a flag resolved once you have checked in; you can undo it.</p>
            </div>
        </div>
        <ul class="flags">
            @foreach ($flagGroups as $g)
                @include('teacher.partials.flag', ['g' => $g, 'name' => $name, 'anchor' => 'flags'])
            @endforeach
        </ul>
        <details class="disclosure">
            <summary>What do these mean?</summary>
            <ul class="disclosure-body small measure" style="padding-left: 1.1rem;">
                @foreach ($openFlags->unique(fn ($f) => $f['flag']->type) as $f)
                    <li><strong>{{ $f['label'] }}:</strong> {{ $f['help'] }}</li>
                @endforeach
                @if ($openFlags->contains('better', true))
                    <li><strong>Looks better now:</strong> since the flag, {{ $name }} mastered that skill-level or climbed back to 50% or more.</li>
                @endif
                <li><strong>Mark resolved</strong> only clears the flag from your list; nothing changes in the game.</li>
            </ul>
        </details>
    </section>
@endif

{{-- Skills: plain state first, the game's estimate and its history on demand (D-037). --}}
<section class="panel" id="skills" aria-labelledby="chart-title">
    <div class="panel-head">
        <div>
            <h2 id="chart-title">Mastery over time</h2>
            <p class="muted small measure">For each sub-skill: where {{ $name }} is now, and the game's estimate of mastery after each answer, oldest on the left. The dashed green line is "Got it" (95% after at least 5 answers at a level). "Slipping" means mastered earlier, but the estimate has fallen under 50%.</p>
        </div>
    </div>
    <ul class="skills" id="skill-history">
        @foreach ($skillStates->reject(fn ($s) => $s['key'] === 'locked') as $skill => $s)
            @php($h = $histories[$skill] ?? null)
            @php($label = SkillCatalog::label($skill))
            <li class="skill-card">
                <div class="top">
                    <h3>{{ $label }}</h3>
                    @php($max = SkillCatalog::maxLevel($skill))
                    <span class="state state-{{ $s['key'] }}">{{ $s['label'] }} <span class="lvl">{{ $s['key'] === 'got' && $s['level'] === $max ? 'all levels' : 'level '.$s['level'].' of '.$max }}</span></span>
                </div>
                @if ($s['attempts'] > 0 || in_array($s['key'], ['got', 'slip'], true))
                    <p class="estimate">Mastery estimate {{ round($s['p'] * 100) }}% at level {{ $s['level'] }}{{ $s['review'] ? ' (review after a rescue)' : '' }} · {{ $h['n'] ?? 0 }} {{ Str::plural('answer', $h['n'] ?? 0) }} in all</p>
                @elseif ($s['review'])
                    <p class="estimate">Back at level {{ $s['level'] }} to review after a rescue; no answers yet.</p>
                @endif
                @if ($h)
                    <svg class="history" viewBox="0 0 {{ SkillHistory::WIDTH }} {{ SkillHistory::HEIGHT }}" role="img"
                         aria-label="{{ $label }}: mastery estimate over {{ $h['n'] }} answers, from {{ $h['first'] }}% to {{ $h['end']['p'] }}%.">
                        <line class="grid-line" x1="4" x2="{{ SkillHistory::WIDTH - 40 }}" y1="{{ SkillHistory::HEIGHT - 6 }}" y2="{{ SkillHistory::HEIGHT - 6 }}"/>
                        <line class="goal" x1="4" x2="{{ SkillHistory::WIDTH - 40 }}" y1="{{ $h['goal'] }}" y2="{{ $h['goal'] }}"/>
                        <text class="goal-label" x="{{ SkillHistory::WIDTH - 4 }}" y="{{ $h['goal'] - 3 }}" text-anchor="end">Got it</text>
                        @foreach ($h['levels'] as $i => $lvl)
                            @if ($i > 0)<line class="lvl-line" x1="{{ $lvl['x'] }}" x2="{{ $lvl['x'] }}" y1="12" y2="{{ SkillHistory::HEIGHT - 6 }}"/>@endif
                            <text x="{{ $lvl['x'] + ($i > 0 ? 3 : 0) }}" y="10">L{{ $lvl['level'] }}</text>
                        @endforeach
                        <path class="area" d="{{ $h['area'] }}"/>
                        <path class="line" d="{{ $h['line'] }}"/>
                        <circle class="end" cx="{{ $h['end']['x'] }}" cy="{{ $h['end']['y'] }}" r="4"/>
                        <text class="end-label" x="{{ $h['end']['x'] + 7 }}" y="{{ abs($h['end']['y'] - $h['goal']) < 12 ? $h['end']['y'] + 15 : min(SkillHistory::HEIGHT - 4, max(12, $h['end']['y'] + 4)) }}">{{ $h['end']['p'] }}%</text>
                    </svg>
                @else
                    <p class="muted small" style="margin: var(--s2) 0;">No answers yet.</p>
                @endif
            </li>
        @endforeach
    </ul>
    @if ($locked->isNotEmpty())
        <p class="locked-line">Not reached yet: {{ $locked->keys()->map(fn ($skill) => SkillCatalog::label($skill).' (opens at map level '.SkillCatalog::minLevel($skill).')')->join(', ') }}.</p>
    @endif

    <details class="disclosure">
        <summary>All {{ $states->count() }} skill-levels, with the numbers</summary>
        <div class="disclosure-body table-wrap">
            <table class="compact">
                <thead><tr><th>Sub-skill</th><th>Level</th><th class="num">P(L)</th><th class="num">Answers</th><th>State</th></tr></thead>
                <tbody>
                @foreach ($states as $state)
                    <tr>
                        <td>{{ SkillCatalog::label($state->sub_skill) }}</td>
                        <td>L{{ $state->level }}</td>
                        <td class="num">{{ $state->attempts > 0 || $state->mastered_at ? round($state->p_mastery * 100).'%' : '-' }}</td>
                        <td class="num">{{ $state->attempts }}</td>
                        <td>
                            @if ($state->mastered_at)
                                <span class="state state-got">Got it</span>
                            @elseif ($state->review)
                                <span class="state state-prac">Review</span>
                            @elseif ($state->p_mastery < config('reading_racoon.bkt.hint_p') && $state->attempts >= config('reading_racoon.bkt.mastery_min_attempts'))
                                <span class="state state-help">Needs help</span>
                            @elseif ($state->attempts > 0)
                                <span class="state state-prac">Practising</span>
                            @else
                                <span class="muted small">Not started</span>
                            @endif
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
    </details>
</section>

<div class="grid grid-2 grid-gap-bottom">
    <section class="panel" aria-labelledby="sessions-title">
        <h2 id="sessions-title">Recent lessons</h2>
        @if ($sessions->isEmpty())
            <p class="muted">No lessons synced yet.</p>
        @else
            <div class="table-wrap">
                <table class="compact table-cards">
                    <thead><tr><th>When</th><th>What</th><th>Result</th></tr></thead>
                    <tbody>
                    @foreach ($sessions as $i => $row)
                        <tr @if ($i >= 8) data-more hidden @endif>
                            <td data-label="When" class="nowrap">{{ $row['time']->setTimezone($timezone)->format('M j, g:i A') }}</td>
                            @if ($row['kind'] === 'lesson')
                                <td data-label="What">Lesson {{ $row['node'] + 1 }} · L{{ $row['level'] }} {{ SkillCatalog::level($row['level'])['world'] }}</td>
                                <td data-label="Result">
                                    {{ $row['correct'] }}/{{ $row['total'] }} correct · <span aria-label="{{ $row['stars'] }} of 3 stars">{{ $row['stars'] }}/3 stars</span>
                                    @if ($row['level_up']) <span class="badge badge-green">Level up</span> @endif
                                </td>
                            @else
                                <td data-label="What">Racoon's Rescue · {{ SkillCatalog::label($row['skill']) }} L{{ $row['from_level'] }}</td>
                                <td data-label="Result">
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
            @if ($sessions->count() > 8)
                <p style="margin: var(--s3) 0 0;"><button class="btn btn-quiet btn-sm" type="button" data-show-more>Show all {{ $sessions->count() }}</button></p>
            @endif
        @endif
    </section>

    <section class="panel" aria-labelledby="usage-title">
        <h2 id="usage-title">Play time after school</h2>
        <p class="muted small">Last 14 days, outside reading class.</p>
        @if ($usage->isEmpty())
            <p class="muted">No play time synced yet.</p>
        @else
            <table class="compact">
                <thead><tr><th>Date</th><th class="num">Minutes</th></tr></thead>
                <tbody>
                @foreach ($usage as $day)
                    <tr><td>{{ $day->date->format('D, M j') }}</td><td class="num">{{ $day->minutes }} min</td></tr>
                @endforeach
                </tbody>
            </table>
        @endif

        @if ($pastFlags->isNotEmpty())
            <details class="disclosure">
                <summary>Resolved flags ({{ $pastFlags->count() }})</summary>
                <ul class="disclosure-body small" style="list-style: none; padding: 0; margin-bottom: 0;">
                    @foreach ($pastFlags as $flag)
                        @php([$badge, $color, $label] = SectionStats::FLAG_STYLES[$flag->type] ?? ['badge', '#6b6b78', ucfirst(str_replace('_', ' ', $flag->type))])
                        <li style="margin-bottom: .35rem;">{{ $label }}{{ $flag->sub_skill ? ': '.SkillCatalog::label($flag->sub_skill) : '' }}{{ $flag->level ? ' L'.$flag->level : '' }} · <span class="muted">raised {{ $fmt($flag->raised_at) }}</span></li>
                    @endforeach
                </ul>
            </details>
        @endif
    </section>
</div>

{{-- Rare and risky actions live here, not on the class page (FR-16, RA 10173). --}}
<section class="panel" id="manage" aria-labelledby="manage-title">
    <h2 id="manage-title">Manage {{ $name }}</h2>
    <div class="grid grid-2" style="gap: var(--s5);">
        <div>
            <h3>Parental consent</h3>
            @if ($student->consent_recorded_at)
                <p><span class="badge badge-green">On file</span> <span class="muted small">since {{ $student->consent_recorded_at->setTimezone($timezone)->format('M j, Y') }}</span></p>
                <form method="POST" action="{{ route('teacher.students.consent', $student) }}"
                      data-confirm="Clear {{ $name }}'s consent record? {{ $name }} will be left out of research exports and AI reports until it is recorded again.">
                    @csrf
                    <input type="hidden" name="consent" value="0">
                    <button class="btn btn-danger-outline btn-sm" type="submit">Clear consent</button>
                </form>
            @else
                <p class="small"><span class="badge badge-amber">Missing</span> Record it once the signed form is in your hands.</p>
                <form method="POST" action="{{ route('teacher.students.consent', $student) }}">
                    @csrf
                    <input type="hidden" name="consent" value="1">
                    <button class="btn btn-sm" type="submit">Record consent</button>
                </form>
            @endif
        </div>
        <div>
            <h3>Login code</h3>
            <p class="small muted">Lost the card? A new code replaces the old one at once, and its card is shown once to print.</p>
            <form method="POST" action="{{ route('teacher.students.code', $student) }}" data-confirm="Give {{ $name }} a new login code? The old code stops working.">
                @csrf
                <button class="btn btn-secondary btn-sm" type="submit">New login code</button>
            </form>
        </div>
        <div>
            <h3>Remove from the section</h3>
            <p class="small muted">Deletes {{ $name }} and all of their reading data. This cannot be undone.</p>
            <form method="POST" action="{{ route('teacher.students.destroy', $student) }}" data-confirm="Remove {{ $name }} and delete all their reading data? This cannot be undone.">
                @csrf
                @method('DELETE')
                <button class="btn btn-danger-outline btn-sm" type="submit">Remove {{ $name }}</button>
            </form>
        </div>
    </div>
</section>
@endsection
