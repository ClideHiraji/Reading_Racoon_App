{{-- One skill level's open flags: every reason as a badge, one "Mark resolved" for all of them.
$g is a row of SectionStats::bySkill(), $name the learner's display name, $anchor where to
land after resolving. --}}
@php($what = ($g['skill'] ?? 'Flag').($g['level'] ? ' L'.$g['level'] : ''))
<li @class(['flag', 'is-better' => $g['better']]) data-inline-scope>
    <span class="row" style="gap: .3rem;">
        @foreach ($g['flags'] as $f)
            <span class="badge {{ $f['badge'] }}"><span class="flag-dot" style="background: {{ $f['color'] }}" aria-hidden="true"></span>{{ $f['label'] }}</span>
        @endforeach
    </span>
    <span class="what">
        {{ $what }}
        @if ($g['better'])
            <span class="better">Looks better now</span>
        @endif
    </span>
    <span class="when">@include('partials.when', ['at' => $g['raised']])</span>
    <form method="POST" action="{{ route('teacher.flags.resolve-many') }}" data-inline>
        @csrf
        <input type="hidden" name="anchor" value="{{ $anchor ?? 'needs-help' }}">
        @foreach ($g['ids'] as $id)
            <input type="hidden" name="ids[]" value="{{ $id }}">
        @endforeach
        <button class="btn btn-quiet btn-sm" type="submit" aria-label="Mark resolved: {{ $what }}, for {{ $name }}">Mark resolved</button>
    </form>
</li>
