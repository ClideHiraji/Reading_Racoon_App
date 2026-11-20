@extends('layouts.app')
@section('title', 'Library & Videos')

@php($languages = config('reading_racoon.content.languages'))

@section('content')
<div class="page-head">
    <div>
        <h1>Library &amp; Videos</h1>
        <p class="meta measure">Books and videos you publish appear on your learners' tablets under "From your teacher" after their next sync.</p>
    </div>
    <div class="actions">
        <a class="btn" href="{{ route('teacher.content.books.create') }}">Add a book</a>
        <a class="btn btn-secondary" href="{{ route('teacher.content.videos.create') }}">Upload a video</a>
    </div>
</div>

<div class="alert alert-warn">
    <p>Only use <strong>openly licensed</strong> books and videos (for example StoryWeaver or Let's Read, under Creative Commons) and give their source.</p>
</div>

<div class="panel">
    @if ($items->isEmpty())
        <div class="empty">
            <div>
                <p class="big">Nothing here yet.</p>
                <p class="muted small">Add a book or upload a video, choose its sections, then publish it. Three steps, and the tablets download it on Wi-Fi.</p>
            </div>
        </div>
    @else
        <div class="table-wrap">
            <table class="table-cards">
                <thead><tr><th>Title</th><th>Sections</th><th>Status</th><th><span class="sr-only">Actions</span></th></tr></thead>
                <tbody>
                @foreach ($items as $item)
                    @php($video = $item->isBook() ? null : $item->video())
                    @php($missingFile = ! $item->isBook() && $video === null)
                    <tr>
                        <td data-label="">
                            <span class="badge {{ $item->isBook() ? 'badge-teal' : 'badge-blue' }}">{{ $item->isBook() ? 'Book' : 'Video' }}</span>
                            <strong>{{ $item->title }}</strong>
                            <div class="muted small" style="margin-top: .2rem;">
                                {{ $languages[$item->language] ?? $item->language }}
                                @if ($item->isBook())
                                    · {{ ucfirst((string) $item->level) }} · {{ count($item->body['pages'] ?? []) }} {{ Str::plural('page', count($item->body['pages'] ?? [])) }}
                                @else
                                    · {{ $item->minutes }} min
                                    @if ($video) · {{ number_format($video->size_bytes / 1048576, 1) }} MB @endif
                                @endif
                                · {{ $item->licence }}
                            </div>
                        </td>
                        <td data-label="Sections">
                            @if ($sections->isEmpty())
                                <span class="muted small">No sections yet.</span>
                            @else
                                <span class="small">{{ $item->sections->pluck('name')->join(', ') ?: 'None chosen' }}</span>
                                <details class="disclosure" style="margin-top: .25rem;">
                                    <summary class="small">Change<span class="sr-only"> sections for {{ $item->title }}</span></summary>
                                    <form method="POST" action="{{ route('teacher.content.assign', $item) }}" class="disclosure-body" style="margin-top: .25rem;">
                                        @csrf
                                        @method('PUT')
                                        @foreach ($sections as $section)
                                            <label class="check is-plain" style="margin: .1rem 0;">
                                                <input type="checkbox" name="sections[]" value="{{ $section->id }}" @checked($item->sections->contains($section))> {{ $section->name }}
                                            </label>
                                        @endforeach
                                        <button class="btn btn-secondary btn-sm" type="submit">Save sections</button>
                                    </form>
                                </details>
                            @endif
                        </td>
                        <td data-label="Status">
                            @if ($item->published)
                                <span class="badge badge-green">Published</span>
                            @elseif ($missingFile)
                                <span class="badge badge-amber">Draft · needs its video file</span>
                            @else
                                <span class="badge">Draft</span>
                            @endif
                        </td>
                        <td data-label="">
                            <div class="row" style="justify-content: flex-end;">
                                @if ($missingFile && ! $item->published)
                                    <a class="btn btn-sm" href="{{ route('teacher.content.edit', $item) }}">Add the video file</a>
                                @else
                                    <form method="POST" action="{{ route('teacher.content.publish', $item) }}"
                                          @if ($item->published) data-confirm="Hide &quot;{{ $item->title }}&quot; from the tablets? It stays here as a draft." @endif>
                                        @csrf
                                        <input type="hidden" name="published" value="{{ $item->published ? 0 : 1 }}">
                                        <button class="btn btn-sm {{ $item->published ? 'btn-secondary' : '' }}" type="submit">{{ $item->published ? 'Unpublish' : 'Publish' }}<span class="sr-only"> {{ $item->title }}</span></button>
                                    </form>
                                    <a class="btn btn-secondary btn-sm" href="{{ route('teacher.content.edit', $item) }}">Edit<span class="sr-only"> {{ $item->title }}</span></a>
                                @endif
                                <form method="POST" action="{{ route('teacher.content.destroy', $item) }}" data-confirm="Delete &quot;{{ $item->title }}&quot;? Tablets remove it at their next sync.">
                                    @csrf
                                    @method('DELETE')
                                    <button class="btn btn-danger-outline btn-sm" type="submit">Delete<span class="sr-only"> {{ $item->title }}</span></button>
                                </form>
                            </div>
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
    @endif
</div>
@endsection
