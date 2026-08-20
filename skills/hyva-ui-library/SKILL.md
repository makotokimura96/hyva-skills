---
name: hyva-ui-library
description: Covers the two Hyvä content/UI add-ons - the separately licensed Hyvä UI Library (hyva-themes/hyva-ui - copy-paste .phtml components with working PHP and Alpine logic: headers, menus and mega menus, mobile menus, product galleries, sliders, cards, footers, minicart, ajax add-to-cart, category filters incl. Elasticsuite, cookie notices, USPs, loaders, plus UI plugins, a Figma design system, component badges, i18n and CSS-variable/Tailwind-token conventions) and the free Hyvä Widgets module (hyva-themes/magento2-hyva-widgets - native Magento 2 widgets for banners, generic content, category product sliders and multi-field/step content, editable in the admin WYSIWYG). Use this skill when installing or upgrading hyva-ui or Hyva_Widgets, picking or copying a UI component into a theme, configuring a Hyvä UI product gallery through etc/view.xml, building a CSS scroll-snap slider or using x-snap-slider, translating UI components, wiring a client-editable CMS block with Hyvä Widgets, or deciding between Hyvä UI, Hyvä Widgets, PageBuilder and Hyvä CMS; keywords Hyvä UI, hyva-ui, Hyvä Widgets, Hyva_Widgets, mega menu, product gallery, snap slider, Splide, component badges, packagist.com license key.
---

# Hyvä UI Library and Hyvä Widgets

Two different products, often confused:

- **Hyvä UI Library** (`hyva-themes/hyva-ui`) - a **separately licensed commercial**
  collection of ready-to-use components. Each component is a real `.phtml` with
  integrated PHP and Alpine logic, so it works as soon as it is copied into a theme;
  think "Tailwind UI for Hyvä, with the logic included". It is **not a composer
  dependency you keep** - you copy individual components into the project. As of
  November 2025, with the Hyvä theme becoming open source, Hyvä UI is a stand-alone
  commercial product: licenses bought before 10 Nov 2025 include it, users of the
  open-source theme need a separate license, and it is also included with Hyvä
  Commerce licenses. <https://docs.hyva.io/hyva-ui-library/what-is-the-hyva-ui-library.html>
- **Hyvä Widgets** (`hyva-themes/magento2-hyva-widgets`) - a package of prebuilt
  **native Magento 2 widgets** with no dependency beyond the Hyvä theme, giving
  content editors a deliberately constrained CMS toolkit inside the standard admin
  WYSIWYG. <https://docs.hyva.io/hyva-widgets/what-are-hyva-widgets.html>

Copied UI components belong in your child theme or an in-house module — never edited in
place inside `vendor/`. Rebuild Tailwind from the theme's `web/tailwind/` directory after
adding one (on projects with no child theme that is
`vendor/hyva-themes/magento2-default-theme/web/tailwind/`), and translate every component
string for each store locale.

## References

- `references/ui-library.md` - licensing, composer/packagist install, the "copy, do not clone" rule, full component/variant list, desktop and mobile menu variants, UI plugins, component badges, CSS variables and Tailwind tokens, translations, upgrade strategy, Figma, version highlights.
- `references/product-gallery.md` - the four gallery versions and every `etc/view.xml` `<var name="gallery">` option, with the magnifier / autoplay / caption / dots caveats.
- `references/hyva-widgets.md` - requirements, install, enabling, placing widgets, module layout for developers, and every field of the four widget types.
- `references/component-recipes.md` - accessible CSS scroll-snap slider recipe and the `x-snap-slider` plugin, plus an index mapping each Hyvä UI FAQ topic (packagist/gitlab auth, badges, CSS variables, translations, upgrading) to where it is documented.

## Pitfalls

- Hyvä UI needs its own license; never assume an open-source Hyvä theme project has access to `hyva-themes/hyva-ui`.
- Require Hyvä UI with `--dev` so `composer install --no-dev` keeps it out of builds; it is a source of components, not a runtime dependency.
- Never clone or install the Hyvä UI repo inside the theme - it bloats `styles.css` with unused Tailwind classes and future releases can rename or remove components under you.
- Read the component's own `README.md` first: it carries the `## Requirements` (minimum Hyvä default theme version, extra Alpine plugins or icon packs) before `## Usage`.
- Check the component/Figma badges: `wysiwyg_only` components are for WYSIWYG/PageBuilder/Hyvä CMS content and are not theme-integration components; `Hyvä CMS` badged ones already ship with Hyvä CMS.
- Copied components are yours to maintain - upgrade them selectively by diffing PHP/JS while checking Alpine directives have not changed, not by blind overwrite (safe only when you customised via XML arguments alone).
- Gallery options are version-dependent and not every version supports every var; confirm against the gallery's `README.md` before adding a `view.xml` var.
- The gallery magnifier is non-touch only by design, and nav dots exist only in Gallery D and are auto-hidden on touch devices.
- Gallery `autoplay` loads video data as soon as a video becomes active - a video as first gallery item costs page-load performance; it is unavailable in Gallery C.
- Hyvä UI ships no translations: use `i18n/en-US.csv` (2.4.0+) only as the list of translatable generic strings and add real per-locale dictionaries yourself.
- Snap Slider and Html Dialog are **part of the Hyvä 1.4 theme module**, not standalone plugins - do not go looking for them in `hyva-ui/plugins` on 2.7.0+.
- Hyvä Widgets animations rely on Alpine `x-intersect`, which only exists from Hyvä 1.1.10 onward.
- Widget images are not resized on the frontend: set the width/height fields and upload correctly sized files or you ship megabyte hero images.
- In production mode, refresh the Block HTML and Full Page Cache after editing a widget or nothing changes on the storefront.
- Override widget templates through theme inheritance (`Hyva_Widgets/templates/widget/…`), never by editing `vendor/hyva-themes/magento2-hyva-widgets`.
