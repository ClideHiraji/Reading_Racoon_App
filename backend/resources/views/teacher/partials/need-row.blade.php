{{-- One child in "Needs your help" or "Looks better": who, where they are, their open flags per skill. --}}
@php($student = $row['student'])
@php($name = $student->displayName())
@php($last = $stats->lastActivity[$student->id] ?? null)
@php($level = \App\Support\SectionStats::highest($student))
<li class="need">
    <div class="need-who">
        <a href="{{ route('teacher.students.show', $student) }}">{{ $name }}</a>
        <p class="muted small">L{{ $level }} · {{ \App\Support\SkillCatalog::level($level)['world'] }} · @if ($last) played @include('partials.when', ['at' => $last]) @else never played @endif</p>
    </div>
    <ul class="flags">
        @foreach (\App\Support\SectionStats::bySkill($row['flags']) as $g)
            @include('teacher.partials.flag', ['g' => $g, 'name' => $name, 'anchor' => $anchor ?? 'needs-help'])
        @endforeach
    </ul>
    <div class="need-go">
        <a class="btn btn-secondary btn-sm" href="{{ route('teacher.students.show', $student) }}">Open<span class="sr-only"> {{ $name }}</span></a>
    </div>
</li>
