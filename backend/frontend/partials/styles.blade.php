{{-- Shared stylesheet and script for the teacher and admin pages: static files on this host
(no build step, nothing from other hosts), versioned so a change reaches browsers at once
and stays cached until then. --}}
@php($asset = fn (string $path) => asset($path).'?v='.(@filemtime(public_path($path)) ?: '1'))
<link rel="icon" href="{{ $asset('favicon.ico') }}" sizes="32x32">
<link rel="icon" href="{{ $asset('favicon.svg') }}" type="image/svg+xml">
<link rel="stylesheet" href="{{ $asset('css/portal.css') }}">
<script src="{{ $asset('js/portal.js') }}" defer></script>
