@extends('layouts.app')
@section('title', 'Library & Videos')

@php($languages = config('reading_racoon.content.languages'))

@section('content')
<div class="page-head">
    <div>
        <h1>Library &amp; Videos</h1>
        <p class="muted">Books and videos you add appear on your learners' tablets under "From your teacher" after their next sync.</p>
    </div>
    <div class="row">
        <a class="btn" href="{{ route('teacher.content.books.create') }}">Add a book</a>
        <a class="btn btn-light" href="{{ route('teacher.content.videos.create') }}">Upload a video</a>
    </div>
</div>

<div class="alert alert-warn">
    Only use <strong>openly licensed</strong> books and videos (for example StoryWeaver or Let's Read, under Creative Commons) and give their source.
    Videos must be Ogg Theora files (.ogv), at most {{ config('reading_racoon.content.max_video_mb') }} MB.
</div>

<div class="card">
    @if ($items->isEmpty())
        <p class="muted">Nothing here yet. Add a book or upload a video, assign it to a section, then publish it.</p>
    @else
        <div class="table-wrap">
            <table>
                <thead><tr><th>Title</th><th>Sections</th><th>Status</th><th></th></tr></thead>
                <tbody>
                @foreach ($items as $item)
                    <tr>
                        <td>
                            <span class="badge {{ $item->isBook() ? 'badge-teal' : 'badge-orange' }}">{{ $item->isBook() ? 'Book' : 'Video' }}</span>
                            <strong>{{ $item->title }}</strong>
                            <div class="muted small">
                                {{ $languages[$item->language] ?? $item->language }}
                                @if ($item->isBook())
                                    · {{ $item->level }} · {{ count($item->body['pages'] ?? []) }} pages
                                @else
                                    · {{ $item->minutes }} min
                                    @if ($video = $item->video()) · {{ number_format($video->size_bytes / 1048576, 1) }} MB @else · <span class="status-fail">no file</span> @endif
                                @endif
                                · {{ $item->licence }}
                            </div>
                        </td>
                        <td>
                            @if ($sections->isEmpty())
                                <span class="muted small">No sections yet.</span>
                            @else
                                <form method="POST" action="{{ route('teacher.content.assign', $item) }}">
                                    @csrf
                                    @method('PUT')
                                    @foreach ($sections as $section)
                                        <label class="check" style="margin: .1rem 0; font-weight: 400;">
                                            <input type="checkbox" name="sections[]" value="{{ $section->id }}" @checked($item->sections->contains($section))> {{ $section->name }}
                                        </label>
                                    @endforeach
                                    <button class="btn btn-light btn-sm" type="submit">Save sections</button>
                                </form>
                            @endif
                        </td>
                        <td>
                            @if ($item->published)
                                <span class="badge badge-green">Published</span>
                            @else
                                <span class="badge">Draft</span>
                            @endif
                            <form method="POST" action="{{ route('teacher.content.publish', $item) }}" style="margin-top: .4rem;">
                                @csrf
                                <input type="hidden" name="published" value="{{ $item->published ? 0 : 1 }}">
                                <button class="btn btn-sm {{ $item->published ? 'btn-light' : '' }}" type="submit">{{ $item->published ? 'Unpublish' : 'Publish' }}</button>
                            </form>
                        </td>
                        <td>
                            <div class="row">
                                <a class="btn btn-light btn-sm" href="{{ route('teacher.content.edit', $item) }}">Edit</a>
                                <form method="POST" action="{{ route('teacher.content.destroy', $item) }}" data-confirm="Delete &quot;{{ $item->title }}&quot;? Tablets remove it at their next sync.">
                                    @csrf
                                    @method('DELETE')
                                    <button class="btn btn-danger btn-sm" type="submit">Delete</button>
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
