---
name: hyva-commerce
description: Covers the Hyvä Commerce product suite for Magento 2 / Adobe Commerce — Hyvä CMS and the Liveview Editor, admin dashboard widgets, admin theme, Menu Builder, Form Builder, Email & Newsletter Templates, Media Optimization, Image Editor, Category Merchandiser and Linked Products — including composer packages, licensing, admin config paths, component declaration JSON, PHP contracts, layout handles, events and REST/GraphQL endpoints. Use this skill when a task mentions hyva-themes/commerce-*, Hyvä CMS, Liveview Editor, components.json, hyva_cms, hyva_dashboard_widget.xml, WidgetTypeInterface, Hyva\CmsLiveviewEditor, instance components, Page Builder migration, content scheduling, menu builder, form builder submissions/webhooks, email templates, media optimization / hyva:media-optimization:clear, image editor presets, category merchandiser — or when creating/overriding a CMS component, adding a dashboard widget, extending Hyvä CMS to a custom content type, wiring Tailwind JIT for CMS content, or debugging why Hyvä CMS content does not render.
---

# Hyvä Commerce

Hyvä Commerce is a suite of Magento modules (plus one admin theme) sold on top of the Hyvä Theme
licence. It is **not** the Hyvä storefront theme: it adds merchant-facing tooling (a component CMS,
an admin dashboard, a visual merchandiser, email builders) and developer APIs around it.

Everything installs through Composer from a private Packagist (licence key) or from
`gitlab.hyva.io` (Gold/Platinum agency + technology partners). Requires Magento Open Source or
Adobe Commerce **2.4.4+**, PHP **8.1+**, Hyvä Default Theme **1.3.0+**, Hyvä Theme Module
**1.3.15+**. Adobe Commerce / B2B feature compatibility additionally needs a **Hyvä Enterprise**
licence. <https://docs.hyva.io/hyva-commerce/getting-started/index.html>

Commands below are written bare. On a containerised local stack (Warden, DDEV,
docker compose) prefix every `bin/magento` call with your own wrapper. On projects with
no `app/code`, client code lives in `vendor/<vendor>/*` composer packages, and every
customer-facing string should go through `__()` for each store locale.

## Feature map

| Feature | What it does | Reference |
|---|---|---|
| Hyvä CMS + Liveview Editor | Component-based CMS for CMS pages/blocks, product & category attributes, templates, snippets. JSON content trees rendered by PHTML. | `references/cms-liveview.md` |
| Hyvä CMS component development | `components.json` declaration schema, field types, nesting, `Element` block helpers, overrides, custom field types, custom content types. | `references/cms-component-development.md` |
| Admin Dashboard | Widget grid replacing the Magento dashboard; per-user & role-shared views; widget XML + PHP contract. | `references/admin-dashboard.md` |
| Admin Theme | Refreshed adminhtml theme (Mage-OS M137 based), plus admin branding/logos. | `references/admin-theme.md` |
| Menu Builder | Visual storefront menus (mega menu, drilldown, mobile, footer) built as Hyvä CMS content. | `references/menu-builder.md` |
| Form Builder (beta) | Forms as a Hyvä CMS content type; email + webhook delivery, security gates, validators. | `references/form-builder.md` |
| Email & Newsletter Templates (beta) | Transactional email + newsletter templates built with email-safe components. | `references/email-templates.md` |
| Media Optimization + Image Editor | Resize/convert (WebP, AVIF) with automatic HTML/CSS replacement; in-admin image editing. | `references/media-and-images.md` |
| Category Merchandiser (beta), Linked Products (beta) | Drag-and-drop category product grid; product groups by shared attribute. | `references/other-features.md` |
| Install, licensing, release status | Metapackage vs individual modules, GitLab install, beta channel, upgrade process. | `references/installation-and-licensing.md` |

## References

