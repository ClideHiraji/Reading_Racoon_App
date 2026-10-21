{{-- Fields shared by the book and video forms: title, language, credit, licence, source, sections. --}}
@php($c = config('reading_racoon.content'))
<label for="title">Title</label>
<input id="title" type="text" name="title" value="{{ old('title', $item?->title) }}" required maxlength="150">
<div class="grid grid-2">
    <div>
        <label for="language">Language</label>
        <select id="language" name="language" required>
            @foreach ($c['languages'] as $code => $name)
                <option value="{{ $code }}" @selected(old('language', $item?->language) === $code)>{{ $name }}</option>
            @endforeach
        </select>
    </div>
    <div>
        <label for="licence">Open licence</label>
        <select id="licence" name="licence" required>
            <option value="">Choose...</option>
            @foreach ($c['licences'] as $licence)
                <option value="{{ $licence }}" @selected(old('licence', $item?->licence) === $licence)>{{ $licence }}</option>
            @endforeach
        </select>
    </div>
</div>
<label for="source_url">Where you found it (link)</label>
<input id="source_url" type="text" name="source_url" value="{{ old('source_url', $item?->source_url) }}" required maxlength="500" placeholder="https://storyweaver.org.in/...">
<label for="credit">Credit line</label>
<input id="credit" type="text" name="credit" value="{{ old('credit', $item?->credit) }}" required maxlength="500" placeholder="Title by Author, illustrated by Illustrator, Pratham Books, CC BY 4.0">

<h2 style="margin-top: 1.25rem;">Sections</h2>
@forelse ($sections as $section)
    <label class="check" style="font-weight: 400;">
        <input type="checkbox" name="sections[]" value="{{ $section->id }}" @checked(in_array($section->id, array_map('intval', old('sections', $item?->sections->pluck('id')->all() ?? [])), true))> {{ $section->name }}
    </label>
@empty
    <p class="muted small">You have no sections yet.</p>
@endforelse

<datalist id="picture-names">
    @foreach ($c['pictures'] as $picture)
        <option value="{{ $picture }}">
    @endforeach
</datalist>
