<?php

namespace App\Models;

use Database\Factories\StudentFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * A learner in a section. Their game state hangs off this row.
 * Create real students with App\Actions\EnrollStudent. `code` is the
 * pseudonym used in exports and logs (RA 10173).
 */
class Student extends Model
{
    /** @use HasFactory<StudentFactory> */
    use HasFactory;

    protected $fillable = ['section_id'];

    protected function casts(): array
    {
        return [
            'consent_recorded_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * @return BelongsTo<Section, $this>
     */
    public function section(): BelongsTo
    {
        return $this->belongsTo(Section::class);
    }

    /**
     * @return HasMany<BktState, $this>
     */
    public function bktStates(): HasMany
    {
        return $this->hasMany(BktState::class);
    }

    /**
     * @return HasOne<PathProgress, $this>
     */
    public function pathProgress(): HasOne
    {
        return $this->hasOne(PathProgress::class);
    }

    /**
     * @return HasOne<StudentWallet, $this>
     */
    public function wallet(): HasOne
    {
        return $this->hasOne(StudentWallet::class);
    }

    /**
     * @return HasMany<InterventionFlag, $this>
     */
    public function interventionFlags(): HasMany
    {
        return $this->hasMany(InterventionFlag::class);
    }

    /**
     * @return HasMany<SyncEvent, $this>
     */
    public function syncEvents(): HasMany
    {
        return $this->hasMany(SyncEvent::class);
    }

    /**
     * @return HasMany<StudentItem, $this>
     */
    public function items(): HasMany
    {
        return $this->hasMany(StudentItem::class);
    }

    /**
     * @return HasMany<DailyUsage, $this>
     */
    public function dailyUsage(): HasMany
    {
        return $this->hasMany(DailyUsage::class);
    }

    /** First name for the teacher's screens; exports and logs use `code` instead (RA 10173). */
    public function displayName(): string
    {
        return $this->user?->name ?? $this->code;
    }
}
