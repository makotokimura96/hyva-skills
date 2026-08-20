# Installation, requirements and environment setup

## Version requirements

Stated by the docs for current Hyvä releases:

- Magento `2.4.4-p9`, `2.4.5-p8`, `2.4.6-p7`, `2.4.7-p1` or higher.
- PHP `8.1`, `8.2`, `8.3` or `8.4`. PHP 7.4 is no longer supported.
- Node.js `>= 20.0.0` on development/build instances (only needed to run the Tailwind compiler).
- CSP support (Hyvä >= 1.3.11) requires the Magento CSP Nonce Provider, i.e. Magento >= 2.4.4.

Node minimum per Hyvä release: 1.4.0+ → Node 20; 1.3.6 → Node 16; 1.2.0 → Node 14; 1.1.0 → Node 12.13.

Tailwind version per Default Theme release: **v4** in 1.4.x/1.5.x, **v3** in 1.2.x/1.3.x, **v2** in 1.0.x/1.1.x.
Alpine.js version: **v3** in Default Theme 1.2.x and newer, **v2** in 1.0.x/1.1.x. You cannot mix Alpine v2 and v3 in one theme (different store views may use different themes).

Supported browsers (current releases): Chrome/Edge/Opera 111, Firefox 102, Safari 16 (Tailwind v4 keeps backward compatibility down to Safari 15.4). Opera Mini is unsupported. IE11 is not supported.

<https://docs.hyva.io/hyva-themes/getting-started/index.html>, <https://docs.hyva.io/hyva-themes/working-with-tailwindcss/supported-versions.html>, <https://docs.hyva.io/hyva-themes/faqs/supported-browsers.html>

## Composer installation

Hyvä ships from a **private Packagist** repo. The URL always has the shape
`https://hyva-themes.repo.packagist.com/<yourProjectName>/`. `repo.hyva.io` does not exist (a known AI hallucination).

```bash
composer config --auth http-basic.hyva-themes.repo.packagist.com token yourLicenseAuthentificationKey
composer config repositories.private-packagist composer https://hyva-themes.repo.packagist.com/yourProjectName/
composer require hyva-themes/magento2-default-theme
bin/magento setup:upgrade
```

For strict-CSP projects, require `hyva-themes/magento2-default-theme-csp` instead (theme code `Hyva/default-csp`). Both can be installed side by side, which is useful while migrating.

Tech/contributing partners may add `gitlab.hyva.io` git repositories and install with `--prefer-source`, but **never use SSH-key auth in CI/CD** — GitLab uptime is not guaranteed; always build from packagist.com.

Common composer errors: "project could not be found" → missing `auth.json` key; composer asking for a GitLab password → run `ssh-add`, add the public key to the GitLab profile, or delete a `composer.lock` still referencing `gitlab.hyva.io`.

<https://docs.hyva.io/hyva-themes/getting-started/index.html>, <https://docs.hyva.io/hyva-themes/faqs/configuring-packagist-and-gitlab.html>

## Activating the theme

`Content > Design > Configuration`, select `hyva/default`.

**Always set a theme at Website level.** Setting `hyva/default` only on a store view while Website/Store stay at `-- No Theme --` causes storefront breakage. Any theme at Website level is fine (Luma, Hyvä, …), as long as one is set.

Verification depends on deploy mode: `developer` shows immediately (maybe after `cache:flush`); `production` requires `setup:static-content:deploy`; `default` mode requires manual `module:enable` per module — never run a store in `default` mode.

## Required post-install configuration

Hyvä does **not** support the legacy Magento captcha or reCAPTCHA V1. Disable the legacy captcha or forms break:

```bash
bin/magento config:set customer/captcha/enable 0
```

Supported captchas: Google reCAPTCHA **v3 invisible**, **v2 invisible** (since 1.1.15), **v2 checkbox** (since 1.1.15), configured under `Security > Google reCAPTCHA Storefront`.

Turn off Magento's own minification/bundling for Hyvä store views (no benefit, adds overhead and side effects):

```bash
bin/magento config:set dev/template/minify_html 0
bin/magento config:set dev/js/merge_files 0
bin/magento config:set dev/js/enable_js_bundling 0
bin/magento config:set dev/js/minify_files 0
bin/magento config:set dev/js/move_script_to_bottom 0
bin/magento config:set dev/css/merge_css_files 0
bin/magento config:set dev/css/minify_files 0
```

