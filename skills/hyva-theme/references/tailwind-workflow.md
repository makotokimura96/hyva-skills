# Tailwind CSS workflow in Hyvä

## What differs from Luma

There is no LESS pipeline, no `_module.less`, no automatic CSS inheritance. Tailwind scans `.phtml` and layout `.xml` files for class names and emits a single `web/css/styles.css` (~100 KB, ~17 KB over the wire). Nothing that Tailwind cannot see in a source file ends up in the stylesheet. Unlike Luma/LESS, **Tailwind config and CSS files are not inherited from a parent theme** — a child theme must copy the build setup and explicitly include the parent's sources.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/index.html>, <https://docs.hyva.io/hyva-themes/working-with-tailwindcss/sharing-common-css-between-themes.html>

## Build commands

Run from the theme's `web/tailwind` directory — or `vendor/hyva-themes/magento2-default-theme/web/tailwind/` on projects with no child theme. Most projects wrap these in a `make build` / `make watch` target.

```bash
npm ci --ignore-scripts      # clean, reproducible install; --ignore-scripts guards against supply-chain attacks
npm run build                # minified production styles.css into ../css/
npm run watch                # rebuild on save
npm start                    # alias for `npm run watch` (since Hyvä 1.4.0)
npm run browser-sync -- --proxy http://your-magento.test
```

`--prefix` lets you run from anywhere:

```bash
npm --prefix path/to/theme/web/tailwind ci --ignore-scripts
npm --prefix path/to/theme/web/tailwind run build
```

Removed/deprecated: `npm run build-prod` (removed in 1.4.0), `npm run build-dev` (deprecated in 1.2.0, removed in 1.4.0 — use `watch`).

Tailwind v4 `package.json` scripts in the Default Theme:

```json
"scripts": {
    "start": "npm run watch",
    "generate": "npx hyva-sources && npx hyva-tokens",
    "prewatch": "npm run generate",
    "watch": "npx tailwindcss -i tailwind-source.css -o ../css/styles.css --watch",
    "browser-sync": "npx browser-sync start --config ./browser-sync.config.js",
    "prebuild": "npm run generate",
    "build": "npx tailwindcss -i tailwind-source.css -o ../css/styles.css --minify"
}
```

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/generating-css.html>, <https://docs.hyva.io/hyva-themes/working-with-tailwindcss/updating-to-tailwind-4.html>

## Directory structure (Hyvä >= 1.4.0)

```
./web/tailwind
├── base           # Hyvä preflight, better defaults than Tailwind's; example of classless styling
├── components     # toolbar, button, form, messages, slider, page-builder …
├── generated      # hyva-source.css and hyva-tokens.css (generated, do not edit)
├── utilities      # custom utilities
└── theme          # page-specific / custom styles (e.g. page-layout.css, typography.css)
```

Themes based on 1.3.x or older have a flatter, different layout.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/hyva-theme-css-files.html>

## Entry point (`tailwind-source.css`, Tailwind v4)

```css
@import "@hyva-themes/hyva-modules/css";
@import "tailwindcss" source(none);

@source "../../**/*.phtml";
@source "../../**/*.xml";

/* Custom styles */
@import "./base";
@import "./components";
@import "./theme";
@import "./utilities";

/* Generated: Hyvä-compatible module sources and design tokens */
@import "./generated/hyva-source.css";
@import "./generated/hyva-tokens.css";

@theme {
    --color-bg: var(--color-slate-50);
    --color-fg: var(--color-slate-950);
    --color-fg-secondary: var(--color-slate-600);
    --color-surface: var(--color-white);
}
```

Since 1.5.2 the tokens `--color-ink` and `--color-ink-muted` exist alongside `fg`/`fg-secondary`; `ink` pairs with `surface`. Both names still work, but `fg`/`fg-secondary` are slated for removal — update overridden `.phtml` templates that use those class names.

Tailwind v4 requires **explicit relative `@import` paths** (`./` or `../`). `@import "acme/file.css"` fails; `@import "./acme/file.css"` works in both v3 and v4.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/updating-to-tailwind-4.html>, <https://docs.hyva.io/hyva-themes/upgrading/upgrading-to-1-5-2.html>

## Content ("purge") configuration

