{{-- One picture question: prompt, up to three choices, which one is right. $name = input prefix, $question = saved {prompt, choices, answer}. --}}
@php
    $saved = $question ?? [];
    $savedAnswer = collect($saved['choices'] ?? [])->search(fn ($c) => ($c['id'] ?? null) === ($saved['answer'] ?? null));
    $old = fn ($key, $default = null) => old(str_replace(['[', ']'], ['.', ''], $name).'.'.$key, $default);
@endphp
<label for="{{ $name }}-prompt">{{ $label }}</label>
<input id="{{ $name }}-prompt" type="text" name="{{ $name }}[prompt]" value="{{ $old('prompt', $saved['prompt'] ?? '') }}" maxlength="200" {{ $required ? 'required' : '' }}>
<table class="small" style="margin-top: .4rem;">
    <thead><tr><th>Right?</th><th>Answer choice</th><th>Picture</th></tr></thead>
    <tbody>
    @for ($k = 0; $k < 3; $k++)
        <tr>
            <td><input type="radio" name="{{ $name }}[answer]" value="{{ $k }}" @checked((string) $old('answer', $savedAnswer === false ? null : $savedAnswer) === (string) $k) aria-label="Choice {{ $k + 1 }} is right"></td>
            <td><input type="text" name="{{ $name }}[choices][{{ $k }}][label]" value="{{ $old("choices.$k.label", $saved['choices'][$k]['label'] ?? '') }}" maxlength="60" aria-label="Choice {{ $k + 1 }}"></td>
            <td><input type="text" name="{{ $name }}[choices][{{ $k }}][picture]" value="{{ $old("choices.$k.picture", $saved['choices'][$k]['picture'] ?? '') }}" list="picture-names" aria-label="Picture for choice {{ $k + 1 }}"></td>
        </tr>
    @endfor
    </tbody>
</table>
