{{-- One picture question: prompt, up to three choices, which one is right. $name = input prefix, $question = saved {prompt, choices, answer}. --}}
@php
    $saved = $question ?? [];
    $savedAnswer = collect($saved['choices'] ?? [])->search(fn ($c) => ($c['id'] ?? null) === ($saved['answer'] ?? null));
    $old = fn ($key, $default = null) => old(str_replace(['[', ']'], ['.', ''], $name).'.'.$key, $default);
    $id = str_replace(['[', ']'], ['-', ''], $name);
@endphp
<fieldset class="page-box">
    <legend>{{ $label }}{{ $required ? '' : ' (optional)' }}</legend>
    <label for="{{ $id }}-prompt" style="margin-top: var(--s2);">Question the child hears</label>
    <input id="{{ $id }}-prompt" type="text" name="{{ $name }}[prompt]" value="{{ $old('prompt', $saved['prompt'] ?? '') }}" maxlength="200" {{ $required ? 'required' : '' }}>
    <div class="table-wrap">
        <table class="compact choice-table" style="margin-top: var(--s2);">
            <thead><tr><th scope="col">Right answer</th><th scope="col">Answer choice</th><th scope="col">Picture</th></tr></thead>
            <tbody>
            @for ($k = 0; $k < 3; $k++)
                <tr>
                    <td><label style="margin: 0; display: inline-grid; place-items: center; min-width: 44px; min-height: 40px; cursor: pointer;"><input type="radio" name="{{ $name }}[answer]" value="{{ $k }}" @checked((string) $old('answer', $savedAnswer === false ? null : $savedAnswer) === (string) $k)><span class="sr-only">Choice {{ $k + 1 }} is the right answer</span></label></td>
                    <td><input type="text" name="{{ $name }}[choices][{{ $k }}][label]" value="{{ $old("choices.$k.label", $saved['choices'][$k]['label'] ?? '') }}" maxlength="60" aria-label="Choice {{ $k + 1 }}"></td>
                    <td><input type="text" name="{{ $name }}[choices][{{ $k }}][picture]" value="{{ $old("choices.$k.picture", $saved['choices'][$k]['picture'] ?? '') }}" list="picture-names" aria-label="Picture for choice {{ $k + 1 }}" placeholder="e.g. boat"></td>
                </tr>
            @endfor
            </tbody>
        </table>
    </div>
</fieldset>
