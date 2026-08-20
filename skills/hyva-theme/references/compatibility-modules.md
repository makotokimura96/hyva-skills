# Compatibility modules and Luma → Hyvä conversion

## Why they exist

Modules built for the Luma/Blank themes rely on RequireJS, Knockout, jQuery, `x-magento-init`, `data-mage-init` and LESS — none of which Hyvä loads. A **compatibility module** re-implements only the parts that do not work out of the box on a Hyvä storefront. The available modules and their status are tracked in the Compatibility Module Tracker on `gitlab.hyva.io/hyva-public/module-tracker`.

Two distinct situations, often confused:

1. **A new compatibility module** for a third-party module you do not own → follow the naming and the `magento2-compat-module-fallback` mechanism below.
2. **Making a module you own Hyvä-compatible** → no separate module. Register it for `hyva-themes.json` yourself, keep `.phtml`/CSS/JS working for **both** Luma and Hyvä, and put Hyvä-only blocks and templates in `hyva_`-prefixed layout XML files so Luma store views ignore them.

<https://docs.hyva.io/hyva-themes/compatibility-modules/index.html>, <https://docs.hyva.io/hyva-themes/compatibility-modules/getting-started.html>

## Working method

1. Pick a page that uses the module's functionality.
2. Open it in a private window on a **Luma reference store view** and on the Hyvä store view side by side.
3. Open the browser console on the Hyvä store view and look for errors (`require is not defined` is the classic one).
4. Find the template in the original module that causes it.
5. Copy that template into the compatibility module at the same relative path under `view/frontend/templates`.
6. Inline the JavaScript, convert it to vanilla JS + Alpine, and restyle with Tailwind.
7. Clean up, then move to the next template.

If several templates on one page break, copy them all and short-circuit each with an early `<?php return; ?>` so you can fix them one at a time. Take small steps.

Useful tooling: a second Luma store view for reference; Alpine.js devtools; the Alpine.js and Tailwind IDE plugins/extensions; commercially, Windy and DevTools for Tailwind.

<https://docs.hyva.io/hyva-themes/compatibility-modules/development-guidelines.html>

## Naming conventions

| | Original | Compatibility module |
|---|---|---|
| Magento module | `Smile_ElasticSuite` | `Hyva_SmileElasticSuite` |
| Composer package | `smile/magento-elasticsuite` | `hyva-themes/magento2-smile-elasticsuite` |

The Magento module name is the `Hyva` namespace plus the concatenation of the original namespace and module name. The composer vendor is `hyva-themes` for packages hosted on `gitlab.hyva.io`. For compat modules hosted elsewhere (e.g. GitHub) use your own vendor and put `hyva` in the package name instead: `my-org/magento-integration` → `my-org/magento-hyva-integration`.

**A common agency convention** follows the same idea under a single vendor namespace: `module-<feature>` (base/Luma logic), `module-<feature>-hyva` (Hyvä frontend integration), `module-<feature>-hyva-compat` (shim for a third-party module under Hyvä), `module-<feature>-hyva-checkout` (Hyvä-checkout-specific). Each `vendor/<vendor>/*` package is its own git repo on `git.sutunam.com`, so an edit in `vendor/` is real but must also be committed and pushed in that package's repo to survive a fresh `composer install`.

## Folder structure

```
magento2-example-module/
├── LICENSE.md
├── README.md
├── composer.json
└── src
    ├── etc
    │   ├── frontend
    │   │   └── di.xml
    │   └── module.xml
    └── registration.php
```

Tests go in `tests/` alongside `src/`. `LICENSE.md` is a verbatim copy of the Hyvä Themes Software User License and must not be changed. `README.md` documents the original module.

Copyright notices: keep the Hyvä notice for files that closely resemble Hyvä core code; for from-scratch files use either the Hyvä notice or your own, adding a line that allows the code to be used with Hyvä installations.

## Automatic template overrides

Provided by `hyva-themes/magento2-compat-module-fallback` (a dependency of the compat-module skeleton). Registering a module as a compatibility module injects its template directory into the design fallback path for the **original** module's files, so overriding a template needs no layout XML at all:

