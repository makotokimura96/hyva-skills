# Hyvä UI Library

## What it is, and licensing

More than a CSS/HTML library: every component ships a fully functional `.phtml`
with integrated logic, crafted for the Hyvä environment, so it works immediately
after integration. Hyvä positions it as "the functional equivalent of Tailwind UI,
but tailored for Hyvä Themes and with built-in logic".

Licensing (important, it changed):

- As of **November 2025**, with the Hyvä theme becoming open source, **Hyvä UI is a
  stand-alone commercial product**.
- Licenses purchased **before 10 November 2025** include Hyvä UI.
- Users of the **open-source** Hyvä theme need a **separate** Hyvä UI license.
- Hyvä UI is also **included with Hyvä Commerce licenses**.
- Purchase at `hyva.io/hyva-ui.html`.

<https://docs.hyva.io/hyva-ui-library/what-is-the-hyva-ui-library.html>
<https://docs.hyva.io/hyva-ui-library/getting-started.html>

## Installation

Three delivery routes: Composer with a valid packagist.com license key, direct
download from packagist.com, or download from the Hyvä Portal
(`hyva.io/licenses/downloads/`).

```bash
composer require --dev hyva-themes/hyva-ui
```

`--dev` is deliberate: it makes copy-pasting components convenient locally while
`composer install --no-dev` keeps it out of a proper deployment pipeline.

Downloading from Packagist:

1. Go to `https://packagist.com/customers/<license-url-key>.hyva-themes/packages`
   (e.g. `acme-abc123`), or `https://hyva-themes.repo.packagist.com/<key>/` then
   Packages. The key is on the Hyvä Portal at `hyva.io/licenses/manage/shops/`.
2. Log in to Packagist with the license key/token.
3. Search for and open **hyva-themes/hyva-ui**, then click the download icon.

Composer repository setup (packagist.com / gitlab.hyva.io auth) is the same as for
the Hyvä theme itself - the Hyvä UI docs simply point at the Hyvä Theme FAQ
"Configuring the Hyvä composer repository".

<https://docs.hyva.io/hyva-ui-library/faqs/configuring-packagist-and-gitlab.html>

## Using components - the rules

- Each component folder has its own `README.md` with component-specific
  instructions. Since 2.7.1 the `## Requirements` section comes **before**
  `## Usage`, and states the minimum Hyvä default theme version as plain text.
- Usage is normally: copy the component's template(s) into the Hyvä theme, and
  possibly adjust the Tailwind configuration.
- **Do not clone the Hyvä UI repository into the Magento project**, especially not
  inside the theme:
  - bloated stylesheet - unnecessary Tailwind classes get generated into `styles.css`;
  - compatibility breakage - future Hyvä UI updates may remove, rename or modify
    components and break the site.
- Occasionally a component needs something the default theme lacks (a missing Alpine
  plugin, an alternative icon pack). Such extras are listed in the component's
  **Requirements** section.

<https://docs.hyva.io/hyva-ui-library/getting-started.html>
<https://docs.hyva.io/hyva-ui-library/included-components.html>

## Component list (component -> variants)

| Component | Variants |
|---|---|
| Accordion | `A-basic` |
| Ajax-ATC | `A-simple` (asynchronous add to cart) |
| Banner | `A-default` (hero + bg image + CTA), `B-split`, `C-text` |
| Breadcrumbs | `A-simple` |
| Buttons | `A-basic` (base styles + modifiers) |
| Card | `A-default`, `B-media` (media object) |
| Categories | `A-grid-images`, `B-grid-patterns` |
| Category-filter | `A-standard` (layered nav, collapsible groups), `B-elasticsuite` |
| Cookie-notice | `A-full-width`, `B-overlay`, `C-simple-elegant` |
| Error-page | `A-simple`, `B-split` |
| Footer | `A-clean`, `B-4-column-newsletter`, `C-mega` |
| Gallery | `A-basic`, `B-fancy`, `C-grid`, `D-splide` |
| Generic-content | `A-text`, `B-visual` |
| Header | `A-clean`, `B-compact`, `C-stacked` |
| Loaders | `A-spinner`, `B-ping`, `C-dancers` |
| Menu | `A-simple-static-links`, `B-4-column-megamenu`, `C-vertical-dropdown-4-column`, `D-shop-dropdown` |
| Menu-mobile | `A-scroll`, `B-tabs` |
| Minicart | `A-classic` (panel), `B-popover` |
| Modal | `A-simple` (accessible dialog with focus trap) |
| Notification | `A-simple` (inline toasts), `B-full-width` |
| Order-confirmation | `A-clear` |
| Pagination | `A-clean` |
| Popup | `A-newsletter-image`, `B-newsletter-title` |
| Product-card | `A-card-with-swatches` |
| Product-data | `A-specs`, `B-accorditabs` (accordion+tabs hybrid), `C-highlights` |
| Product-reviews | `A-basic`, `B-minimal` |
| Scroll-to-top | `A-simple`, `B-action` |
| Search-form | `A-header` |
| Shortcuts | `A-simple` (quick-link grid / action tiles) |
| Slider | `A-basic`, `B-marquee` (continuous autoplay), `C-product` |
| Sticky-ATC | `A-simple` (sticky add-to-cart bar on PDP) |
| Swatches | `A-swatches-rounded` |
| Testimonial | `A-simple`, `B-card` |
| USP | `A-icons`, `B-cards`, `C-compact` |

