{{-- Shared styles for the teacher and admin pages. Inline on purpose: no build step,
     and the admin portal loads nothing from other hosts (D-012). Paper palette from D-009. --}}
<style>
    :root {
        --paper: #fbf6ec; --card: #ffffff; --ink: #2b2a33; --muted: #6b6b78; --line: #e6dfd0;
        --teal: #2a9d8f; --teal-dark: #1f776c; --orange: #e76f51; --amber: #e9a23b; --red: #c8423b;
        --green: #4f9a3f; --blue: #3f80aa; --purple: #6a4c93; --soft: #f3ede0;
        --radius: 12px;
    }
    * { box-sizing: border-box; }
    body { margin: 0; background: var(--paper); color: var(--ink); font: 15px/1.5 system-ui, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; }
    a { color: var(--teal-dark); }
    h1 { font-size: 1.6rem; margin: 0 0 .25rem; }
    h2 { font-size: 1.15rem; margin: 0 0 .75rem; }
    h3 { font-size: 1rem; margin: 0 0 .5rem; }
    .topbar { background: var(--card); border-bottom: 1px solid var(--line); }
    .topbar-inner { max-width: 1180px; margin: 0 auto; padding: .7rem 1rem; display: flex; align-items: center; gap: 1rem; flex-wrap: wrap; }
    .brand { font-weight: 800; color: var(--ink); text-decoration: none; display: flex; align-items: center; gap: .5rem; }
    .brand-mark { width: 30px; height: 30px; border-radius: 50%; background: var(--teal); color: #fff; display: grid; place-items: center; font-size: .9rem; }
    .brand small { font-weight: 600; color: var(--muted); }
    .nav { display: flex; gap: .25rem; flex-wrap: wrap; margin-left: auto; align-items: center; }
    .nav a, .nav button { color: var(--ink); text-decoration: none; padding: .4rem .7rem; border-radius: 8px; border: 0; background: none; font: inherit; cursor: pointer; }
    .nav a:hover, .nav button:hover, .nav a.active { background: var(--soft); }
    main { max-width: 1180px; margin: 0 auto; padding: 1.5rem 1rem 3rem; }
    .narrow { max-width: 460px; margin: 2rem auto; }
    .card { background: var(--card); border: 1px solid var(--line); border-radius: var(--radius); padding: 1.1rem 1.2rem; margin-bottom: 1rem; }
    .grid { display: grid; gap: 1rem; }
    .grid-2 { grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); }
    .grid-4 { grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); }
    .tile { background: var(--card); border: 1px solid var(--line); border-radius: var(--radius); padding: .9rem 1rem; }
    .tile .value { font-size: 1.7rem; font-weight: 800; }
    .tile .label { color: var(--muted); font-size: .85rem; }
    .muted { color: var(--muted); }
    .small { font-size: .85rem; }
    .page-head { display: flex; align-items: flex-end; justify-content: space-between; gap: 1rem; flex-wrap: wrap; margin-bottom: 1rem; }
    table { width: 100%; border-collapse: collapse; }
    th, td { text-align: left; padding: .5rem .55rem; border-bottom: 1px solid var(--line); vertical-align: top; }
    th { font-size: .78rem; text-transform: uppercase; letter-spacing: .03em; color: var(--muted); font-weight: 700; }
    tr.anomaly td { background: #fdecea; }
    .table-wrap { overflow-x: auto; }
    label { display: block; font-weight: 600; margin: .7rem 0 .25rem; }
    input[type=text], input[type=email], input[type=password], input[type=time], input[type=number], input[type=date], select, textarea {
        width: 100%; padding: .55rem .65rem; border: 1px solid #cfc6b4; border-radius: 8px; font: inherit; background: #fff; color: var(--ink);
    }
    input:focus, select:focus, textarea:focus, button:focus-visible, a:focus-visible { outline: 3px solid rgba(42,157,143,.35); outline-offset: 1px; }
    .check { display: flex; gap: .5rem; align-items: center; font-weight: 600; margin: .8rem 0; }
    .check input { width: 18px; height: 18px; }
    .btn { display: inline-block; padding: .55rem 1rem; border-radius: 8px; border: 1px solid transparent; background: var(--teal); color: #fff; font: inherit; font-weight: 700; cursor: pointer; text-decoration: none; }
    .btn:hover { background: var(--teal-dark); }
    .btn-light { background: #fff; color: var(--ink); border-color: #cfc6b4; }
    .btn-light:hover { background: var(--soft); }
    .btn-danger { background: var(--red); }
    .btn-danger:hover { background: #a3342e; }
    .btn-sm { padding: .3rem .6rem; font-size: .85rem; }
    .row { display: flex; gap: .5rem; align-items: center; flex-wrap: wrap; }
    .row > * { margin: 0; }
    .inline { display: inline; }
    .alert { padding: .75rem 1rem; border-radius: 10px; margin-bottom: 1rem; border: 1px solid; }
    .alert-ok { background: #eaf6f2; border-color: #b9e0d6; }
    .alert-error { background: #fdecea; border-color: #f2c0bb; }
    .alert-warn { background: #fdf4e3; border-color: #f0d6a6; }
    .errors { color: var(--red); font-size: .88rem; margin: .25rem 0 0; }
    .badge { display: inline-block; padding: .12rem .5rem; border-radius: 999px; font-size: .78rem; font-weight: 700; background: var(--soft); color: var(--ink); white-space: nowrap; }
    .badge-red { background: #fbe1df; color: #8e2a24; }
    .badge-orange { background: #fde7dd; color: #9a3f22; }
    .badge-amber { background: #fcefd6; color: #85590f; }
    .badge-green { background: #e2f2dd; color: #2f6524; }
    .badge-teal { background: #dff1ee; color: #17594f; }
    .flag-dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; margin-right: .35rem; vertical-align: middle; }
    .bar { background: var(--soft); border-radius: 999px; height: 10px; overflow: hidden; min-width: 80px; }
    .bar > span { display: block; height: 100%; background: var(--teal); }
    .skill-row { display: flex; gap: .45rem; align-items: center; flex-wrap: nowrap; line-height: 1.7; }
    .skill-row .skill-name { width: 118px; flex: none; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .skill-row .bar { flex: 1; min-width: 60px; }
    .skill-row .muted { flex: none; }
    .code-card { font-family: ui-monospace, Consolas, monospace; font-size: 1.6rem; font-weight: 800; letter-spacing: .12em; background: #fff; border: 2px dashed var(--teal); border-radius: 10px; padding: .6rem 1rem; display: inline-block; }
    .chart-box { position: relative; height: 280px; }
    .tabs { display: flex; gap: .25rem; margin-bottom: 1rem; flex-wrap: wrap; }
    .tabs a { padding: .45rem .8rem; border-radius: 8px; text-decoration: none; color: var(--ink); border: 1px solid var(--line); background: #fff; }
    .tabs a.active { background: var(--teal); color: #fff; border-color: var(--teal); }
    .legend { display: flex; gap: 1rem; flex-wrap: wrap; font-size: .85rem; color: var(--muted); }
    .report p { margin: 0 0 .8rem; }
    pre.json { background: var(--soft); padding: .5rem; border-radius: 8px; font-size: .78rem; white-space: pre-wrap; word-break: break-word; margin: 0; max-width: 420px; }
    @media (max-width: 640px) { .nav { margin-left: 0; } h1 { font-size: 1.35rem; } }
</style>
