{{-- One open flag (FR-17) in a teacher's words, with Resolve. $f is a row from
     SectionStats::$needsHelp, $name the learner's display name. --}}
@php($flag = $f['flag'])
@php($what = $f['label'].($f['skill'] ? ': '.$f['skill'] : '').($flag->level ? ' L'.$flag->level : ''))
<li @class(['flag', 'is-better' => $f['better']])>
    <span><span class="badge {{ $f['badge'] }}"><span class="flag-dot" style="background: {{ $f['color'] }}" aria-hidden="true"></span>{{ $f['label'] }}</span></span>
    <span class="what">
        {{ $f['skill'] ?? '' }}{{ $flag->level ? ' L'.$flag->level : '' }}
        @if ($f['better'])
            <span class="better">Looks better now</span>
        @endif
    </span>
    <span class="when">{{ $flag->raised_at->diffForHumans() }}</span>
    <form method="POST" action="{{ route('teacher.flags.resolve', $flag) }}">
        @csrf
        <button class="btn btn-quiet btn-sm" type="submit" aria-label="Mark resolved: {{ $what }}, for {{ $name }}">Mark resolved</button>
    </form>
</li>
