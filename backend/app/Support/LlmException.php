<?php

namespace App\Support;

use RuntimeException;

/**
 * An LLM call that got no usable reply: HTTP error (with its status), timeout
 * or a malformed body. The message goes to ai_logs.error, so it must never
 * contain the API key.
 */
final class LlmException extends RuntimeException
{
    public function __construct(string $message, public readonly ?int $status = null)
    {
        parent::__construct(mb_substr($message, 0, 255));
    }

    /**
     * Worth another attempt: timeouts, rate limits (429) and server errors.
     * A bad key, model id or request (other 4xx) fails the same way every time.
     */
    public function retryable(): bool
    {
        return $this->status === null || $this->status === 429 || $this->status >= 500;
    }
}
