# Hyvä UI Product Gallery

Part of the commercially licensed Hyvä UI Library (see `ui-library.md`), so the
galleries are copy-into-your-theme components, not a module you keep installed.

The Hyvä UI Product Galleries **extend or completely replace** the default Hyvä theme
gallery, adding customization options configured through `etc/view.xml`. They exist to
improve UX and fix accessibility (A11Y) issues, and in doing so they change how some
gallery features behave compared to the Magento 2 Luma Fotorama gallery - expect
differences when migrating.

Configure the *default* Hyvä theme gallery first (Hyvä Themes docs
"Product Images and Gallery") before reaching for a Hyvä UI version.

> **Deprecation notice in the docs:** the current galleries are built on **Hyvä Theme
> 1.4**. The next Hyvä UI release will introduce a brand-new gallery built on the
> **Hyvä Theme 1.5 PHP rendering approach**, dropping JavaScript-driven layouts in
> favour of modern CSS grid and native View Transitions - less JavaScript, smoother
> animations, leaner implementation. Weigh that before investing heavily in
> customising a current gallery version.

<https://docs.hyva.io/hyva-ui-library/product-gallery.html>

## Gallery versions

- **A - Basis** - adds **vertical thumbnails** while keeping the core functionality of
  the default Hyvä theme gallery.
- **B - Fancy** - a complete rebuild of the default Hyvä theme gallery. Looks much
  like A but adds extensive `etc/view.xml` customization; the fullscreen dialog can be
  enabled/disabled and the magnifier switched on.
- **C - Grid** - for image-heavy stores: lays images and videos out in a grid so
  several media elements are visible at once (the main difference from B).
- **D - Splide** - similar to B but **without thumbnails**, using
  [SplideJS](https://splidejs.com/) for smooth transitions and a minimalist design.

## `etc/view.xml` configuration

All options live in a `<var name="gallery">` block in the theme's `etc/view.xml`.
**Not every version supports every option** - always check the `README.md` that ships
with the chosen gallery, and confirm your Hyvä UI Library version is new enough
(features are sometimes introduced in later releases).

```xml
<!-- app/design/frontend/{Vendor}/{theme}/etc/view.xml -->
<var name="gallery">
    <var name="loop">false</var>            <!-- Gallery navigation loop (true/false) -->
    <var name="caption">false</var>         <!-- Display alt text as image title (true/false) -->
    <var name="allowfullscreen">true</var>  <!-- Turn on/off fullscreen (true/false) -->
    <var name="navdir">horizontal</var>     <!-- Thumbnail direction (horizontal/vertical) -->
    <var name="navarrows">false</var>       <!-- Thumbnail arrows (true/false) -->

    <!-- Contains Hyvä-only options -->
    <var name="nav">thumbs</var>            <!-- Navigation style (false/thumbs/dots/counter) -->
    <var name="arrows">false</var>          <!-- Gallery arrows (start/end/true/false) -->

    <!-- Hyvä-only options -->
    <var name="fullscreenicon">false</var>  <!-- Icon for allowfullscreen (true/false) -->
    <var name="navoverflow">false</var>     <!-- Overflow style (true/false) -->
    <var name="autoplay">false</var>        <!-- Autoplay for videos (true/false) -->
    <var name="magnifier">
        <var name="enable">false</var>      <!-- Turn on/off magnifier (true/false) -->
        <var name="zoom">80</var>           <!-- Magnifier zoom level (integer) -->
        <var name="fullscreen">true</var>   <!-- Magnifier while fullscreen (true/false) -->
        <var name="trigger">click</var>     <!-- How to show the magnifier (hover/click) -->
    </var>
</var>
```

When the theme is a child of the Hyvä default theme the block goes in
that child theme's `etc/view.xml`; rebuild Tailwind with `make build` after copying a
gallery component in.

## Options that behave unexpectedly

**Magnifier** (`<var name="magnifier">`) - zooms into a product image on hover or
click. People expect Luma behaviour, but the Hyvä UI implementation is deliberately
**non-touch devices only**; on touch devices the native pinch-to-zoom gesture is the
recommended experience. Reasons given: (1) performance - touch magnification needs
extra JavaScript to avoid clashing with native touch interactions like swiping,
adding complexity and page weight for little gain; (2) conflict prevention - custom
zoom gestures interfere with native gestures such as swiping.

**Autoplay** (`autoplay`) - plays **every** video in the gallery, not just the first,
and skips the video preview, playing the active video automatically.
- **Not available in Gallery C**, because that version displays all items at once.
- Performance warning: video data loads as soon as a video becomes the active gallery
  item, so `autoplay` can slow the page down, especially when the **first** gallery
  item is a video (that data then loads on page load).

**Captions** (`caption`) - displays the image's `alt` text as a title. Add meaningful
alt text to product images first: a caption will **not** display when the alt text is
missing or identical to the product name.

**Navigation dots** (`<var name="nav">dots</var>`) - a compact alternative to
thumbnails, **exclusive to Gallery D (Splide)**. Dots are hidden automatically on
touch devices for accessibility, because the default touch target is too small to tap
reliably. To keep dots on touch devices, change how SplideJS renders them - see the
`README.md` shipped with Gallery D for its options.

<https://docs.hyva.io/hyva-ui-library/product-gallery.html>

## Gallery-related changelog notes

- 2.7.0 - proper escaping added to **Gallery B** (community contribution).
- 2.6.1 - **Gallery B** fixed: correct initial state when the starting image is not the
  first in the gallery.
- 2.4.0 - **Gallery B** magnifier toggle button no longer visible on mobile; missing
  `itemprop="image"` fixed in **Gallery B/C/D**.
- 2.3.0 - magnifier support added to **Gallery B/C**; **Gallery C** renamed its `nav`
  option value from `number` to `counter` for consistency; **Gallery C** fullscreen
  close-button contrast fixed.
- 2.2.0 - video preview image support in **Gallery A/B/D** when autoplay is off;
  per-gallery config support for enabling/disabling video autoplay; **Gallery B** shows
  thumbs when there is only one image; **Gallery C** (mobile) stops video playback when
  out of view.
- 2.1.0 - initial release of **Gallery A/B/C** and **Gallery D** (SplideJS).

<https://docs.hyva.io/hyva-ui-library/changelog.html>
