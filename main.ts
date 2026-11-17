// Brainrot Heist — the hand-in program for make.fun's roblox-brainrot-01 bounty.
//
// The game itself is a Rojo project: the Luau under src/ is what runs in Roblox Studio, and
// game.rbxl is the published place saved in Roblox's binary format. This program is only the
// courier. It copies game.rbxl, PLAY.json, src/ and screenshots/ from beside itself into the
// output directory and writes dossier.json there — the summary the judge reads — using
// buildDossier from the vendored make.fun library, which must stay byte for byte the kit's copy.
//
// The grader refuses an entry whose output holds a name that does not start with a letter, a
// digit or an underscore, so the copies below drop every dotted name (.gitkeep, .DS_Store,
// .git, ...) at any depth.
//
// Outside the grader's container, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const repoDir = fileURLToPath(new URL('.', import.meta.url));
const outputDir = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** cpSync filter: keep a path only when its final component does not start with a dot. */
function keepUndotted(path: string): boolean {
  return !basename(path).startsWith('.');
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

writeFileSync(join(outputDir, 'dossier.json'), buildDossier(outputDir, GATE_CAPS));
