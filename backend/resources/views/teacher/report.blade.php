@extends('layouts.app')
@section('title', 'Report · '.$student->displayName())

@section('content')
<p class="small"><a href="{{ route('teacher.students.show', $student) }}">&larr; {{ $student->displayName() }}</a></p>
<div class="page-head">
    <div>
        <h1>Diagnostic report</h1>
        <p class="muted">{{ $student->displayName() }} · {{ $student->code }} · {{ $student->section->name }}</p>
    </div>
    <a class="btn" href="{{ route('teacher.students.report.pdf', $student) }}">Download PDF</a>
</div>

<div class="card report">
    @include('teacher.partials.report-body')
</div>
@endsection
