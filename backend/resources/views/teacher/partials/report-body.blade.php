{{-- Shared by the report page and its PDF. Plain tables only: dompdf has no flexbox or JS. --}}
<h2>Summary</h2>
{{-- The writer only ever sees the student code (RA 10173); the teacher reads the name. --}}
@foreach ($report->paragraphs as $paragraph)
    <p>{{ str_replace(['Learner '.$student->code, $student->code], $student->displayName(), $paragraph) }}</p>
@endforeach

@if ($report->strengths !== [])
    <h3>Strengths</h3>
    <ul>@foreach ($report->strengths as $line)<li>{{ $line }}</li>@endforeach</ul>
@endif
@if ($report->needs !== [])
    <h3>Needs support</h3>
    <ul>@foreach ($report->needs as $line)<li>{{ $line }}</li>@endforeach</ul>
@endif
@if ($report->interventions !== [])
    <h3>Suggested classroom activities</h3>
    <ul>@foreach ($report->interventions as $line)<li>{{ $line }}</li>@endforeach</ul>
@endif

<h3>Sub-skills</h3>
<div class="table-wrap">
<table class="small compact">
    <thead><tr><th>Sub-skill</th><th>Current level</th><th>Mastery estimate</th><th>Mastered levels</th><th>Recent accuracy</th></tr></thead>
    <tbody>
    @foreach ($facts['skills'] as $skill)
        <tr>
            <td>{{ $skill['label'] }}</td>
            <td>{{ $skill['unlocked'] ? 'L'.$skill['current_level'] : 'not reached yet' }}{{ $skill['current_mastered'] ? ' (mastered)' : '' }}{{ $skill['review'] ? ' (review)' : '' }}</td>
            <td>
                @if ($skill['p'] !== null)
                    <table class="pbar" role="presentation" style="width: 120px; border-collapse: collapse;"><tr>
                        <td style="padding: 0; border: 0; height: 8px; width: {{ max(1, round($skill['p'] * 100)) }}%; background: #2a9d8f;"></td>
                        <td style="padding: 0; border: 0; height: 8px; background: #f3ede0;"></td>
                    </tr></table>
                    {{ round($skill['p'] * 100) }}%
                @else
                    -
                @endif
            </td>
            <td>{{ $skill['mastered_levels'] === [] ? '-' : 'L'.implode(', L', $skill['mastered_levels']) }} <span class="muted">of L{{ implode('–', [min($skill['levels']), max($skill['levels'])]) }}</span></td>
            <td>{{ $skill['recent_accuracy'] === null ? '-' : $skill['recent_accuracy'].'% of '.$skill['recent_answers'] }}</td>
        </tr>
    @endforeach
    </tbody>
</table>
</div>

<p class="muted small" style="margin-top: 1rem;">
    Generated {{ $report->generatedAt->setTimezone($timezone)->format('M j, Y g:i A') }} from the game's numbers.
    @if ($report->generatedBy === 'template')
        Summary written by the built-in template from the numbers.
    @else
        Summary paragraphs written by AI ({{ $report->generatedBy }}) from the numbers in the table above and checked against them; the lists come from the numbers. The AI sees only the student code, never the name. It supports, not replaces, your own judgement.
    @endif
    Mastered = a mastery estimate (P(L)) of at least 95% after at least 5 answers at a level. ARAL band from the highest unlocked map level.
</p>
