@extends('layouts.app')
@section('title', 'Play schedule · '.$section->name)

@php
    // The saved day as a strip (FR-12, D-014): asleep, awake, reading class, after school.
    $min = function (?string $hm) {
        if (! $hm || ! str_contains($hm, ':')) {
            return null;
        }
        [$h, $m] = array_map('intval', explode(':', $hm));

        return $h * 60 + $m;
    };
    $span = function ($from, $to) {
        if ($from === null || $to === null || $to <= $from) {
            return null;
        }

        return ['left' => round(100 * $from / 1440, 2), 'width' => round(100 * ($to - $from) / 1440, 2)];
    };
    $awake = $span($min($schedule->hm('day_start')), $min($schedule->hm('day_end')));
    $class = $span($min($schedule->hm('class_start')), $min($schedule->hm('class_end')));
    $after = $span($min($schedule->hm('after_school_start')), $min($schedule->hm('after_school_end')));
    $field = function (string $name) use ($errors) {
        return $errors->has($name) ? 'aria-invalid=true aria-describedby='.$name.'-error' : '';
    };
@endphp

@section('content')
<nav class="crumbs" aria-label="Breadcrumb">
    <ol>
        <li><a href="{{ route('teacher.sections.show', $section) }}">{{ $section->name }}</a></li>
        <li aria-current="page">Play schedule</li>
    </ol>
</nav>
<div class="page-head">
    <div>
        <h1>Play schedule</h1>
        <p class="meta measure">When {{ $section->name }} can use Reading Racoon. Times are Philippine time. Tablets check this at sign-in and between screens, and show a friendly Racoon lock screen outside these times. Changes reach each tablet at its next sync.</p>
    </div>
</div>

<div class="panel" style="max-width: 46rem;">
    <h2 class="small" style="font-size: 1rem; margin-bottom: 0;">The day at a glance</h2>
    <p class="hint" style="margin-top: 0;">Follows the times below as you change them; nothing is saved until you press Save schedule.</p>
    <div class="day" data-day-strip role="img" aria-label="Awake {{ $schedule->hm('day_start') }} to {{ $schedule->hm('day_end') }}; reading class {{ $schedule->hm('class_start') }} to {{ $schedule->hm('class_end') }}; after school {{ $schedule->hm('after_school_start') }} to {{ $schedule->hm('after_school_end') }}.">
        @if ($awake)<span class="awake" style="left: {{ $awake['left'] }}%; width: {{ $awake['width'] }}%"></span>@endif
        @if ($after)<span class="after" style="left: {{ $after['left'] }}%; width: {{ $after['width'] }}%"></span>@endif
        @if ($class)<span class="class" style="left: {{ $class['left'] }}%; width: {{ $class['width'] }}%"></span>@endif
    </div>
    <div class="day-hours" aria-hidden="true"><span>12 AM</span><span>6 AM</span><span>12 PM</span><span>6 PM</span><span>12 AM</span></div>
    <ul class="legend" style="margin-top: var(--s3);">
        <li><span class="swatch" style="background: var(--primary)"></span>Reading class: full access</li>
        <li><span class="swatch" style="background: var(--prac-bg); box-shadow: inset 0 0 0 1px var(--prac)"></span>After school: daily limit</li>
        <li><span class="swatch" style="background: var(--paper-2); box-shadow: inset 0 0 0 1px var(--line-strong)"></span>Awake: free play only</li>
        <li><span class="swatch" style="background: #3b3a46"></span>Asleep: locked</li>
    </ul>

    <form method="POST" action="{{ route('teacher.schedule.update', $section) }}">
        @csrf
        @method('PUT')
        <div class="form-group">
            <h2>Reading class</h2>
            <p class="hint" style="margin-top: 0;">Full access, including the pre-test and post-test. Time in class doesn't count toward the daily limit.</p>
            <div class="field-row">
                <div><label for="class_start">Starts</label><input id="class_start" type="time" name="class_start" value="{{ old('class_start', $schedule->hm('class_start')) }}" required {!! $field('class_start') !!}>@include('partials.field-error', ['field' => 'class_start'])</div>
                <div><label for="class_end">Ends</label><input id="class_end" type="time" name="class_end" value="{{ old('class_end', $schedule->hm('class_end')) }}" required {!! $field('class_end') !!}>@include('partials.field-error', ['field' => 'class_end'])</div>
            </div>
        </div>
        <div class="form-group">
            <h2>After school</h2>
            <p class="hint" style="margin-top: 0;">Practice at home or in the library, with a countdown. During other subjects the game stays locked.</p>
            <div class="field-row">
                <div><label for="after_school_start">From</label><input id="after_school_start" type="time" name="after_school_start" value="{{ old('after_school_start', $schedule->hm('after_school_start')) }}" required {!! $field('after_school_start') !!}>@include('partials.field-error', ['field' => 'after_school_start'])</div>
                <div><label for="after_school_end">Until</label><input id="after_school_end" type="time" name="after_school_end" value="{{ old('after_school_end', $schedule->hm('after_school_end')) }}" required {!! $field('after_school_end') !!}>@include('partials.field-error', ['field' => 'after_school_end'])</div>
            </div>
            <div class="field-row">
                <div>
                    <label for="daily_minutes">Daily after-school limit (minutes)</label>
                    <input id="daily_minutes" type="number" name="daily_minutes" min="0" max="240" value="{{ old('daily_minutes', $schedule->daily_minutes) }}" required {!! $field('daily_minutes') !!}>
                    @include('partials.field-error', ['field' => 'daily_minutes'])
                </div>
                <div></div>
            </div>
            <label class="check"><input type="checkbox" name="weekends_open" value="1" @checked(old('weekends_open', $schedule->weekends_open))> Open on weekends (same daily limit)</label>
        </div>
        <div class="form-group">
            <h2>Free play</h2>
            <p class="hint" style="margin-top: 0;">Practice games, the Library and Watch &amp; Listen stay open all day. Outside reading class they share this many minutes a day.</p>
            <div class="field-row">
                <div>
                    <label for="free_play_minutes">Daily free-play limit (minutes)</label>
                    <input id="free_play_minutes" type="number" name="free_play_minutes" min="0" max="240" value="{{ old('free_play_minutes', $schedule->free_play_minutes) }}" required {!! $field('free_play_minutes') !!}>
                    @include('partials.field-error', ['field' => 'free_play_minutes'])
                </div>
                <div></div>
            </div>
        </div>
        <div class="form-group">
            <h2>Bedtime</h2>
            <p class="hint" style="margin-top: 0;">Outside these hours the whole game sleeps.</p>
            <div class="field-row">
                <div><label for="day_start">Wakes up at</label><input id="day_start" type="time" name="day_start" value="{{ old('day_start', $schedule->hm('day_start')) }}" required {!! $field('day_start') !!}>@include('partials.field-error', ['field' => 'day_start'])</div>
                <div><label for="day_end">Sleeps at</label><input id="day_end" type="time" name="day_end" value="{{ old('day_end', $schedule->hm('day_end')) }}" required {!! $field('day_end') !!}>@include('partials.field-error', ['field' => 'day_end'])</div>
            </div>
        </div>
        <div class="form-actions">
            <button class="btn" type="submit">Save schedule</button>
            <a class="btn btn-quiet" href="{{ route('teacher.sections.show', $section) }}">Cancel</a>
        </div>
    </form>
</div>
@endsection