`app/etc/hyva-themes.json` lists installed modules whose files must be scanned. It is generated/updated automatically by `setup:install`, `setup:upgrade`, `module:enable`, `module:disable` (since theme-module 1.1.15 / 1.1.14). Regenerate manually with:

```bash
bin/magento hyva:config:generate
```

- **Tailwind v4**: `npx hyva-sources` reads `app/etc/hyva-themes.json` + `hyva.config.json` and writes `web/tailwind/generated/hyva-source.css` with `@source`/`@import` directives.
- **Tailwind v3**: `mergeTailwindConfig` (in `tailwind.config.js`) and `postcssImportHyvaModules` (in `postcss.config.js`) read the same JSON and merge paths into the `content` array.

Add extra paths manually with more `@source` rules (v4) or extra `content` entries (v3):

```css
@source "../../**/*.phtml";
/* app/code module templates */
@source "../../../../../../code/acme/my-module/**/*.phtml";
```

On CI/CD builds where `setup:install` runs with Hyvä packages already present (Hyvä <= 1.1.13), run `bin/magento hyva:config:generate` before building the stylesheet.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/tailwind-purging-settings.html>, <https://docs.hyva.io/hyva-themes/building-your-theme/ci-cd-hyva-installation.html>

## `@hyva-themes/hyva-modules` npm package

The glue between the theme build and Hyvä-compatible modules. Capabilities: source/config merging, CSS-variable helpers (`twProps`/`twVar`, v2/v3 only), design token integration, prose typography, form styles, and fallback utilities.

### `npx hyva-init`

Creates `hyva.config.json` next to `package.json`. Full shape:

```json
{
  "tailwind": {
    "include": [{ "src": "<PATH>" }],
    "exclude": [{ "src": "<PATH>", "keepSource": true }]
  },
  "tokens": {
    "src": "acme-hyva.design.tokens.json",
    "values": { "color": { "hyva-blue": "oklch(0.38 0.23 265.33)" } },
    "format": "default",
    "cssSelector": ":root",
    "stripPrefix": "tokens.values",
    "rename": { "colors": "color" },
    "mediaDark": ".dark"
  }
}
```

`tokens.format` accepts `"default"` or `"figma"`. Unknown keys are ignored.

### `npx hyva-sources` (Tailwind v4 only)

Generates `generated/hyva-source.css`. For each registered module it emits `@source` for `.phtml`/`.xml` (when the module has a `tailwind.config.js`) and `@import` for its `tailwind-source.css`. If a module ships `view/frontend/tailwind/module.css`, that file is the single source of truth and legacy config files are ignored.

Extra options in `hyva.config.json`: `area` (default `view/frontend`, set `adminhtml` for admin themes), `includeExternalModules` (default enabled; `false` to manage all sources manually), `exclude[].keepSource: true` to keep `@source` scanning while skipping the CSS `@import`.

### `npx hyva-tokens`

Reads a design-token file (default `design.tokens.json` in `tailwind/`) and writes `generated/hyva-tokens.css`, outputting under `@theme` (v4) or `:root` (set `cssSelector`, for v2/v3).

Supported formats: **DTCG** (default; `$value`/`$type`), **legacy Tokens Studio** (`format: "figma"`; `value`/`type`), **Google Stitch Markdown** (auto-detected from a `.md` `src`; only YAML frontmatter read, `colors` group auto-renamed to `color`), and **Simple Tokens** (plain key/value pairs under `tokens.values` in `hyva.config.json`, with `@media:dark-` prefixed keys for dark mode). DTCG 2025.10 is **not yet supported**.

CSS variable names come from the key path with dots replaced by dashes: `color.primary-lighter` → `--color-primary-lighter`. Keep hierarchies shallow. Use `stripPrefix` to drop wrapper keys and `rename` to align group names. `values` is ignored (with a warning) if `src` is also set.

Simple tokens can be shared with a Tailwind v3 config:

```js
const hyvaConfig = require('./hyva.config.json');
module.exports = { theme: { extend: {
    colors: hyvaConfig.tokens.values.color,
    spacing: hyvaConfig.tokens.values.spacing,
} } };
```

Beware: token names that collide with Tailwind's own scale (e.g. `spacing.4`) override it.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/using-hyva-modules/index.html>, <https://docs.hyva.io/hyva-themes/working-with-tailwindcss/using-hyva-modules/sources.html>, <https://docs.hyva.io/hyva-themes/working-with-tailwindcss/using-hyva-modules/tokens.html>, <https://docs.hyva.io/hyva-themes/working-with-tailwindcss/design-tokens/formats.html>, <https://docs.hyva.io/hyva-themes/working-with-tailwindcss/design-tokens/simple-tokens.html>

