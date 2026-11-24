@extends('layouts.admin')
@section('title', ['audit' => 'Audit log', 'ai' => 'AI calls'][$kind] ?? 'System log')

@section('content')
<div class="page-head">
    <div>
        <h1>Logs</h1>
        <p class="meta">Times are {{ $timezone }}. Highlighted rows are anomalies (system), sensitive actions (audit) or failed calls (AI), and say so in the row.</p>
    </div>
    @if ($kind === 'system')
        @php($max = max(1, $anomalyDays->max() ?? 1))
        @php($days = collect(range(13, 0))->map(fn ($back) => now()->setTimezone($timezone)->subDays($back)->format('Y-m-d')))
        <div style="min-width: 260px;">
            <div class="small muted" id="spark-title">Anomalies per day, last 14 days ({{ $days->sum(fn ($d) => $anomalyDays[$d] ?? 0) }} in all)</div>
            <div class="spark" role="img" aria-labelledby="spark-title" aria-describedby="spark-values">
                @foreach ($days as $day)
                    <span @class(['is-zero' => ($anomalyDays[$day] ?? 0) === 0]) title="{{ $day }}: {{ $anomalyDays[$day] ?? 0 }}" style="height: {{ round(100 * ($anomalyDays[$day] ?? 0) / $max) }}%"></span>
                @endforeach
            </div>
            <div class="day-hours" aria-hidden="true"><span>{{ \Carbon\Carbon::parse($days->first())->format('M j') }}</span><span>max {{ $max }}</span><span>today</span></div>
            <p class="sr-only" id="spark-values">{{ $days->filter(fn ($d) => ($anomalyDays[$d] ?? 0) > 0)->map(fn ($d) => $d.': '.$anomalyDays[$d])->join('; ') ?: 'None.' }}</p>
        </div>
    @endif
</div>

<nav class="tabs" aria-label="Log type">
    <a href="{{ route('admin.logs', ['kind' => 'system']) }}" @if ($kind === 'system') aria-current="page" @endif>System log</a>
    <a href="{{ route('admin.logs', ['kind' => 'audit']) }}" @if ($kind === 'audit') aria-current="page" @endif>Audit log</a>
    <a href="{{ route('admin.logs', ['kind' => 'ai']) }}" @if ($kind === 'ai') aria-current="page" @endif>AI calls</a>
</nav>

<form method="GET" action="{{ route('admin.logs') }}" class="panel">
    <input type="hidden" name="kind" value="{{ $kind }}">
    <div class="field-row" style="grid-template-columns: repeat(auto-fit, minmax(min(100%, 160px), 1fr));">
        <div>
            <label for="event">{{ ['audit' => 'Action', 'ai' => 'Task'][$kind] ?? 'Event' }}</label>
            <select id="event" name="event">
                <option value="">All</option>
                @foreach ($events as $event)
                    <option value="{{ $event }}" @selected(($filters['event'] ?? '') === $event)>{{ $event }}</option>
                @endforeach
            </select>
        </div>
        @if ($kind === 'system')
            <div>
                <label for="level">Level</label>
                <select id="level" name="level">
                    <option value="">All</option>
                    @foreach (['info', 'warning', 'error', 'critical'] as $level)
                        <option value="{{ $level }}" @selected(($filters['level'] ?? '') === $level)>{{ $level }}</option>
                    @endforeach
                </select>
            </div>
        @elseif ($kind === 'ai')
            <div>
                <label for="status">Status</label>
                <select id="status" name="status">
                    <option value="">All</option>
                    @foreach (['ok', 'invalid', 'blocked', 'error'] as $status)
                        <option value="{{ $status }}" @selected(($filters['status'] ?? '') === $status)>{{ $status }}</option>
                    @endforeach
                </select>
            </div>
        @endif
        <div><label for="from">From</label><input id="from" type="date" name="from" value="{{ $filters['from'] ?? '' }}"></div>
        <div><label for="to">To</label><input id="to" type="date" name="to" value="{{ $filters['to'] ?? '' }}"></div>
        <div><label for="q">Search</label><input id="q" type="text" name="q" value="{{ $filters['q'] ?? '' }}" placeholder="{{ ['audit' => 'Actor, subject or IP', 'ai' => 'Code, model or error'][$kind] ?? 'IP or text' }}"></div>
    </div>
    <div class="row" style="margin-top: .75rem;">
        <label class="check is-plain" style="margin: 0 var(--s3) 0 0;"><input type="checkbox" name="anomaly" value="1" @checked($filters['anomaly'] ?? false)> {{ ['audit' => 'Sensitive actions only', 'ai' => 'Failed calls only'][$kind] ?? 'Anomalies only' }}</label>
        @if ($kind === 'audit')
            <label class="check is-plain" style="margin: 0 var(--s3) 0 0;"><input type="checkbox" name="views" value="1" @checked($filters['views'] ?? false)> Include page views</label>
        @endif
        <button class="btn" type="submit">Apply filters</button>
        <a class="btn btn-secondary" href="{{ route('admin.logs', ['kind' => $kind]) }}">Clear</a>
    </div>
