# CMS content, Page Builder and Tailwind in the database

Magento offers CMS Pages, CMS Blocks, PageBuilder and Widgets — Hyvä supports all of them. Headless options (Prismic, Storyblok) exist, and Hyvä CMS (part of Hyvä Commerce, with its own Liveview Editor) is the most integrated option. Everything below applies to **native** Magento CMS content.

<https://docs.hyva.io/hyva-themes/cms/index.html>

## The two problems with CMS content in a Tailwind theme

1. **Tailwind's base reset strips default element styling.** HTML pasted into a CMS block renders as unstyled plain text — headings, paragraphs and bullet lists all look the same.
2. **Tailwind only compiles classes it can see at build time.** Classes that only exist in the database are never scanned and therefore never emitted.

## Problem 1: the `prose` class

Add `prose` to a container to restore readable defaults for headings, paragraphs, lists, blockquotes, links, tables and code. Since Hyvä 1.4 it comes from `@hyva-themes/hyva-modules` (previously `@tailwindcss/typography`), has **no default max-width**, and uses `:where()` so Tailwind utilities inside a prose container still win without `unset` overrides.

```html
<div class="prose max-w-prose">
    <!-- CMS content here -->
</div>
```

Upgrading from 1.3 or earlier: drop the `max-w-none` that used to be needed to undo the plugin's max-width.

To apply it everywhere automatically, override the relevant template in the child theme — e.g. category CMS content:

```php
<?php /* app/design/frontend/Vendor/Theme/Magento_Catalog/templates/category/cms.phtml */ ?>
<?php if ($block->isContentMode() || $block->isMixedMode()) :?>
    <div class="category-cms prose max-w-none">
        <?= $block->getCmsBlockHtml() ?>
    </div>
<?php endif; ?>
```

See `tailwind-workflow.md` for the full list of prose CSS variables and variants.

<https://docs.hyva.io/hyva-themes/cms/cms-content-text-styling.html>, <https://docs.hyva.io/hyva-themes/working-with-tailwindcss/using-hyva-modules/prose.html>

## Problem 2: the CMS Tailwind JIT module

`Hyva_CmsTailwindJit` runs a Tailwind compiler **when content is saved in the admin**, stores the resulting CSS in the database, and injects it inline immediately before the content on the storefront. There is no compilation on storefront requests, so no page-load cost.

```bash
composer require hyva-themes/magento2-cms-tailwind-jit
bin/magento setup:upgrade
```

It is installed automatically as a dependency of Hyvä CMS; with Hyvä Theme + PageBuilder only, install it explicitly.

Supported content types: **CMS Blocks**, **CMS Pages**, **Product Descriptions** (full and short), **Category Descriptions**. Supported editors: Hyvä CMS, Magento PageBuilder, classic TinyMCE. In PageBuilder the content preview works for CMS Block widgets and HTML Code content types.

### Choosing the compiler version

One **global** setting selects the compiler:
`Stores → Configuration → Hyvä Themes → PageBuilder → CMS Tailwind Compilation → PageBuilder Tailwind Compiler`
(config path `hyva_cms_tailwind_jit/general/compiler_version`).

| Option | Value | Per-theme source file |
|---|---|---|
| Tailwind v3 (in-browser) | `v3` (default) | `web/tailwind/tailwind.browser-jit-config.js` (JS) |
| Tailwind v4 (in-browser) | `v4` | `web/tailwind/tailwind.browser-jit.css` (CSS) |
| Node Tailwind (server-side) | — | none; uses the theme's real Tailwind config |

```bash
bin/magento config:set --lock-config hyva_cms_tailwind_jit/general/compiler_version v4
```

`--lock-config` writes the value into `app/etc/config.php` so it can be committed and is no longer editable in the admin.

