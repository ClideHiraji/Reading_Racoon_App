<?php

namespace App\Providers;

use App\Reports\DiagnosticReportWriter;
use App\Reports\TemplateReportWriter;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // The report seam (FR-05, D-012): bind GeminiReportWriter here in the LLM slice.
        $this->app->bind(DiagnosticReportWriter::class, TemplateReportWriter::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // A whole class signs in from one school Wi-Fi address (NAT), so the
        // per-IP login limit must fit ~40 children plus typos. Guessing one of
        // 31^8 codes at this rate is still hopeless. NFR-04.
        RateLimiter::for('login', fn (Request $request) => Limit::perMinute(60)->by($request->ip()));

        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(120)->by($request->user()?->id ?: $request->ip()));

        RateLimiter::for('sync', fn (Request $request) => Limit::perMinute(60)->by($request->user()?->id ?: $request->ip()));

        // Teacher web forms. The login controller also locks an email after 5 misses.
        RateLimiter::for('teacher-login', fn (Request $request) => Limit::perMinute(20)->by($request->ip()));
        RateLimiter::for('teacher-register', fn (Request $request) => Limit::perHour(10)->by($request->ip()));
    }
}
