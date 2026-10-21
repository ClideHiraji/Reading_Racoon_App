@extends('layouts.app')
@section('title', 'Play schedule')

@section('content')
<p class="small"><a href="{{ route('teacher.sections.show', $section) }}">&larr; {{ $section->name }}</a></p>
<div class="narrow" style="max-width: 620px;">
    <div class="card">
        <h1>Play schedule</h1>
        <p class="muted">When {{ $section->name }} can use Reading Racoon. Times are {{ $timezone }} time. Tablets check this at sign-in and between screens, and show a friendly raccoon lock screen outside these windows.</p>
        <form method="POST" action="{{ route('teacher.schedule.update', $section) }}">
            @csrf
            @method('PUT')
            <h2 style="margin-top: 1rem;">Reading class</h2>
            <p class="muted small">Full access, including the pre-test and post-test. Time in class doesn't count toward the daily limit.</p>
            <div class="grid grid-2">
                <div><label for="class_start">Starts</label><input id="class_start" type="time" name="class_start" value="{{ old('class_start', $schedule->hm('class_start')) }}" required></div>
                <div><label for="class_end">Ends</label><input id="class_end" type="time" name="class_end" value="{{ old('class_end', $schedule->hm('class_end')) }}" required></div>
            </div>
            <h2 style="margin-top: 1.25rem;">After school</h2>
            <p class="muted small">Practice at home or in the library, with a countdown. During other subjects the game stays locked.</p>
            <div class="grid grid-2">
                <div><label for="after_school_start">From</label><input id="after_school_start" type="time" name="after_school_start" value="{{ old('after_school_start', $schedule->hm('after_school_start')) }}" required></div>
                <div><label for="after_school_end">Until</label><input id="after_school_end" type="time" name="after_school_end" value="{{ old('after_school_end', $schedule->hm('after_school_end')) }}" required></div>
            </div>
            <label for="daily_minutes">Daily after-school limit (minutes)</label>
            <input id="daily_minutes" type="number" name="daily_minutes" min="0" max="240" value="{{ old('daily_minutes', $schedule->daily_minutes) }}" required>
            <label class="check"><input type="checkbox" name="weekends_open" value="1" @checked(old('weekends_open', $schedule->weekends_open))> Open on weekends (same daily limit)</label>
            <p><button class="btn" type="submit">Save schedule</button></p>
        </form>
    </div>
</div>
@endsection