**Use v4 for new installations** — it produces significantly smaller compiled CSS, so less is injected per entity. The default stays `v3` for backward compatibility. Switching to v4 is **not** backward compatible for per-theme config: migrate customizations to CSS first. Already-stored CSS from either compiler keeps rendering after a switch (both flow through the same render-time pipeline), so no recompile is strictly required; re-save entities to regenerate with the new compiler.

Per-theme source files are optional — the default Tailwind utilities work without one. On save, the module posts an informational admin notice listing Hyvä themes that lack the active version's source file.

<https://docs.hyva.io/hyva-themes/cms/tailwind-jit/index.html>, <https://docs.hyva.io/hyva-themes/cms/tailwind-jit/installation.html>

### Per-theme configuration, Tailwind v3

`web/tailwind/tailwind.browser-jit-config.js` follows `tailwind.config.js` structure but is evaluated **in the browser**, so it is heavily restricted.

Allowed: the `module.exports.theme` object and exactly two imports —
`require('tailwindcss/defaultTheme')` and `require('tailwindcss/colors')`.
Not allowed: any other `require()`, `resolveConfig()`, filesystem access, or code outside `module.exports`.

```js
const { spacing } = require('tailwindcss/defaultTheme');
const colors = require('tailwindcss/colors');

module.exports = {
  theme: {
    container: { center: true, padding: spacing["6"] },
    extend: {
      colors: {
        'my-gray': '#888877',
        primary: {
          lighter: colors.purple['300'],
          DEFAULT: colors.purple['800'],
          darker: colors.purple['900'],
        },
      }
    },
  }
}
```

To avoid maintaining the same extensions twice, append a deep-merge snippet at the end of `tailwind.config.js` that merges `tailwind.browser-jit-config.js` into it (documented on the configuration page).

### Per-theme configuration, Tailwind v4

`web/tailwind/tailwind.browser-jit.css` is passed verbatim to the in-browser compiler and may use any Tailwind v4 directive (`@theme`, `@layer`, `@utility`, …).

**No `@import` or `@source`** — the compiler has no filesystem access. Inline whatever you need. Because it runs against the live page, CSS custom properties your theme already defines via `@theme` are in scope:

```css
.cms-callout {
    border-left: 4px solid var(--color-primary);
    padding: var(--spacing-4);
    background: var(--color-primary-lighter);
}
```

Migration from v3: recreate each `theme.extend` value as a CSS custom property.

```css
@theme {
    --color-primary-lighter: #d8b4fe; /* purple-300 */
    --color-primary: #6b21a8;         /* purple-800 */
    --color-primary-darker: #581c87;  /* purple-900 */
}
```

Then set the compiler to v4 and `bin/magento cache:flush` (the admin save invalidates the config cache automatically; a CLI `config:set` does not).

Both paths can be relocated with `etc/cms-tailwind-jit-theme-config.json` in the theme (`tailwindBrowserJitConfigPath` / `tailwindBrowserJitCssPath`). Paths starting with `/` are absolute, everything else is relative to the theme directory; an unreadable file falls back silently to the default configuration.

<https://docs.hyva.io/hyva-themes/cms/tailwind-jit/configuration.html>

### How the CSS is scoped

Compiled CSS is stored per entity and store view:

| Content type | Table |
|---|---|
| CMS Blocks | `hyva_cms_block_tailwindcss` |
| CMS Pages | `hyva_cms_page_tailwindcss` |
| Product Descriptions | `hyva_catalog_product_tailwindcss` |
| Category Descriptions | `hyva_catalog_category_tailwindcss` |

At render time the class names in both the CSS and the content are rewritten with a per-entity prefix `hcms-{type}-{id}-` — `.bg-red-300` becomes `.hcms-page-42-bg-red-300` — which scopes the styles without a wrapper element. The Tailwind-v3-only versions of the module used `cmsp{id}-` / `cmsb{id}-`; theme CSS that hand-targets those old class names stops matching after the update, and affected content must be re-saved to recompile.

### Instances without PageBuilder

