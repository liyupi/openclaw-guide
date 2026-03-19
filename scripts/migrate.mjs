#!/usr/bin/env node
import fs from 'fs';
import path from 'path';

const ROOT = process.cwd();
const DOCS_JSON = path.join(ROOT, 'docs.json');
const SRC_DOCS = path.join(ROOT, 'src', 'content', 'docs');
const PUBLIC = path.join(ROOT, 'public');

const docsConfig = JSON.parse(fs.readFileSync(DOCS_JSON, 'utf-8'));

const SKIP_FILES = new Set([
  'AGENTS.md', 'index.mdx', 'package.json', 'tsconfig.json',
  'astro.config.mjs', 'docs.json', 'style.css', 'nav-tabs-underline.js',
]);
const SKIP_DIRS = new Set([
  'node_modules', '.mintlify', '.git', '.i18n', 'scripts',
  'src', 'public', '.github', '.astro',
]);

// ============================================================
// Phase 1: Copy static assets
// ============================================================
function copyDirRecursive(src, dest) {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirRecursive(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function copyAssets() {
  console.log('📦 Copying static assets...');
  copyDirRecursive(path.join(ROOT, 'assets'), path.join(PUBLIC, 'assets'));
  copyDirRecursive(path.join(ROOT, 'images'), path.join(PUBLIC, 'images'));

  // Copy root-level image files
  for (const f of fs.readdirSync(ROOT)) {
    if (/\.(png|jpg|jpeg|gif|svg|webp|ico)$/i.test(f)) {
      fs.copyFileSync(path.join(ROOT, f), path.join(PUBLIC, f));
    }
  }
  console.log('   ✓ Assets copied to public/');
}

// ============================================================
// Phase 2: Frontmatter conversion
// ============================================================
function convertFrontmatter(content) {
  const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
  if (!fmMatch) return content;

  const fm = fmMatch[1];
  const body = content.slice(fmMatch[0].length);
  const lines = fm.split('\n');
  const newLines = [];
  let skipBlock = false;
  let skipIndent = 0;
  let sidebarTitle = null;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trimStart();
    const indent = line.length - trimmed.length;

    if (skipBlock) {
      if (indent > skipIndent || (trimmed.startsWith('- ') && indent >= skipIndent)) {
        continue;
      }
      skipBlock = false;
    }

    if (/^x-i18n\s*:/.test(trimmed)) {
      skipBlock = true;
      skipIndent = indent;
      continue;
    }
    if (/^read_when\s*:/.test(trimmed)) {
      skipBlock = true;
      skipIndent = indent;
      continue;
    }
    if (/^summary\s*:/.test(trimmed)) continue;
    if (/^mode\s*:/.test(trimmed)) continue;

    if (/^sidebarTitle\s*:/.test(trimmed)) {
      sidebarTitle = trimmed.replace(/^sidebarTitle\s*:\s*/, '').replace(/^["']|["']$/g, '').trim();
      continue;
    }

    newLines.push(line);
  }

  if (sidebarTitle) {
    newLines.push(`sidebar:`);
    newLines.push(`  label: "${sidebarTitle}"`);
  }

  return `---\n${newLines.join('\n')}\n---${body}`;
}

// ============================================================
// Phase 3: Component conversion
// ============================================================
function convertComponents(content) {
  let c = content;
  const imports = new Set();
  let needsMdx = false;

  // --- Admonitions (work in .md, no import needed) ---
  c = c.replace(/<Note>\s*/g, '\n:::note\n');
  c = c.replace(/\s*<\/Note>/g, '\n:::\n');
  c = c.replace(/<Info>\s*/g, '\n:::note\n');
  c = c.replace(/\s*<\/Info>/g, '\n:::\n');
  c = c.replace(/<Tip>\s*/g, '\n:::tip\n');
  c = c.replace(/\s*<\/Tip>/g, '\n:::\n');
  c = c.replace(/<Warning>\s*/g, '\n:::caution\n');
  c = c.replace(/\s*<\/Warning>/g, '\n:::\n');

  // --- Accordion -> <details>/<summary> (HTML, no import) ---
  c = c.replace(/<Accordion\s+title="([^"]*)">/g, '<details>\n<summary>$1</summary>\n');
  c = c.replace(/<\/Accordion>/g, '\n</details>');
  c = c.replace(/<AccordionGroup>/g, '');
  c = c.replace(/<\/AccordionGroup>/g, '');

  // --- Tabs / Tab -> Tabs / TabItem (needs MDX) ---
  if (/<Tabs>/.test(c) || /<Tab\s/.test(c)) {
    needsMdx = true;
    imports.add('Tabs');
    imports.add('TabItem');
    c = c.replace(/<Tab\s+title="([^"]*)">/g, '<TabItem label="$1">');
    c = c.replace(/<\/Tab>/g, '</TabItem>');
  }

  // --- Steps / Step -> Steps with ordered list (needs MDX) ---
  if (/<Steps>/.test(c)) {
    needsMdx = true;
    imports.add('Steps');
    c = convertSteps(c);
  }

  // --- Card with href -> LinkCard (needs MDX) ---
  const cardWithHrefRe = /<Card\s+([^>]*href="[^"]*"[^>]*)>([\s\S]*?)<\/Card>/g;
  if (cardWithHrefRe.test(c)) {
    needsMdx = true;
    imports.add('LinkCard');
    c = c.replace(/<Card\s+([^>]*href="[^"]*"[^>]*)>([\s\S]*?)<\/Card>/g, (_match, attrs, body) => {
      const title = attrs.match(/title="([^"]*)"/)?.[1] || '';
      const href = attrs.match(/href="([^"]*)"/)?.[1] || '';
      const desc = body.trim().replace(/"/g, '\\"');
      return `<LinkCard title="${title}" href="${href}" description="${desc}" />`;
    });
  }

  // --- Card without href -> Card (needs MDX) ---
  if (/<Card\s+[^>]*>/.test(c)) {
    needsMdx = true;
    imports.add('Card');
    c = c.replace(/<Card\s+([^>]*)>/g, (_match, attrs) => {
      const title = attrs.match(/title="([^"]*)"/)?.[1] || '';
      return `<Card title="${title}">`;
    });
  }

  // --- Columns / CardGroup -> CardGrid (needs MDX) ---
  if (/<Columns>/.test(c) || /<CardGroup/.test(c)) {
    needsMdx = true;
    imports.add('CardGrid');
    c = c.replace(/<Columns>/g, '<CardGrid>');
    c = c.replace(/<\/Columns>/g, '</CardGrid>');
    c = c.replace(/<CardGroup(?:\s+cols=\{?\d+\}?)?\s*>/g, '<CardGrid>');
    c = c.replace(/<\/CardGroup>/g, '</CardGrid>');
  }

  // --- Add imports after frontmatter ---
  if (imports.size > 0) {
    const importLine = `import { ${[...imports].sort().join(', ')} } from '@astrojs/starlight/components';\n`;
    c = c.replace(/^(---[\s\S]*?---\n)/, `$1\n${importLine}\n`);
  }

  return { content: c, needsMdx };
}

