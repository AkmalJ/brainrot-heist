// MAGMA MAYHEM: Brainrot Volcano — the hand-in program for make.fun's
// roblox-brainrot-01 bounty.
//
// The game: a volcanic-island brainrot tycoon. Brainrots parade out of the
// caldera on a conveyor; you buy one, carry it home on your back (watching for
// magma goblins who will bonk it off you and for the volcano, which erupts on a
// timer), bank it on a pedestal, and watch it print cash. Around that loop sit
// the systems the dossier below exists to show off:
//
//   * a 44-strong cast across nine rarities, with mutations and an index that
//     pays income milestones for completing it,
//   * pedestal banking with per-second income, multipliers and cash collection,
//   * magma goblins that steal carried brainrots, a mallet to bonk them back,
//     and a timed base lock to keep thieves out,
//   * a living volcano: warning phase, eruption, falling ash and lava,
//   * timed island events that bend the parade and the prices,
//   * four upgrade tracks of six tiers each, a Rekindle prestige loop that
//     trades cash for permanent multipliers, pedestals and new island zones,
//   * fifteen contracts from the Volcano Spirit, claimed for cash and gems.
//
// The game itself is a Rojo project: the Luau under src/ is what runs in Roblox
// Studio, and game.rbxl is the published place saved in Roblox's binary format.
// This program is only the courier — but a careful one. Before it copies
// anything it runs a pre-flight check of the hand-in against the same caps the
// scorer enforces, so a bad place file, an oversized screenshot or a missing
// PLAY.json fails here, in plain language, instead of at the gate. It then
// copies game.rbxl, PLAY.json, src/ and screenshots/ from beside itself into
// the output directory and writes dossier.json there — the summary the judge
// reads — using buildDossier from the vendored make.fun library, which must
// stay byte for byte the kit's copy. The dossier's bytes are exactly the
// library's; the systems summary above is printed to the console only and is
// never written into the output.
//
// The grader refuses an entry whose output holds a name that does not start
// with a letter, a digit or an underscore, so the copies below drop every
// dotted name (.gitkeep, .DS_Store, .git, ...) at any depth.
//
// Outside the grader's container, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const repoDir = fileURLToPath(new URL('.', import.meta.url));
const outputDir = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** cpSync filter: keep a path only when its final component does not start with a dot. */
function keepUndotted(path: string): boolean {
  return !basename(path).startsWith('.');
}

// The scorer's own caps, from the kit's gate: only text_max_bytes shapes the dossier's bytes;
// the rest exist so this program refuses exactly what the scorer would refuse — more than four
// screenshots or one over 256 KiB, a place over 500,000 instances, script sources over 8 MiB
// in all, or script paths totalling over 1,048,576 characters.
const GATE_CAPS = {
  text_max_bytes: 65536,
  screenshots: { max: 4, max_bytes: 262144 },
  max_instances: 500000,
  scripts_max_source_bytes: 8388608,
  scripts_max_path_chars: 1048576,
};

/** Every file under a directory, as paths relative to it, dotted names skipped. */
function filesUnder(dir: string, prefix = ''): string[] {
  const out: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) continue;
    const rel = prefix === '' ? entry.name : `${prefix}/${entry.name}`;
    if (entry.isDirectory()) out.push(...filesUnder(join(dir, entry.name), rel));
    else if (entry.isFile()) out.push(rel);
  }
  return out;
}

/**
 * The pre-flight check: prove the hand-in is whole before copying any of it.
 * Returns a list of problems in plain language; an empty list means go.
 */