If PageBuilder modules are disabled, disable the module's PageBuilder form mixin or the admin errors:

```js
// app/code/My/Module/view/adminhtml/requirejs-config.js
var config = {
    config: { mixins: { 'Magento_Ui/js/form/form': {
        'Hyva_CmsTailwindJit/js/form/pagebuilder-form-submit-mixin': false
    } } }
};
```

Add `<module name="Hyva_CmsTailwindJit"/>` to your module's `etc/module.xml` `<sequence>` for load order, then `bin/magento cache:flush` (plus `setup:static-content:deploy` in production mode).

### Alpine `:class` bindings with single-quoted Tailwind classes

Narrow edge case: Tailwind classes containing single quotes (e.g. `after:content-['bar']`) inside an Alpine `:class` binding must be backslash-escaped, and a Tailwind JIT bug then emits the escaped quotes literally. Workaround — add an HTML comment with the unquoted class right before the element:

```html
<!-- after:content-['bar'] -->
<div :class="{'after:content-[\'bar\']': activeTab === 0}"></div>
```

Better: avoid `:class` entirely and use Tailwind data-attribute variants — no JS string escaping, no compiler bug:

```html
<div :data-open="activeTab === 0" class="data-[open=true]:rotate-90"></div>
```

Alpine class bindings are **not recommended on strict-CSP pages** at all: the expressions are inline JS and get blocked.

<https://docs.hyva.io/hyva-themes/cms/tailwind-jit/alpine-js.html>

### Server-side compilation (optional)

Three modules move compilation from the admin iframe to a Node daemon:

