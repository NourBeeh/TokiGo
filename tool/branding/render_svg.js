// Rasterize one SVG to a PNG with resvg.
//
//   node tool/branding/render_svg.js <in.svg> <out.png> <size>
//
// Requires @resvg/resvg-js, installed in this directory:
//
//   cd tool/branding && npm install
//
// Used by generate_app_icon.py; safe to run by hand too.
const fs = require('fs');
const path = require('path');

const [, , svgPath, outPath, sizeArg] = process.argv;
if (!svgPath || !outPath || !sizeArg) {
  console.error(
    'usage: node render_svg.js <in.svg> <out.png> <size>',
  );
  process.exit(2);
}

let Resvg;
try {
  ({ Resvg } = require('@resvg/resvg-js'));
} catch (error) {
  console.error(
    'Missing @resvg/resvg-js. Run: cd tool/branding && npm install',
  );
  throw error;
}

const svg = fs.readFileSync(svgPath, 'utf8');
const resvg = new Resvg(svg, {
  fitTo: { mode: 'width', value: Number(sizeArg) },
  background: 'rgba(0,0,0,0)',
});
const png = resvg.render().asPng();
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, png);
console.log(`rendered ${outPath} (${resvg.width}x${resvg.height})`);
