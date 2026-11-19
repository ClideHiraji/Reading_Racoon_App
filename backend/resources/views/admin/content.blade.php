@extends('layouts.admin')
@section('title', 'Content')

@php($tz = config('reading_racoon.access.timezone'))

@section('content')
<div class="page-head">
    <div>
        <h1>Library &amp; Videos</h1>
        <p class="muted">Everything teachers added for the tablets. Unpublish anything unsuitable or not openly licensed; the teacher can fix it and publish again.</p>
    </div>
</div>

<div class="card">
    @if ($items->isEmpty())
        <p class="muted">No teacher content yet.</p>
    @else
        <div class="table-wrap">
            <table class="small">
                <thead><tr><th>Item</th><th>Teacher · sections</th><th>Licence · source</th><th>Status</th><th></th></tr></thead>
                <tbody>
                @foreach ($items as $item)
                    <tr>
                        <td>
                            <span class="badge {{ $item->isBook() ? 'badge-teal' : 'badge-orange' }}">{{ $item->isBook() ? 'Book' : 'Video' }}</span>
                            <strong>{{ $item->title }}</strong>
                            <div class="muted">{{ $item->id }} · {{ $item->language }} · {{ $item->created_at->setTimezone($tz)->format('M j, Y') }}</div>
                            @foreach ($item->files as $file)
                                <a href="{{ route('admin.content.file', [$item, $file]) }}" target="_blank" rel="noopener noreferrer">{{ $file->role === 'video' ? 'video' : 'page '.($file->page_index + 1).' picture' }}</a>
                            @endforeach
                        </td>
                        <td>{{ $item->owner?->email ?? 'removed teacher' }}<div class="muted">{{ $item->sections->pluck('name')->join(', ') ?: 'no section' }}</div></td>
                        <td>{{ $item->licence }}<div><a href="{{ $item->source_url }}" target="_blank" rel="noopener noreferrer">{{ \Illuminate\Support\Str::limit($item->source_url, 40) }}</a></div><div class="muted">{{ \Illuminate\Support\Str::limit($item->credit, 80) }}</div></td>
                        <td>@if ($item->published)<span class="badge badge-green">Published</span>@else<span class="badge">Draft</span>@endif</td>
                        <td>
                            @if ($item->published)
                                <form method="POST" action="{{ route('admin.content.unpublish', $item) }}">
                                    @csrf
                                    <button class="btn btn-danger btn-sm" type="submit">Unpublish</button>
                                </form>
                            @endif
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
        <div class="pager">{{ $items->links('admin.partials.pager') }}</div>
    @endif
</div>
@endsection
