#!/usr/bin/env node
/**
 * render_pc_optim_pdf.js — convertit rapport pc-optim MD → PDF A4 branded Julienweb.
 *
 * Usage : node render_pc_optim_pdf.js <rapport.md> [<sortie.pdf>]
 *
 * 0 dépendance npm. Parser MD maison (headings, tables, lists, code, blockquote, hr, gras/italique).
 * Template HTML : ../templates/pdf/template-report.html (topbar Julienweb + palette + Squada/Poppins).
 * Render Chrome headless avec les MÊMES flags que courrier-admin-pdf (workaround GDrive temp+cp).
 *
 * Env :
 *   CHROME_PATH      override exécutable Chrome
 *   PCOPTIM_DEBUG    log la commande Chrome
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const inputPath = process.argv[2];
const outputPath = process.argv[3];
if (!inputPath) {
  console.error('Usage : node render_pc_optim_pdf.js <rapport.md> [<sortie.pdf>]');
  process.exit(1);
}
if (!fs.existsSync(inputPath)) {
  console.error(`ERREUR : fichier introuvable : ${inputPath}`);
  process.exit(1);
}

const mdAbs = path.resolve(inputPath);
const baseName = path.basename(mdAbs, path.extname(mdAbs));
const outDir = path.dirname(mdAbs);
const pdfOut = outputPath ? path.resolve(outputPath) : path.join(outDir, baseName + '.pdf');
const htmlOut = path.join(outDir, baseName + '.html');
const pdfTmp = path.join(os.tmpdir(), `pcoptim-${Date.now()}-${process.pid}.pdf`);

const templatePath = path.resolve(__dirname, '..', 'templates', 'pdf', 'template-report.html');
if (!fs.existsSync(templatePath)) {
  console.error(`ERREUR : template introuvable : ${templatePath}`);
  process.exit(1);
}

const md = fs.readFileSync(mdAbs, 'utf8');
const tpl = fs.readFileSync(templatePath, 'utf8');

const data = {
  TITLE: baseName,
  DATE: new Date().toISOString().slice(0, 10),
  BODY_HTML: markdownToHtml(md),
};

const html = tpl
  .replace(/\{\{\{BODY_HTML\}\}\}/g, data.BODY_HTML)
  .replace(/\{\{TITLE\}\}/g, escapeHtml(data.TITLE))
  .replace(/\{\{DATE\}\}/g, escapeHtml(data.DATE));

fs.writeFileSync(htmlOut, html, 'utf8');
console.log(`HTML écrit : ${htmlOut}`);

const chromeCandidates = [
  process.env.CHROME_PATH,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/usr/bin/chromium-browser',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
].filter(Boolean);

const chrome = chromeCandidates.find(p => fs.existsSync(p));
if (!chrome) {
  console.error(`ERREUR : Chrome introuvable. Définir CHROME_PATH ou installer Chrome.`);
  process.exit(1);
}

const htmlAbs = path.resolve(htmlOut);
const fileUrl = 'file:///' + htmlAbs.replace(/\\/g, '/').replace(/ /g, '%20').replace(/^\/+/, '');
const cmd = `"${chrome}" --headless --disable-gpu --no-pdf-header-footer --virtual-time-budget=15000 --run-all-compositor-stages-before-draw --print-to-pdf="${pdfTmp}" "${fileUrl}"`;
if (process.env.PCOPTIM_DEBUG) console.log('DEBUG cmd:', cmd);

try {
  execSync(cmd, { stdio: ['ignore', 'inherit', 'inherit'] });
} catch (err) {
  console.error('ERREUR Chrome headless');
  process.exit(1);
}

if (!fs.existsSync(pdfTmp)) {
  console.error(`ERREUR : PDF non généré (${pdfTmp})`);
  process.exit(1);
}

fs.copyFileSync(pdfTmp, pdfOut);
fs.unlinkSync(pdfTmp);

const sizeKB = (fs.statSync(pdfOut).size / 1024).toFixed(1);
console.log(`PDF écrit  : ${pdfOut} (${sizeKB} KB)`);

// ──────────────────────────────────────────────────────────
// Markdown → HTML (subset suffisant pour pc-optim : headings,
// tables GFM, listes, code inline+block, blockquote, hr, gras/italique, liens)
// ──────────────────────────────────────────────────────────
function markdownToHtml(src) {
  const lines = src.replace(/\r\n?/g, '\n').split('\n');
  const out = [];
  let i = 0;
  let inCode = false, codeBuf = [];
  let paraBuf = [];

  function flushPara() {
    if (paraBuf.length) {
      out.push(`<p>${inline(paraBuf.join(' ').trim())}</p>`);
      paraBuf = [];
    }
  }

  while (i < lines.length) {
    const line = lines[i];

    // Code fence
    if (/^```/.test(line)) {
      flushPara();
      if (inCode) {
        out.push(`<pre><code>${escapeHtml(codeBuf.join('\n'))}</code></pre>`);
        codeBuf = [];
        inCode = false;
      } else {
        inCode = true;
      }
      i++;
      continue;
    }
    if (inCode) { codeBuf.push(line); i++; continue; }

    // Blank line
    if (/^\s*$/.test(line)) { flushPara(); i++; continue; }

    // HR
    if (/^---+\s*$/.test(line) || /^\*\*\*+\s*$/.test(line)) {
      flushPara();
      out.push('<hr>');
      i++;
      continue;
    }

    // Headings
    const h = line.match(/^(#{1,6})\s+(.*?)\s*#*\s*$/);
    if (h) {
      flushPara();
      const level = h[1].length;
      out.push(`<h${level}>${inline(h[2])}</h${level}>`);
      i++;
      continue;
    }

    // Tables GFM (header | --- | row…)
    if (/\|/.test(line) && i + 1 < lines.length && /^\s*\|?[\s:|-]+\|?\s*$/.test(lines[i + 1]) && /-/.test(lines[i + 1])) {
      flushPara();
      const header = splitRow(line);
      i += 2; // skip separator
      const rows = [];
      while (i < lines.length && /\|/.test(lines[i]) && !/^\s*$/.test(lines[i])) {
        rows.push(splitRow(lines[i]));
        i++;
      }
      const thead = '<thead><tr>' + header.map(c => `<th>${inline(c)}</th>`).join('') + '</tr></thead>';
      const tbody = '<tbody>' + rows.map(r => '<tr>' + r.map(c => `<td>${inline(c)}</td>`).join('') + '</tr>').join('') + '</tbody>';
      out.push(`<table>${thead}${tbody}</table>`);
      continue;
    }

    // Blockquote
    if (/^>\s?/.test(line)) {
      flushPara();
      const bq = [];
      while (i < lines.length && /^>\s?/.test(lines[i])) {
        bq.push(lines[i].replace(/^>\s?/, ''));
        i++;
      }
      out.push(`<blockquote>${inline(bq.join(' '))}</blockquote>`);
      continue;
    }

    // Unordered list
    if (/^\s*[-*+]\s+/.test(line)) {
      flushPara();
      const items = [];
      while (i < lines.length && /^\s*[-*+]\s+/.test(lines[i])) {
        items.push(lines[i].replace(/^\s*[-*+]\s+/, ''));
        i++;
      }
      out.push('<ul>' + items.map(t => `<li>${inline(t)}</li>`).join('') + '</ul>');
      continue;
    }

    // Ordered list
    if (/^\s*\d+\.\s+/.test(line)) {
      flushPara();
      const items = [];
      while (i < lines.length && /^\s*\d+\.\s+/.test(lines[i])) {
        items.push(lines[i].replace(/^\s*\d+\.\s+/, ''));
        i++;
      }
      out.push('<ol>' + items.map(t => `<li>${inline(t)}</li>`).join('') + '</ol>');
      continue;
    }

    // Plain paragraph line
    paraBuf.push(line.trim());
    i++;
  }
  flushPara();
  if (inCode && codeBuf.length) {
    out.push(`<pre><code>${escapeHtml(codeBuf.join('\n'))}</code></pre>`);
  }
  return out.join('\n');
}

function splitRow(line) {
  return line.replace(/^\s*\|/, '').replace(/\|\s*$/, '').split('|').map(c => c.trim());
}

function inline(s) {
  let out = escapeHtml(s);
  // restore escaped backticks for inline code
  out = out.replace(/`([^`]+?)`/g, (_, c) => `<code>${c}</code>`);
  out = out.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
  out = out.replace(/\*\*([^*]+?)\*\*/g, '<strong>$1</strong>');
  out = out.replace(/(?<![*\w])\*([^*]+?)\*(?!\*)/g, '<em>$1</em>');
  return out;
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}
