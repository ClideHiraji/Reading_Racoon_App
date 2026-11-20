@extends('layouts.app')
@section('title', 'Report · '.$student->displayName())

@section('content')
<nav class="crumbs" aria-label="Breadcrumb">
    <ol>
        <li><a href="{{ route('teacher.sections.show', $student->section) }}">{{ $student->section->name }}</a></li>
        <li><a href="{{ route('teacher.students.show', $student) }}">{{ $student->displayName() }}</a></li>
        <li aria-current="page">Diagnostic report</li>
    </ol>
</nav>
<div class="page-head">
    <div>
        <h1>Diagnostic report: {{ $student->displayName() }}</h1>
        <p class="meta">Student ID {{ $student->code }} · {{ $student->section->name }}</p>
    </div>
    <div class="actions">
        <a class="btn" href="{{ route('teacher.students.report.pdf', $student) }}">Download PDF</a>
    </div>
</div>

<article class="panel report">
    @include('teacher.partials.report-body')
</article>
@endsection
