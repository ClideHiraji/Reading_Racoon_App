@extends('layouts.app')
@section('title', $item ? 'Edit video' : 'Upload a video')

@php
    $c = config('reading_racoon.content');
    $video = $item?->video();
@endphp

@section('content')
<nav class="crumbs" aria-label="Breadcrumb">
    <ol>
        <li><a href="{{ route('teacher.content.index') }}">Library &amp; Videos</a></li>
        <li aria-current="page">{{ $item ? 'Edit video' : 'Upload a video' }}</li>
    </ol>
</nav>
<div class="page-head">
    <div>
        <h1>{{ $item ? 'Edit video' : 'Upload a video' }}</h1>
        <p class="meta measure">Tablets download the video on Wi-Fi and play it offline in Watch &amp; Listen.</p>
    </div>
</div>

<div class="panel" style="max-width: 46rem;">
    <form method="POST" action="{{ $item ? route('teacher.content.update', $item) : route('teacher.content.videos.store') }}" enctype="multipart/form-data">
        @csrf
        @if ($item) @method('PUT') @endif

        @if ($errors->any())
            <div class="alert alert-warn"><p>Your typing is kept, but browsers can't keep chosen files after an error: <strong>choose the video file again</strong> before saving.</p></div>
        @endif

        @include('teacher.content.partials.common')

        <div class="form-group">
            <h2>Video</h2>
            <div class="field-row">
                <div>
                    <label for="scene">Background scene</label>
                    <select id="scene" name="scene" required>
                        @foreach ($c['scenes'] as $scene)
                            <option value="{{ $scene }}" @selected(old('scene', $item?->scene) === $scene)>{{ ucfirst($scene) }}</option>
                        @endforeach
                    </select>
                </div>
                <div>
                    <label for="minutes">Length (minutes)</label>
                    <input id="minutes" type="number" inputmode="numeric" name="minutes" min="1" max="60" value="{{ old('minutes', $item?->minutes ?? 3) }}" required>
                    @include('partials.field-error', ['field' => 'minutes'])
                </div>
            </div>
            <label for="file">Video file{{ $item ? ', only to replace it' : '' }}</label>
            <input id="file" type="file" name="file" accept=".ogv,video/ogg" {{ $item ? '' : 'required' }} aria-describedby="file-hint @error('file') file-error @enderror" @error('file') aria-invalid="true" @enderror>
            <p class="hint" id="file-hint">An <strong>.ogv</strong> file (the format the game plays), at most {{ $c['max_video_mb'] }} MB. Have an MP4? Ask your school's ICT coordinator to convert it, or use a free online converter "to OGV".</p>
            @include('partials.field-error', ['field' => 'file'])
            <details class="disclosure">
                <summary>For the ICT coordinator: converting MP4</summary>
                <p class="disclosure-body small">With ffmpeg: <code>ffmpeg -i in.mp4 -c:v libtheora -q:v 6 -c:a libvorbis out.ogv</code></p>
            </details>
            @if ($video)
                <p class="small muted" style="margin-top: var(--s3);">Current file: {{ number_format($video->size_bytes / 1048576, 1) }} MB · <a href="{{ route('teacher.content.file', [$item, $video]) }}" target="_blank" rel="noopener">Play it</a></p>
            @endif
        </div>

        <div class="form-group">
            <h2>Check question</h2>
            <p class="hint" style="margin-top: 0;">One picture question after the video, like the songs have.</p>
            @include('teacher.content.partials.question', ['name' => 'check', 'label' => 'Question', 'question' => $item?->body['check'] ?? null, 'required' => false])
        </div>

        <div class="form-actions">
            <button class="btn" type="submit">{{ $item ? 'Save video' : 'Upload video' }}</button>
            <a class="btn btn-quiet" href="{{ route('teacher.content.index') }}">Cancel</a>
        </div>
    </form>
</div>
@endsection
