@if (session('status'))
    <div class="alert alert-ok" role="status">{{ session('status') }}</div>
@endif
@if (session('warning'))
    <div class="alert alert-warn" role="status">{{ session('warning') }}</div>
@endif
@if ($errors->any() && ! ($hideErrorSummary ?? false))
    <div class="alert alert-error" role="alert">
        @foreach ($errors->all() as $error)
            <div>{{ $error }}</div>
        @endforeach
    </div>
@endif
