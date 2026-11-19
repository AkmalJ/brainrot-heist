# MAGMA MAYHEM: Brainrot Volcano

A volcanic-island brainrot tycoon for Roblox, built for make.fun's
**roblox-brainrot-01** bounty ("Make the best AI Roblox brainrot game").

A living volcano squats in the middle of a tropical island, and it is having
a day. Brainrots — 44 absurd meme creatures across nine rarities — parade out
of the caldera on a conveyor belt. Buy one, hoist it onto your back, and run
it home to your base on Ashen Beach before a magma goblin bonks it off you,
a rival player steals it, or the volcano erupts and the whole island scrambles
for cover. Banked brainrots print cash every second on their pedestals. Bank
fast, lock your base, and when the mountain offers, throw it all into the
caldera and **Rekindle** for permanent power.

## The loop

1. **Buy** — walk the parade by the crater and use a brainrot's prompt (E)
   to buy it. Rarer brainrots cost more and earn far more per second.
2. **Carry** — your prize rides on your back with its name tag showing. You
   can carry one at a time, and carrying makes you a target.
3. **Run home** — goblins chase carriers, rivals can steal, and when the
   eruption warning sounds the HUD screams RUN HOME! Get it to your base.
4. **Bank** — drop it on a pedestal at your base (the plot with your name on
   the sign). It starts paying you every second, ticking up in the top bar.
5. **Collect** — hit COLLECT (or F) to sweep your pedestals' earnings into
   cash, with a giant +$ fountain over your head.
6. **Protect** — lock your base on a timer so thieves and goblins bounce
   off; bonk goblin thieves with your mallet when they come for your pads.
7. **Grow** — spend cash on 4 upgrade tracks × 6 tiers, chase index
   milestones, complete the Volcano Spirit's 15 contracts, and Rekindle to
   reset for a permanent income multiplier, more pedestals and new zones.

## Systems

- **The cast** — 44 brainrots, nine rarities (Common → Magma), each with its
  own price, income rate and joke. Mutations (from pedestal rerolls) multiply
  a banked brainrot's pay.
- **The index** — every discovery is recorded; milestone finds (5/10/15/25/
  35/44) pay permanent income bonuses, up to +25% and the Magma Crown.
- **The volcano** — a full eruption cycle: calm, a red WARNING countdown
  (the HUD counts the seconds), then ERUPTING — screen shake, falling ash,
  lava — while carriers out in the open risk it all.
- **Thieves** — magma goblins spawn, chase carriers and raid unlocked
  bases; the mallet settles arguments. Base lock runs OPEN → LOCKED →
  COOLDOWN, all counted live on the lock button.
- **Events** — timed island events bend the parade and the prices, announced
  on the banner with a live countdown.
- **Upgrades** — 4 tracks × 6 tiers: faster feet, deeper pockets, stronger
  pedestals, longer locks (data-driven from `src/shared/Upgrades.luau`).
- **Rekindle** — the prestige loop: burn your cash and pedestals for a
  permanent income multiplier, extra pedestals and a new island zone.
- **Contracts** — 15 quests from the Volcano Spirit ("Bonk 12 magma
  goblins", "Survive 3 eruptions", "Discover all 44 brainrots"…) paying cash
  and gems, tracked on the QUEST panel with a progress bar.
- **The HUD** — built entirely in code: cash/gems/income/multiplier top bar,
  event and eruption banner, lock button with live state, buttons that show
  live counts (INDEX 29/44, QUEST #7 · 3/12), stacked toasts, giant collect
  feedback and the RUN HOME! banner. The top-left corner stays clear for
  Roblox's own buttons, as it should.

## Controls

| Input | Action |
| --- | --- |
| W A S D / joystick | Move |
| E (prompt) | Buy a brainrot from the parade / interact |
| Click / tap (mallet equipped) | Swing the mallet |
| F | Collect pedestal cash |
| L | Toggle base lock |
| 1 / 2 / 3 / 4 | Toggle INDEX / UPGRADES / REKINDLE / QUEST |
| Esc | Close the open panel |
| On-screen buttons | COLLECT, lock, INDEX, UPGRADES, REKINDLE, QUEST |

## Running it in Studio

The game is a set of Luau scripts pasted into one published experience — the
step-by-step owner's sheet is **STUDIO-STEPS.md**. In short:

- `ReplicatedStorage`: `Brainrots`, `Upgrades` (ModuleScripts, from `src/shared/`)
- `ServerScriptService`: `Main` (Script) + `Economy`, `Conveyor`, `Thieves`,
  `Eruption`, `Progression` (ModuleScripts, from `src/server/`)
- `StarterPlayer → StarterPlayerScripts`: `Client` (LocalScript) +
  `Interface` (ModuleScript, from `src/client/`)

The server builds the island procedurally when Main loads — volcano, parade
conveyor, beaches and bases — so there is no terrain to sculpt by hand.
`default.project.json` describes the same tree for Rojo users.
`main.ts` is the make.fun hand-in program (pre-flight check + dossier);
`PLAY.json` points at the published experience.
