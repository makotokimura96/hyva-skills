# Installation, licensing and releases

## Prerequisites

- Hyvä Commerce licence (Private Packagist key), **or** a `gitlab.hyva.io` account with Hyvä Commerce
  Agency (Platinum/Gold) or Technology Partner access.
- Hyvä Default Theme `1.3.0`+ and Hyvä Theme Module `1.3.15`+.
- Magento Open Source or Adobe Commerce `2.4.4`+ (Cloud and on-premise).
- PHP `8.1`+.
- Hyvä Checkout is optional; if the project uses it, install it alongside Hyvä Theme *before*
  Hyvä Commerce.
- Adobe Commerce / B2B / additional-services compatibility still requires a **Hyvä Enterprise**
  licence.
- Mage-OS is expected to work but is not in Hyvä's internal test matrix.

<https://docs.hyva.io/hyva-commerce/getting-started/index.html>

## Metapackage install (recommended)

```bash
composer require hyva-themes/commerce
bin/magento setup:upgrade
bin/magento hyva:config:generate
npm --prefix vendor/hyva-themes/magento2-default-theme/web/tailwind/ ci --ignore-scripts
npm --prefix vendor/hyva-themes/magento2-default-theme/web/tailwind/ run build
```

Replace the `web/tailwind` path with the project theme's own. If containerised, run everything through
`bin/magento …` / `npm --prefix … run build`, or `make build`.

The metapackage contains only stable (`>= 1.0.0`) packages. Individual features can be installed
separately instead — each feature page documents its own package.

## Per-feature composer packages

| Package | Magento module(s) / purpose |
|---|---|
| `hyva-themes/commerce` | Metapackage: all GA features |
| `hyva-themes/commerce-module-commerce` | `Hyva_Commerce` base module (admin branding, user settings table, config tab) |
| `hyva-themes/commerce-module-cms` | Hyvä CMS (multi-module package) |
| `hyva-themes/commerce-module-cms-ai-translations` | `Hyva_CmsAiTranslations` (OpenAI / Gemini / DeepL) |
| `hyva-themes/commerce-module-cms-google-maps` | Google Maps CMS component |
| `hyva-themes/magento2-cms-tailwind-compiler` | Server-side Tailwind compiler (CMS 1.2.0+) |
| `hyva-themes/commerce-module-cms-tailwind-jit-bridge` | Hyvä CMS ↔ Tailwind compiler bridge, strategy toggle |
| `hyva-themes/magento2-cms-tailwind-recompile` | Optional; ships `bin/magento hyva:cms-tailwind:recompile` |
| `hyva-themes/commerce-module-admin-dashboard` | `Hyva_AdminDashboardFramework` + `Hyva_AdminDashboardWidgets` |
| `hyva-themes/commerce-module-admin-dashboard-api` | `Hyva_AdminDashboardApi` — widget contract, OSL-3.0 |
| `hyva-themes/commerce-module-admin-dashboard-cms-widgets` | `Hyva_AdminDashboardCmsWidgets` |
| `hyva-themes/commerce-module-admin-dashboard-google-crux-history-widget` | `Hyva_AdminDashboardGoogleCruxHistoryWidget` |
| `hyva-themes/commerce-theme-adminhtml` | Admin Theme |
| `hyva-themes/commerce-module-admin-theme` | Admin theme support module |
| `hyva-themes/commerce-module-menu-builder` | `Hyva_MenuBuilder` |
| `hyva-themes/commerce-module-media-optimization` | `Hyva_MediaOptimization` |
| `hyva-themes/commerce-module-image-editor` | `Hyva_ImageEditor` |
| `hyva-themes/commerce-module-form-builder` | `Hyva_FormBuilder` (beta) |
| `hyva-themes/commerce-module-email-templates` | `Hyva_EmailTemplates` (beta) |
| `hyva-themes/commerce-module-category-merchandiser` | Category Merchandiser (beta) |
| `hyva-themes/commerce-module-linked-products` | Linked Products (beta) |
| `hyva-themes/magento2-ai-providers`, `magento2-module-ai`, `-ai-deep-l`, `-ai-gemini`, `-ai-open-ai` | AI provider stack used by AI translations |

## Agency / technology partner install (dev environments only)

GitLab installs require SSH key auth and are **not** suitable for deployments.

