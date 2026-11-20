{{-- One child in "Needs your help": who, where they are, their open flags. --}}
@php($student = $row['student'])
@php($name = $student->displayName())
@php($last = $stats->lastActivity[$student->id] ?? null)
@php($level = \App\Support\SectionStats::highest($student))
<li class="need">
    <div class="need-who">
        <a href="{{ route('teacher.students.show', $student) }}">{{ $name }}</a>
        <p class="muted small">L{{ $level }} · {{ \App\Support\SkillCatalog::level($level)['world'] }} · {{ $last ? 'played '.\Carbon\CarbonImmutable::parse($last)->diffForHumans() : 'not played yet' }}</p>
    </div>
    <ul class="flags">
        @foreach ($row['flags'] as $f)
            @include('teacher.partials.flag', ['f' => $f, 'name' => $name])
        @endforeach
    </ul>
    <div class="need-go">
        <a class="btn btn-secondary btn-sm" href="{{ route('teacher.students.show', $student) }}">Open<span class="sr-only"> {{ $name }}</span></a>
    </div>
</li>
