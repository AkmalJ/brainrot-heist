# STUDIO STEPS — MAGMA MAYHEM: Brainrot Volcano (owner's sheet)

*For the account owner, in Roblox Studio, on the SAME experience that is
already published (already Public, play code already in its description).
Do not create a new experience: everything below publishes over that one.
Keep the play code in the description and keep the experience Public.*

This is a full rebuild, so **all nine scripts are pasted fresh** — even ones
whose names look familiar from the old game. Open each repository file in
any text editor, select all (Ctrl+A), copy, and paste the whole contents
over the script in its home below. Where a placeholder script already sits
in a home, open it, select all, delete, and paste ours over it — the game's
pieces are found by name and home, so both must match exactly.

## 1. Paste the nine scripts

| File in the repo | Home in Studio | Class | Name in Studio |
| --- | --- | --- | --- |
| `src/shared/Brainrots.luau` | ReplicatedStorage | ModuleScript | `Brainrots` |
| `src/shared/Upgrades.luau` | ReplicatedStorage | ModuleScript | `Upgrades` |
| `src/server/Main.server.luau` | ServerScriptService | Script | `Main` |
| `src/server/Economy.luau` | ServerScriptService | ModuleScript | `Economy` |
| `src/server/Conveyor.luau` | ServerScriptService | ModuleScript | `Conveyor` |
| `src/server/Thieves.luau` | ServerScriptService | ModuleScript | `Thieves` |
| `src/server/Eruption.luau` | ServerScriptService | ModuleScript | `Eruption` |
| `src/server/Progression.luau` | ServerScriptService | ModuleScript | `Progression` |
| `src/client/Client.client.luau` | StarterPlayer → StarterPlayerScripts | LocalScript | `Client` |
| `src/client/Interface.luau` | StarterPlayer → StarterPlayerScripts | ModuleScript | `Interface` |

Delete any leftover scripts from the old game that are not in this table
(an old `Main` helper, an old HUD script) — two captains sink the ship.

**No place settings to fix by hand.** The Main script heals the place the
moment it loads and builds the whole island procedurally — volcano, parade
conveyor, Ashen Beach and the bases — so there is nothing to sculpt and no
terrain to clear. Paste the nine scripts, playtest, publish, done.

## 2. Playtest (F5)

Press **Play** (F5) and check, in order:

- [ ] You spawn at your **Ashen Beach base**, on a plot whose sign carries
      **your name**.
- [ ] The **top bar** sits top-right: 💰 cash, 💎 gems, 📈 $/s, ✖ multiplier,
      🔥 rekindles. The top-left corner is empty (Roblox's buttons live there).
- [ ] Brainrots **parade** past the crater on the conveyor. Walk up to one
      and buy it with its prompt (**E**) — a cha-ching, and it rides on your
      back with its name tag.
- [ ] Carry it home: the carried banner shows its name; step onto a free
      pedestal at your base and it banks.
- [ ] The pedestal **ticks**: your $/s rises in the top bar and cash builds
      up. Press **COLLECT** (bottom-left, or **F**) — a giant **+$** fountain
      pops and your cash jumps.
- [ ] **Lock test:** press the lock button (right side, or **L**). It flips
      to 🔒 LOCKED with a countdown, then ⏳ COOLDOWN, then back to OPEN.
- [ ] **Index opens:** INDEX (bottom-right) shows the brainrot grid —
      owned ones in colour, the rest as ??? silhouettes. Tap one for its
      joke line. UPGRADES, REKINDLE and QUEST panels open too.
- [ ] If a goblin chases you or the volcano flashes an **ERUPTION warning**,
      the red **RUN HOME!** banner appears while you are carrying.
- [ ] Stop (Shift+F5). Fix nothing by hand — if a check fails, note which
      one and tell me; the fix belongs in the scripts, not in Studio.

## 3. Publish

File → **Publish to Roblox** (over the same experience). Confirm the
experience page still shows it **Public** with the play code in the
description.

## 4. Export the place file

File → **Save to File As…** → save as **`game.rbxl`** and replace the
`game.rbxl` in the repository root with it. The hand-in gate checks that
the scripts inside this file match `src/` byte for byte, so this export
must happen **after** the final paste and publish — if any script changes
afterwards, export again.

## 5. Take the four screenshots

With the game **running** (F5, Play — never while Studio has paused it),
capture at 1280×720 or as close as your screen allows. Roblox's own menu
buttons overlay the top-left of the play view; the game's HUD already
keeps that corner clear, so just frame the action centre-right.

1. **`1-start.png`** — your rich base mid-event: pedestals busy, event
   banner up, top bar fat with numbers. *This one becomes the thumbnail.*
2. **`2-play.png`** — the RUN HOME dash: you carrying a brainrot while the
   eruption WARNING banner counts down (wait for a warning if you can).
3. **`3-index.png`** — the INDEX panel open over your base, grid showing
   owned colours and ??? silhouettes.
4. **`4-upgrades.png`** — the UPGRADES panel open (REKINDLE panel visible
   is fine too), tiers and costs readable.

Each screenshot must end up **at most 256 KiB**. Studio captures are
usually bigger than that — send me the raw files and I will re-encode them
under the cap **keeping these exact names**, then commit them into
`screenshots/` in the repo (replacing the old three).

## 6. Creator Dashboard: icon + thumbnail

On https://create.roblox.com/dashboard/creations: select the experience →
**Configurations → Places** → its start place (marked with a star):

- **Icon:** upload a square picture (512×512 is best) — the volcano/cast
  art or a tight crop of screenshot 1.
- **Thumbnails → Experience Detail Page tab:** upload **`1-start.png`**
  (the exact same picture as the repo screenshot) as the **first**
  thumbnail. The hand-in gate compares them: the first thumbnail must be
  the same picture as one of the entry's screenshots.

Roblox reviews each upload. **Wait until the experience's public page
shows both the icon and the thumbnail** before the entry is submitted —
the play link is refused while either is missing, still in review, or the
thumbnail does not match a screenshot. The description (with the play
code), the genre and the content questions were set on the first publish;
just confirm the experience is still **Public**.
