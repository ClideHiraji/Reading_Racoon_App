@extends('layouts.admin')
@section('title', 'Registrations')

@php($tz = config('reading_racoon.access.timezone'))

@section('content')
<div class="page-head">
    <div>
        <h1>Teacher registrations</h1>
        <p class="meta measure">Approve teachers you can verify with their school. Revoking an approved teacher locks them out from their next click; their sections and learners stay.</p>
    </div>
</div>

<nav class="tabs" aria-label="Status">
    @foreach (['pending' => 'Waiting', 'approved' => 'Approved', 'denied' => 'Denied'] as $value => $label)
        <a href="{{ route('admin.registrations', ['status' => $value]) }}" @if ($status === $value) aria-current="page" @endif>{{ $label }} <span class="num">({{ $counts[$value] ?? 0 }})</span></a>
    @endforeach
</nav>

<div class="panel">
    @if ($registrations->isEmpty())
        <p class="muted">{{ $status === 'pending' ? 'No registrations are waiting.' : 'Nothing here.' }}</p>
    @else
        <div class="table-wrap">
            <table class="table-cards">
                <thead><tr><th>Teacher</th><th>School · sections</th><th>Registered</th><th>Review</th><th>Decision</th></tr></thead>
                <tbody>
                @foreach ($registrations as $registration)
                    @php($teacher = $registration->user)
                    @php($learners = $teacher->sections->sum('students_count'))
                    @php($impact = $teacher->sections->count().' '.Str::plural('section', $teacher->sections->count()).' and '.$learners.' '.Str::plural('learner', $learners))
                    <tr>
                        <td data-label=""><strong>{{ $teacher->name }}</strong><div class="small">{{ $teacher->email }}</div></td>
                        <td data-label="School">{{ $registration->school ?? '-' }}<div class="small muted">{{ $teacher->sections->map(fn ($s) => $s->name.' ('.$s->students_count.')')->join(', ') }}</div></td>
                        <td data-label="Registered" class="small nowrap">{{ $registration->created_at->setTimezone($tz)->format('M j, Y g:i A') }}</td>
                        <td data-label="Review" class="small">
                            @if ($registration->reviewed_at)
                                {{ $registration->reviewer?->email ?? 'removed admin' }}<br>{{ $registration->reviewed_at->setTimezone($tz)->format('M j, Y') }}
                                @if ($registration->review_note)<div class="muted">"{{ $registration->review_note }}"</div>@endif
                            @else
                                <span class="muted">Not reviewed</span>
                            @endif
                        </td>
                        <td data-label="Decision" style="min-width: 260px;">
                            <form method="POST" class="row">
                                @csrf
                                <label for="note-{{ $registration->id }}" class="sr-only">Note for {{ $teacher->name }} (optional)</label>
                                <input id="note-{{ $registration->id }}" type="text" name="note" maxlength="500" placeholder="Note (optional)" style="flex: 1; min-width: 120px;">
                                @if ($status !== 'approved')
                                    <button class="btn btn-sm" type="submit" formaction="{{ route('admin.registrations.approve', $registration) }}">Approve<span class="sr-only"> {{ $teacher->name }}</span></button>
                                @endif
                                @if ($status !== 'denied')
                                    <button class="btn btn-danger-outline btn-sm" type="submit" formaction="{{ route('admin.registrations.deny', $registration) }}"
                                            data-confirm="{{ $status === 'approved'
                                                ? 'Revoke '.$teacher->name.'? From their next click they can no longer see their '.$impact.'. Their data stays.'
                                                : 'Deny '.$teacher->name.'\'s registration? They will not be able to sign in.' }}">{{ $status === 'approved' ? 'Revoke' : 'Deny' }}<span class="sr-only"> {{ $teacher->name }}</span></button>
                                @endif
                            </form>
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
        <div class="pager">{{ $registrations->links('admin.partials.pager') }}</div>
    @endif
</div>
@endsection
