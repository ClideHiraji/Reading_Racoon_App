<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Checks only the batch envelope. Each event is validated on its own by
 * App\Actions\RecordSyncEvents so one bad event can't block the queue.
 */
class SyncRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'events' => ['present', 'array', 'list', 'max:'.config('reading_racoon.sync.max_batch')],
        ];
    }
}
