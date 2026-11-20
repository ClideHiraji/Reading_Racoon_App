{{-- Fields shared by the book and video forms: title, language, credit, licence, source, sections. --}}
@php($c = config('reading_racoon.content'))
@php($invalid = fn (string $name) => $errors->has($name) ? 'aria-invalid=true aria-describedby='.$name.'-error' : '')
<div class="field">
    <label for="title">Title</label>
    <input id="title" type="text" name="title" value="{{ old('title', $item?->title) }}" required maxlength="150" {!! $invalid('title') !!}>
    @include('partials.field-error', ['field' => 'title'])
</div>
<div class="field-row">
    <div>
        <label for="language">Language</label>
        <select id="language" name="language" required {!! $invalid('language') !!}>
            @foreach ($c['languages'] as $code => $name)
                <option value="{{ $code }}" @selected(old('language', $item?->language) === $code)>{{ $name }}</option>
            @endforeach
        </select>
        @include('partials.field-error', ['field' => 'language'])
    </div>
    <div>
        <label for="licence">Open licence</label>
        <select id="licence" name="licence" required {!! $invalid('licence') !!}>
            <option value="">Choose...</option>
            @foreach ($c['licences'] as $licence)
                <option value="{{ $licence }}" @selected(old('licence', $item?->licence) === $licence)>{{ $licence }}</option>
            @endforeach
        </select>
        @include('partials.field-error', ['field' => 'licence'])
    </div>
</div>
<label for="source_url">Where you found it (link)</label>
<input id="source_url" type="text" name="source_url" value="{{ old('source_url', $item?->source_url) }}" required maxlength="500" placeholder="https://storyweaver.org.in/..." {!! $invalid('source_url') !!}>
@include('partials.field-error', ['field' => 'source_url'])
<label for="credit">Credit line</label>
<input id="credit" type="text" name="credit" value="{{ old('credit', $item?->credit) }}" required maxlength="500" placeholder="Title by Author, illustrated by Illustrator, Pratham Books, CC BY 4.0" aria-describedby="credit-hint" {!! $invalid('credit') !!}>
<p class="hint" id="credit-hint">Copy it from the book or video's own page. It is shown to the children with the item.</p>
@include('partials.field-error', ['field' => 'credit'])

<fieldset class="form-group">
    <legend><h2 style="margin: 0 0 var(--s1);">Sections</h2></legend>
    <p class="hint" style="margin-top: 0;">Which classes get it on their tablets once it is published.</p>
    @forelse ($sections as $section)
        <label class="check is-plain">
            <input type="checkbox" name="sections[]" value="{{ $section->id }}" @checked(in_array($section->id, array_map('intval', old('sections', $item?->sections->pluck('id')->all() ?? [])), true))> {{ $section->name }}
        </label>
    @empty
        <p class="muted small">You have no sections yet.</p>
    @endforelse
    @include('partials.field-error', ['field' => 'sections'])
</fieldset>

<datalist id="picture-names">
    @foreach ($c['pictures'] as $picture)
        <option value="{{ $picture }}">
    @endforeach
</datalist>
