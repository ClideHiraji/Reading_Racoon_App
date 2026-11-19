@if ($paginator->hasPages())
    @if ($paginator->onFirstPage())
        <span class="btn btn-light btn-sm" aria-disabled="true">Newer</span>
    @else
        <a class="btn btn-light btn-sm" href="{{ $paginator->previousPageUrl() }}" rel="prev">Newer</a>
    @endif
    <span class="muted small">Page {{ $paginator->currentPage() }} of {{ $paginator->lastPage() }}</span>
    @if ($paginator->hasMorePages())
        <a class="btn btn-light btn-sm" href="{{ $paginator->nextPageUrl() }}" rel="next">Older</a>
    @else
        <span class="btn btn-light btn-sm" aria-disabled="true">Older</span>
    @endif
@endif
