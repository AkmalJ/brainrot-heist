# STUDIO STEPS — Brainrot Heist, v2.1 update (owner's sheet)

*For the account owner, in Roblox Studio, on the SAME experience that
phase 1 published (already Public, play code already in its
description). Do not create a new experience: everything below
publishes over that one. Keep the play code in the description and
keep the experience Public.*

You need three text files from the repository, open in any text editor:

- `src/shared/Brainrots.luau`
- `src/server/Main.server.luau`
- `src/client/Client.client.luau`

**What changed in v2.1:** only `Main.server.luau` has new contents —
a bug fix (the frozen-walkers bug from the last playtest), the new
BRAINROT HALL OF FAME stage at spawn, framed signs everywhere, a
filled-in meadow (plaza, paths, pond, hills, a second arch), and a new
GOLDEN RUSH event. `Brainrots.luau` and `Client.client.luau` are
unchanged; re-paste them only if you are setting up from scratch.

**No place settings to fix by hand.** The Main script heals the place
itself the moment it loads: it switches character auto-load on and
clears the starter ground (Baseplate, SpawnLocation, terrain) in code,
so the procedural world can never be buried or spawn-locked. Paste
the three scripts, publish, done.

---

## 1. Paste the three scripts

Open the experience in **Roblox Studio** (Creator Dashboard → the
experience → **Edit**, or Studio's home screen → the experience).
In the **Explorer** panel (View → Explorer if hidden), put each file's
whole contents into its home below. Where the starter place still has
a placeholder script in that home, open it, select all (Ctrl+A),
delete, and paste ours over it — the game's pieces are found by name
and home, so both must match exactly:

| Script | Home | Name |
| --- | --- | --- |
| ModuleScript | ReplicatedStorage | `Brainrots` |
| Script | ServerScriptService | `Main` |
| LocalScript | StarterPlayer → StarterPlayerScripts | `Client` |

1. **ReplicatedStorage** → the ModuleScript named `Brainrots` →
   paste the whole contents of `src/shared/Brainrots.luau`.
2. **ServerScriptService** → the Script named `Main` →
   paste the whole contents of `src/server/Main.server.luau`.
3. **StarterPlayer → StarterPlayerScripts** → the LocalScript named
   `Client` → paste the whole contents of `src/client/Client.client.luau`.

## 2. Playtest (F5)

Press **Play** (F5). Check, in order:

- [ ] You spawn and are teleported to stand in front of a base plot
      whose framed sign carries **your name**.
- [ ] HUD, top-right: **$100**, "+$0/s", a rebirth line. A help line
      sits bottom-left and a purple **REBIRTH** button bottom-right.
      The top-left corner stays empty (that's Roblox's own menu
      corner).
- [ ] Around the spawn: two framed totems — a pink-trimmed
      **BRAINROT HEIST** welcome sign and a gold-trimmed **HOW TO
      PLAY** rules board (dark boards, neon trim, wooden posts) —
      and the **BRAINROT HALL OF FAME**: a two-tier stone stage with
      glowing gold rings, all 12 brainrots on pedestals (base, column,
      glowing tier-coloured top plate), the six higher tiers elevated
      at the back, a backdrop wall reading **★ BRAINROT HALL OF
      FAME ★**, two spotlights beaming onto the stage, and a small
      framed info board in front of each pedestal (name / tier /
      price • income).
- [ ] The meadow is filled in: a light-stone **plaza** under the
      spawn quarter, stone **paths** running out to every plot, a
      **pond** with a plank dock and lily pads, green **hills** in
      the corners (two topped with trees), and bushes and rocks
      scattered between the trees and flowers.
- [ ] **The walkers are MOVING**: eight brainrots are already
      strolling the pastel-rainbow lane, each with a nameplate
      ("Noodle Newt +$1/s • Common", prices on their prompts). One
      of them is **GOLD** and one is **RAINBOW**, both sparkling.
      Epic-and-above walkers wear a gold crown; Legendary-and-above
      float a Neon halo. ⚠️ **If they stand frozen, STOP here:**
      open **View → Output**, take a photo of the red error line,
      and send it to the agent before doing anything else — a frozen
      world is exactly the bug this version fixes, and the error
      line is how the agent finds any new one.
- [ ] Along the lane: fences and lamp posts, a **second rainbow
      arch** halfway down, and three giant statues — a cappuccino
      cup, a banana with headphones, a cactus with a cowboy hat —
      each with a framed plaque.
- [ ] Your plot has a low fence (posts and a rail) along its back and
      sides and a glowing **lantern** at its entrance.
- [ ] Walk to a cheap one (Noodle Newt, $25), press **E** on its
      **Buy** prompt: it rides over your head, slowly spinning, and
      the HUD's carry line appears.
- [ ] Run back onto **your own plot**: the brainrot banks onto a pad,
      the pad lights up in its tier colour, the brainrot bobs gently,
      a green "+$" floats up, and your cash starts climbing. Your
      base sign now shows your income.
- [ ] At about **55 seconds** (with something banked): a banner
      announces the **BANDIT**; a tall red beam glows over him the
      whole time he is hunting and escaping, and it is gone once he
      is back home. He grabs a banked brainrot and flees — chase him
      and get close, he drops it. Pick it up, bank it again.
- [ ] At about 2.5 minutes: a red **TSUNAMI** warning banner, and the
      lane slabs pulse red for 10 seconds; then a blue wall of water
      with a tall foam crest sweeps the lane and washes away anything
      standing on it. Banked brainrots survive.
- [ ] At about **4 minutes**: a **★ GOLDEN RUSH! ★** banner — the
      main arch's rainbow stripes turn gold, and every walker that
      spawns for the next 30 seconds is Gold. (It comes back every
      ~4 minutes; fine to skip in a short test.)
- [ ] Stop with **Shift+F5**. If anything above failed, open
      **View → Output**, take a photo/screenshot of any red error
      lines, and send it to the agent before going on.

(Rebirth confetti needs a $25K rebirth, so it won't show in a short
playtest — it fires over your plot the first time anyone rebirths.)

## 3. Publish the finished place

**File → Publish to Roblox** (Alt+P). This overwrites the same
experience's place with the finished game — do **not** use
"Publish As..." / create a new game. Confirm it stays **Public**.

## 4. Screenshots (while the game runs in Studio)

Play again (F5) and capture four shots of the running game, **1280×720**
(16:9). Easiest: size the Studio window so the 3D view is 16:9, then
use **View → Screenshot**, or Windows' **Win+Shift+S** snip saved as
PNG. Use these exact file names:

| File | What it shows |
| --- | --- |
| `01-cover.png` | The cover: stand at the spawn looking across the **Hall of Fame stage** toward the **BRAINROT HEIST** arch — framed welcome and rules totems, the staged roster on its pedestals with nameplates, strolling brainrots beyond, base plots around. |
| `02-base.png` | Your base with at least one banked brainrot bobbing on a lit pad, "+$" floating, your name and income on the framed base sign, the treasure chest in the corner. |
| `03-steal.png` | A brainrot spinning over your head mid-dash home (buy one — or steal one if a second player is in — and run), carry line on the HUD. |
| `04-wave.png` | The tsunami: when the warning banner fires, get a view over the lane — red pulsing slabs if you catch the warning, the blue wall with its foam crest if you catch the sweep. |

Keep HUD text out of the very top-left corner of the frame (Roblox's
menu buttons sit there) — the game's own HUD already avoids it.

## 5. Icon and thumbnail (Creator Dashboard)

On **create.roblox.com** → your experience → **Configure**:

1. **Basic Settings → Game Icon:** upload a square version of the
   cover picture (crop `01-cover.png` to a square).
2. **Thumbnails:** add `01-cover.png` as the **first** thumbnail. It
   must be the *same picture* as `screenshots/01-cover.png` in the
   entry.
3. Both go through Roblox moderation. The entry cannot be submitted
   while either is still in review or rejected — check back until
   both show approved, and tell the agent when they are.

## 6. Export the place file

Back in Studio: **File → Save to File As…** → save as **`game.rbxl`**
(the binary place format — **not** `.rbxlx`).

## 7. Send back to the agent

- `game.rbxl`
- `01-cover.png`, `02-base.png`, `03-steal.png`, `04-wave.png`
- A note that the icon and first thumbnail are **approved** (or still
  in review)

The agent fills in `PLAY.json` from phase 1, drops these files into
the repository, runs the kit's check, and hands the entry in.
