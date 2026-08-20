---
name: hyva-theme
description: Hyvä theme development on Magento 2 - installation and version requirements, child themes and theme inheritance, the Tailwind build workflow, view models and the ViewModelRegistry, templates and layout handles, Alpine.js and the window.hyva JS API, strict CSP authoring, CMS content and the Tailwind JIT compiler, Luma-to-Hyvä compatibility modules, and deployment and performance. Use this skill when installing or upgrading Hyvä, creating a child theme, running or debugging the Tailwind build, writing a .phtml template or view model, adding SVG icons, modals, sliders or form validation, wiring customer section data or fetch() calls, fixing a CSP violation, styling CMS or Page Builder content, writing a *-hyva-compat module or converting Luma CSS/JS to Tailwind and Alpine, configuring static content deploy, or diagnosing missing styles, stale DI config, ESI or Varnish issues - keywords Hyvä, hyva/default, hyva_default, tailwind-source.css, hyva-themes.json, ViewModelRegistry, heroicons, hyva.js, alpine3-csp, magento2-default-theme, Tailwind JIT, compat module.
---

# Hyvä theme

Hyvä replaces Luma's LESS + RequireJS + Knockout stack with Tailwind + Alpine.js
and server-rendered `.phtml`. The consequences run deep enough that Luma habits
are usually the wrong instinct: CSS is a build artifact rather than something
Magento compiles, there is no JS module loader, and data reaches templates
through view models instead of custom block classes.

This file is an index. The detail is in `references/`.

## References

- `references/installation-and-setup.md` — version requirements (Magento, PHP,
  Node, Tailwind, Alpine per release), private Packagist install, theme
  activation, required post-install config (captcha, minification), child themes,
  locales, Hyvä settings reference, upgrade strategy.
- `references/theme-structure.md` — theme inheritance, `hyva_` layout handles,
  template conventions, the view model registry, responsive images, product
  gallery config, SVG icons, modals, sliders, form validation, reCAPTCHA.
- `references/tailwind-workflow.md` — build commands, directory layout,
  `tailwind-source.css` (v4), content/purge config, `@hyva-themes/hyva-modules`,
  CSS variables, dynamic class names, custom fonts, RTL, critical CSS,
  troubleshooting.
- `references/alpine-and-js.md` — the architectural break from Luma, inlining
  Luma scripts, component communication, Hyvä JS events, customer section data,
  the `window.hyva` API, `fetch()` instead of `$.ajax`, overriding JS without
  copying templates, loading external JS, bundled Alpine plugins.
- `references/csp.md` — strict CSP configuration, nonce vs hash, the
  `block_html` interaction, installing the CSP theme, writing CSP-compatible
  Alpine, the migration tool and checklist, header size, in-context payment
  buttons.
- `references/cms-and-widgets.md` — the two problems Tailwind creates for CMS
  content (`prose`, and classes living in the database), the CMS Tailwind JIT
  module incl. server-side compilation, full-bleed content, CMS caveats.
- `references/compatibility-modules.md` — why compat modules exist, the working
  method, naming, folder structure, automatic template overrides, Tailwind asset
  merging, supporting both cart types, converting Luma CSS/JS, coding standards,
  local development via composer path repositories.
- `references/deployment-and-performance.md` — the build-artifact rule, SCD
  optimisation and its two Hyvä-specific failures, **the stale DI config trap**,
  Adobe Commerce Cloud (build hooks, Node daemons), Capistrano, response
  minification, Core Web Vitals, Speculation Rules, bfcache, the four cache
  layers and view model cache tags, Varnish gotchas, troubleshooting.

## Projects with no `app/code` theme

A common agency setup has **no `app/code` and no `app/design` custom theme** at
all: client behaviour lives entirely in composer packages under
`vendor/<vendor>/*`, typically `module-<feature>`, `-hyva`, `-hyva-compat` and
`-hyva-checkout` packages adapting a base or third-party module to Hyvä. If that
describes your project, two consequences matter:

- Edits inside `vendor/<vendor>/module-*` take effect immediately but are wiped
  by the next `composer install` unless you also commit them in that package's
  own repository.
- The Tailwind source is then the vendor default theme's, not a local child
  theme's: `vendor/hyva-themes/magento2-default-theme/web/tailwind/`.

`.phtml` edits normally need only `cache:flush`, not a full
`setup:upgrade`/`di:compile` cycle.

Containerised local stacks (Warden, DDEV, plain docker compose) need
their own prefix in front of every command in these references — e.g.
`warden env exec php bin/magento …`. Commands are written bare; add your wrapper.

## Related skills

For checkout work use `hyva-checkout`; for Alpine under CSP use `alpinejs-csp`;
for the Commerce product suite use `hyva-commerce`; for admin grids `hyva-admin`.

## Pitfalls

- CSS is a build artifact — `setup:static-content:deploy` only copies
  `web/css/styles.css`. If Tailwind never ran, SCD deploys nothing and the
  storefront renders unstyled.
- Build Tailwind before SCD, never after, and never on production.
- Flush the cache **between `setup:upgrade` and `setup:di:compile`**. Many deploy
  scripts flush only at the very end, which cannot prevent a poisoned compile —
  check yours; see the stale DI config trap.
- If `bin/magento cache:flush` reports *"There are no commands defined in the
  cache namespace"*, DI metadata is already poisoned and the CLI has silently
  degraded. Remediation scripts ending in a flush will no-op.
- Always set a theme at **Website** level. `hyva/default` on a store view alone,
  with Website at `-- No Theme --`, breaks the storefront.
- Disable the legacy Magento captcha (`customer/captcha/enable 0`) — Hyvä does
  not support it or reCAPTCHA V1, and forms break.
- Turn off Magento's own JS/CSS minification and bundling for Hyvä store views;
  Tailwind already emits minified CSS. Note CSS minification has **no store-view
  scope**, so on a mixed Hyvä/Luma instance you cannot simply switch it off.
- Use `npm ci --ignore-scripts` in CI, not `npm install`. Hyvä 1.1.x used
  `npm run build-prod`; current versions use `npm run build`.
- Never mix Alpine v2 and v3 in one theme, and remember different store views may
  run different themes.
- Use `referenceBlock`, not `block`, in child theme layout XML.
- Dynamic Tailwind class names must exist somewhere the scanner can see them, or
  they are purged from the build.
- SVG icon helpers (`$heroiconsoutline->xxxHtml()`) resolve to a kebab-cased
  filename — the method name must match a real `.svg`. There is no `cross` icon.
- Don't overuse arbitrary Tailwind values (`w-[123px]`); each generates an
  unshareable rule and grows the stylesheet.
- A view model cannot contribute cache tags the standard Magento way. Implement
  `IdentityInterface` on the view model so `ViewModelRegistry` collects them, or
  pages serve stale content from Varnish.
- On Adobe Commerce Cloud, a Hyvä Node daemon persists **only** on Pro
  Staging/Production in Cron mode. `on_demand` is never safe there.
- Lighthouse's render-blocking-CSS warning for Hyvä is expected and correct — do
  not chase it with async or critical CSS. A large stylesheet usually means a
  dev/watch build was deployed.
