<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Reading Racoon report {{ $student->code }}</title>
    <style>
        @page { margin: 28mm 18mm 20mm; }
        body { font-family: "DejaVu Sans", sans-serif; font-size: 10.5pt; color: #2b2a33; line-height: 1.45; }
        h1 { font-size: 17pt; margin: 0 0 2pt; }
        h2 { font-size: 12.5pt; margin: 14pt 0 6pt; color: #1f776c; }
        h3 { font-size: 11pt; margin: 12pt 0 4pt; }
        p { margin: 0 0 7pt; }
        ul { margin: 0 0 6pt 14pt; padding: 0; }
        li { margin-bottom: 3pt; }
        table { width: 100%; border-collapse: collapse; }
        th, td { text-align: left; padding: 4pt 5pt; border-bottom: 0.6pt solid #e6dfd0; vertical-align: top; }
        th { font-size: 8.5pt; text-transform: uppercase; color: #6b6b78; }
        .muted { color: #6b6b78; }
        .small { font-size: 9pt; }
        .head { border-bottom: 2pt solid #2a9d8f; padding-bottom: 6pt; margin-bottom: 8pt; }
        .meta td { border: 0; padding: 1pt 8pt 1pt 0; }
    </style>
</head>
<body>
<div class="head">
    <h1>Reading Racoon diagnostic report</h1>
    <table class="meta small">
        <tr><td><strong>Learner</strong> {{ $student->displayName() }} ({{ $student->code }})</td><td><strong>Section</strong> {{ $student->section->name }}</td></tr>
        <tr><td><strong>Map level</strong> L{{ $facts['highest_level'] }} {{ $facts['world'] }} · {{ $facts['aral_band'] }}</td><td><strong>Teacher</strong> {{ $student->section->teacher?->name }}</td></tr>
    </table>
</div>
@include('teacher.partials.report-body')
</body>
</html>
