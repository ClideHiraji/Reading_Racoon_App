@extends('layouts.app')
@section('title', 'My sections')

@section('content')
<div class="page-head">
    <div>
        <h1>My sections</h1>
        <p class="muted">Choose a section to see its reading dashboard.</p>
    </div>
</div>

<div class="grid grid-2">
    <div class="card">
        @forelse ($sections as $section)
            <p class="row">
                <a href="{{ route('teacher.sections.show', $section) }}"><strong>{{ $section->name }}</strong></a>
                <span class="badge">{{ $section->students_count }} {{ Str::plural('learner', $section->students_count) }}</span>
            </p>
        @empty
            <p class="muted">You have no sections yet. Add one to start your roster.</p>
        @endforelse
    </div>
    <div class="card">
        <h2>Add a section</h2>
        <form method="POST" action="{{ route('teacher.sections.store') }}">
            @csrf
            <label for="name">Section name</label>
            <input id="name" type="text" name="name" required maxlength="100" placeholder="e.g. Grade 1 - Rosal">
            <p><button class="btn" type="submit">Add section</button></p>
        </form>
    </div>
</div>
@endsection