- `references/installation-and-licensing.md` — prerequisites, `hyva-themes/commerce` metapackage, per-feature packages, GitLab/`dev-main` install, beta aliasing, upgrade commands, GA vs alpha/beta status, post-install steps and troubleshooting.
- `references/cms-liveview.md` — Hyvä CMS module split, content storage, rendering, editor workflow, Tailwind scoping/compilation, scheduling, translations, import/export, instance components, user settings API, Liveview Bridge, REST/GraphQL, all admin config paths.
- `references/cms-component-development.md` — the full `etc/hyva_cms/components.json` schema, field types and validation, parent/child rules, `Hyva\CmsLiveviewEditor\Block\Element` helpers, template overrides vs declaration overrides, legacy templates, custom field types and field handlers, extending Hyvä CMS to a custom entity, product/category attribute rendering.
- `references/admin-dashboard.md` — module/package structure, `hyva_dashboard_widget.xml` reference, `WidgetTypeInterface` composition API vs legacy `AbstractWidgetType`, configurable input types, cache, layout handles, JS event catalogue, dashboard views + ACL, built-in widget classes, system config paths.
- `references/admin-theme.md` — installation, active-theme and admin-branding config, child-theme customisation, compatibility notes.
- `references/menu-builder.md` — creating/displaying menus, rendering from widget/layout/PHTML, `hyva_menu_root` context flag, category importer, `CategoryTreeExpander`, preview menu locking.
- `references/form-builder.md` — form roots, field types, submission pipeline, entity vs component settings, security gates, field descriptors/validators, webhook payloads and test marking, embedding.
- `references/email-templates.md` — content types and providers, render vs preview pipelines, CSS inlining, newsletter queue behaviour, email component rules, config and setup buttons.
- `references/media-and-images.md` — Media Optimization engines/config, automatic replacement modes, `Hyva\Theme\ViewModel\Media` API, CLI flush, Hyvä CMS integration; Image Editor save/restore, quality config, crop presets, upload limits.
- `references/other-features.md` — Category Merchandiser config and scope, Linked Products attribute constraints.

## Pitfalls

- Regenerate Tailwind after installing/updating any Hyvä Commerce feature (`bin/magento hyva:config:generate` then `npm --prefix <theme>/web/tailwind ci --ignore-scripts && npm … run build`); an unstyled storefront is almost always a skipped build.
- Enable Magento's **New Media Gallery** before using Hyvä CMS or the Image Editor — image pickers and saves silently fail without it.
- Hyvä CMS component overrides are **full replacements**, never merges: copy the whole declaration and re-add an explicit `template` key, or the path resolves to your module and the component stops rendering.
- Never guard a product/category attribute template on the native EAV value; render through `Hyva\CmsMagentoAttributes\ViewModel\AttributeContent::getHtml()` and check the returned HTML.
- Publish, don't just save: a Hyvä CMS draft never replaces live output, and embedded forms/menus always render the *published* version.
- Write new dashboard widgets against `Hyva\AdminDashboardApi\Api\V1\WidgetTypeInterface` and require only `hyva-themes/commerce-module-admin-dashboard-api`; `AbstractWidgetType` is legacy and only bridged at runtime.
- A dashboard widget without a matching `display_type` entry in `Converter::displayTypeTemplateMap` (or `display_type=template` without `<template>`) throws on render.
- Custom `ProviderInterface` implementations must implement `getScopeSelector(int $entityId): string` returning `.hcms-{type}-{id}`; the old `getTailwindClassPrefix()` is deprecated and fatal-by-omission was introduced in CMS 1.2.0.
- Hyvä CMS Tailwind CSS lands in `@layer hyva-cms-tailwind` at lowest priority — theme styles always win; use Tailwind's `!` modifier only as a last resort.
- Add third-party adminhtml CSS/JS to `Hyva\CmsLiveviewEditor\Plugin\PageConfigStructurePlugin::allowedAssets` or it will not load inside the Liveview Editor.
- Clean `hyva_cms` (`bin/magento cache:clean hyva_cms`) on deploy — it caches `components.json` declarations and is enabled in production mode.
- Hyvä CMS scheduling needs Magento cron running (due-release check every 5 min); it cannot be driven by Adobe Content Staging.
- Form Builder and Email Templates are **beta**, require specific Hyvä CMS beta versions, and their PHP APIs may break between betas — keep an explicit version constraint in the root `composer.json`.
- Form Builder test submissions from a preview really send: emails get a `[test]` subject prefix and webhooks an `X-Hyva-Form-Test: 1` header — make receivers honour it before testing.
- Media Optimization's picture-mode HTML replacement breaks configurable swatch image switching, and only childless blocks are processed; exclude a block with `skip_img_optimization`.
