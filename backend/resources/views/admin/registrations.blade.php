@extends('layouts.admin')
@section('title', 'Registrations')

@php($tz = config('reading_racoon.access.timezone'))

@section('content')
<div class="page-head">
    <div>
        <h1>Teacher registrations</h1>
        <p class="muted">Approve teachers you can verify with their school. Denying an approved teacher revokes their access at once.</p>
    </div>
</div>

<nav class="tabs" aria-label="Status">
    @foreach (['pending' => 'Waiting', 'approved' => 'Approved', 'denied' => 'Denied'] as $value => $label)
        <a href="{{ route('admin.registrations', ['status' => $value]) }}" @class(['active' => $status === $value])>{{ $label }} ({{ $counts[$value] ?? 0 }})</a>
    @endforeach
</nav>

<div class="card">
    @if ($registrations->isEmpty())
        <p class="muted">Nothing here.</p>
    @else
        <div class="table-wrap">
            <table>
                <thead><tr><th>Teacher</th><th>School · sections</th><th>Registered</th><th>Review</th><th>Decision</th></tr></thead>
                <tbody>
                @foreach ($registrations as $registration)
                    <tr>
                        <td><strong>{{ $registration->user->name }}</strong><div class="small">{{ $registration->user->email }}</div></td>
                        <td>{{ $registration->school ?? '-' }}<div class="small muted">{{ $registration->user->sections->pluck('name')->join(', ') }}</div></td>
                        <td class="small">{{ $registration->created_at->setTimezone($tz)->format('M j, Y g:i A') }}</td>
                        <td class="small">
                            @if ($registration->reviewed_at)
                                {{ $registration->reviewer?->email ?? 'removed admin' }}<br>{{ $registration->reviewed_at->setTimezone($tz)->format('M j, Y') }}
                                @if ($registration->review_note)<div class="muted">"{{ $registration->review_note }}"</div>@endif
                            @else
                                <span class="muted">not reviewed</span>
                            @endif
                        </td>
                        <td style="min-width: 260px;">
                            <form method="POST" class="row" style="margin-bottom: .35rem;">
                                @csrf
                                <input type="text" name="note" maxlength="500" placeholder="Note (optional)" style="flex: 1; min-width: 120px;">
                                @if ($status !== 'approved')
                                    <button class="btn btn-sm" type="submit" formaction="{{ route('admin.registrations.approve', $registration) }}">Approve</button>
                                @endif
                                @if ($status !== 'denied')
                                    <button class="btn btn-danger btn-sm" type="submit" formaction="{{ route('admin.registrations.deny', $registration) }}">{{ $status === 'approved' ? 'Revoke' : 'Deny' }}</button>
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