- Original module `Orig_Module`, compat module `Hyva_OrigModule`, original template `Orig_Module::example.phtml`.
- A file at `Hyva/OrigModule/view/frontend/templates/example.phtml` replaces it automatically.

Registration lives in `etc/frontend/di.xml`:

```xml
<type name="Hyva\CompatModuleFallback\Model\CompatModuleRegistry">
    <arguments>
        <argument name="compatModules" xsi:type="array">
            <item name="orig_module_map" xsi:type="array">
                <item name="original_module" xsi:type="string">Orig_Module</item>
                <item name="compat_module" xsi:type="string">Hyva_OrigModule</item>
            </item>
        </argument>
    </arguments>
</type>
```

**Overriding a compat template in a theme uses the ORIGINAL module name**, because the fallback does not change the template's declared module context:

- declaration `Mirasvit_Gdpr::cookie_bar.phtml`
- compat template `Hyva/MirasvitGdpr/view/frontend/templates/cookie_bar.phtml`
- theme override `app/design/frontend/Vendor/theme/Mirasvit_Gdpr/templates/cookie_bar.phtml`

The automatic override does **not** work for price renderer templates — override those with layout XML.

This mechanism is for compatibility modules only; it does not apply to regular modules that are made Hyvä-compatible.

<https://docs.hyva.io/hyva-themes/compatibility-modules/technical-deep-dive.html>

## Core Magento / Adobe Commerce compat modules

The Hyvä base layout reset removes **all** layout XML block declarations from core and Adobe Commerce modules (see `theme-structure.md`). Containers and extension points are preserved, and the removed declarations are left as comments for reference, e.g. for `Magento_Banner`:

```xml
<referenceContainer name="content">
    <!--
        <block name="banner.data" class="Magento\Banner\Block\Ajax\Data"
               template="Magento_Banner::js/banner.phtml"/>
    -->
</referenceContainer>
```

The fix is to add the needed blocks back in a `hyva_default.xml` layout file inside the compatibility module.

<https://docs.hyva.io/hyva-themes/compatibility-modules/core-magento-compat-modules.html>

## Tailwind asset merging for compat modules

Handled by `@hyva-themes/hyva-modules`, which scans the modules listed in `app/etc/hyva-themes.json`. The mode depends on which files exist in `view/frontend/tailwind/`.

**Modern approach (required for full Tailwind v4 support)** — a single `module.css`, which becomes the module's single source of truth. When present, `tailwind.config.js` and `tailwind-source.css` in the same directory are **ignored**:

```css
/* view/frontend/tailwind/module.css */
@source "../templates";
@source "../layout";
@import "./components/widget.css";
```

**Legacy fallback**, when no `module.css` exists:

- With a **Tailwind v3** theme: `tailwind.config.js` → its `purge.content` paths are merged into the theme config; `tailwind-source.css` → its `@import` statements are added to the build.
- With a **Tailwind v4** theme: `tailwind.config.js` → the tool only adds a broad generic `@source` for all `.phtml`/`.xml` in the module (no deep config merge); `tailwind-source.css` → its `@import` statements are added, but **all paths inside must be explicit relative paths** (`./components/widget.css`) or the v4 compiler fails.

A module that uses old Tailwind syntax or non-relative `@import` paths is incompatible with Tailwind v4. Work around it by excluding the module in `hyva.config.json` and adding its template paths manually:

```css
@source "../../../../../../../vendor/hyva-themes/magento2-hyva-checkout/src/**/*.phtml";
@source "../../../../../../../vendor/hyva-themes/magento2-hyva-checkout/src/**/*.xml";
```

### Registering and de-registering in `hyva-themes.json`

Compat modules using the `CompatModuleRegistry` are registered for Tailwind compilation **automatically**. Any other module needs an observer on `hyva_config_generate_before`:

```xml
<!-- etc/frontend/events.xml -->
<event name="hyva_config_generate_before">
    <observer name="My_Module_Register_Hyva_Config"
              instance="My\Module\Observer\RegisterModuleForHyvaConfig"/>
</event>
```

