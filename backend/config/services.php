<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    // Gemini through its OpenAI-compatible endpoint, called only from Laravel
    // (docs/knowledge/08-ai-integration.md, D-002, D-018). Off until all three are set.
    'llm' => [
        'base_url' => env('LLM_BASE_URL'),
        'key' => env('LLM_API_KEY'),
        'model' => env('LLM_MODEL'),
        // Sent as reasoning_effort when set, to limit Gemini's "thinking" (which
        // adds latency and uses up max_tokens). Allowed values depend on the model.
        'reasoning_effort' => env('LLM_REASONING_EFFORT'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

];
