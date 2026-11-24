@extends('layouts.app')
@section('title', 'My sections')

@section('content')
<div class="page-head">
    <div>
        <h1>My sections</h1>
        <p class="meta">Choose a section to see who needs help, the class's progress and its learners.</p>
    </div>
</div>

@if ($sections->isEmpty())
    <div class="panel">
        <div class="empty">
            <div>
                <p class="big">You have no sections yet.</p>
                <p class="muted small">Add your Grade 1 section below, then add its learners to make their login cards.</p>
            </div>
        </div>
    </div>
@else
    <ul class="grid grid-2 grid-gap-bottom" style="list-style: none; padding: 0; margin-top: 0;">
        @foreach ($sections as $section)
            @php($sum = $summaries[$section->id])
            <li class="panel" style="margin: 0;">
                <h2 style="margin-bottom: var(--s2);"><a href="{{ route('teacher.sections.show', $section) }}">{{ $section->name }}</a></h2>
                @if ($section->students_count === 0)
                    <p class="muted" style="margin: 0;">No learners yet: open it to add your class and print their login cards.</p>
                @else
                    <ul class="summary" style="margin-top: 0;">
                        <li><span class="n">{{ $section->students_count }}</span> {{ Str::plural('learner', $section->students_count) }}</li>
                        <li>
                            @if ($sum['need'] > 0)
                                <span class="badge badge-red">{{ $sum['need'] }} {{ $sum['need'] === 1 ? 'needs' : 'need' }} your help</span>
                            @else
                                <span class="badge badge-green">Nobody needs extra help</span>
                            @endif
                        </li>
                        @if ($sum['better'] > 0)
                            <li><span class="badge badge-amber">{{ $sum['better'] }} to check and close</span></li>
                        @endif
                    </ul>
                    <p class="freshness">@if ($sum['sync']) Tablets last synced @include('partials.when', ['at' => $sum['sync']]). @else No tablet has synced yet. @endif</p>
                @endif
                <p style="margin: var(--s4) 0 0;"><a class="btn btn-secondary btn-sm" href="{{ route('teacher.sections.show', $section) }}">Open<span class="sr-only"> {{ $section->name }}</span></a></p>
            </li>
        @endforeach
    </ul>
@endif

<details class="panel disclosure" @if ($sections->isEmpty() || $errors->has('name')) open @endif style="margin-top: 0;">
    <summary>Add a section</summary>
    <form method="POST" action="{{ route('teacher.sections.store') }}" class="disclosure-body" style="max-width: 28rem;">
        @csrf
        <label for="name" style="margin-top: 0;">Section name</label>
        <input id="name" type="text" name="name" required maxlength="100" placeholder="e.g. Grade 1 - Rosal" value="{{ old('name') }}" @error('name') aria-invalid="true" aria-describedby="name-error" @enderror>
        @include('partials.field-error', ['field' => 'name'])
        <div class="form-actions" style="margin-top: var(--s3);"><button class="btn" type="submit">Add section</button></div>
    </form>
</details>
@endsection