Keep them **on** for Luma store views if the instance runs both — CSS minification cannot be scoped per store view, Magento always uses the global setting. If `setup:static-content:deploy` then fails inside `tubalmartin/cssmin`, enable `dev/css/minify_files 1` and apply the community patch documented at
<https://docs.hyva.io/hyva-themes/faqs/static-content-deploy-fails-with-css-error.html>.

## Required GraphQL modules

Hyvä uses parts of the Magento GraphQL API, so these must be enabled (all enabled by default on a fresh install, but often disabled on stores migrated from Luma): `Magento_BundleGraphQl`, `Magento_CatalogCustomerGraphQl`, `Magento_CatalogGraphQl`, `Magento_CatalogRuleGraphQl`, `Magento_CatalogUrlRewriteGraphQl`, `Magento_ConfigurableProductGraphQl`, `Magento_CustomerGraphQl`, `Magento_DirectoryGraphQl`, `Magento_DownloadableGraphQl`, `Magento_EavGraphQl`, `Magento_GraphQl`, `Magento_GroupedProductGraphQl`, `Magento_QuoteGraphQl`, `Magento_GraphQlCache`, `Magento_RelatedProductGraphQl`, `Magento_ReviewGraphQl`, `Magento_SalesGraphQl`, `Magento_StoreGraphQl`, `Magento_SwatchesGraphQl`, `Magento_UrlRewriteGraphQl`, `Magento_WishlistGraphQl`.

Check with `bin/magento module:status <Module> …`. Which ones are strictly required depends on the features used (e.g. `Magento_CatalogGraphQl` is only needed if Recently Viewed Products is enabled).

## Checkout is not included

Hyvä is a "bring your own checkout" theme — an empty checkout page is expected until you install one of: Hyvä Checkout, a Luma-based checkout via the theme fallback module, or a third-party checkout.

<https://docs.hyva.io/hyva-themes/faqs/why-is-the-checkout-page-empty.html>

### Luma theme fallback (gradual migration)

`hyva-themes/magento2-theme-fallback` renders configured routes with a Luma-based theme while the rest of the store runs Hyvä. On fallback pages Tailwind and Alpine are **not** loaded; RequireJS and Luma dependencies are — style those pages the Magento way.

```bash
composer require hyva-themes/magento2-theme-fallback
bin/magento setup:upgrade
```

Config paths: `hyva_theme_fallback/general/enable`, `hyva_theme_fallback/general/theme_full_path` (default `frontend/Magento/luma`), `hyva_theme_fallback/general/list_part_of_url`. For a Luma checkout the default list is `checkout/index`, `paypal/express/review`, `paypal/express/saveShippingMethod`. It works via a before-plugin on all frontend controllers matching `route/controller/action` or a part of the SEO URL path.

<https://docs.hyva.io/hyva-themes/building-your-theme/luma-theme-fallback.html>

## Creating a child theme

`app/design/frontend/Vendor/ThemeName/theme.xml` with `<parent>Hyva/default</parent>` (or `Hyva/default-csp`). Note the Default Theme ships `preview.png`, not `preview.jpg`.

Child themes need a **complete copy** of the Tailwind build config — Tailwind config and CSS are *not* inherited through the Magento fallback:

```bash
mkdir -p app/design/frontend/Vendor/ThemeName/web
cp -r vendor/hyva-themes/magento2-default-theme/web/* app/design/frontend/Vendor/ThemeName/web/
```

Then point Tailwind at the parent theme so parent classes end up in the build. Tailwind v4 (`web/tailwind/hyva.config.json`):

```json
{
    "tailwind": {
        "include": [
            { "src": "vendor/hyva-themes/magento2-default-theme" }
        ]
    }
}
```

Use `vendor/hyva-themes/magento2-default-theme-csp` when the parent is the CSP theme. On Tailwind v3 the equivalent was `content` paths in `tailwind.config.js`.

<https://docs.hyva.io/hyva-themes/building-your-theme/index.html>

## Themes that live in vendor packages

Some projects (a common agency pattern) have **no `app/code` and no `app/design` child theme** at all. Client behaviour lives in composer packages under `vendor/<vendor>/*` (`module-<feature>`, `-hyva`, `-hyva-compat`, `-hyva-checkout`), and the Tailwind source is therefore the vendor default theme's rather than a local child theme's:

```
vendor/hyva-themes/magento2-default-theme/web/tailwind/
```

Two things follow. Edits inside `vendor/` are real and immediate but are wiped by the next `composer install` unless committed in the package's own repository. And because the build entry point is under `vendor/`, any wrapper script (a project `Makefile`, `composer` script, or similar) has to point there:

