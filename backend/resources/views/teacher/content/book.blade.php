@extends('layouts.app')
@section('title', $item ? 'Edit book' : 'Add a book')

@php
    $c = config('reading_racoon.content');
    $pages = $item?->body['pages'] ?? [];
    $images = $item?->files->where('role', 'page_image')->keyBy('page_index') ?? collect();
    $words = collect($item?->body['words'] ?? [])->map(fn ($w) => $w['word'].(isset($w['picture']) ? ' = '.$w['picture'] : ''))->implode("\n");
@endphp

@section('content')
<p class="small"><a href="{{ route('teacher.content.index') }}">&larr; Library &amp; Videos</a></p>
<div class="narrow" style="max-width: 820px;">
    <div class="card">
        <h1>{{ $item ? 'Edit book' : 'Add a book' }}</h1>
        <p class="muted">Copy an openly licensed picture book page by page. Children read it in the Library and answer the two picture questions at the end.</p>
        <form method="POST" action="{{ $item ? route('teacher.content.update', $item) : route('teacher.content.books.store') }}" enctype="multipart/form-data">
            @csrf
            @if ($item) @method('PUT') @endif

            @include('teacher.content.partials.common')

            <h2 style="margin-top: 1.25rem;">Book</h2>
            <div class="grid grid-2">
                <div>
                    <label for="level">Level</label>
                    <select id="level" name="level" required>
                        @foreach ($c['levels'] as $level)
                            <option value="{{ $level }}" @selected(old('level', $item?->level) === $level)>{{ ucfirst($level) }}</option>
                        @endforeach
                    </select>
                </div>
                <div>
                    <label for="cover">Cover scene</label>
                    <select id="cover" name="cover" required>
                        @foreach ($c['scenes'] as $scene)
                            <option value="{{ $scene }}" @selected(old('cover', $item?->scene) === $scene)>{{ ucfirst($scene) }}</option>
                        @endforeach
                    </select>
                </div>
            </div>
            <label for="words">Key words, one per line: word = picture (picture optional)</label>
            <textarea id="words" name="words" rows="4" placeholder="bangka = boat&#10;isda = fish">{{ old('words', $words) }}</textarea>

            <h2 style="margin-top: 1.25rem;">Pages</h2>
            <p class="muted small">Leave a page empty to skip it. Pictures are names from the game's picture list (start typing to see them); a page picture upload is optional (PNG or JPG, up to {{ $c['max_image_kb'] / 1024 }} MB).</p>
            @for ($i = 0; $i < $c['max_pages']; $i++)
                <fieldset class="card" style="padding: .7rem .9rem; margin-bottom: .6rem;">
                    <legend class="small"><strong>Page {{ $i + 1 }}</strong></legend>
                    <textarea name="pages[{{ $i }}][text]" rows="2" maxlength="400" aria-label="Page {{ $i + 1 }} text">{{ old("pages.$i.text", $pages[$i]['text'] ?? '') }}</textarea>
                    <div class="grid grid-2">
                        <div>
                            <label class="small" for="scene-{{ $i }}">Scene</label>
                            <select id="scene-{{ $i }}" name="pages[{{ $i }}][scene]">
                                @foreach ($c['scenes'] as $scene)
                                    <option value="{{ $scene }}" @selected(old("pages.$i.scene", $pages[$i]['scene'] ?? $item?->scene) === $scene)>{{ ucfirst($scene) }}</option>
                                @endforeach
                            </select>
                        </div>
                        <div>
                            <label class="small" for="pictures-{{ $i }}">Pictures (comma-separated)</label>
                            <input id="pictures-{{ $i }}" type="text" name="pages[{{ $i }}][pictures]" list="picture-names" value="{{ old("pages.$i.pictures", implode(', ', $pages[$i]['pictures'] ?? [])) }}">
                        </div>
                    </div>
                    <label class="small" for="image-{{ $i }}">Page picture (optional)</label>
                    <input id="image-{{ $i }}" type="file" name="pages[{{ $i }}][image]" accept="image/png,image/jpeg">
                    @if ($image = $images->get($i))
                        <div class="row small" style="margin-top: .3rem;">
                            <a href="{{ route('teacher.content.file', [$item, $image]) }}" target="_blank" rel="noopener">Current picture</a>
                            <label class="check" style="margin: 0; font-weight: 400;"><input type="checkbox" name="pages[{{ $i }}][remove_image]" value="1"> Remove</label>
                        </div>
                    @endif
                </fieldset>
            @endfor

            <h2 style="margin-top: 1.25rem;">Questions after the story</h2>
            @foreach ([0, 1] as $q)
                @include('teacher.content.partials.question', ['name' => "questions[$q]", 'label' => 'Question '.($q + 1), 'question' => $item?->body['questions'][$q] ?? null, 'required' => true])
            @endforeach

            <p style="margin-top: 1rem;"><button class="btn" type="submit">Save book</button></p>
        </form>
    </div>
</div>
@endsection