function convertSteps(content) {
  return content.replace(/<Steps>([\s\S]*?)<\/Steps>/g, (_match, inner) => {
    let stepNum = 0;
    const steps = [];
    const stepRe = /<Step\s+title="([^"]*)">([\s\S]*?)<\/Step>/g;
    let m;
    while ((m = stepRe.exec(inner)) !== null) {
      stepNum++;
      const title = m[1];
      const body = m[2].trim();
      const indented = body.split('\n').map(line => (line === '' ? '' : '   ' + line)).join('\n');
      steps.push(`${stepNum}. ${title}\n\n${indented}`);
    }
    if (steps.length === 0) return _match;
    return `<Steps>\n\n${steps.join('\n\n')}\n\n</Steps>`;
  });
}

// ============================================================
// Phase 4: Migrate content files
// ============================================================
function collectContentFiles(dir, base) {
  const results = [];
  if (!fs.existsSync(dir)) return results;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = base ? path.join(base, entry.name) : entry.name;
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) continue;
      results.push(...collectContentFiles(path.join(dir, entry.name), rel));
    } else if (/\.(md|mdx)$/.test(entry.name)) {
      if (SKIP_FILES.has(entry.name) || SKIP_FILES.has(rel)) continue;
      results.push(rel);
    }
  }
  return results;
}

function migrateContent() {
  console.log('📝 Migrating content files...');
  const files = collectContentFiles(ROOT, '');
  let converted = 0;
  let toMdx = 0;

  for (const relPath of files) {
    const srcPath = path.join(ROOT, relPath);
    const raw = fs.readFileSync(srcPath, 'utf-8');

    let content = convertFrontmatter(raw);
    const { content: final, needsMdx } = convertComponents(content);

    let destRel = relPath;
    if (needsMdx && destRel.endsWith('.md')) {
      destRel = destRel.replace(/\.md$/, '.mdx');
      toMdx++;
    }

    const destPath = path.join(SRC_DOCS, destRel);
    fs.mkdirSync(path.dirname(destPath), { recursive: true });
    fs.writeFileSync(destPath, final, 'utf-8');
    converted++;
  }

  console.log(`   ✓ ${converted} files migrated (${toMdx} converted to .mdx)`);
}

