# Hyvä Widgets

## What they are, and licensing

Hyvä Widgets are a **native Magento 2** way to give content editors a simple CMS
framework: a package of prebuilt Magento widgets configured through fields for image
upload, WYSIWYG, text, colour pickers, sliders, dynamic listings of category
products and more. They can be placed directly in CMS pages as a widget, or into
containers via Magento's admin layout functionality.

Unlike the Hyvä UI Library, Hyvä Widgets is **not a separate commercial product** -
it is a package delivered through the Hyvä Themes composer access you already have,
with **no dependency beyond the Hyvä theme**.

Design intent (worth repeating to clients): PageBuilder-like extensions carry dozens
of dependencies and give editors so much freedom that carefully designed sites end up
looking broken. Hyvä Widgets deliberately apply "the right amount of restrictions" so
content stays inside the design system, while developers get a toolset for building
custom content templates and layouts fast with Tailwind and Alpine. Everything runs
on native Magento widgets plus native TinyMCE drag and drop - no custom page-builder
machinery. The bundled animation/slider libraries can be used, replaced or removed at
the developer's discretion.

<https://docs.hyva.io/hyva-widgets/what-are-hyva-widgets.html>

## Requirements and installation

- Magento **2.4.4** or newer
- Hyvä Themes **1.1.10** or higher (animations need `x-intersect`, added in 1.1.10)
- Access to Hyvä Themes via Private Packagist or `gitlab.hyva.io`

```bash
composer require hyva-themes/magento2-hyva-widgets
bin/magento module:enable Hyva_Widgets
bin/magento setup:upgrade
```

Contributors and technology partners can install from GitLab instead (requires
GitLab access, with your public SSH key registered on your `gitlab.hyva.io` profile):

```bash
composer config repositories.hyva-themes/magento2-hyva-widgets vcs git@gitlab.hyva.io:hyva-themes/magento2-hyva-widgets.git
composer require hyva-themes/magento2-hyva-widgets:dev-main
```

Run the CLI through your container wrapper if containerised, e.g.
`bin/magento setup:upgrade`, then rebuild Tailwind with
`make build` so any widget classes used by the templates are compiled.

<https://docs.hyva.io/hyva-widgets/getting-started.html>

## Placing widgets - two routes

- **Admin widget interface** - `Content > Widgets`: create widget instances and
  assign them to specific pages or layout positions.
- **WYSIWYG editor / PageBuilder** - insert widgets directly into CMS pages and
  blocks with the widget insertion button in any content editor.

## Admin workflow (the one to hand to a client)

1. `Content > Pages > <page, e.g. Home page>`, open the Content section and activate
   the editor with the **Show/Hide Editor** button.
2. Click the **Insert Widget** icon.
3. Pick a widget type from the dropdown, e.g. *Hyva content widget*.
4. The widget popup opens with the list of options for that type.
5. Press **Insert Widget** (top right) when done editing, then **Save** the page.
6. **In production mode, refresh the Block HTML and Full Page Cache** or the change
   will not appear on the storefront.
7. Check the result on the storefront.

<https://docs.hyva.io/hyva-widgets/how-to-use.html>

## Module layout for developers

Source lives at `vendor/hyva-themes/magento2-hyva-widgets/src` and follows the
standard Hyvä module structure:

- `Block/` - the widget PHP block classes.
- `etc/widget.xml` - **the primary place to work**: how each widget is initialised.
  Add a field, add extra data, or create a new widget based on the blueprints here.
- `Observer/` - forces generation of static URLs for widget images (works around an
  open Magento 2 issue with directives).
- `Plugin/` - fixes the widget declaration, where widget rendering breaks on
  unescaped apostrophes.
- `ViewModel/CategoryProducts` - supplies the products for the selected categories in
  the category slider widget.
- `view/frontend/templates/` - the frontend templates, built with vanilla JS, Tailwind
  and Alpine.
- `view/frontend/web/` - library code for the slider widget.

**Overriding a template** uses native Magento theme inheritance: create
`Hyva_Widgets/templates/widget/` in your theme and copy in the template you want to
override. Never edit files under `vendor/hyva-themes/magento2-hyva-widgets` - on this
project put the overrides in the child theme (or a `vendor/<vendor>/*` module that
declares them), since there is no `app/code`.

<https://docs.hyva.io/hyva-widgets/how-to-use.html>

## Widget type: Hyvä Banner Widget

**Content options**

- Banner image - **not resized on the frontend**; watch file sizes.
- Banner image width / Banner image height - original dimensions, so the browser can
  determine the aspect ratio early.
- Banner title.
- Banner text - a paragraph of plain text.
- Banner button label, Banner button url.
- Banner content text alignment - left / center / right (default left).
- Content text color.
- Content container background.
- Container - apply the theme container to the widget content; for a different size,
  add a custom class in the theme's `tailwind.config.js`.
