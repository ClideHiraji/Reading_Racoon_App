<?php

namespace App\Support;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

/**
 * Chat completions on an OpenAI-compatible endpoint: Gemini's today
 * (D-002, docs/knowledge/08-ai-integration.md). Changing provider means
 * changing LLM_BASE_URL, LLM_API_KEY and LLM_MODEL only. Laravel is the only
 * caller; the key never reaches the game.
 */
final class LlmClient
{
    /** All three of base URL, key and model are set. */
    public static function enabled(): bool
    {
        return filled(config('services.llm.base_url')) && filled(config('services.llm.key')) && filled(config('services.llm.model'));
    }

    public static function model(): string
    {
        return (string) config('services.llm.model');
    }

    /**
     * @param  list<array{role: string, content: string}>  $messages
     * @return array{text: ?string, finish_reason: ?string, prompt_tokens: ?int, completion_tokens: ?int}
     *
     * @throws LlmException on an HTTP error, timeout or unreadable reply
     */
    public function chat(array $messages, float $temperature, int $maxTokens, int $timeoutSeconds): array
    {
        $body = [
            'model' => self::model(),
            'messages' => $messages,
            'temperature' => $temperature,
            'max_tokens' => $maxTokens,
        ];
        if (filled(config('services.llm.reasoning_effort'))) {
            $body['reasoning_effort'] = config('services.llm.reasoning_effort');
        }

        try {
            $response = Http::baseUrl((string) config('services.llm.base_url'))
                ->withToken((string) config('services.llm.key'))
                ->acceptJson()
                ->timeout($timeoutSeconds)
                ->post('chat/completions', $body);
        } catch (ConnectionException $e) {
            throw new LlmException('connection: '.$e->getMessage());
        }

        if ($response->failed()) {
            // The error body never holds the key; keep it short for ai_logs.
            $message = $response->json('error.message') ?? $response->json('0.error.message') ?? '';
            throw new LlmException(trim('HTTP '.$response->status().' '.(is_string($message) ? $message : '')), $response->status());
        }

        $choice = $response->json('choices.0');
        if (! is_array($choice)) {
            throw new LlmException('reply without choices');
        }
        $text = $choice['message']['content'] ?? null;

        return [
            'text' => is_string($text) ? $text : null,
            'finish_reason' => is_string($choice['finish_reason'] ?? null) ? $choice['finish_reason'] : null,
            'prompt_tokens' => is_int($response->json('usage.prompt_tokens')) ? $response->json('usage.prompt_tokens') : null,
            'completion_tokens' => is_int($response->json('usage.completion_tokens')) ? $response->json('usage.completion_tokens') : null,
        ];
    }
}