Hyvä UI targets all Hyvä products and modules, with focus on the Hyvä **Default
Theme**. PDF and Figma files are the visual reference.

<https://docs.hyva.io/hyva-ui-library/included-components.html>

## Menus

Desktop and mobile menus are deliberately separate designs, and the menu structure
is kept minimal so it is easy to customise or extend (including with third-party
modules).

Desktop:

- **A - Simple Static Links** - static list, full control over desktop items; useful
  when the desktop menu is managed independently while another menu type (e.g.
  mobile) handles category listings.
- **B - Column Megamenu** - classic mega menu: top-level item opens a panel with
  nested items in columns; best for content-rich menus.
- **C - Vertical Dropdown (4 Columns)** - drilldown for deeply nested structures,
  visually similar to the mobile menus, multi-level navigation.
- **D - Shop Dropdown** - like C but all top-level items sit under one "Shop" button,
  and it also supports extra static links.

Mobile:

- **A - Scroll Menu** - modern drilldown with search bar and CTA button.
- **B - Tabs Menu** - like the scroll menu plus tabs to group items, for a more
  compact layout.

Menus C/D support static (CMS) blocks the same way Menu B does, so banners or extra
content can be placed inside or after the menu. Menu A gained XML menu support (as
the mobile menus have) in 2.5.0.

<https://docs.hyva.io/hyva-ui-library/menus.html>

## UI Plugins

Reusable Alpine.js or vanilla-JS plugins designed to pair with Hyvä UI components -
e.g. a Sticky Header plugin that works with any header, including the default
theme's. They are also where Hyvä experiments with features that may later be merged
into the theme.

Layout - plugins live in their own directory, not in `components`:

```
./hyva-ui
├── assets
├── components
├── i18n
└── plugins
    └── <PLUGIN>
        ├── src
        └── README.md
```

Naming: a plugin prefixed with `alpine` is for Alpine.js; unprefixed ones are
vanilla JavaScript and are not bound to a specific Hyvä version. Each plugin's
`README.md` explains usage; third-party Alpine plugin docs live under the Hyvä
Themes `working-with-alpinejs/alpine-plugins` docs.

**Important version note:** the **Snap Slider** and **Html Dialog** plugins were
removed from Hyvä UI in 2.7.0 because they are now part of the **Hyvä 1.4 theme
module** (`x-snap-slider`, `x-htmldialog`). Hyvä UI 2.6.1 also added an
*experimental* Tailwind v4 support plugin and a Tailwind v3 design-tokens example
plugin.

<https://docs.hyva.io/hyva-ui-library/ui-plugins.html>
<https://docs.hyva.io/hyva-ui-library/changelog.html>

## Component badges

Badges appear in component `README.md` files and in the Figma design:

| Badge | Meaning |
|---|---|
| `License` | Component is part of Hyvä UI, governed by the Hyvä UI **commercial license** (requires an active license) |
| `Figma` | A matching design exists in the Hyvä UI Figma file |
| `wysiwyg_support` | Usable **both** as a theme component (layout XML / `.phtml`) **and** inside a WYSIWYG editor (Magento PageBuilder, Hyvä CMS) as plain HTML |
| `wysiwyg_only` | Designed **exclusively** for WYSIWYG editors; plain HTML, no theme integration |
| `Hyvä CMS` | Bundled with the Hyvä CMS module - installing Hyvä CMS gives access with no extra setup |

The `wysiwyg_*` badges were renamed from `CMS only` / `CMS Support` in 2.7.0 to avoid
confusion with Hyvä CMS. Version badges (Hyvä / Tailwind / Alpine) were removed from
READMEs in 2.7.1; that information is now plain text in the Requirements section.

<https://docs.hyva.io/hyva-ui-library/faqs/component-badges.html>

## CSS variables and Tailwind tokens

Hyvä UI leans on CSS custom properties plus Tailwind tokens to keep components
customisable and scalable - message styles, for example, are driven by a combination
of both. A common use case is feeding dynamic PHP values into CSS through custom
properties. The in-depth reference is the Hyvä Themes page
"CSS Variables + TailwindCSS" (`working-with-tailwindcss/css-variables-plus-tailwindcss.html`).

Related: the swatches were reworked into a **single CSS file** in 2.7.0, so swatch
styling no longer requires template overrides.

<https://docs.hyva.io/hyva-ui-library/faqs/css-variables.html>

## Translations

Hyvä UI components ship **no pre-built translations** - components evolve constantly
and maintaining every language per release is not feasible. Instead, from **Hyvä UI
2.4.0** onward an `i18n/en-US.csv` file is provided inside the Magento installation,
containing the translatable text used across components - **generic text only, not
sample text**. Use it as the starting point and reference for identifying which
strings need translating (produce a dictionary per store locale
in the theme or module that owns the copied component).

