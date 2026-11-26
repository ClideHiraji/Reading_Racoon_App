{{-- A time a teacher can read: "2 days ago" within a week, the date after that, and the exact
time on hover and for screen readers (datetime). $at = Carbon or string. --}}
@php($t = ($at instanceof \DateTimeInterface ? \Carbon\CarbonImmutable::instance($at) : \Carbon\CarbonImmutable::parse($at))->setTimezone(config('reading_racoon.access.timezone')))
<time datetime="{{ $t->toIso8601String() }}" title="{{ $t->format('M j, Y g:i A') }}">{{ $t->greaterThan(now()->subWeek()) ? $t->diffForHumans() : $t->format($t->year === now()->year ? 'M j' : 'M j, Y') }}</time>