- Banner inner content container - container for the *inner* content, used together
  with the outer container removed to get a full-width background with contained
  content; uses the theme's native container sizes.

**Banner styles options**

- Banner layout - `Full width` (edge to edge), `Half left caption` (contained 50/50,
  content left), `Half right caption` (contained 50/50, content right).
- Shading - Yes/No; applies a transparent shading over the image for contrast.
- Shading color - colour picker, only applied when Shading is "Yes".

**Animations**

- Banner fade animations - 10 options; the banner animates in when the visitor scrolls
  half the element into view and animates out when scrolled out of the viewport.
  Powered by Alpine's `x-intersect` plugin, so **Hyvä 1.1.10+ only**.

**Spacing**

- Hyvä banner margin (Tailwind classes) - styling applied to the main element, e.g.
  `mt-8 mb-8 mr-4 ml-4`; other Tailwind classes such as `card rounded shadow` are also
  accepted.

<https://docs.hyva.io/hyva-widgets/widget-types/hyva-banner-widget.html>

## Widget type: Hyvä Category Products

**Content options**

- Widget title.
- Content / WYSIWYG editor - visual editing of headings, font sizes etc.; also takes
  pasted Tailwind UI / tailwindcomponents markup. Hide the editor when pasting HTML,
  show it again to use the WYSIWYG interface.
- Container - container class applied to the widget content, using the theme container
  size; override the container definition in the theme's `tailwind.config.js` for a
  different size.
- Category container background - colour picker for the widget background.
- Hyvä content padding - inside spacing using native Tailwind padding classes.

**Category product list options**

- Category select - dropdown of all store categories with name and ID; the selected
  category's products are rendered.
- Number of Products to display.

**Widget type**

- Display type - `Hyvä Slider`, `Splide.js Slider` or `Grid`.

**Animations** - Content fade animations, 10 options, same `x-intersect` mechanism and
same Hyvä 1.1.10 requirement.

**Spacing**

- Hyva content padding - e.g. `pt-8 pb-8 pl-4 pr-4` or `py-6 px-8`; multiple entries
  allowed per Tailwind conventions.
- Hyva content margin - e.g. `mt-8 mb-8 mr-4 ml-4`.

Products come from the `CategoryProducts` class in the module's `ViewModel` directory -
the extension point when the product set needs different rules.

<https://docs.hyva.io/hyva-widgets/widget-types/hyva-category-products.html>

## Widget type: Hyvä Content Widget

**Content**

- Content / WYSIWYG editor - as above; supports pasted Tailwind UI / free
  tailwindcomponents markup. Hide the editor to paste HTML, show it for WYSIWYG.
- Container - width customisable by overriding the container in the theme's
  `tailwind.config.js`.

**Animations**

- Content fade animations - 10 options, `x-intersect`, Hyvä 1.1.10+.
- Content container background - colour picker for the widget background.

**Spacing**

- Hyvä content padding - e.g. `pt-8 pb-8 pl-4 pr-4` or `py-6 px-8`.
- Hyvä content margin - e.g. `mt-8 mb-8 mr-4 ml-4`.

**Text font color**

- Colour picker; **only effective when using the WYSIWYG interface**, not when pasting
  raw HTML. Available colours can be changed in the HTML using Tailwind colour classes.

<https://docs.hyva.io/hyva-widgets/widget-types/hyva-content-widget.html>

## Widget type: Hyvä Multi Field Widget

Repeatable "steps" - the widget to reach for when the client needs to maintain a list
of icon/image + title + text + link blocks.

**Content fields**

1. Widget title - text field, output as the heading at the top of the widget.
2. Multi-field data - textarea, output below the title as an explanatory section.
3. Display type - `Hyvä Slider`, `Splide.js Slider` or `Grid`.
4. Steps - reusable elements, each containing:
   - Image - image uploader.
   - Title - text field.
   - Description - textarea.
   - Button text - creates a button.
   - Button url - internal (`/products`) or external (`https://hyva.io`).
   - Action - admin button deleting the current step; **save the page afterwards** for
     the removal to apply.

**Animations** - Multi field fade animations, 10 options, `x-intersect`, Hyvä 1.1.10+.

**Spacing**

- Hyvä multifield padding - maps directly to Tailwind padding classes, e.g.
  `pt-8 pb-8 pl-4 pr-4` or `py-6 px-8`; multiple entries allowed.
- Hyvä multifield margin - e.g. `mt-8 mb-8 mr-4 ml-4`.

<https://docs.hyva.io/hyva-widgets/widget-types/hyva-multi-field-widget.html>

## Background

Goran Horvat (Bemeir) presents the introduction video covering the history of widgets
versus PageBuilder, why some agencies prefer widgets for content, the Hyvä Widgets
feature set, and how to implement and customise them.

<https://docs.hyva.io/hyva-widgets/introduction-video.html>