```bash
# typical wrappers, whatever your project calls them
make build     # npm run build for the Hyvä Tailwind theme + cache:flush
make watch     # Tailwind watch mode
```

Containerised stacks (Warden, DDEV, docker compose) need their own prefix on every `bin/magento` call, e.g. `warden env exec php bin/magento cache:flush`. Commands in these references are written bare — add your own wrapper.

Deploy the locales your stores actually use, e.g. `setup:static-content:deploy fr_FR en_US -f`.

## Sample data (Koti)

Hyvä ships its own **Koti** sample data. Commands come from `Hyva_Theme` >= 1.4.7 and build on `magento/module-sample-data`.

```bash
bin/magento hyva:sampledata:deploy
bin/magento setup:upgrade
```

Flags: `--replace-luma` (destructive: removes Luma sample data modules **and all products, orders, customers**), `--keep-luma` (installs Koti on a separate website with store view code `koti`, reachable via `?___store=koti`; mutually exclusive with `--replace-luma`), `--reinstall` (destructive reset), `--no-update` (write `composer.json` without running `composer update`). Remove again with `bin/magento hyva:sampledata:remove`.

If you use the **Luma** sample data, its `styles.css` is injected from `pub/media` on every page and breaks layouts. Clear `Design Configuration > Other Settings > HTML Head > Scripts and Style Sheets` for the Hyvä store view (config path `design/head/includes`), then flush the cache.

<https://docs.hyva.io/hyva-themes/getting-started/sample-data.html>, <https://docs.hyva.io/hyva-themes/faqs/sample-data.html>

## Localization

Hyvä uses standard Magento CSV dictionaries. The Default Theme ships `i18n/en_US.csv` as the reference for all Hyvä-specific strings. Two options: a theme-level dictionary (`app/design/frontend/Vendor/ThemeName/i18n/fr_FR.csv`) or a project-level language pack in `app/i18n/{project}/{locale}/` with `registration.php` (`ComponentRegistrar::LANGUAGE`), `language.xml` and CSV files.

Pre-built Hyvä translation packages include `hyva-themes/i18n-fr-fr`, `-de-de`, `-nl-nl`, `-es-es`, `-it-it`, `-pt-br`, `-pl-pl`, `-da-dk`, `-ca-es`, `-ro-ro`, `-bg-bg`, `-uk-ua`, `-et-ee`, `-lt-lt`, `-lv-lv`, `-ko-kr`, `-de-ch`, `-nl-be`, `-nl-di`.

```bash
composer require hyva-themes/i18n-fr-fr
bin/magento setup:upgrade
```

Also install the matching Magento core language pack, set the store view locale, flush caches and redeploy static content in production.

<https://docs.hyva.io/hyva-themes/building-your-theme/localization.html>

## Hyvä theme settings reference (`Stores > Configuration > Hyvä Themes`)

Provided by `hyva-themes/magento2-theme-module`, which is always safe to update to the latest version.

| Group | Setting | Default | Notes |
|---|---|---|---|
| General > Message Display | Success Message Default Timeout | empty | ms; empty = persist until dismissed (recommended). Errors/warnings always persist. |
| General > Hyvä Demo Content | Show Homepage Content | `Yes` | Set to `No` on real stores. |
| General > Deferred Alpine.js Components | Defer until idle timeout | `4000` | ms before `x-defer="idle"` components init. |
| General > Deferred Alpine.js Components | Defer components | preset selectors | Prefer template-level `x-defer` instead. |
| General > Animations and Transitions | Enable View Transition Gallery | `No` | View Transitions API PLP→PDP gallery. |
| General > Speculation Rules | Method / Eagerness | `Prefetch` / `Moderate` | See performance reference. |
| Catalog > Compare Products | 3 toggles | `Yes` | Mirrors Catalog > Storefront. |
| Catalog > Recently Viewed Products | Enable + 2 display toggles | `No` | Master toggle must be `Yes` first. |
| Catalog > Crosssell Products | Max Product Count | `4` | Cart cross-sells. |
| Catalog > Client-Side Breadcrumbs | Enable on PDP | `No` | Slow with thousands of categories. |
| Catalog > Developer | Product List Item block_html caching / lifetime | `Yes` / `3600` | Keep on. |
| Google GTag > GTag | Anonymize IP / Lazyload Tag Manager | `Yes` / `No` | Lazyload defers GTM to first interaction. |
| Page Builder > Images | Lazy-load background images | `No` | Requires Default Theme >= 1.3.10. |
| Developer > Cache Options | Enable SVG Icon Caching | `No` | Trades Redis storage for PHP time. |
| System > Cache Options | Enable Bfcache | `No` | Also needs a Varnish/Fastly VCL change. |

