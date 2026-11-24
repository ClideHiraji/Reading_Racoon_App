<?php

namespace Tests\Feature\Teacher;

use App\Actions\EnrollStudent;
use App\Models\AuditLog;
use App\Models\ContentFile;
use App\Models\ContentItem;
use App\Models\Section;
use App\Models\Student;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Library & Videos (D-019, game D-017): teachers add openly licensed books and
 * Ogg videos, and the tablets of the assigned sections download them from
 * GET /api/content/manifest and /api/content/files/{id}.
 */
class ContentLibraryTest extends TestCase
{
    use RefreshDatabase;

    /** A real 1x1 PNG (the test PHP has no GD to draw one). */
    private const PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

    private User $teacher;

    private Section $section;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');

        $this->teacher = User::factory()->registered()->create();
        $this->section = $this->teacher->sections()->create(['name' => 'Grade 1 - Sampaguita']);
        $this->student = app(EnrollStudent::class)->handle($this->section, 'Ana')['student'];
    }

    private function bookPayload(array $overrides = []): array
    {
        return array_replace_recursive([
            'title' => 'Ang Bangka ni Lolo', 'language' => 'fil', 'level' => 'easy', 'cover' => 'river',
            'credit' => 'Ang Bangka ni Lolo by A. Writer, Pratham Books, CC BY 4.0', 'licence' => 'CC BY 4.0',
            'source_url' => 'https://storyweaver.org.in/stories/1234',
            'words' => "bangka = boat\nisda = fish",
            'sections' => [$this->section->id],
            'pages' => [
                ['text' => 'May bangka si Lolo.', 'scene' => 'river', 'pictures' => 'boat, raccoon'],
                ['text' => '', 'scene' => 'river', 'pictures' => ''],
                ['text' => 'Nakakita siya ng isda.', 'scene' => 'bay', 'pictures' => 'fish'],
            ],
            'questions' => [
                ['prompt' => 'Ano ang mayroon si Lolo?', 'answer' => 0,
                    'choices' => [['label' => 'bangka', 'picture' => 'boat'], ['label' => 'bus', 'picture' => 'bus'], ['label' => '']]],
                ['prompt' => 'Ano ang nakita niya?', 'answer' => 1,
                    'choices' => [['label' => 'pusa', 'picture' => 'cat'], ['label' => 'isda', 'picture' => 'fish']]],
            ],
        ], $overrides);
    }

    private function videoPayload(array $overrides = []): array
    {
        return array_replace_recursive([
            'title' => 'Mga Hayop sa Bukid', 'language' => 'fil', 'scene' => 'grove', 'minutes' => 3,
            'credit' => 'Mga Hayop by B. Maker, CC BY 4.0', 'licence' => 'CC BY 4.0',
            'source_url' => 'https://example.org/videos/hayop', 'sections' => [$this->section->id],
            'file' => UploadedFile::fake()->createWithContent('hayop.ogv', 'OggS'.str_repeat("\x01\x02", 2000)),
            'check' => ['prompt' => 'Alin ang aso?', 'answer' => 0, 'choices' => [['label' => 'aso', 'picture' => 'dog'], ['label' => 'pusa', 'picture' => 'cat']]],
        ], $overrides);
    }

    private function manifest()
    {
        Sanctum::actingAs($this->student->user);

        return $this->getJson('/api/content/manifest')->assertOk();
    }

    public function test_a_book_needs_an_open_licence_a_source_and_known_pictures(): void
    {
        $this->actingAs($this->teacher);

        $this->post(route('teacher.content.books.store'), $this->bookPayload(['licence' => '', 'source_url' => '']))
            ->assertSessionHasErrors(['licence', 'source_url']);
        $this->post(route('teacher.content.books.store'), $this->bookPayload(['licence' => 'All rights reserved']))
            ->assertSessionHasErrors('licence');
        $this->post(route('teacher.content.books.store'), $this->bookPayload(['pages' => [0 => ['pictures' => 'boat, unicorn']]]))
            ->assertSessionHasErrors('pages.0.pictures');
        $this->post(route('teacher.content.books.store'), $this->bookPayload(['questions' => [0 => ['answer' => 2]]]))
            ->assertSessionHasErrors('questions.0.answer');
        $this->post(route('teacher.content.books.store'), $this->bookPayload(['words' => 'bangka = spaceship']))
            ->assertSessionHasErrors('words');

        $this->assertDatabaseCount('content_items', 0);
    }

    public function test_a_book_with_no_section_cannot_be_published(): void
    {
        $this->actingAs($this->teacher);
        $payload = $this->bookPayload();
        unset($payload['sections']);
        $this->post(route('teacher.content.books.store'), $payload)->assertRedirect(route('teacher.content.index'));
        $item = ContentItem::sole();

        $this->post(route('teacher.content.publish', $item), ['published' => 1])->assertSessionHasErrors('published');
        $this->assertFalse($item->fresh()->published);
    }

    public function test_a_published_book_reaches_its_sections_tablets_in_the_games_shape(): void
    {
        $this->actingAs($this->teacher);
        $payload = $this->bookPayload();
        $payload['pages'][2]['image'] = UploadedFile::fake()->createWithContent('page.png', base64_decode(self::PNG));

        $this->post(route('teacher.content.books.store'), $payload)->assertRedirect(route('teacher.content.index'));
        $item = ContentItem::sole();
        $this->assertMatchesRegularExpression('/^tb-[a-z0-9]{8}$/', $item->id);
        $this->assertSame([$this->section->id], $item->sections()->pluck('sections.id')->all());

        // A draft never reaches the tablets.
        $this->assertSame([], $this->manifest()->json('books'));

        $this->actingAs($this->teacher)->post(route('teacher.content.publish', $item), ['published' => 1])->assertRedirect();
        $response = $this->manifest()->assertJsonStructure(['version', 'books', 'watch', 'server_time']);
        $book = $response->json('books.0');

        $this->assertSame(['id', 'title', 'language', 'level', 'cover', 'credit', 'licence', 'source_url', 'words', 'pages', 'questions'], array_keys($book));
        $this->assertSame(['fil', 'easy', 'river', 'CC BY 4.0'], [$book['language'], $book['level'], $book['cover'], $book['licence']]);
        $this->assertSame([['word' => 'bangka', 'picture' => 'boat'], ['word' => 'isda', 'picture' => 'fish']], $book['words']);
        $this->assertCount(2, $book['pages'], 'the empty page slot is dropped');
        $this->assertSame(['text' => 'May bangka si Lolo.', 'scene' => 'river', 'pictures' => ['boat', 'raccoon']], $book['pages'][0]);
        $image = ContentFile::sole();
        $this->assertSame(1, $image->page_index, 'the picture moved with its page');
        $this->assertSame('/api/content/files/'.$image->id, $book['pages'][1]['image_url']);
        $this->assertSame('user://content/'.$image->id.'.png', $book['pages'][1]['image']);
        $this->assertSame(
            ['prompt' => 'Ano ang mayroon si Lolo?', 'choices' => [['id' => 'bangka', 'label' => 'bangka', 'picture' => 'boat'], ['id' => 'bus', 'label' => 'bus', 'picture' => 'bus']], 'answer' => 'bangka'],
            $book['questions'][0]);
        $this->assertSame('isda', $book['questions'][1]['answer']);
        $this->assertSame(['content.create', 'content.publish'], AuditLog::orderBy('id')->pluck('action')->intersect(['content.create', 'content.publish'])->values()->all());
    }

    public function test_the_manifest_version_changes_with_the_set_and_supports_if_none_match(): void
    {
        $this->actingAs($this->teacher)->post(route('teacher.content.books.store'), $this->bookPayload());
        $item = ContentItem::sole();
        $item->forceFill(['published' => true])->save();

        $version = $this->manifest()->json('version');
        $this->getJson('/api/content/manifest', ['If-None-Match' => '"'.$version.'"'])->assertStatus(304);

        $this->actingAs($this->teacher)->put(route('teacher.content.assign', $item), ['sections' => []])->assertRedirect();
        $empty = $this->manifest();
        $this->assertNotSame($version, $empty->json('version'));
        $this->assertSame([], $empty->json('books'));
    }

    public function test_a_video_must_be_ogg_and_downloads_with_its_sha256(): void
    {
        $this->actingAs($this->teacher);
        $this->post(route('teacher.content.videos.store'), $this->videoPayload(['file' => UploadedFile::fake()->createWithContent('clip.mp4', 'ftypisom')]))
            ->assertSessionHasErrors('file');
        $this->post(route('teacher.content.videos.store'), $this->videoPayload(['file' => UploadedFile::fake()->createWithContent('clip.ogv', 'RIFF....')]))
            ->assertSessionHasErrors('file');
        config(['reading_racoon.content.max_video_mb' => 1]);
        $this->post(route('teacher.content.videos.store'), $this->videoPayload(['file' => UploadedFile::fake()->createWithContent('big.ogv', 'OggS'.str_repeat('x', 1100 * 1024))]))
            ->assertSessionHasErrors('file');
        config(['reading_racoon.content.max_video_mb' => 50]);

        $upload = $this->videoPayload();
        $expectedSha = hash_file('sha256', $upload['file']->getRealPath());
        $this->post(route('teacher.content.videos.store'), $upload)->assertRedirect(route('teacher.content.index'));
        $item = ContentItem::sole();
        $this->assertMatchesRegularExpression('/^tv-[a-z0-9]{8}$/', $item->id);
        $file = ContentFile::sole();
        Storage::disk('local')->assertExists($file->path);
        $this->assertSame('content/'.$file->id.'.ogv', $file->path, 'random name, no learner or teacher data');

        $this->post(route('teacher.content.publish', $item), ['published' => 1]);
        $video = $this->manifest()->json('watch.0');
        $this->assertSame([
            'id' => $item->id, 'kind' => 'video', 'title' => 'Mga Hayop sa Bukid', 'language' => 'fil', 'scene' => 'grove',
            'minutes' => 3, 'credit' => 'Mga Hayop by B. Maker, CC BY 4.0', 'licence' => 'CC BY 4.0',
            'source_url' => 'https://example.org/videos/hayop', 'file' => 'user://content/'.$item->id.'.ogv',
            'file_url' => '/api/content/files/'.$file->id, 'size_bytes' => 4004, 'sha256' => $expectedSha,
            'check' => ['prompt' => 'Alin ang aso?', 'choices' => [['id' => 'aso', 'label' => 'aso', 'picture' => 'dog'], ['id' => 'pusa', 'label' => 'pusa', 'picture' => 'cat']], 'answer' => 'aso'],
        ], $video);

        $download = $this->get($video['file_url'])->assertOk();
        $this->assertSame($expectedSha, $download->headers->get('X-Content-SHA256'));
        $this->assertSame('video/ogg', $download->headers->get('Content-Type'));
        $this->assertSame($expectedSha, hash_file('sha256', $download->baseResponse->getFile()->getPathname()));
    }

    public function test_files_need_a_student_token_from_an_assigned_section(): void
    {
        $this->actingAs($this->teacher)->post(route('teacher.content.videos.store'), $this->videoPayload());
        $item = ContentItem::sole();
        $file = ContentFile::sole();
        $url = '/api/content/files/'.$file->id;

        // Not published yet.
        Sanctum::actingAs($this->student->user);
        $this->getJson($url)->assertNotFound();

        $item->forceFill(['published' => true])->save();
        $this->getJson($url)->assertOk();
        $this->getJson('/api/content/files/not-a-uuid')->assertNotFound();
        $this->getJson('/api/content/files/'.Str::uuid())->assertNotFound();

        $other = app(EnrollStudent::class)->handle(Section::factory()->create(), 'Ben')['student'];
        Sanctum::actingAs($other->user);
        $this->getJson($url)->assertNotFound();
        $this->assertSame([], $this->getJson('/api/content/manifest')->json('watch'));

        Sanctum::actingAs($this->teacher);
        $this->getJson($url)->assertForbidden();

        $this->app['auth']->forgetGuards();
        $this->getJson($url)->assertUnauthorized();
    }

    public function test_teachers_only_manage_their_own_items_and_sections(): void
    {
        $this->actingAs($this->teacher)->post(route('teacher.content.books.store'), $this->bookPayload());
        $item = ContentItem::sole();
        $other = User::factory()->registered()->create();
        $otherSection = $other->sections()->create(['name' => 'Grade 1 - Rosal']);

        $this->put(route('teacher.content.assign', $item), ['sections' => [$otherSection->id]])->assertSessionHasErrors('sections.0');

        $this->actingAs($other);
        $this->get(route('teacher.content.edit', $item))->assertNotFound();
        $this->post(route('teacher.content.publish', $item), ['published' => 1])->assertNotFound();
        $this->delete(route('teacher.content.destroy', $item))->assertNotFound();
        $this->get(route('teacher.content.index'))->assertOk()->assertDontSee('Ang Bangka ni Lolo');
        $this->assertFalse($item->fresh()->published);
    }

    public function test_editing_a_book_moves_its_pictures_and_deleting_removes_the_files(): void
    {
        $this->actingAs($this->teacher);
        $payload = $this->bookPayload();
        $payload['pages'][2]['image'] = UploadedFile::fake()->createWithContent('page.png', base64_decode(self::PNG));
        $this->post(route('teacher.content.books.store'), $payload);
        $item = ContentItem::sole();
        $this->get(route('teacher.content.edit', $item))->assertOk()->assertSee('Current picture')->assertSee('May bangka si Lolo.');

        // The edit form shows the two pages in slots 0 and 1; the first page is now emptied.
        $edit = $this->bookPayload(['pages' => [
            ['text' => '', 'scene' => 'river', 'pictures' => ''],
            ['text' => 'Nakakita siya ng isda.', 'scene' => 'bay', 'pictures' => 'fish'],
            ['text' => '', 'scene' => 'river', 'pictures' => ''],
        ]]);
        $this->put(route('teacher.content.update', $item), $edit)->assertRedirect(route('teacher.content.index'));
        $file = ContentFile::sole();
        $this->assertSame(0, $file->page_index);
        $this->assertSame(['Nakakita siya ng isda.'], array_column($item->fresh()->body['pages'], 'text'));

        $this->delete(route('teacher.content.destroy', $item))->assertRedirect(route('teacher.content.index'));
        Storage::disk('local')->assertMissing($file->path);
        $this->assertDatabaseCount('content_items', 0);
        $this->assertDatabaseCount('content_files', 0);
    }

    public function test_the_library_pages_render(): void
    {
        $this->actingAs($this->teacher);
        $this->get(route('teacher.content.index'))->assertOk()->assertSee('Library &amp; Videos', false)->assertSee('openly licensed');
        $this->get(route('teacher.content.books.create'))->assertOk()->assertSee('picture-names', false)->assertSee('Page 12');
        $this->get(route('teacher.content.videos.create'))->assertOk()->assertSee('ffmpeg');
        $this->get(route('teacher.sections.show', $this->section))->assertSee(route('teacher.content.index'), false);
    }
}