</form>

<div class="panel">
    @if ($logs->isEmpty())
        <p class="muted">{{ match ($kind) { 'ai' => \App\Support\LlmClient::enabled() ? 'No AI calls match.' : 'No AI calls: the AI is off, so reports use the built-in template.', 'audit' => 'No actions match.', default => 'No events match these filters.' } }}</p>
    @else
        <div class="table-wrap">
            <table class="compact">
                @if ($kind === 'audit')
                    <thead><tr><th>When</th><th>Actor</th><th>Action</th><th>Subject</th><th>Details</th><th>IP</th></tr></thead>
                    <tbody>
                    @foreach ($logs as $log)
                        <tr @class(['anomaly' => in_array($log->action, $sensitive, true)])>
                            <td style="white-space: nowrap;">{{ $log->created_at->setTimezone($timezone)->format('M j, g:i:s A') }}</td>
                            <td>{{ $log->actor_label ?? 'console' }}<div class="muted">{{ $log->actor_role }}</div></td>
                            <td><span class="badge">{{ $log->action }}</span> @if (in_array($log->action, $sensitive, true))<span class="badge badge-red">sensitive</span>@endif</td>
                            <td>{{ $log->subject_type }} {{ $log->subject_id }}</td>
                            <td>@if ($log->details)<pre class="json">{{ json_encode($log->details, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) }}</pre>@endif</td>
                            <td>{{ $log->ip }}</td>
                        </tr>
                    @endforeach
                    </tbody>
                @elseif ($kind === 'ai')
                    <thead><tr><th>When</th><th>Task</th><th>Learner</th><th>Model</th><th>Status</th><th>Latency</th><th>Tokens</th><th>Input and reply</th></tr></thead>
                    <tbody>
                    @foreach ($logs as $log)
                        <tr @class(['anomaly' => $log->status !== 'ok'])>
                            <td style="white-space: nowrap;">{{ $log->created_at->setTimezone($timezone)->format('M j, g:i:s A') }}</td>
                            <td>{{ $log->task }}<div class="muted">{{ $log->prompt_version }}</div></td>
                            <td>{{ $log->student?->code ?? '-' }}</td>
                            <td>{{ $log->model }}</td>
                            <td>
                                <span @class(['badge', 'badge-red' => in_array($log->status, ['error', 'blocked'], true), 'badge-amber' => $log->status === 'invalid'])>{{ $log->status }}</span>
                                @if ($log->error)<div class="muted">{{ $log->error }}</div>@endif
                            </td>
                            <td style="white-space: nowrap;">{{ number_format($log->latency_ms) }} ms</td>
                            <td>{{ $log->prompt_tokens ?? '-' }} / {{ $log->completion_tokens ?? '-' }}</td>
                            <td>
                                <details><summary>Input JSON</summary><pre class="json">{{ json_encode($log->input, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) }}</pre></details>
                                @if ($log->output !== null)<details><summary>Reply</summary><pre class="json">{{ $log->output }}</pre></details>@endif
                            </td>
                        </tr>
                    @endforeach
                    </tbody>
                @else
                    <thead><tr><th>When</th><th>Level</th><th>Event</th><th>Context</th><th>IP</th></tr></thead>
                    <tbody>
                    @foreach ($logs as $log)
                        <tr @class(['anomaly' => $log->anomaly])>
                            <td style="white-space: nowrap;">{{ $log->created_at->setTimezone($timezone)->format('M j, g:i:s A') }}</td>
                            <td><span @class(['badge', 'badge-red' => in_array($log->level, ['error', 'critical']), 'badge-amber' => $log->level === 'warning'])>{{ $log->level }}</span></td>
                            <td>{{ $log->event }} @if ($log->anomaly)<span class="badge badge-red">anomaly</span>@endif</td>
                            <td>@if ($log->context)<pre class="json">{{ json_encode($log->context, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) }}</pre>@endif</td>
                            <td>{{ $log->ip }}</td>
                        </tr>
                    @endforeach
                    </tbody>
                @endif
            </table>
        </div>
        <div class="pager">{{ $logs->links('admin.partials.pager') }}</div>
    @endif
</div>
@endsection
