@extends('layouts.app')
@section('title', $item ? 'Edit book' : 'Add a book')

@php
    $c = config('reading_racoon.content');
    $pages = $item?->body['pages'] ?? [];
    $images = $item?->files->where('role', 'page_image')->keyBy('page_index') ?? collect();
    $words = collect($item?->body['words'] ?? [])->map(fn ($w) => $w['word'].(isset($w['picture']) ? ' = '.$w['picture'] : ''))->implode("\n");
    // Show the pages in use plus two empty ones; the rest wait behind "More pages".
    $used = 0;
    for ($i = 0; $i < $c['max_pages']; $i++) {
        if (filled(old("pages.$i.text", $pages[$i]['text'] ?? null)) || $images->has($i)) {
            $used = $i + 1;
        }
    }
    $open = min($c['max_pages'], max(3, $used + 2));
@endphp

@section('content')
<nav class="crumbs" aria-label="Breadcrumb">
    <ol>
        <li><a href="{{ route('teacher.content.index') }}">Library &amp; Videos</a></li>
        <li aria-current="page">{{ $item ? 'Edit book' : 'Add a book' }}</li>
    </ol>
</nav>
<div class="page-head">
    <div>
        <h1>{{ $item ? 'Edit book' : 'Add a book' }}</h1>
        <p class="meta measure">Copy an openly licensed picture book page by page. Children read it in the Library and answer the two picture questions at the end.</p>
    </div>
</div>

<div class="panel" style="max-width: 52rem;">
    <form method="POST" action="{{ $item ? route('teacher.content.update', $item) : route('teacher.content.books.store') }}" enctype="multipart/form-data">
        @csrf
        @if ($item) @method('PUT') @endif

        @if ($errors->any())
            <div class="alert alert-warn"><p>Your typing is kept, but browsers can't keep chosen files after an error: <strong>choose any page pictures again</strong> before saving.</p></div>
        @endif

        @include('teacher.content.partials.common')

        <div class="form-group">
            <h2>Book</h2>
            <div class="field-row">
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
            <label for="words">Key words, one per line <span class="muted">(optional)</span></label>
            <textarea id="words" name="words" rows="4" placeholder="word = picture" aria-describedby="words-hint">{{ old('words', $words) }}</textarea>
            <p class="hint" id="words-hint">For example <code>bangka = boat</code>. The picture is optional and comes from the game's picture list.</p>
            @include('partials.field-error', ['field' => 'words'])
        </div>

        <div class="form-group">
            <h2>Pages</h2>
            <p class="hint" style="margin-top: 0;">Leave a page empty to skip it. Pictures are names from the game's picture list (start typing to see them). A page picture upload is optional (PNG or JPG, up to {{ $c['max_image_kb'] / 1024 }} MB).</p>
            @for ($i = 0; $i < $c['max_pages']; $i++)
                @if ($i === $open)
                    <details class="disclosure">
                        <summary>More pages ({{ $open + 1 }} to {{ $c['max_pages'] }})</summary>
                @endif
                <fieldset class="page-box">
                    <legend>Page {{ $i + 1 }}</legend>
                    <label for="page-text-{{ $i }}" class="sr-only">Page {{ $i + 1 }} text</label>
                    <textarea id="page-text-{{ $i }}" name="pages[{{ $i }}][text]" rows="2" maxlength="400" placeholder="What this page says (up to 400 letters)" @error("pages.$i.text") aria-invalid="true" aria-describedby="page-text-{{ $i }}-error" @enderror>{{ old("pages.$i.text", $pages[$i]['text'] ?? '') }}</textarea>
                    @include('partials.field-error', ['field' => "pages.$i.text", 'id' => "page-text-$i"])
                    <div class="field-row">
                        <div>
                            <label class="small" for="scene-{{ $i }}">Scene</label>
                            <select id="scene-{{ $i }}" name="pages[{{ $i }}][scene]">
                                @foreach ($c['scenes'] as $scene)
                                    <option value="{{ $scene }}" @selected(old("pages.$i.scene", $pages[$i]['scene'] ?? $item?->scene) === $scene)>{{ ucfirst($scene) }}</option>
                                @endforeach
                            </select>
                        </div>
                        <div>
                            <label class="small" for="pictures-{{ $i }}">Pictures <span class="muted">(optional, comma-separated)</span></label>
                            <input id="pictures-{{ $i }}" type="text" name="pages[{{ $i }}][pictures]" list="picture-names" value="{{ old("pages.$i.pictures", implode(', ', $pages[$i]['pictures'] ?? [])) }}">
                        </div>
                    </div>
                    <label class="small" for="image-{{ $i }}">Page picture <span class="muted">(optional, PNG or JPG)</span></label>
                    <input id="image-{{ $i }}" type="file" name="pages[{{ $i }}][image]" accept="image/png,image/jpeg" @error("pages.$i.image") aria-invalid="true" aria-describedby="image-{{ $i }}-error" @enderror>
                    @include('partials.field-error', ['field' => "pages.$i.image", 'id' => "image-$i"])
                    @if ($image = $images->get($i))
                        <div class="row small" style="margin-top: .3rem;">
                            <a href="{{ route('teacher.content.file', [$item, $image]) }}" target="_blank" rel="noopener">Current picture</a>
                            <label class="check is-plain" style="margin: 0;"><input type="checkbox" name="pages[{{ $i }}][remove_image]" value="1"> Remove</label>
                        </div>
                    @endif
                </fieldset>
                @if ($i === $c['max_pages'] - 1 && $open < $c['max_pages'])
                    </details>
                @endif
            @endfor
        </div>

        <div class="form-group">
            <h2>Questions after the story</h2>
            @foreach ([0, 1] as $q)
                @include('teacher.content.partials.question', ['name' => "questions[$q]", 'label' => 'Question '.($q + 1), 'question' => $item?->body['questions'][$q] ?? null, 'required' => true])
            @endforeach
        </div>

        <div class="form-actions">
            <button class="btn" type="submit" data-busy-label="Saving the book…">Save book</button>
            <a class="btn btn-quiet" href="{{ route('teacher.content.index') }}">Cancel</a>
        </div>
    </form>
</div>
@endsection