### Prose (typography)

Since 1.4 `prose` comes from `@hyva-themes/hyva-modules` instead of `@tailwindcss/typography`. Differences: **no default max-width** (add `max-w-prose`; the old `prose max-w-none` workaround is obsolete), lower specificity via `:where()` so utilities inside prose win, CSS-variable customization, smaller output.

```css
.prose {
    --link-color: var(--color-primary);
    --h-weight: 700;
    --h1-size: 2.5em;
}
```

Variables: `--text-flow` (`1em 1rem`), `--separator-flow` (`2.5em`), `--list-flow` (`0.5em`), `--h-color`, `--h-family`, `--h-weight` (`600`), `--h-line` (`1.1`), `--h1-size` (`3em`), `--h2-size` (`2em`), `--h3-size` (`1.625em`), `--h4-size` (`1.375em`), `--marker-color`, `--link-color`, `--link-weight` (`500`), `--blockquote-color`, `--table-py`, `--table-px`, `--table-stroke`, `--table-bg`, `--table-color`.

Variants `prose-headings:`, `prose-h1:`…`prose-h6:`, `prose-lead:`, `prose-p:`, `prose-a:`, `prose-blockquote:`, `prose-strong:`, `prose-em:`, `prose-code:`, `prose-pre:`, `prose-ul:`, `prose-ol:`, `prose-li:`, `prose-hr:`, `prose-table:`, `prose-th:`, `prose-td:`, `prose-img:`, `prose-figure:`, `prose-figcaption:`, `prose-video:`, `prose-iframe:`. Each variant used adds CSS — prefer a custom modifier class that overrides variables. `class="lead"` gives an intro paragraph at `1.25em`.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/using-hyva-modules/prose.html>

### Forms

`css/forms.css` is a Tailwind-v4-optimized port of `@tailwindcss/forms` (with Fylgja Base improvements), driven entirely by CSS variables defined under `@theme`:

| Variable | Default | Controls |
|---|---|---|
| `--form-py` | `spacing(2)` | vertical padding |
| `--form-px` | `spacing(3)` | horizontal padding |
| `--form-radius` | `var(--radius-sm)` | border radius |
| `--form-stroke` | `currentcolor` | border color |
| `--form-bg` | `#fff` | background |
| `--form-color` | `currentcolor` | text color |
| `--form-active-color` | `var(--color-blue-600)` | focus/checked color |
| `--select-icon` | chevron SVG | dropdown arrow |
| `--select-icon-size` | `1.25em` | arrow size |
| `--select-icon-offset` | `0.8rem` | arrow offset |

Explicit class selectors are also styled: `.form-input`, `.form-textarea`, `.form-select`, `.form-multiselect`, `.form-checkbox`, `.form-radio`.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/using-hyva-modules/forms.html>

### Fallback utilities

`css/fallback.css` re-adds v2/v3 utilities removed in v4 so third-party modules keep working: `bg-opacity-*`/`text-opacity-*`/`border-opacity-*`/`divide-opacity-*`/`ring-opacity-*`/`placeholder-opacity-*` (→ slash syntax `bg-black/50`), `flex-shrink`/`flex-shrink-0`/`flex-grow`/`flex-grow-0` (→ `shrink`/`grow`), `overflow-ellipsis` (→ `text-ellipsis`), `decoration-slice`/`decoration-clone` (→ `box-decoration-*`). Safe to keep — unused utilities are not emitted. Do not use them in new code.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/using-hyva-modules/fallback.html>

## CSS variables + Tailwind

Tailwind v4 is built on CSS variables. Declare theme colors with `@theme`, and reference other variables freely:

```css
@theme {
    --color-bg: var(--color-primary-lighter);
    --color-fg: var(--color-primary-darker);
    --color-surface: var(--color-white);
}
```

Prefer `var(--color-primary)` over the v3 `theme('colors.primary.DEFAULT')` function. Arbitrary values can reference variables directly: `class="text-[var(--alt-color)]"` — but overusing arbitrary values inflates the stylesheet.

