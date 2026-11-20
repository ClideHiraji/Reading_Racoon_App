@if (session('status'))
    <div class="alert alert-ok" role="status">
        <p>{{ session('status') }}</p>
        @if (($undo = session('undo_flag')) && Route::has('teacher.flags.reopen'))
            {{-- Undo for "Mark resolved" (FR-17): the flag opens again. --}}
            <form method="POST" action="{{ route('teacher.flags.reopen', $undo) }}">
                @csrf
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