// ============================================================
// Phase 5: Generate sidebar config from docs.json
// ============================================================
function convertGroup(group) {
  const items = [];
  for (const page of group.pages) {
    if (typeof page === 'string') {
      items.push(`        { slug: '${page}' }`);
    } else if (page.group) {
      const nested = convertGroup(page);
      items.push(nested);
    }
  }
  return `      {\n        label: '${group.group}',\n        items: [\n${items.join(',\n')}\n        ],\n      }`;
}

function generateSidebarConfig() {
  const groups = [];
  const tabMeta = [];
  let groupIndex = 0;

  for (const tab of docsConfig.navigation.tabs) {
    const tabGroups = [];
    for (const group of tab.groups) {
      tabGroups.push(groupIndex);
      groups.push(convertGroup(group));
      groupIndex++;
    }
    tabMeta.push({
      label: tab.tab,
      groupIndices: tabGroups,
      firstPage: findFirstPage(tab),
    });
  }

  return { sidebarStr: groups.join(',\n'), tabMeta };
}

function findFirstPage(tab) {
  for (const group of tab.groups) {
    for (const page of group.pages) {
      if (typeof page === 'string') return `/${page}/`;
      if (page.pages) {
        for (const p of page.pages) {
          if (typeof p === 'string') return `/${p}/`;
        }
      }
    }
  }
  return '/';
}

function extractAllPages(tab) {
  const pages = [];
  function walk(items) {
    for (const item of items) {
      if (typeof item === 'string') pages.push(item);
      else if (item.pages) walk(item.pages);
    }
  }
  for (const group of tab.groups) {
    walk(group.pages);
  }
  return pages;
}

// ============================================================
// Phase 6: Generate astro.config.mjs
// ============================================================
function generateAstroConfig() {
  console.log('⚙️  Generating astro.config.mjs...');
  const { sidebarStr } = generateSidebarConfig();

  const config = `import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://openclaw-cn.pages.dev',
  integrations: [
    starlight({
      title: 'OpenClaw 中文网',
      logo: {
        src: '/assets/pixel-lobster.svg',
      },
      favicon: '/assets/pixel-lobster.svg',
      defaultLocale: 'root',
      locales: {
        root: { label: '简体中文', lang: 'zh-CN' },
      },
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/openclaw/openclaw' },
      ],
      customCss: [
        './src/styles/custom.css',
      ],
      components: {
        Header: './src/overrides/Header.astro',
      },
      expressiveCode: {
        themes: ['min-dark', 'min-light'],
      },
      sidebar: [
${sidebarStr}
      ],
    }),
  ],
});
`;

  fs.writeFileSync(path.join(ROOT, 'astro.config.mjs'), config, 'utf-8');
  console.log('   ✓ astro.config.mjs generated');
}

// ============================================================
// Phase 7: Generate navigation data for tabs
// ============================================================
function generateNavigationData() {
  console.log('🗺️  Generating navigation data...');
  const tabs = [];
  let groupIndex = 0;

  for (const tab of docsConfig.navigation.tabs) {
    const groupIndices = [];
    for (let i = 0; i < tab.groups.length; i++) {
      groupIndices.push(groupIndex);
      groupIndex++;
    }
    tabs.push({
      label: tab.tab,
      slug: tab.tab,
      firstPage: findFirstPage(tab),
      groupIndices,
      pages: extractAllPages(tab),
    });
  }

  const data = `export const tabs = ${JSON.stringify(tabs, null, 2)};

export function getActiveTab(pathname) {
  const clean = pathname.replace(/^\\//, '').replace(/\\/$/, '');
  for (const tab of tabs) {
    if (tab.pages.some(p => clean === p || clean.startsWith(p + '/'))) {
      return tab;
    }
  }
  return tabs[0];
}
`;

  fs.mkdirSync(path.join(ROOT, 'src', 'data'), { recursive: true });
  fs.writeFileSync(path.join(ROOT, 'src', 'data', 'navigation.mjs'), data, 'utf-8');
  console.log('   ✓ src/data/navigation.mjs generated');
}

// ============================================================
// Phase 8: Generate redirects
// ============================================================
function generateRedirects() {
  console.log('🔀 Generating redirects...');
  const redirects = docsConfig.redirects || [];
  const lines = redirects.map(r => `${r.source} ${r.destination} 301`);
  fs.mkdirSync(PUBLIC, { recursive: true });
  fs.writeFileSync(path.join(PUBLIC, '_redirects'), lines.join('\n') + '\n', 'utf-8');
  console.log(`   ✓ ${lines.length} redirects written to public/_redirects`);
}

// ============================================================
// Run
// ============================================================
console.log('🚀 Starting migration from Mintlify to Astro Starlight...\n');
copyAssets();
generateAstroConfig();
generateNavigationData();
migrateContent();
generateRedirects();
console.log('\n✅ Migration complete!');