Variables can be declared in `:root` in imported CSS, in `Design Configuration > HTML Head > Scripts and Style Sheets`, or rendered from PHP in a `<style>` block:

```html
<style>
    :root {
        --color-primary: 160 100% 54%;
        --color-primary-darker: <?= $brandColor ?>;
    }
</style>
```

For Tailwind v3, `@hyva-themes/hyva-modules` >= 1.0.10 provides `twProps` (wraps a whole token tree) and `twVar` (single value), both preserving Tailwind opacity modifiers via CSS `color-mix()`:

```js
const { twProps, twVar, mergeTailwindConfig } = require('@hyva-themes/hyva-modules');
const colors = require('tailwindcss/colors');
module.exports = mergeTailwindConfig({
  theme: { extend: { colors: twProps({
      primary: { lighter: colors.blue['600'], DEFAULT: colors.blue['700'], darker: colors.blue['800'] },
  }) } }
});
```

`twProps` turns values into `var(--color-primary, #1d4ed8)` — the original value becomes the fallback.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/css-variables-plus-tailwindcss.html>

## Dynamic class names

Tailwind cannot evaluate PHP. `columns-<?= $n ?>` is never generated. Three fixes, in order of preference:

**1. CSS variables (recommended, Tailwind v4):**

```html
<ul class="gap-8 columns-(--responsive-columns-number) xl:columns-(--columns-number)"
    style="--responsive-columns-number: <?= $responsiveColumnsNumber ?>;
           --columns-number: <?= $columnsNumber ?>;"></ul>
```

**2. Declare all possible values in a PHP comment** (Tailwind scans all text, comments included) — co-located, and removed with the template:

```php
<?php
// Declare possible values for Tailwind:
// columns-1 columns-2 columns-3 xl:columns-1 xl:columns-2 xl:columns-3
?>
```

**3. Safelist** — only when values come from the database or an external source. Tailwind v4 in `tailwind-source.css`:

```css
@source inline("{xl:,}columns-{1,2,3}");
```

Tailwind v3 in `tailwind.config.js`:

```js
safelist: [{ pattern: /columns-(1|2|3)/, variants: ['lg'] }]
```

Safelisted classes are always emitted, growing the CSS.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/dynamic-tailwind-classes.html>

## Styling layout containers

Layout XML containers accept `htmlTag` and `htmlClass`:

```xml
<container name="example" htmlTag="div" htmlClass="container mx-auto px-4"/>
```

Magento's `htmlClassType` XSD pattern is `[a-zA-Z][a-zA-Z\d\-_]*(\s…)*`, so Tailwind classes containing `/ : [ ] .` (e.g. `w-1/3`) raise a `Config\Dom\ValidationException`. Two workarounds:

- Patch `vendor/magento/framework/View/Layout/etc/elements.xsd` to widen the pattern (upstream PR merged Feb 2023 but not in every release — test with `w-1/2` first).
- **Preferred**: use a schema-safe class name in XML and compose utilities in `web/tailwind/theme/page-layout.css`:

```css
.columns { @apply order-2 w-1/3; }
```

Hyvä 1.2.x+ already includes layout XML in the Tailwind content paths; 1.0.x/1.1.x needed manual patterns.

Sticky footer example:

```xml
<referenceContainer name="page.wrapper" htmlClass="page-wrapper min-h-screen flex flex-col"/>
<referenceContainer name="main.content" htmlClass="page-main flex-grow"/>
```

<https://docs.hyva.io/hyva-themes/building-your-theme/styling-layout-containers.html>, <https://docs.hyva.io/hyva-themes/faqs/footer-at-screen-bottom-if-short-content.html>

## Sharing CSS between themes / excluding module CSS

Import specific parent-theme CSS files into a child theme's `tailwind-source.css` (never the whole parent `tailwind-source.css` — duplicate `tailwindcss` imports):

```css
@import "../../../../../../../vendor/hyva-themes/magento2-default-theme/web/tailwind/base";
@import "../../../../../../../vendor/hyva-themes/magento2-default-theme/web/tailwind/components";
```

Tailwind v3 alternatives: `presets: [parentTheme]` inside `mergeTailwindConfig({...})`, or `require` and merge selected parts (e.g. `...parentTheme.theme.extend.screens`).

Exclude a module's CSS — Tailwind v4 in `hyva.config.json`:

