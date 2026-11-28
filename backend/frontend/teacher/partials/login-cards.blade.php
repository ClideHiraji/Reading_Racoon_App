{{-- Shown once: only a scrambled copy of each code is kept. Must stay a direct child of <main>
so printing shows only the cards. --}}
@if ($cards = session('login_cards'))
    @php($sectionName = $sectionName ?? '')
    <section id="login-cards" class="panel is-accent" aria-labelledby="cards-title" data-guard-unload>
        <div class="panel-head no-print">
            <div>
                <h2 id="cards-title">{{ count($cards) === 1 ? 'Login card for '.$cards[0]['name'] : 'Login cards for '.count($cards).' learners' }}</h2>
                <p class="muted small">Print them now, or copy each code onto the child's card. For privacy the codes are stored only in scrambled form and <strong>won't be shown again</strong>: once you leave or reload this page, a lost card needs "New login code". Student IDs (RR-...) are only for reports and are not login codes.</p>
            </div>
            <div class="actions row">
                <button class="btn" type="button" data-print>Print {{ count($cards) === 1 ? 'card' : 'cards' }}</button>
                <button class="btn btn-secondary" type="button" data-guard-done>I've copied them</button>
            </div>
        </div>
        <div class="login-cards">
            @foreach ($cards as $card)
                <div class="login-card">
                    <div class="login-card-head"><span class="brand-mark" aria-hidden="true">RR</span> Reading Racoon &middot; {{ $sectionName }}</div>
                    <div class="login-card-name">{{ $card['name'] }}</div>
                    <div class="login-card-code" aria-label="Login code {{ $card['login_code'] }}">
                        @foreach (str_split(str_replace('-', '', $card['login_code'])) as $i => $char)
                            @if ($i === 4)<span class="gap" aria-hidden="true"></span>@endif
                            <span class="box">{{ $char }}</span>
                        @endforeach
                    </div>
                    <div class="login-card-plain">{{ $card['login_code'] }}</div>
                    <div class="login-card-help">Type these 8 letters and numbers in the game, then tap LET'S GO!</div>
                </div>
            @endforeach
        </div>
    </section>
@endif
