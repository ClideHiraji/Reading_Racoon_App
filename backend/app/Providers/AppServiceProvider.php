<?php

namespace App\Providers;

use App\Enums\RegistrationStatus;
use App\Models\SystemLog;
use App\Models\TeacherRegistration;
use App\Reports\DiagnosticReportWriter;
use App\Reports\StoredReportWriter;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Facades\View;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // The report seam (FR-05, D-012, D-018): pages show the stored Gemini
        // paragraphs; App\Jobs\WriteAiReport calls GeminiReportWriter.
        $this->app->bind(DiagnosticReportWriter::class, StoredReportWriter::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // On the internet the server is reached only at its https APP_URL
        // through the tunnel (D-036). Build every link and redirect from APP_URL,
        // never from the request's Host header, so a forged Host can't poison them.
        $url = (string) config('app.url');
        if ($this->app->isProduction() && str_starts_with($url, 'https://')) {
            URL::forceRootUrl($url);
            URL::forceScheme('https');
        }

        // Every tablet at a school signs in from one address (NAT), so the
        // per-IP login limit must fit two classes (~64 children) at once plus
        // their typos. Guessing one of 31^8 codes at this rate is still hopeless. FR-01, NFR-04.
        RateLimiter::for('login', fn (Request $request) => Limit::perMinute(300)->by($request->ip()));

        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(120)->by($request->user()?->id ?: $request->ip()));

        RateLimiter::for('sync', fn (Request $request) => Limit::perMinute(60)->by($request->user()?->id ?: $request->ip()));

        // Teacher web forms. The login controller also locks an email after 5 misses.
        RateLimiter::for('teacher-login', fn (Request $request) => Limit::perMinute(20)->by($request->ip()));
        RateLimiter::for('teacher-register', fn (Request $request) => Limit::perHour(10)->by($request->ip()));

        // The admin nav shows what is waiting (FR-08): registrations to review
        // and anomalies in the last 7 days. Two counts, signed-in admins only.
        View::composer('layouts.admin', function ($view) {
            if (! auth('admin')->check()) {
                return;
            }
            $view->with('navCounts', [
                'pending' => TeacherRegistration::where('status', RegistrationStatus::Pending)->count(),
                'anomalies' => SystemLog::where('anomaly', true)->where('created_at', '>=', now()->subDays(7))->count(),
            ]);
        });
    }
}
