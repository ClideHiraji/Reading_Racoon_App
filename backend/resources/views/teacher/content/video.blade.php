@extends('layouts.app')
@section('title', $item ? 'Edit video' : 'Upload a video')

@php
    $c = config('reading_racoon.content');
    $video = $item?->video();
@endphp

@section('content')
<p class="small"><a href="{{ route('teacher.content.index') }}">&larr; Library &amp; Videos</a></p>
<div class="narrow" style="max-width: 720px;">
    <div class="card">
        <h1>{{ $item ? 'Edit video' : 'Upload a video' }}</h1>
        <p class="muted">Tablets download the video on Wi-Fi and play it offline in Watch &amp; Listen. Use Ogg Theora (.ogv), at most {{ $c['max_video_mb'] }} MB; convert MP4 first, for example with <code>ffmpeg -i in.mp4 -c:v libtheora -q:v 6 -c:a libvorbis out.ogv</code>.</p>
        <form method="POST" action="{{ $item ? route('teacher.content.update', $item) : route('teacher.content.videos.store') }}" enctype="multipart/form-data">
            @csrf
            @if ($item) @method('PUT') @endif

            @include('teacher.content.partials.common')

            <h2 style="margin-top: 1.25rem;">Video</h2>
            <div class="grid grid-2">
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
                    <input id="minutes" type="number" name="minutes" min="1" max="60" value="{{ old('minutes', $item?->minutes ?? 3) }}" required>
                </div>
            </div>
            <label for="file">Video file (.ogv){{ $item ? ', only to replace it' : '' }}</label>
            <input id="file" type="file" name="file" accept=".ogv,video/ogg" {{ $item ? '' : 'required' }}>
            @if ($video)
                <p class="small muted">Current file: {{ number_format($video->size_bytes / 1048576, 1) }} MB · SHA-256 {{ substr($video->sha256, 0, 12) }}… · <a href="{{ route('teacher.content.file', [$item, $video]) }}" target="_blank" rel="noopener">play</a></p>
            @endif

            <h2 style="margin-top: 1.25rem;">Check question (optional)</h2>
            <p class="muted small">One picture question after the video, like the songs have.</p>
            @include('teacher.content.partials.question', ['name' => 'check', 'label' => 'Question', 'question' => $item?->body['check'] ?? null, 'required' => false])

            <p style="margin-top: 1rem;"><button class="btn" type="submit">{{ $item ? 'Save video' : 'Upload video' }}</button></p>
        </form>
    </div>
</div>
@endsection