```bash
composer config minimum-stability dev
composer config repositories.hyva-themes/commerce git git@gitlab.hyva.io:hyva-commerce/metapackage-commerce.git
composer config repositories.hyva-themes/commerce-module-cms git git@gitlab.hyva.io:hyva-commerce/module-cms.git
# … one `composer config repositories.<package> git <url>` line per package used
composer require --prefer-source 'hyva-themes/commerce:dev-main'
bin/magento setup:upgrade
```

The full repository list is on the getting-started page. Note the API package lives under a
different namespace on GitLab: `git@gitlab.hyva.io:hyva-themes/commerce-module-admin-dashboard-api.git`.
When a release adds new packages, add their `repositories` entries **before** `composer update`, or
resolution fails. <https://docs.hyva.io/hyva-commerce/upgrading/upgrading-to-1.3.0.html>

## Beta releases

Betas are published as `x.y.z-betaN` for existing packages and `0.x.x` for new ones. Alpha builds
are partner-only and may be untagged; beta builds are available to all licensees.

```bash
# single module to a beta tag
composer require hyva-themes/commerce-module-cms:1.3.0-beta1

# with the metapackage installed, alias the beta to the current stable so the constraint resolves
composer require hyva-themes/commerce-module-cms:"1.3.0-beta1 as 1.2.2"

# a beta feature module that requires a beta CMS base
composer require hyva-themes/commerce-module-cms:1.3.0-beta2 hyva-themes/commerce-module-form-builder:0.1.0
bin/magento setup:upgrade
```

The explicit beta constraint must be present in the root `composer.json`, otherwise the default
`stable` minimum-stability blocks the install.
<https://docs.hyva.io/hyva-commerce/faqs/installing-beta-releases.html>

## Release status (as documented)

- **GA**: Admin Theme, Admin Dashboard, Hyvä CMS, Image Editor, Media Optimization, Menu Builder.
- **Alpha/beta**: Category Merchandiser, Email & Newsletter Templates, Linked Products, Form Builder.

New features arrive either as separate alpha/beta packages, or inside a GA release behind a feature
flag (possibly off by default). Alpha builds should never be used in production; beta builds can be,
accepting that upgrades may require rework. RC builds are generally not published.
<https://docs.hyva.io/hyva-commerce/faqs/release-process-status.html>

## Upgrading

```bash
composer update --with-dependencies hyva-themes/commerce            # latest
composer update --with-dependencies hyva-themes/commerce:x.y.z      # pinned
composer require --with-dependencies hyva-themes/commerce           # needed across 0.x minor bumps
```

Process: read the version-specific upgrade notes, read the changelog, upgrade the metapackage, then
re-apply any project customisations. The upgrade guide only covers metapackage installs.
<https://docs.hyva.io/hyva-commerce/upgrading/index.html>

Recurring patterns across upgrade notes (rather than version-by-version detail):

- Contracts move out of runtime modules into dedicated `*-api` packages; legacy contracts stay
  bridged for a period but are documented as deprecated.
- Breaking interface changes are announced as "will fatal until you add method X"
  (e.g. `ProviderInterface::getScopeSelector()`).
- New ACL resources ship with new features and must be granted to custom admin roles manually.
- Data patches migrate existing rows (e.g. `MigrateWidgetsToViews`) and are idempotent.
- Component behaviour fixes can silently change existing content rendering (e.g. the Grid/Columns
  `start`/`end` direction fix, Menu Content losing its grid) — those notes name the pages to review.
- No security vulnerabilities have been documented for Hyvä Commerce to date.
  <https://docs.hyva.io/hyva-commerce/upgrading/security-changelog.html>

## Post-install setup and common failures

- Enable Magento's **New Media Gallery** — required by Hyvä CMS and Image Editor for image
  selection/editing.
- Multi-domain / custom admin domain: CSP frame policies are applied automatically since Hyvä CMS
  `1.0.2` (`hyva_cms/general/auto_csp_frame_policies`). See `cms-liveview.md` for the manual path.
- All Hyvä Commerce settings live under `Stores > Settings > Configuration > Hyvä Commerce`. They
  used to live under `Hyvä Themes`; only the menu location moved, config paths are unchanged.
- Unstyled storefront after installing a feature → rerun the Tailwind build.
- Image picker not opening / edited images not saving → New Media Gallery is off.
  <https://docs.hyva.io/hyva-commerce/faqs/troubleshooting.html>

## Support channels

Community Slack `#hyva-commerce` and `#hyva-cms`, release notifications in `#update-notifications`,
technical support form in the Hyvä customer portal, and GitLab issues/MRs for Platinum/Gold/
technology partners (MRs need a linked issue).
<https://docs.hyva.io/hyva-commerce/faqs/getting-help.html>