| Module | Role | Required |
|---|---|---|
| `hyva-themes/magento2-cms-tailwind-compiler` | Node daemon compiling CMS HTML server-side, returning only the **delta** CSS (classes not already in the theme's `styles.css`), scoped to the entity | Yes |
| `hyva-themes/magento2-cms-tailwind-jit-bridge` | Replaces the in-browser iframe with calls to the daemon; adds the **Node Tailwind (server-side)** option | Yes |
| `hyva-themes/magento2-cms-tailwind-recompile` | Bulk recompilation via CLI or a cron queue | Optional |

```bash
composer require hyva-themes/magento2-cms-tailwind-jit-bridge   # pulls in the compiler
bin/magento setup:upgrade
```

Why: no separate in-browser config to keep in sync (it uses each theme's real `tailwind.config.js` / `tailwind-source.css`), per-theme Tailwind version detection so v3 and v4 themes coexist, bulk recompilation, faster compiles, and a smaller injected payload (delta CSS only). Admin UX, storage, scoping and PageBuilder integration are unchanged.

**Installing the bridge changes the default** compiler to *Node Tailwind (server-side)*; without it the default stays *Tailwind v3 (in-browser)*. If the daemon is unreachable and on-demand start is off, editor compilation fails.

Deployment requirement: each theme's `web/tailwind/` must be deployed — `package.json`, the Tailwind config, and any referenced local CSS. `node_modules/` is **not** required (the daemon auto-installs per-theme dependencies into `var/hyva_cms_tailwind_deps/` on first compile, configurable via `deps_dir`), but build pipelines that ship only `web/css/` and delete `web/tailwind/` must be changed. Each theme also needs `generated/hyva-source.css` and `generated/hyva-tokens.css`; the daemon generates them if missing but silently reuses **stale** ones — regenerate and restart after adding modules:

```bash
cd vendor/hyva-themes/magento2-default-theme/web/tailwind
npx hyva-sources && npx hyva-tokens
```

**Daemon Management** (`Stores → Configuration → Hyvä Themes → System → CMS Tailwind Compilation`): `Off` (default — start manually or with the admin Start button), `Cron` (a per-minute job starts it if down), `Start on-demand` (started on the first compile request, guarded by a spawn lock). The same screen shows status plus Start/Restart buttons. The first compile per theme is slow (compiler load, dependency install, source generation); later ones reuse the cached compiler.

**Auth token**: the daemon reads `TAILWIND_COMPILER_AUTH_TOKEN` from the environment **only** and refuses to start without it; PHP reads the `auth_token` field of `var/hyva_cms_tailwind_daemon.json` **only**. Both must hold the same random secret. Magento handles this automatically when it starts the daemon; do it manually only when you start it yourself:

```bash
TOKEN=$(bin/magento hyva:cms-tailwind:token)
TAILWIND_COMPILER_AUTH_TOKEN="$TOKEN" node vendor/hyva-themes/magento2-cms-tailwind-compiler/node/daemon.mjs
# --port 3200 or --socket /tmp/hyva-cms-tailwind.sock
```

`--export` prints `TAILWIND_COMPILER_AUTH_TOKEN=<token>` for a systemd `EnvironmentFile`; `--regenerate`/`-f` rotates it (restart the daemon afterwards). `401 Unauthorized` on compile requests means the two values diverged. The state file is mode `0660` because it holds the token — the cron user and the php-fpm user must share a user or group.

Connection settings in `app/etc/env.php`:

```php
'hyva' => [
    'node_binary' => '/usr/local/bin/node'  // default: 'node' from $PATH
],
'hyva_cms_tailwind' => [
    'transport' => 'tcp',                            // 'tcp' or 'unix_socket'
    'tcp_host' => '127.0.0.1',
    'tcp_port' => 3200,
    'socket_path' => '/tmp/hyva-cms-tailwind.sock',
    'connect_timeout_ms' => 100,
    'read_timeout_ms' => 2500,
]
```

The two timeouts are also editable in the admin and via `bin/magento config:set hyva_cms_tailwind/general/connect_timeout_ms 100` (add `--lock-env` to write into `env.php`). The remaining keys are deployment configuration: edit `env.php` or use `magerun2 config:env:set hyva_cms_tailwind/tcp_port 3200`.

`MALLOC_ARENA_MAX=2` is set by Magento when it starts the daemon: the compiler makes many small short-lived allocations and glibc rarely returns freed memory, which can push RSS into tens of GB on multi-core hosts. Add it to any service-manager unit too; it is harmless on musl/macOS/BSD.

Optional **standalone endpoint** `pub/cms-tailwind.php` bypasses the Magento bootstrap (per-request auth overhead ~20 ms → ~1 ms) and is deployed by Composer, but is only used once configured:

```php
'hyva_cms_tailwind' => ['standalone_endpoint_url' => '/cms-tailwind.php']
```

It still requires a valid admin session, so it is not an open compilation service. Hardened nginx configs need an explicit `location = /cms-tailwind.php` block.

**Restart the daemon** after changing a theme's Tailwind config or `postcss.config.js`, switching a theme's git branch, adding/removing Tailwind plugins, running `npm install` in `web/tailwind/`, or regenerating `hyva-source.css`/`hyva-tokens.css`. Changes to `web/css/styles.css` need no restart — the daemon watches that file.

**Scoping strategy** (server-side mode only, `hyva_cms_tailwind/bridge/scoping_strategy`): `jit` (default — store unscoped, prefix `hcms-{type}-{id}-` at render time, matching the in-browser format) or `compiler` (scope at compile time with an ancestor selector `.hcms-{type}-{id}` and wrap the content in a matching container). Either shape renders correctly, so the strategy can be changed and content recompiled without breaking pages.

<https://docs.hyva.io/hyva-themes/cms/tailwind-jit/server-side-compilation.html>, <https://docs.hyva.io/hyva-themes/cms/tailwind-jit/server-side-setup.html>

### Bulk recompilation

```bash
composer require hyva-themes/magento2-cms-tailwind-recompile
bin/magento setup:upgrade
bin/magento hyva:cms-tailwind:recompile [--background|-b] [--theme=Hyva/default]
```

Synchronous (default) populates the queue and processes everything with a progress bar, aborting on the first error — suitable for deploys and CI. `--background` fills the queue (`hyva_cms_tailwind_recompile_queue`) and returns; cron `hyva_cms_tailwind_recompile_process` claims up to 250 entities per minute, `hyva_cms_tailwind_recompile_cleanup` runs daily at 03:00 removing completed entries older than 1 day and failed ones older than 7 days. Rows stuck `processing` for over 10 minutes are reclaimed. Statuses: `pending`, `processing`, `completed`, `failed` (with the error message stored).

The synchronous mode and cron share one queue, so cron can steal rows mid-run — prefer `--background` for deterministic deployments, or disable the cron group.

**It only recompiles entity/theme combinations that already have stored CSS** (IDs are read from each theme's CSS table). Adding a new store view with a new theme therefore generates nothing — re-save the entities, or register an `EntityIdProviderInterface`.

Custom content types register via `etc/tailwind_recompile_sources.xml`:

```xml
<entity name="my_entity" scopePattern=".hcms-myentity-{id}">
    <cssStorage table="my_entity_tailwindcss" entityIdColumn="entity_id"
                themeColumn="theme" cssColumn="css"/>
    <htmlSources>
        <source table="my_entity" htmlColumn="content" joinColumn="entity_id"/>
    </htmlSources>
</entity>
```

`scopePattern` must start with `.` and use `{id}`. For EAV/store-scoped HTML use an `htmlMapper` implementing `Hyva\CmsTailwindCompiler\Api\HtmlSourceMapperInterface` (this is how catalog products are handled) and omit `<htmlSources>`. Use `entityIdMapper` with `Hyva\CmsTailwindCompiler\Api\EntityIdProviderInterface` to include never-compiled entities.

<https://docs.hyva.io/hyva-themes/cms/tailwind-jit/recompiling-cms-content.html>

### Extending the JIT to custom content types

Steps: load the JIT on your admin edit page, observe content changes and pass HTML to the compiler, capture the CSS in a hidden form field, create a DB table, persist on save, then prefix classes in HTML and CSS at render time.

```xml
<!-- view/adminhtml/layout/my_custom_entity_edit.xml -->
<update handle="tailwind_jit"/>
```

The handle loads the compiler into an invisible `<iframe id="tailwindcss-jit">` and exposes:

```js
window.tailwindCSS.process(htmlContent, customConfig, customCss).then(css => { /* store it */ });
window.tailwindCSS.configForStore(storeId);
window.tailwindCSS.configForTheme('frontend/Hyva/default');
window.tailwindCSS.tailwindThemes([1, 2, 5]);   // storeId -> theme identifier
window.tailwindCSS.storeIdsForWebsites([1, 2]);
```

The API surface is identical for the v3 and v4 compilers. The promise resolves with **unscoped** utility CSS; scope it at render time with `\Hyva\CmsTailwindJit\Model\PrefixJitClasses::prefixJitClassesInHtml` and `::prefixJitClassesInCss`. `\Hyva\CmsTailwindJit\ViewModel\CategoryTailwindCss::getStyles` is the reference implementation — it uses `\Hyva\CmsTailwindJit\Model\ScopedCssDetector` to inline already-scoped CSS as-is and prefix legacy unscoped CSS.

An integration built on the `tailwind_jit` handle plus `window.tailwindCSS.process()` needs **no changes** for server-side compilation — the bridge reroutes it transparently. The daemon's own API is only needed for a standalone integration:

```js
HyvaCmsTailwindCompiler.compile({
    html: '<div class="text-blue-600 p-4 hover:bg-red-500">Content</div>',
    scopeSelector: '.hcms-myentity-42'
}).then(result => { /* { "Hyva/default": ".hcms-myentity-42 .text-blue-600 { … }" } */ });
```

Load it by rendering `Hyva_CmsTailwindCompiler::compile-config.phtml` with the `Hyva\CmsTailwindCompiler\ViewModel\CompileConfig` view model into `before.body.end` on your edit-page handle. Options: `html` (required), `scopeSelector`, `themes`, `previewTheme` (full CSS including preflight, for an admin preview). With a `scopeSelector` the CSS comes back already scoped, so wrap the content in a matching container on the frontend and leave class attributes untouched. Use the same value as the `scopePattern` registered for bulk recompilation.

<https://docs.hyva.io/hyva-themes/cms/tailwind-jit/extending.html>, <https://docs.hyva.io/hyva-themes/cms/tailwind-jit/server-side-extending.html>

## Without the JIT module (legacy strategies)

Deprecated since the JIT module exists, kept for sites not using it:

- Define named classes with `@apply` in CSS and have editors use those names instead of raw utilities.
- Safelist full class names in `tailwind.config.js`. **Regex safelist values only work with the legacy AOT compiler** — with JIT, list full class names.
- Keep a plain text file (e.g. `safelist.txt`) of class names and add it to the Tailwind content paths.

<https://docs.hyva.io/hyva-themes/cms/using-tailwind-classes-in-cms-content-without-browser-compilation.html>

## Full-bleed CMS content

Hyvä puts a `container` class on all pages. Three ways to break out:

**1. Page Builder full-width layout** — switch the page layout to "Page -- Full Width" and use a Page Builder Row for anything that still needs a constrained container.

**2. CSS techniques** (need the CMS Tailwind JIT module so the classes get compiled):

- *Viewport full-bleed* — `ml-[50%] w-screen -translate-x-1/2`, with `overflow: hidden` on the parent (`.page-main` or `body`). Least recommended: it introduces horizontal overflow.
- *Border image* — `[border-image:conic-gradient(theme(colors.blue.400)_0_0)_fill_0//0_100vw]`. A conic gradient is used because `border-image` does not accept solid colours. No horizontal scrollbar, and it supports richer patterns.

**3. CSS Grid** — restructure `.columns` into a three-column grid (`1fr`, constrained centre column, `1fr`); direct children default to `grid-column-start: 2` and anything with `.fullbleed` spans `1 / -1`. Requires comfort with CSS grid.

<https://docs.hyva.io/hyva-themes/cms/full-bleed-cms-content.html>

## Other CMS caveats

- **Strict CSP kills scripts in CMS content.** Once `unsafe-inline` is disabled for `script-src`, `<script>` tags inside CMS content cannot be authorized.
- Alpine `:class` bindings in CMS content are also incompatible with strict CSP.
- The JS form validation library cannot be loaded via a layout handle from CMS content — render it with a block directive instead:

```
{{block class="Magento\Framework\View\Element\Template" template="Hyva_Theme::page/js/advanced-form-validation.phtml"}}
```

- SVG icons in CMS content use `{{icon "lucide/shopping-cart" width=24 height=24}}`; custom sets need a `pathPrefixMapping` (see `theme-structure.md`).
- Page Builder background images can be lazy-loaded via `Hyvä Themes > Page Builder > Images` (default `No`, requires default-theme >= 1.3.10).
- From Hyvä 1.4 all sliders, including the Page Builder ones, are driven by `x-snap-slider` instead of Glider JS. To keep the old Page Builder slider, copy `web/tailwind/components/page-builder.css`, `components/slider.css`, `Magento_PageBuilder/web/js/glider.js`, `glider.min.js`, `Magento_PageBuilder/templates/carousel-nav.phtml`, `widgets/parallax.phtml`, `widgets/carousel.phtml` and `catalog/product/widget/content/carousel.phtml` from the default theme into your own **before** upgrading.

<https://docs.hyva.io/hyva-themes/writing-code/csp/csp-magento-configuration.html>, <https://docs.hyva.io/hyva-themes/upgrading/upgrading-to-1-4-0.html>