```php
public function execute(Observer $event)
{
    $config = $event->getData('config');
    $extensions = $config->hasData('extensions') ? $config->getData('extensions') : [];
    $path = $this->componentRegistrar->getPath(ComponentRegistrar::MODULE, 'My_Module');
    $extensions[] = ['src' => substr($path, strlen(BP) + 1)];   // path relative to the Magento root
    $config->setData('extensions', $extensions);
}
```

The generated file looks like:

```json
{
    "extensions": [
        { "src": "app/code/My/Module" },
        { "src": "vendor/Acme/Anvil/src" }
    ]
}
```

To **exclude** a compat module (e.g. to drop its styles), the method depends on how it registered itself — and some modules use both, in which case you need both:

```xml
<!-- registered via the compat module registry -->
<type name="Hyva\CompatModuleFallback\Observer\HyvaThemeHyvaConfigGenerateBefore">
    <arguments>
        <argument name="exclusions" xsi:type="array">
            <item name="Hyva_VendorModule" xsi:type="boolean">true</item>
        </argument>
    </arguments>
</type>
```

```xml
<!-- registered via its own observer: disable that observer -->
<event name="hyva_config_generate_before">
    <observer name="{{OBSERVER_NAME_HERE}}" disabled="true"/>
</event>
```

The observer name is conventionally the module name or similar, but verify it — the convention is not guaranteed. Exclusion without disabling the whole module requires `hyva-themes/magento2-compat-module-fallback` >= 1.1.3.

<https://docs.hyva.io/hyva-themes/compatibility-modules/technical-deep-dive.html>, <https://docs.hyva.io/hyva-themes/working-with-tailwindcss/registering-a-module-for-tailwind-compilation.html>

## Supporting both cart types

Since Hyvä 1.1.15 the default cart is the server-rendered **PHP cart**; earlier versions used a client-side **GraphQL cart**. `hyva-themes/magento2-graphql-cart` allows switching, and compat modules should ideally support both.

Two mechanisms:

- Layout handles `hyva_checkout_cart_type_php.xml` and `hyva_checkout_cart_type_graphql.xml`.
- `ifconfig` flags `hyva_themes_cart/general/php_cart_enabled` and `hyva_themes_cart/general/graphql_cart_enabled`:

```xml
<block name="php-cart-checkout-button"
       template="My/Module::php-cart/my-checkout.phtml"
       ifconfig="hyva_themes_cart/general/php_cart_enabled"/>
```

For most compat modules it is enough to declare blocks for both cart types in `hyva_checkout_cart_index.xml` attached to the correct parent containers — only the active cart type's containers are rendered. Put PHP-cart templates in a `php-cart/` subdirectory to avoid clashes.

<https://docs.hyva.io/hyva-themes/compatibility-modules/technical-deep-dive.html>

## Converting Luma CSS to Tailwind

All Luma CSS in a converted `.phtml` must be replaced with Tailwind utility classes.

```html
<!-- Luma -->
<ul class="compare wrapper">
    <li class="item link compare">
        <a class="action compare no-display" title="Compare products">

<!-- Hyvä -->
<div class="flex items-center">
    <a id="compare-link"
       class="relative hidden md:inline-flex btn bg-transparent border-transparent p-1 invisible"
       aria-label="Compare Products">
```

**Additional LESS files** compiled by Magento and included via layout XML must be removed:

```xml
<remove src="Some_Module::css/styles.css"/>
```

**External non-Luma CSS** (usually bundled with a JS library) — decide per case:

- The library is being removed by the compat module → remove the CSS too.
- The CSS is in the critical rendering path → remove it and use Tailwind classes instead.
- Not critical and independent of Luma → keep using it, but load it on demand:

```js
document.addEventListener('init-external-scripts', () => {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.type = 'text/css';
    link.href = '<?= $escaper->escapeUrl($block->getViewFileUrl('Some_Module::css/some.css')) ?>';
    document.head.append(link);
}, {once: true});
```

The **windy** browser plugin (Chrome/Firefox, commercial) converts existing styles to Tailwind classes semi-automatically. Results are not perfect but it is much faster than by hand; hold Shift while clicking a DOM section to copy only the Tailwind classes rather than the HTML.

