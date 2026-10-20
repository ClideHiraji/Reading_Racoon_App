@extends('layouts.admin')
@section('title', 'Research export')

@section('content')
<div class="page-head">
    <div>
        <h1>Research export</h1>
        <p class="muted">CSV files for the study analysis (pre/post-test, BKT history). Learners appear by student code only, never by name.</p>
    </div>
</div>

@if ($consented < $total)
    <div class="alert alert-warn">{{ $total - $consented }} of {{ $total }} learners have no parental consent on file and are left out of both files (RA 10173). Teachers record consent in their roster.</div>
@endif

<div class="grid grid-2">
    <section class="card">
        <h2>Learner summary</h2>
        <p class="small">One row per consented learner: map level, ARAL band, accuracy, XP, pre-test and post-test scores (total and per sub-skill) and the final P(L) of all 14 skill-levels.</p>
        <p><a class="btn" href="{{ route('admin.export.students') }}">Download students.csv</a></p>
    </section>
    <section class="card">
        <h2>BKT history</h2>
        <p class="small">One row per answer the server replayed: time (UTC), sub-skill, level, correct, posterior, P(L) for the next answer, attempts, mastery and Level Up moments.</p>
        <p><a class="btn" href="{{ route('admin.export.history') }}">Download bkt-history.csv</a></p>
    </section>
</div>
<p class="muted small">Each download is written to the audit log with the number of learners included.</p>
@endsection