<https://docs.hyva.io/hyva-themes/building-your-theme/hyva-settings.html>

## Troubleshooting installation

- **"Overriding view file '…xml' does not match to any of the files"** after adding a child theme → `Hyva_Theme` is disabled. `bin/magento module:enable Hyva_Theme && bin/magento setup:upgrade`.
- **`Compilation from source: LESS file is empty: …/email-fonts.less`** during SCD → harmless; fixed in `hyva-themes/magento2-email-module` >= 1.0.4.
- **`tailwindcss: Permission Denied`** (often after macOS/Xcode updates) → delete `node_modules` and `npm install --ignore-scripts` again.
- **"Argument must be of type array, null given" TypeError after `setup:di:compile`** → stale `global::DiConfig` cache. `setup:di:compile` reads a cached pre-merged DI config that is *not* invalidated when the module list changes, so a required `array` argument is baked in as `null` (e.g. `Hyva\Theme\Service\HyvaThemes::__construct($hyvaBaseThemes)`, `Hyva\BaseLayoutReset\…\SpecialCaseLayoutResetPool::__construct($specialCases)`). Symptom escalation: `bin/magento` itself degrades and reports `There are no commands defined in the "cache" namespace`. Fix and prevention — flush **before** compiling:

```bash
bin/magento setup:upgrade
bin/magento deploy:mode:set production --skip-compilation
bin/magento cache:flush            # drop the stale global::DiConfig FIRST
bin/magento setup:di:compile
bin/magento setup:static-content:deploy -j 4
```

  If the CLI is already degraded, `redis-cli -n <config-cache-db> flushdb` then recompile. Treat `There are no commands defined` in build output as a hard build failure.

<https://docs.hyva.io/hyva-themes/faqs/troubleshooting.html>, <https://docs.hyva.io/hyva-themes/faqs/stale-di-config-cache.html>

## Upgrade strategy

Hyvä has two moving parts: the **default-theme** (templates/styles/layout — the more files you override, the more expensive upgrades get) and the **theme-module** (infrastructure, strong BC commitment — always safe to update to latest, even without upgrading the theme).

Process: read the version upgrade notes → read the changelogs → upgrade the theme-module → diff each customized file against the new default-theme → upgrade the default-theme → re-apply changes.

Tooling: `hyva-themes/upgrade-helper-tools` (dev-only, never on production; `composer require --dev hyva-themes/upgrade-helper-tools:dev-main`) offers `update-to-tailwind-v4.js` (wrapper), `convert-to-tailwind-v4.js` (backs up `web/tailwind` to `web/tailwind.backup.DATE`, copies the v4 structure), `convert-tailwind-config.js` (v3 JS config → `generated/tailwind.config.css` with `@theme` vars), `find-deprecated-classes.js` (writes `tailwind-deprecated-report.md`), and `hyva-csp-helper`. Also useful: Ampersand upgrade-patch-helper, Elgentos upgrade GUI, and plain `git diff` between old and new theme copies.

Recurring migration patterns across releases (not version-by-version):

- Alpine v2 → v3: drop `x-spread` for `x-bind`, `@click.away` → `@click.outside`, `$el` semantics change, `init` auto-runs.
- Tailwind v2 → v3: `purge.content` → `content`, JIT everywhere, regex safelists stop working.
- Tailwind v3 → v4: JS config → CSS `@theme`; `postcss*` packages and `postcss.config.js` removed; `@tailwindcss/forms` + `@tailwindcss/typography` replaced by `@hyva-themes/hyva-modules` CSS; `mergeTailwindConfig`/`postcssImportHyvaModules` replaced by `npx hyva-sources`; `@screen` removed; relative `@import` paths mandatory.
- Reset theme → generated base layout resets (1.3.21+/1.4.0).
- Custom modal/slider implementations → native `<dialog>` + `x-htmldialog` and `x-snap-slider` (1.4.0/1.5.0).

<https://docs.hyva.io/hyva-themes/upgrading/index.html>, <https://docs.hyva.io/hyva-themes/upgrading/upgrade-helper.html>, <https://docs.hyva.io/hyva-themes/upgrading/upgrading-to-1-4-0.html>, <https://docs.hyva.io/hyva-themes/upgrading/upgrading-to-1-5-2.html>
