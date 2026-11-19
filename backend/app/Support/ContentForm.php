<?php

namespace App\Support;

use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator as ValidatorInstance;

/**
 * Validates the teacher's book and video forms and turns them into the game's
 * JSON shapes (reading-racoon/content/library.json and watch.json), D-019.
 * Only openly licensed material: licence and source are required.
 */
final class ContentForm
{
    /**
     * @param  list<int>  $sectionIds  the teacher's own sections
     * @return array{attributes: array<string, mixed>, body: array<string, mixed>, slots: array<int, int>, sections: list<int>}
     *                                                                                                                          `slots` maps a page slot in the form to its page index
     */
    public static function book(Request $request, array $sectionIds): array
    {
        $c = config('reading_racoon.content');
        $validator = Validator::make($request->all(), self::common($sectionIds) + [
            'level' => ['required', Rule::in($c['levels'])],
            'cover' => ['required', Rule::in($c['scenes'])],
            'words' => ['nullable', 'string', 'max:2000'],
            'pages' => ['required', 'array', 'max:'.$c['max_pages']],
            'pages.*.text' => ['nullable', 'string', 'max:400'],
            'pages.*.scene' => ['nullable', Rule::in($c['scenes'])],
            'pages.*.pictures' => ['nullable', 'string', 'max:200'],
            'pages.*.image' => ['nullable', 'image', 'mimes:png,jpg,jpeg', 'max:'.$c['max_image_kb']],
            'pages.*.remove_image' => ['nullable', 'boolean'],
            'questions' => ['required', 'array', 'size:2'],
            'questions.*.prompt' => ['required', 'string', 'max:200'],
            'questions.*.choices' => ['required', 'array', 'max:3'],
            'questions.*.choices.*.label' => ['nullable', 'string', 'max:60'],
            'questions.*.choices.*.picture' => ['nullable', Rule::in($c['pictures'])],
            'questions.*.answer' => ['required', 'integer', 'between:0,2'],
        ], self::messages());

        $validator->after(function (ValidatorInstance $v) use ($request) {
            if (collect($request->input('pages', []))->filter(fn ($p) => filled($p['text'] ?? null))->isEmpty()) {
                $v->errors()->add('pages', 'Write the text of at least one page.');
            }
            foreach ($request->input('pages', []) as $i => $page) {
                if (self::badPictures($page['pictures'] ?? '') !== []) {
                    $v->errors()->add("pages.$i.pictures", 'Page '.($i + 1).': use picture names from the list ('.implode(', ', self::badPictures($page['pictures'])).' unknown).');
                }
            }
            foreach ($request->input('questions', []) as $q => $question) {
                self::checkQuestion($v, "questions.$q", $question, 'Question '.($q + 1));
            }
            self::words((string) $request->input('words', ''), $v);
        });
        $data = $validator->validate();

        $pages = [];
        $slots = [];
        foreach ($data['pages'] as $slot => $page) {
            if (! filled($page['text'] ?? null)) {
                continue;
            }
            $slots[$slot] = count($pages);
            $pages[] = [
                'text' => trim($page['text']),
                'scene' => $page['scene'] ?? $data['cover'],
                'pictures' => self::pictures($page['pictures'] ?? ''),
            ];
        }

        return [
            'attributes' => self::attributes($data) + ['level' => $data['level'], 'scene' => $data['cover'], 'minutes' => null],
            'body' => [
                'words' => self::words((string) ($data['words'] ?? '')),
                'pages' => $pages,
                'questions' => array_values(array_map(fn (array $q) => self::question($q), $data['questions'])),
            ],
            'slots' => $slots,
            'sections' => array_map('intval', $data['sections'] ?? []),
        ];
    }

    /**
     * @param  list<int>  $sectionIds
     * @return array{attributes: array<string, mixed>, body: array<string, mixed>, file: ?UploadedFile, sections: list<int>}
     */
    public static function video(Request $request, array $sectionIds, bool $creating): array
    {
        $c = config('reading_racoon.content');
        $validator = Validator::make($request->all(), self::common($sectionIds) + [
            'scene' => ['required', Rule::in($c['scenes'])],
            'minutes' => ['required', 'integer', 'between:1,60'],
            'file' => [$creating ? 'required' : 'nullable', 'file', 'max:'.($c['max_video_mb'] * 1024), self::oggRule()],
            'check' => ['nullable', 'array'],
            'check.prompt' => ['nullable', 'string', 'max:200'],
            'check.choices' => ['nullable', 'array', 'max:3'],
            'check.choices.*.label' => ['nullable', 'string', 'max:60'],
            'check.choices.*.picture' => ['nullable', Rule::in($c['pictures'])],
            'check.answer' => ['nullable', 'integer', 'between:0,2'],
        ], self::messages() + [
            'file.required' => 'Choose the video file (.ogv).',
            'file.max' => 'The video can be at most '.$c['max_video_mb'].' MB.',
            'file.uploaded' => 'The upload failed; the file may be bigger than the server allows.',
        ]);
        $validator->after(function (ValidatorInstance $v) use ($request) {
            if (filled($request->input('check.prompt'))) {
                self::checkQuestion($v, 'check', $request->input('check'), 'The check question');
            }
        });
        $data = $validator->validate();

        return [
            'attributes' => self::attributes($data) + ['level' => null, 'scene' => $data['scene'], 'minutes' => (int) $data['minutes']],
            'body' => filled($data['check']['prompt'] ?? null) ? ['check' => self::question($data['check'])] : [],
            'file' => $request->file('file'),
            'sections' => array_map('intval', $data['sections'] ?? []),
        ];
    }