<https://docs.hyva.io/hyva-ui-library/faqs/how-to-add-translations.html>

## Upgrading copied components

Hyvä UI components are unlike other Hyvä modules: once integrated, **you own and
maintain the code**. They do not auto-update with new library releases, but you may
still want bug fixes or new features.

- **Optional updates:** if you only customised the component through XML arguments,
  you can simply replace the file with the new version - XML arguments override
  default behaviour without touching the code.
- **Selective updates:** otherwise, diff your version against the latest to identify
  changes; if you only changed styling, replace just the PHP and JavaScript with the
  newer versions and verify the Alpine directives in your HTML have not changed. Your
  custom styles can normally be kept. Double-check your customisations do not
  conflict with new functionality.

<https://docs.hyva.io/hyva-ui-library/faqs/how-to-upgrade.html>

## Figma design system

A full design system is published at `figma.com/@hyva`, using Figma components,
variants, Auto Layout and shared text/colour/effect styles - edit a style once and it
propagates. All code assets are included, so e.g. payment icons can be swapped for
brand-appropriate ones; the **Hyvä Payment Icons** were added to the Figma file as of
Hyvä UI **2.5.0**.

To reuse it across projects: publish the Hyvä UI file as a Figma **library**
(Library modal via the editor toolbar, the Assets panel book icon, or `⌥3` / `Alt+3`),
then activate that library in other files and browse the components from the Assets
panel. Questions go to the `#hyva-ui-figma` Slack channel; general Hyvä UI questions
and component suggestions to `#hyva-ui` or the GitLab repository (Hyvä prioritises
designs from its internal design process, but logs suggestions in the UI backlog).

<https://docs.hyva.io/hyva-ui-library/figma.html>
<https://docs.hyva.io/hyva-ui-library/faqs/how-can-i-contribute.html>

## Version highlights worth knowing

Read the full changelog before an upgrade; these are the structural ones.

- **2.8.0** (2026-06-30) - new **Map A** component (Google Maps with one or more
  markers, `AdvancedMarkerElement` API when a Map ID is provided) and **Embed A**
  (YouTube/Vimeo with optional lazy-load). Fixed an invalid reCAPTCHA implementation
  in Popup A/B: the outdated `getRecaptchaData` approach was replaced with the correct
  `viewModelRecaptcha` layout argument, plus a missing
  `Magento_ReCaptchaNewsletter/layout/default.xml` and a missing `<body>` wrapper in
  `Magento_Newsletter/layout/default.xml`. Footer B's orders link block renamed
  `customer.header.orders.link` -> `customer.footer.orders.link`.
- **2.7.1** - README restructure; `translate="true"` added to Banner A/B/C `title`,
  `subtitle`, `label` XML arguments; Banner A/B `alt` fixed to use `escapeHtmlAttr`
  instead of `escapeUrl`; Banner C `getClasses()` -> `getCssClasses()`; Category
  Filter B updated for Hyvä Smile Elasticsuite compatibility module 2.7.
- **2.7.0** - new **Card** and **Loader C**; all **CTA** components merged into
  **Banner** (now also part of Hyvä CMS); Snap Slider and Html Dialog plugins removed
  (now in the Hyvä 1.4 theme module); Tailwind 4 / Hyvä 1.4 compatibility fixes;
  swatches unified into one CSS file.
- **2.6.1** - experimental Tailwind v4 support plugin; Product Card A image template
  split into default and CSP variants; CSP violations fixed in Menu C/D, Cart A/B,
  Message A/B, Pagination A.
- **2.6.0** - **all UI code made CSP compliant**; plugins moved to the `plugins`
  directory; Slider C (product) added.
- **2.5.0** - Breadcrumbs A, Button A, Mobile Menu A/B, Pagination A, Search Form A
  (with Smile Elasticsuite support); search form extracted out of Header A/B/C; XML
  menu support in Menu A; static block support in Menu C/D.
- **2.4.0** - Order Confirmation A, Error Pages A/B, the i18n boilerplate, README
  badges.
- **2.2.0 / 2.1.0** - Ajax ATC A, Minicart A/B, Loaders, Slider C (Splide), the
  galleries A-D, Product-Data A/B/C, Product-Review A/B, Swatches A, Category Filter
  A + B (Smile ElasticSuite).
- **2.0.0** - everything updated for Hyvä theme 1.2.x, Tailwind CSS 3 and Alpine.js 3.

Recurring themes across releases: CSP compliance, Tailwind 4 / Hyvä 1.4
compatibility, accessibility and colour-contrast fixes, correct escaping, and moving
duplicated markup out of templates.

<https://docs.hyva.io/hyva-ui-library/changelog.html>

## Demo and instruction videos

Hyvä publishes walkthroughs: the UI Plugins + Snap Slider episode of Hyvä Bytes
(recorded at UI 2.6.0), Willem's pre-release demo of the first 20+ components and
their integration into a Hyvä theme, and a "How To Hyvä" episode on using and
customising the mega-menu components. More on the `@HyvaThemes` YouTube channel.

<https://docs.hyva.io/hyva-ui-library/videos.html>
