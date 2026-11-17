# STUDIO STEPS — Brainrot Heist, phase 2 (owner's sheet)

*Draft — for the account owner, in Roblox Studio, on the SAME experience
that phase 1 published (the starter place, already Public, play code
already in its description). Do not create a new experience: everything
below publishes over that one. Keep the play code in the description and
keep the experience Public.*

You need three text files from the repository, open in any text editor:

- `src/shared/Brainrots.luau`
- `src/server/Main.server.luau`
- `src/client/Client.client.luau`

---

## 1. Paste the three scripts

Open the experience in **Roblox Studio** (Creator Dashboard → the
experience → **Edit**, or Studio's home screen → the experience).
In the **Explorer** panel (View → Explorer if hidden):

**First, delete the starter's two scripts** — the published starter place
still contains them, and its client script draws a grey square over the
whole screen:

- **ServerScriptService** → the Script named `Server` → right-click →
  **Delete**.
- **StarterPlayer → StarterPlayerScripts** → the Folder named `Client`
  (it holds a LocalScript named `Game`) → right-click → **Delete**.

Then paste ours:

1. **ReplicatedStorage** → hover → **+** → **ModuleScript**.
   Rename it to exactly `Brainrots`. Double-click to open it, select all
   (Ctrl+A), delete, and paste the whole contents of
   `src/shared/Brainrots.luau`.
2. **ServerScriptService** → **+** → **Script**.
   Rename it to exactly `Main`. Open it, select all, delete, paste the
   whole contents of `src/server/Main.server.luau`.
3. **StarterPlayer** → **StarterPlayerScripts** → **+** → **LocalScript**.
   Rename it to exactly `Client`. Open it, select all, delete, paste the
   whole contents of `src/client/Client.client.luau`.

Names and homes matter — the game finds its pieces by them:

| Script | Home | Name |
| --- | --- | --- |
| ModuleScript | ReplicatedStorage | `Brainrots` |
| Script | ServerScriptService | `Main` |
| LocalScript | StarterPlayer → StarterPlayerScripts | `Client` |

Leave the place's own Baseplate and SpawnLocation as they are — the
server script builds its meadow, lane and bases on top of them.

## 2. Playtest (F5)

Press **Play** (F5). Check, in order:

- [ ] You spawn and are teleported to stand in front of a base plot
      whose sign carries **your name**.
- [ ] HUD, top-right: **$100**, "+$0/s", a rebirth line. A help line sits
      bottom-left and a purple **REBIRTH** button bottom-right. The
      top-left corner stays empty (that's Roblox's own menu corner).
- [ ] Five brainrots are already strolling the sandy lane, each with a
      nameplate ("Noodle Newt +$1/s • Common", prices on their prompts).
- [ ] Walk to a cheap one (Noodle Newt, $25), press **E** on its
      **Buy** prompt: it rides over your head and the HUD's carry line
      appears.
- [ ] Run back onto **your own plot**: the brainrot banks onto a pad,
      the pad lights up in its tier colour, a green "+$" floats up, and
      your cash starts climbing. Your base sign now shows your income.
- [ ] After about a minute (with something banked): a banner announces
      the **BANDIT**; he runs in, grabs a banked brainrot and flees.
      Chase him and get close — he drops it. Pick it up, bank it again.
- [ ] At about 2.5 minutes: a red **TSUNAMI** warning banner; 10 seconds
      later a blue wall of water sweeps the lane and washes away anything
      standing on it. Banked brainrots survive.
- [ ] Stop with **Shift+F5**. If anything above failed, open
      **View → Output**, take a photo/screenshot of any red error lines,
      and send it to the agent before going on.

## 3. Publish the finished place

**File → Publish to Roblox** (Alt+P). This overwrites the same
experience's place with the finished game — do **not** use
"Publish As..." / create a new game. Confirm it stays **Public**.

## 4. Screenshots (while the game runs in Studio)

Play again (F5) and capture four shots of the running game, **1280×720**
(16:9). Easiest: size the Studio window so the 3D view is 16:9, then use
**View → Screenshot**, or Windows' **Win+Shift+S** snip saved as PNG.
Use these exact file names:

| File | What it shows |
| --- | --- |
| `01-cover.png` | The cover: stand just south of the big **BRAINROT HEIST** arch looking across the lane — arch sign, strolling brainrots with nameplates, base plots around. |
| `02-base.png` | Your base with at least one banked brainrot on a lit pad, "+$" floating, your name and income on the base sign. |
| `03-steal.png` | A brainrot riding over your head mid-dash home (buy one — or steal one if a second player is in — and run), carry line on the HUD. |
| `04-wave.png` | The tsunami: when the warning banner fires, get a view over the lane and capture the blue wall sweeping it. |

Keep HUD text out of the very top-left corner of the frame (Roblox's menu
buttons sit there) — the game's own HUD already avoids it.

## 5. Icon and thumbnail (Creator Dashboard)

On **create.roblox.com** → your experience → **Configure**:

1. **Basic Settings → Game Icon:** upload a square version of the cover
   picture (crop `01-cover.png` to a square).
2. **Thumbnails:** add `01-cover.png` as the **first** thumbnail. It must
   be the *same picture* as `screenshots/01-cover.png` in the entry.
3. Both go through Roblox moderation. The entry cannot be submitted
   while either is still in review or rejected — check back until both
   show approved, and tell the agent when they are.

## 6. Export the place file

Back in Studio: **File → Save to File As…** → save as **`game.rbxl`**
(the binary place format — **not** `.rbxlx`).

## 7. Send back to the agent

- `game.rbxl`
- `01-cover.png`, `02-base.png`, `03-steal.png`, `04-wave.png`
- A note that the icon and first thumbnail are **approved** (or still in
  review)

The agent fills in `PLAY.json` from phase 1, drops these files into the
repository, runs the kit's check, and hands the entry in.