```json
{ "tailwind": { "exclude": [{ "src": "vendor/hyva-themes/magento2-hyva-checkout/src" }] } }
```

Tailwind v3 via `postcssImportHyvaModules({ excludeDirs: [...] })` in `postcss.config.js` (must come **before** `postcss-import` and `tailwindcss/nesting`).

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/sharing-common-css-between-themes.html>, <https://docs.hyva.io/hyva-themes/working-with-tailwindcss/overriding-module-css.html>

## Custom fonts

Load either from Google Fonts (via `Magento_Theme/layout/default_head_blocks.xml`, `&` written as `&amp;`; note GDPR risk — self-hosting is recommended) or self-hosted `woff2` files in `web/fonts/`. Register with `@font-face` in e.g. `web/tailwind/theme/typography.css`; paths are relative to the generated CSS in `web/css/`, so `../fonts/`.

```css
@font-face {
    font-family: 'Roboto';
    font-style: normal;
    font-weight: 400;
    font-display: swap;
    src: url('../fonts/roboto-regular.woff2') format('woff2');
}
```

Expose as a utility — Tailwind v4:

```css
@theme {
    --font-sans: 'Roboto', ui-sans-serif, system-ui, sans-serif;
    --font-brand: 'Roboto', ui-sans-serif, system-ui, sans-serif; /* generates font-brand */
}
```

Tailwind v3: `theme.extend.fontFamily.sans = ['Roboto', ...defaultTheme.fontFamily.sans]`.

`font-display` values: `swap` (recommended), `optional`, `block`, `fallback`. **Preloading fonts blocks first render and can hurt LCP** — prefer accurate fallback stacks with matching `line-height`, `size-adjust` and `ascent-override`. If you still preload: `<font src="fonts/roboto.woff2"/>` in `default_head_blocks.xml`.

<https://docs.hyva.io/hyva-themes/building-your-theme/custom-fonts.html>

## RTL

Add `dir` to the `<html>` tag (not `<body>`). Static, in `default_head_blocks.xml`:

```xml
<html><attribute name="dir" value="rtl"/></html>
```

Or conditionally via an observer on `layout_load_before` calling
`$pageConfig->setElementAttribute(PageConfig::ELEMENT_TYPE_HTML, 'dir', $isRtl ? 'rtl' : 'ltr')`.

Use Tailwind's `rtl:` modifier (v3.0+) or, better, direction-aware logical utilities (`ps-4`/`pe-4`, `ms-*`/`me-*`, v3.3+).

<https://docs.hyva.io/hyva-themes/faqs/rtl-text.html>

## Troubleshooting Tailwind

- **`@import` is not found (v4)** → use `./` or `../` prefixed relative paths.
- **`Unknown at rule: @screen` (v4)** → `@screen` was removed. Use `@variant md { … }` or `md:` utilities. Hyvä Checkout must be >= 1.3.6 for v4-ready CSS.
- **`.gitignore` conflicts with `@source` (v4)** → Tailwind v4 honours `.gitignore`. An allow-list `.gitignore` (`*` then `!app/`) makes `vendor/hyva-themes/magento2-default-theme` invisible and produces missing styles. Switch to a deny-list `.gitignore` based on the official Magento 2 one. This is also the fix for Adobe Commerce Cloud's default `.gitignore`.
- **`corePlugins: false` no longer works in v4.** An undocumented workaround is `@source not inline("class-name")` for some utilities (e.g. `container`); it cannot replace the disabled utility and may break without notice. Disabling `preflight` needs the approach in the Tailwind docs.
- **Styles look broken** → hard reload; check the `styles.css` network response (200 with PHP error vs 404 → check deploy mode and `setup:static-content:deploy`); run `npm run build` and read its output; then debug at HTML/CSS level.
- **Header unstyled but the rest fine** → `<esi:include>` tags in the source mean Varnish is enabled but misconfigured. Locally set `Caching Application` to `Built-in Cache`. Reported also with Varnish + Brotli compression — disable Brotli.
- **Lighthouse "eliminate render-blocking CSS"** for `styles.css` is expected and correct; the real problems are a large file or unused styles. Make sure you shipped a production build, not the watch output.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/troubleshooting.html>, <https://docs.hyva.io/hyva-themes/faqs/troubleshooting.html>, <https://docs.hyva.io/hyva-themes/performance/measuring-performance.html>