function preflight(): string[] {
  const problems: string[] = [];

  const placePath = join(repoDir, 'game.rbxl');
  if (!existsSync(placePath)) {
    problems.push('game.rbxl is missing: export the published place from Studio (Save to File As) first.');
  } else {
    const head = readFileSync(placePath).subarray(0, 8).toString('latin1');
    if (!head.startsWith('<roblox!')) {
      problems.push('game.rbxl does not start with the Roblox binary magic: the XML format (.rbxlx) is refused.');
    }
  }

  const playPath = join(repoDir, 'PLAY.json');
  if (!existsSync(playPath)) {
    problems.push('PLAY.json is missing: the entry needs its published place pointer.');
  } else {
    try {
      const play = JSON.parse(readFileSync(playPath, 'utf8')) as { url?: unknown };
      if (typeof play.url !== 'string' || !play.url.includes('roblox.com/games/')) {
        problems.push('PLAY.json holds no roblox.com/games/ url: the play link would not resolve.');
      }
    } catch {
      problems.push('PLAY.json is not valid JSON.');
    }
  }

  if (!existsSync(join(repoDir, 'vendor', 'makefun-roblox.ts'))) {
    problems.push('vendor/makefun-roblox.ts is missing: the dossier library must travel with the entry.');
  }

  const shotsDir = join(repoDir, 'screenshots');
  const shots = existsSync(shotsDir) ? filesUnder(shotsDir) : [];
  if (shots.length === 0) {
    problems.push('screenshots/ holds no image: the first screenshot is the cover and the thumbnail.');
  }
  if (shots.length > GATE_CAPS.screenshots.max) {
    problems.push(`screenshots/ holds ${shots.length} images, over the cap of ${GATE_CAPS.screenshots.max}.`);
  }
  for (const shot of shots) {
    const bytes = readFileSync(join(shotsDir, shot));
    if (bytes.length > GATE_CAPS.screenshots.max_bytes) {
      problems.push(`screenshots/${shot} is ${bytes.length} bytes, over the 256 KiB cap: re-encode or scale it down.`);
    }
    const isPng = bytes.length > 4 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47;
    const isJpeg = bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
    if (!isPng && !isJpeg) {
      problems.push(`screenshots/${shot} is neither a PNG nor a JPEG.`);
    }
  }

  const srcDir = join(repoDir, 'src');
  const scripts = existsSync(srcDir) ? filesUnder(srcDir).filter((p) => /\.(luau|lua)$/i.test(p)) : [];
  if (scripts.length === 0) {
    problems.push('src/ holds no Luau scripts: there is no game to hand in.');
  }
  let scriptBytes = 0;
  let scriptPathChars = 0;
  for (const script of scripts) {
    scriptBytes += statSync(join(srcDir, script)).size;
    scriptPathChars += script.length;
  }
  if (scriptBytes > GATE_CAPS.scripts_max_source_bytes) {
    problems.push(`src/ script sources total ${scriptBytes} bytes, over the 8 MiB cap.`);
  }
  if (scriptPathChars > GATE_CAPS.scripts_max_path_chars) {
    problems.push(`src/ script paths total ${scriptPathChars} characters, over the cap.`);
  }

  return problems;
}

const problems = preflight();
if (problems.length > 0) {
  console.error('MAGMA MAYHEM hand-in refused — fix these first:');
  for (const problem of problems) console.error(`  - ${problem}`);
  process.exit(1);
}

mkdirSync(outputDir, { recursive: true });

// The place and the pointer to its published experience go in first, then the scripts and the
// screenshots the judge will look at.
copyFileSync(join(repoDir, 'game.rbxl'), join(outputDir, 'game.rbxl'));
copyFileSync(join(repoDir, 'PLAY.json'), join(outputDir, 'PLAY.json'));
cpSync(join(repoDir, 'src'), join(outputDir, 'src'), { recursive: true, filter: keepUndotted });
if (existsSync(join(repoDir, 'screenshots'))) {
  cpSync(join(repoDir, 'screenshots'), join(outputDir, 'screenshots'), { recursive: true, filter: keepUndotted });
} else {
  mkdirSync(join(outputDir, 'screenshots'), { recursive: true });
}

const dossier = buildDossier(outputDir, GATE_CAPS);
writeFileSync(join(outputDir, 'dossier.json'), dossier);

// The manifest: what was handed in, and the systems it carries. Console only —
// the gate compares dossier.json byte for byte with its own rebuild, so nothing
// of this is written into the output.
const handedIn = filesUnder(outputDir).filter((rel) => rel !== 'dossier.json');
console.log('MAGMA MAYHEM: Brainrot Volcano — handed in.');
for (const rel of handedIn) {
  console.log(`  ${rel} (${statSync(join(outputDir, rel)).size} bytes)`);
}
console.log(`  dossier.json (${dossier.length} bytes)`);
console.log('Systems on board: 44-brainrot cast + index milestones · pedestal banking and');
console.log('multipliers · goblin thieves + mallet + base lock · volcano eruptions · island');
console.log('events · 4x6 upgrades · Rekindle prestige + zones · 15 Volcano Spirit contracts.');
