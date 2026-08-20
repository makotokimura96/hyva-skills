# Component recipes and FAQ index

Hands-on recipes from the Hyvä UI FAQs. Topics already covered in full in
`ui-library.md` are only cross-referenced here, not repeated:

| Topic | Where |
|---|---|
| Composer repository / packagist.com + gitlab.hyva.io auth | `ui-library.md` -> Installation (the Hyvä UI docs simply defer to the Hyvä Theme FAQ "Configuring the Hyvä composer repository") <https://docs.hyva.io/hyva-ui-library/faqs/configuring-packagist-and-gitlab.html> |
| Component badges (`License`, `Figma`, `wysiwyg_support`, `wysiwyg_only`, `Hyvä CMS`) | `ui-library.md` -> Component badges <https://docs.hyva.io/hyva-ui-library/faqs/component-badges.html> |
| CSS variables + Tailwind tokens | `ui-library.md` -> CSS variables and Tailwind tokens <https://docs.hyva.io/hyva-ui-library/faqs/css-variables.html> |
| Translations (`i18n/en-US.csv`, 2.4.0+) | `ui-library.md` -> Translations <https://docs.hyva.io/hyva-ui-library/faqs/how-to-add-translations.html> |
| Upgrading copied components | `ui-library.md` -> Upgrading copied components <https://docs.hyva.io/hyva-ui-library/faqs/how-to-upgrade.html> |
| UI Plugins layout and Alpine vs vanilla naming | `ui-library.md` -> UI Plugins <https://docs.hyva.io/hyva-ui-library/ui-plugins.html> |
| Desktop and mobile menu variants | `ui-library.md` -> Menus <https://docs.hyva.io/hyva-ui-library/menus.html> |
| Contributing / suggesting a component | `ui-library.md` -> Figma design system <https://docs.hyva.io/hyva-ui-library/faqs/how-can-i-contribute.html> |
| Product gallery versions and `etc/view.xml` options | `product-gallery.md` |

## Recipe: accessible CSS sliders

CSS sliders are the performant, progressive way to build carousels without leaning on
JavaScript, using **CSS Scroll Snap points** for smooth snap-to-item scrolling.

Core structure - a container with `overflow-x-auto` and `snap-x`, children with
`snap-start`:

```html
<div class="flex snap-x scroll-smooth overflow-x-auto">
    <div class="w-96 snap-start shrink-0">Slide 1</div>
    <div class="w-96 snap-start shrink-0">Slide 2</div>
    <div class="w-96 snap-start shrink-0">Slide 3</div>
</div>
```

For accessibility, add:

1. **Semantic wrapping** - a `<section>` marking the slider as a distinct content
   region, with a descriptive `aria-label` and `aria-roledescription="carousel"`.
2. **Slide roles** - `role="group"` on slide containers for general content, or
   `role="tabpanel"` when used with a pager.
3. **Keyboard navigation** - `tabindex="0"` on the scrolling container if the slides
   themselves contain no interactive elements.

```html
<section aria-label="Lorum Ipsum" aria-roledescription="carousel">
    <div class="flex snap-x scroll-smooth overflow-x-auto" tabindex="0">
        <div role="group" class="w-96 snap-start shrink-0">Slide 1</div>
        <div role="group" class="w-96 snap-start shrink-0">Slide 2</div>
        <div role="group" class="w-96 snap-start shrink-0">Slide 3</div>
    </div>
</section>
```

<https://docs.hyva.io/hyva-ui-library/faqs/how-to-build-css-sliders.html>

## Recipe: previous/next buttons with the Snap Slider plugin

The **Snap Slider** Alpine plugin adds previous/next navigation to a CSS slider. Since
Hyvä UI **2.7.0** it is no longer a Hyvä UI plugin - `x-snap-slider` is **part of the
Hyvä default theme module from version 1.4** (same for `x-htmldialog`). Full options,
including pager dots, are in the Hyvä Themes plugin docs
(`working-with-alpinejs/alpine-plugins/x-snap-slider.html`).

Wiring:

1. Initialise it on the `<section>` with `x-data` and `x-snap-slider`.
2. Mark the scrolling container with `data-track`.
3. Add `<button>` elements carrying `data-prev` / `data-next`, each with an
   `aria-label`.

```html
<section
    x-data
    x-snap-slider
    aria-label="Lorum Ipsum"
    aria-roledescription="carousel"
>
    <div class="flex gap-2 justify-between items-center mb-2">
        <h3 class="text-lg font-medium">Explore Lorum Ipsum</h3>
        <div class="flex gap-2">
            <button class="btn" aria-label="Previous Image" data-prev hidden>Previous</button>
            <button class="btn" aria-label="Next Image" data-next hidden>Next</button>
        </div>
    </div>
    <div
        data-track
        class="flex snap-x scroll-smooth overflow-x-auto"
        aria-live="polite"
        tabindex="0"
    >
        <div role="group" class="w-96 snap-start shrink-0">Image 1</div>
        <div role="group" class="w-96 snap-start shrink-0">Image 2</div>
        <div role="group" class="w-96 snap-start shrink-0">Image 3</div>
    </div>
</section>
```

The plugin wires up the button behaviour automatically (note the `hidden` attributes -
it reveals the buttons only when scrolling is actually possible).

Related components that already use this approach: **Slider A/B/C**, **Categories A/B**
(CSS slider layout on mobile with an option to keep the grid), and **Footer C** (USP
carousel on mobile).

<https://docs.hyva.io/hyva-ui-library/faqs/how-to-build-css-sliders.html>
<https://docs.hyva.io/hyva-ui-library/ui-plugins.html>
<https://docs.hyva.io/hyva-ui-library/changelog.html>
