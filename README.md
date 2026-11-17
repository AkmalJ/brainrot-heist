# BRAINROT HEIST

A 3D brainrot collector-and-stealer for Roblox, built for make.fun's
**roblox-brainrot-01** bounty ("Make the best AI Roblox brainrot game").

Absurd meme characters stroll down a winding lane through a bright meadow.
Buy one, hoist it over your head, and dash home to bank it on your base —
where it earns you cash every second. But your rivals can steal what you
bank, a **BANDIT** raids bases on a timer, and every few minutes a
**TSUNAMI** washes the whole lane clean. Bank fast, steal faster, rebirth
for a permanent income multiplier.

## How to play

1. **Buy** — walk up to a brainrot on the lane and use its prompt (E).
   Rarer brainrots cost more and earn more.
2. **Carry** — your prize rides over your head. You can only carry one.
3. **Bank** — step onto your own base plot (the coloured ring plot with
   your name on the sign). Your brainrot takes a pad and starts paying
   you every second, with a floating "+$" over its head.
4. **Steal** — hold the prompt on a rival's banked brainrot for 1.5
   seconds to grab it, then run it home. Freshly stolen brainrots can't
   be re-stolen for 5 seconds.
5. **Survive the BANDIT** — roughly every minute he raids a random base
   and runs for his hideout with the loot. If the owner gets close to him
   on the escape run, he drops the brainrot as a loose carryable anyone
   can pick up. If he reaches the hideout, it's gone.
6. **Survive the TSUNAMI** — every ~3 minutes a wall of water sweeps the
   lane after a 10-second warning. Anything standing on the lane —
   walking, loose, or carried — is washed away. Banked brainrots are safe.
7. **Rebirth** — the HUD button trades your cash and collection for a
   permanent +50% income multiplier. Prices: $25K, $100K, $400K, ...

## The roster

12 original characters across 7 rarity tiers — Common, Uncommon, Rare,
Epic, Legendary, Mythic, and **Brainrot God** — from the humble
**Noodle Newt** ($25) to the **Cosmic Cappuccino** ($150K, $5,200/s).
Spawns can roll a mutation: **Gold x2**, **Diamond x3**, or
**Rainbow x5** income, with a tinted body and sparkles to match.
Rare-and-above brainrots wear a pillar of light in their tier colour, so
the good stuff is visible across the meadow.

## The world

Everything is built procedurally by the server script from plain parts —
no external assets: the S-curve lane and its gates, the signed
**BRAINROT HEIST** arch, 8 colour-coded base plots with pads and live
income signs, a richest-collectors board that updates in-world, the
Rebirth Shrine, the Bandit's hideout, trees, flowers and clouds.

## Files

| File | What it is |
| --- | --- |
| `main.ts` | The hand-in program: copies the place, `src/`, `screenshots/` and `PLAY.json` to the output and writes `dossier.json` with the vendored library. |
| `vendor/makefun-roblox.ts` | make.fun's place library, byte for byte the kit's copy. |
| `src/server/Main.server.luau` | Paste into a **Script** named `Main` in **ServerScriptService**. Builds the world and runs the whole game, server-authoritatively. |
| `src/shared/Brainrots.luau` | Paste into a **ModuleScript** named `Brainrots` in **ReplicatedStorage**. The roster, tiers, mutations, rebirth maths and money formatting, shared by server and client. |
| `src/client/Client.client.luau` | Paste into a **LocalScript** named `Client` in **StarterPlayer > StarterPlayerScripts**. The HUD: cash/income top-right (top-left stays clear for Roblox's menu), carry line, banners, rebirth button. |
| `default.project.json` | The Rojo project mapping the three scripts to those same homes. |
| `game.rbxl` | The published place, saved from Studio in binary format. |
| `PLAY.json` | The published experience's play link, place id and universe id. |
| `screenshots/` | Captures of the game running in Studio; the first by name is the cover and the Roblox thumbnail. |
| `STUDIO-STEPS.md` | The owner's click-by-click sheet for pasting, publishing, screenshotting and exporting. |

Movement is done by the server with `SetPrimaryPartCFrame` steps on a
10 Hz loop — no physics, no DataStore; every session is a fresh heist.
