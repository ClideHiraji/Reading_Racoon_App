@if (session('status'))
    <div class="alert alert-ok" role="status">
        <p>{{ session('status') }}</p>
        {{-- Undo for "Mark resolved" (one or many) and for recording consent (FR-17, D-037). --}}
        @if (($undo = session('undo_flag')) && Route::has('teacher.flags.reopen'))
            <form method="POST" action="{{ route('teacher.flags.reopen', $undo) }}">
                @csrf
                <button class="btn btn-secondary btn-sm" type="submit">Undo</button>
            </form>
        @elseif (($undoMany = session('undo_flags')) && Route::has('teacher.flags.reopen-many'))
            <form method="POST" action="{{ route('teacher.flags.reopen-many') }}">
                @csrf
                @foreach ($undoMany as $id)
                    <input type="hidden" name="ids[]" value="{{ $id }}">
                @endforeach
                <button class="btn btn-secondary btn-sm" type="submit">Undo</button>
            </form>
        @elseif (($undoConsent = session('undo_consent')) && Route::has('teacher.students.consent'))
            <form method="POST" action="{{ route('teacher.students.consent', $undoConsent) }}">
                @csrf
                <input type="hidden" name="consent" value="0">
                <button class="btn btn-secondary btn-sm" type="submit">Undo</button>
            </form>
        @endif
    </div>
@endif
@if (session('warning'))
    <div class="alert alert-warn" role="status"><p>{{ session('warning') }}</p></div>
@endif
@if ($errors->any() && ! ($hideErrorSummary ?? false))
    <div class="alert alert-error" role="alert">
        <div>
            <p><strong>{{ $errors->count() === 1 ? 'Please fix this:' : 'Please fix these '.$errors->count().' things:' }}</strong></p>
            <ul>
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </div>
    </div>
@endif