    /**
     * Parses "word = picture" lines (picture optional) into [{word, picture}].
     *
     * @return list<array{word: string, picture?: string}>
     */
    public static function words(string $text, ?ValidatorInstance $validator = null): array
    {
        $words = [];
        foreach (preg_split('/\R/', $text) as $n => $line) {
            if (trim($line) === '') {
                continue;
            }
            [$word, $picture] = array_pad(array_map('trim', preg_split('/\s*[=,:]\s*/', $line, 2)), 2, '');
            if ($picture !== '' && ! in_array(strtolower($picture), config('reading_racoon.content.pictures'), true)) {
                $validator?->errors()->add('words', 'Line '.($n + 1).": \"{$picture}\" is not a picture name from the list.");
            }
            $words[] = array_filter(['word' => mb_substr($word, 0, 40), 'picture' => strtolower($picture)], fn ($v) => $v !== '');
        }
        if (count($words) > 12) {
            $validator?->errors()->add('words', 'Choose at most 12 key words.');
        }

        return array_slice($words, 0, 12);
    }

    /**
     * @param  list<int>  $sectionIds
     * @return array<string, mixed>
     */
    private static function common(array $sectionIds): array
    {
        $c = config('reading_racoon.content');

        return [
            'title' => ['required', 'string', 'max:150'],
            'language' => ['required', Rule::in(array_keys($c['languages']))],
            'credit' => ['required', 'string', 'max:500'],
            'licence' => ['required', Rule::in($c['licences'])],
            'source_url' => ['required', 'url:http,https', 'max:500'],
            'sections' => ['nullable', 'array'],
            'sections.*' => ['integer', Rule::in($sectionIds)],
        ];
    }

    /**
     * @return array<string, string>
     */
    private static function messages(): array
    {
        return [
            'licence.required' => 'Choose the open licence. Only openly licensed books and videos may be used.',
            'licence.in' => 'Choose one of the open licences in the list.',
            'source_url.required' => 'Give the link where you found it (for example StoryWeaver or Let\'s Read).',
            'credit.required' => 'Write the credit line: title, author, illustrator and source.',
        ];
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private static function attributes(array $data): array
    {
        return [
            'title' => trim($data['title']),
            'language' => $data['language'],
            'credit' => trim($data['credit']),
            'licence' => $data['licence'],
            'source_url' => $data['source_url'],
        ];
    }

    /**
     * One question in the game's shape: {prompt, choices [{id, label, picture?}], answer}.
     *
     * @param  array<string, mixed>  $q
     * @return array{prompt: string, choices: list<array<string, string>>, answer: string}
     */
    private static function question(array $q): array
    {
        $choices = [];
        $answer = '';
        foreach ($q['choices'] ?? [] as $k => $choice) {
            $label = trim((string) ($choice['label'] ?? ''));
            if ($label === '') {
                continue;
            }
            $id = Str::slug($label, '_') ?: 'choice_'.$k;
            while (in_array($id, array_column($choices, 'id'), true)) {
                $id .= '_'.$k;
            }
            $choices[] = array_filter(['id' => $id, 'label' => $label, 'picture' => $choice['picture'] ?? null]);
            if ((int) $q['answer'] === (int) $k) {
                $answer = $id;
            }
        }

        return ['prompt' => trim($q['prompt']), 'choices' => $choices, 'answer' => $answer];
    }

    /**
     * @param  mixed  $question
     */
    private static function checkQuestion(ValidatorInstance $v, string $key, $question, string $name): void
    {
        $choices = collect(is_array($question) ? ($question['choices'] ?? []) : []);
        $filled = $choices->filter(fn ($c) => filled($c['label'] ?? null));
        if ($filled->count() < 2) {
            $v->errors()->add("$key.choices", "$name needs at least two answer choices.");
        }
        $answer = is_array($question) ? ($question['answer'] ?? null) : null;
        if ($answer === null || ! $filled->has((int) $answer)) {
            $v->errors()->add("$key.answer", "$name: mark which choice is right.");
        }
    }

    /**
     * @return list<string>
     */
    private static function pictures(?string $text): array
    {
        return array_values(array_filter(array_map(fn ($p) => strtolower(trim($p)), preg_split('/[\s,]+/', (string) $text))));
    }

    /**
     * @return list<string>
     */
    private static function badPictures(?string $text): array
    {
        return array_values(array_diff(self::pictures($text), config('reading_racoon.content.pictures')));
    }

    /** An Ogg file (Theora video) by extension and its "OggS" magic bytes. */
    private static function oggRule(): \Closure
    {
        return function (string $attribute, mixed $value, \Closure $fail) {
            $ok = $value instanceof UploadedFile && $value->isValid()
                && strtolower($value->getClientOriginalExtension()) === 'ogv'
                && file_get_contents($value->getRealPath(), false, null, 0, 4) === 'OggS';
            if (! $ok) {
                $fail('Upload an Ogg Theora video (.ogv), the format the game plays. Convert MP4 first, for example with ffmpeg.');
            }
        };
    }
}
