# Product

> Working name: **Teduh** — Indonesian for *calm / serene*, and the root of *saat teduh*, the everyday Indonesian term for a daily quiet time with Scripture. Placeholder; rename freely.

## Register

product

## Users

Indonesian-speaking readers who want an unhurried daily time in Scripture, and who want to do it *alongside* a few close people (family, a small group, friends) so the habit feels shared rather than solitary.

- **Context:** early morning before the day starts, or late evening winding down. Phone in hand, in bed or at a kitchen table. Often offline or on poor connectivity. A calm, private, reverent state of mind, not a rushed utility task.
- **Frequency:** ideally daily; the product's job is to make the streak of returning feel gentle and rewarding, never nagging.
- **Job to be done:** "Help me read today's passage in my own language, keep my place, and let me feel I'm doing this *together* with the people I care about, even when we're apart."
- **Language:** the entire interface is in **Bahasa Indonesia**. Scripture text is **TSI (Terjemahan Sederhana Indonesia)** bundled offline.

## Product Purpose

A warm, offline-first Bible reader built around a shared daily reading rhythm. The MVP delivers the personal core completely offline: read TSI, navigate books and chapters, follow a self-paced sequential plan, mark each day read, and watch a quiet streak grow. The communal layer ("did my people read today?", nudges) is deliberately deferred behind a clean sync abstraction so it can be switched on later (Firebase) without rearchitecting.

**Success looks like:** a reader opens the app most mornings, lands directly on today's passage with zero friction, reads, marks it done, and feels both calm and gently connected. The app is so quiet and dependable it disappears into the habit.

## Brand Personality

- **Three words:** Calm. Reverent. Warm.
- **Voice:** like a trusted older friend who reads with you, not a coach with a clipboard. Encouraging, never guilt-tripping. Indonesian copy is natural and gentle, never churchy-stiff or corporate.
- **Emotional goals:** peace and focus while reading; quiet pride (not pressure) in returning; a felt sense of companionship even in a solo MVP.

## Anti-references

- **Gamified habit apps** (Duolingo-style streaks with aggressive nudges, confetti, loss-aversion guilt). We want gentle continuity, not anxiety.
- **The "Bible-app reflex":** gold cross on navy, stock-photo sunrises, ornate gothic blackletter, glossy gradients. Avoid entirely.
- **Meditation-app sameness:** purple/teal gradients, floating blurred orbs, generic "wellness" calm. Our calm comes from paper and ink, not gradients.
- **Dense feature-bloat readers:** cramped toolbars, ten icons per screen, settings-first surfaces. Reading is the surface; everything else recedes.
- **Cold productivity minimalism:** stark white, thin gray sans, zero warmth. We are warm, not clinical.

## Design Principles

1. **The passage is the product.** Every screen exists to get the reader into the text faster and keep them there comfortably. Chrome recedes; Scripture leads.
2. **Print dignity on a screen.** Treat Scripture with the typographic care of a finely printed Bible: real serif, warm paper, generous measure, considered red-letter and verse numbering.
3. **Gentle, never nagging.** Encourage returning through warmth and continuity, not pressure, guilt, or gamified pestering.
4. **Offline is the default, not a fallback.** The full reading experience must work with the radio off. The network is only ever an enhancement.
5. **Build for "together," ship "alone" cleanly.** Architect every data flow as if the communal layer exists, but keep the MVP honest: no broken/empty social UI, just clean seams ready for it.

## Accessibility & Inclusion

- Target **WCAG 2.2 AA**. All three reading themes (morning/dusk/night) must meet AA contrast for body and UI text.
- **Adjustable reading type size** is a first-class control, not buried; older readers are a core audience.
- Respect **reduced-motion**: the one celebratory "marked read" moment degrades to a calm static state.
- Verse-number and red-letter color choices must remain distinguishable for common color-vision deficiencies (lean on weight/size/position, not color alone).
- Generous touch targets (≥44px) for one-handed, low-light, half-awake use.
