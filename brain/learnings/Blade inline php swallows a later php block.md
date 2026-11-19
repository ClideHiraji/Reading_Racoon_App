---
type: learning
date: 2026-10-20
tags: [learning, laravel, blade]
---

# Blade inline php swallows a later php block

What happened: the student profile page threw `ParseError: unexpected token "endif"`. The view used an inline `@php($x = ...)` inside a loop, and further down a `@php ... @endphp` block. Blade first pulls out raw blocks with a lazy regex from `@php` to the next `@endphp`, so it matched from the **inline** `@php(` all the way to the later `@endphp` and turned everything in between (including `@if`/`@endif`) into raw PHP.

**So:** in one template, keep every `@php ... @endphp` block **above** any inline `@php(...)`, or move the logic to the controller. A comment in `teacher/student.blade.php` says so.

Related: [[D-012 Teacher web dashboard]]