<https://docs.hyva.io/hyva-themes/compatibility-modules/from-luma-to-hyva/converting-luma-css-to-tailwind.html>

## Converting Luma JavaScript and templates

See `alpine-and-js.md` for the full detail. In brief:

- `data-mage-init` / `require()` external files → a uniquely named function inlined in the `.phtml`, registered with `Alpine.data()` on `alpine:init`; called on `private-content-loaded` if it needs section data, on `DOMContentLoaded` if it needs `window.hyva` from the head, otherwise inline.
- `<script type="text/x-magento-template">` + `mage/template` + underscore → Alpine `<template x-for>`.
- jQuery `$(el).data()` → `element.dataset` (live, not cached, no JSON auto-parse).
- Underscore helpers → native equivalents; jQuery → youmightnotneedjquery.com.

<https://docs.hyva.io/hyva-themes/compatibility-modules/from-luma-to-hyva/migrating-js-and-templates.html>

## Coding standards and template annotations

Hyvä follows the Magento 2 coding standard (phpcs, phpmd); disable a rule only when it genuinely does not apply, and as narrowly as possible. Annotate every value assigned to a template block at the top of the file with imported class names:

```php
<?php
declare(strict_types=1);

use Hyva\Theme\Model\ViewModelRegistry;
use Magento\Framework\Escaper;
use Magento\Framework\View\Element\Template;

/** @var Template $block */
/** @var Escaper $escaper */
/** @var ViewModelRegistry $viewModels */
```

Run phpcs/phpstan directly against the `vendor/<vendor>/module-*` package being edited — `composer run phpcs` is scoped to `app/code`, which is empty here.

<https://docs.hyva.io/hyva-themes/compatibility-modules/development-guidelines.html>

## Local development with a composer path repository

The docs recommend cloning into `local-src/` and installing via a composer `path` repository (over cloning into `app/code` or using `--prefer-source` into `vendor`):

```bash
mkdir local-src
cd local-src && git clone git@gitlab.hyva.io:hyva-themes/hyva-compat/magento2-your-module.git && cd ..
composer config repositories.local-src path 'local-src/*'
composer require hyva-themes/magento2-your-module
```

Move the `local-src` entry to the **top** of `repositories` in the root `composer.json` so it wins over remote repositories. Composer symlinks `local-src/magento2-your-module` → `vendor/hyva-themes/magento2-your-module`. Exclude one of the two paths from the IDE index to avoid duplicate results.

If composer complains about minimum-stability, add `:dev-main`. If it reports the package existing in multiple repositories with different priorities (common in containerized setups where `.git` is not synced in), either clone **inside** the container, or pin the version in the repository options:

```json
{
    "type": "path",
    "url": "local-src/*",
    "options": { "versions": { "hyva-themes/your-module": "dev-main" } }
}
```

Adding `"version": "dev-main"` to the package's own `composer.json` works but is **not recommended**.

<https://docs.hyva.io/hyva-themes/compatibility-modules/getting-started.html>

## Contribution process (Hyvä-hosted compat modules)

Ask a Hyvä team member for a skeleton repository in the **Hyvä Compat** GitLab group → create or claim a "Module Request" issue in the Compatibility Module Tracker → clone, branch, implement, commit → push and open a merge request (as maintainer you may merge into `main` yourself; review is optional for compat modules) → tag `1.0.0` so it is installable via packagist.com and ask the team to mark it "Published".

Prerequisite knowledge assumed: Magento 2 frontend development, PHP, JavaScript, git, Hyvä theme installation, Alpine.js basics, Tailwind basics.

Other Hyvä repositories are open source on GitHub with the usual GitHub flow: `hyva-themes/magento2-react-checkout`, `hyva-themes/magento2-hyva-admin`, `hyva-themes/magento2-graphql-view-model`, `hyva-themes/magento2-optimized-csp-allowlist`, `hyva-themes/magento2-wysiwyg-svg`, `hyva-themes/hyva-ai-tools`.

<https://docs.hyva.io/hyva-themes/compatibility-modules/getting-started.html>