## Critical CSS

**Not supported by Hyvä.** Tailwind already ships only used styles, so critical CSS is obsolete and can hurt. If unavoidable, add the `critical_css_block` (with `ifconfig="dev/css/use_css_critical_path"` and the `Magento\Theme\Block\Html\Header\CriticalCss` view model) to `Magento_Theme/layout/default_head_blocks.xml`, create `web/css/critical.css`, and enable `Stores > Configuration > Advanced > Developer > CSS Settings > Use CSS critical path`.

<https://docs.hyva.io/hyva-themes/faqs/critical-css.html>

## browser-sync and Browserslist

```bash
npm install -g browser-sync --ignore-scripts
cd path/to/theme/web/tailwind && npm run browser-sync    # honours PROXY_URL
browser-sync start --proxy "https://your-magento.test" --https \
  --files 'app/**/*.phtml, app/**/*.xml, app/**/*.css, app/**/*.js'
```

If reloads show no change, check that `full_page`, `blocks_html` and `layout` caches are disabled (or use `mage-os/magento-cache-clean` with its watcher).

Browserslist (`"browserslist": ["> 0.5% and not dead"]` in `package.json`) applied to Hyvä 1.3.6–1.4.0 with `postcss-preset-env`. **From Hyvä 1.4 / Tailwind v4 it no longer applies** — Tailwind v4 uses a bundled lightningcss build that ignores browserslist and targets iOS Safari 15.4+.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/using-browser-sync.html>, <https://docs.hyva.io/hyva-themes/working-with-tailwindcss/using-browserlist.html>

## Multi-theme / centralized npm (advanced)

Copy `package.json`, `package-lock.json`, `browser-sync.config.js` (and `postcss.config.js` on v3) to the Magento root, `npm install --ignore-scripts` once, then define per-theme scripts:

```json
"build-default": "npx @tailwindcss/cli -i app/design/frontend/Acme/default/web/tailwind/tailwind-source.css -o app/design/frontend/Acme/default/web/css/styles.css --minify"
```

Tailwind v3 needs `npx tailwindcss --postcss … -c <theme>/web/tailwind/tailwind.config.js`. Keep Tailwind itself project-local; only CLI tools like browser-sync are reasonable global installs. For simple sharing of variables/utilities, prefer the shared-CSS approach instead.

<https://docs.hyva.io/hyva-themes/advanced-topics/global-npm-packages.html>

## Email styling

Hyvä does not style transactional emails. `hyva-themes/magento2-email-module` (a dependency of the default theme) re-enables Luma's LESS pipeline **for emails only**. Copy `email.less` to your theme's `web/css/`, `_email-extend.less` and `_email-variables.less` to `web/css/source/`, and (for sales emails) Luma's `Magento_Sales/web/css/source/_email.less` and `_module.less`. Override `Magento_Email/email/header.html` / `footer.html` and place a logo at `Magento_Email/web/logo_email.png`.

Tailwind-generated email CSS is possible on **Tailwind v3 only**: a `web/tailwind/emails/postcss.config.js` plus `tailwind.email.config.js` that disables the `*Opacity` core plugins (Magento's LESS parser cannot handle RGBA), and a `build-email` script piping `theme/email.css` to `../css/source/_theme.less` via `postcss-cli`. **Tailwind v4 has no good email solution yet** — its output is too modern for email clients; the docs suggest keeping v3 alongside v4 for emails or adding a downgrade post-build step (community option: `maizzle/tailwindcss`). Git-ignore the generated `_theme.less`.

<https://docs.hyva.io/hyva-themes/building-your-theme/styling-emails.html>, <https://docs.hyva.io/hyva-themes/advanced-topics/styling-emails-with-tailwind.html>

## Editor setup

Tailwind IntelliSense: built into JetBrains IDEs (no plugin); official `bradlc.vscode-tailwindcss` for VS Code; built into Zed.
Alpine: JetBrains "Alpine.js Support" plugin; an Alpine.js extension for VS Code or Zed. Browser: Alpine.js devtools extension. Commercial helpers for Luma→Tailwind conversion: Windy, DevTools for Tailwind.

<https://docs.hyva.io/hyva-themes/working-with-tailwindcss/editor-setup.html>, <https://docs.hyva.io/hyva-themes/working-with-alpinejs/editor-setup.html>
