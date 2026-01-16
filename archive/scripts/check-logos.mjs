import fs from 'fs';
import path from 'path';

const logos = [
  'lockheed-martin.svg',
  'jp-morgan-chase.svg',
  'nintendo.svg',
  'raytheon.svg',
  'fidelity-investments.svg',
  'aws.svg',
  'expedia.svg'
];

const baseDir = path.join(process.cwd(), 'assets', 'logos');

let missing = [];

for (const file of logos) {
  const full = path.join(baseDir, file);
  if (!fs.existsSync(full)) {
    missing.push(full);
  }
}

if (missing.length === 0) {
  console.log('All expected logo files are present in assets/logos.');
  process.exit(0);
}

console.warn('Missing logo files (will fall back to text badges):');
for (const m of missing) console.warn('- ' + m);
process.exit(0); // warn-only, no build break