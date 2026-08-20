# Official plugins

**None of these are in the Alpine bundle Hyvä ships.** `alpine3-csp.js` contains
`packages/alpinejs` + `packages/csp` only — no plugin directives or magics are registered, so
`x-intersect`, `x-collapse`, `x-trap`, `$persist`, `x-mask`, `x-anchor`, `x-resize`, `x-sort` and
`Alpine.morph` simply do nothing (an unknown `x-*` attribute is inert, which is why these fail
silently). Before using any of them you must add the plugin to the theme's Alpine bundle.

Two further CSP caveats apply to every plugin:

1. **Plugin CDN builds are the standard, non-CSP builds.** Loading one adds no `unsafe-eval` by
   itself (plugins do not evaluate expressions themselves), but every plugin *expression* is
   still evaluated by Alpine's evaluator — i.e. under CSP a plugin directive's value must also
   be a bare dot path.
2. Plugin scripts must be included **before** Alpine's core script, and any inline
   registration needs `$hyvaCsp->registerInlineScript()`.

Install shape is identical for all of them:

```html
<!-- Alpine Plugins -->
<script defer src="https://cdn.jsdelivr.net/npm/@alpinejs/persist@3.x.x/dist/cdn.min.js"></script>
<!-- Alpine Core -->
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
```

```bash
npm install @alpinejs/persist
```

```js
import Alpine from 'alpinejs'
import persist from '@alpinejs/persist'

Alpine.plugin(persist)
```

Bundle it into the Hyvä theme rather than adding a CDN tag — a remote
`script-src` is itself a CSP change.

---

## Persist — `$persist`

Persists state across page loads in `localStorage`, keyed by the property name prefixed with
`_x_`. Good for search filters, active tabs, dismissed banners — anything a user would be annoyed
to lose on reload.

```html
<div x-data="{ count: $persist(0) }">
```

Modifiers: `.as('other-count')` for a custom key (needed when several components use the same
property name), `.using(sessionStorage)` or `.using(customStorage)` for a different store — any
object exposing `getItem`/`setItem`, e.g. a cookie-backed one. Works with primitives, arrays and
objects, but changing a persisted value's *type* requires clearing storage or renaming the key.

With `Alpine.data` the factory must be a **standard function**, not an arrow function, so Alpine
can bind `this`:

```js
Alpine.data('dropdown', function () {
    return { open: this.$persist(false) }
})
```

`Alpine.$persist` is also exposed globally, for use outside `x-data` — e.g. inside a store:
`Alpine.store('darkMode', { on: Alpine.$persist(true).as('darkMode_on') })`.

**CSP:** `$persist(0)` in an attribute is a function call → ✅ only from inside `Alpine.data()` /
`Alpine.store()`, ❌ in markup. **Worth it** when losing state on reload is a real UX problem;
otherwise a cookie via `hyva.setCookie` is fewer moving parts.
<https://alpinejs.dev/plugins/persist>

## Intersect — `x-intersect`

`IntersectionObserver` wrapper: run an expression when an element enters the viewport. Lazy
loading, enter animations, infinite scroll, view logging.

```html
<div x-data="{ shown: false }" x-intersect="shown = true">
```

Variants `x-intersect:enter` (alias of the default) and `x-intersect:leave` (whole element out of
view; `x-intersect:leave.full` for partially out). Modifiers: `.once`, `.half` (threshold > 0.5),
`.full` (> 0.99), `.threshold.50` (0–100), `.margin` (tweaks `rootMargin`, CSS-margin style, `px`
/ `%` / bare number), `.parent` (observe against the parent element rather than the viewport —
useful inside scroll containers).

**CSP:** the expression must be a method reference — `x-intersect="load"`, not
`x-intersect="shown = true"`. **Rarely worth adding on Hyvä**, because `x-defer="intersect"`
already covers the main use case (defer component init until visible) with no extra JavaScript.
<https://alpinejs.dev/plugins/intersect>

## Collapse — `x-collapse`

Smooth height animation for show/hide, which Alpine's normal transition system cannot do.
`x-collapse` requires `x-show` on the same element.

```html
<div x-data="{ expanded: false }">
    <button @click="toggle">Toggle Content</button>
    <p x-show="expanded" x-collapse>…</p>
</div>
```

Modifiers: `.duration.1000ms`; `.min.50px` to "cut off" rather than fully hide (collapsed state
keeps that height instead of `0px` + `display: none`).

**CSP:** takes no expression → fully CSP-safe once loaded. **Worth it** for accordions and FAQ
sections where a height animation is the design; a CSS grid-rows/max-height transition in
Tailwind is the lazier alternative. <https://alpinejs.dev/plugins/collapse>

## Focus — `x-trap` and `$focus`

Focus management (formerly the "Trap" plugin; Trap's functionality was absorbed with no breaking
changes). Built on the `tabbable` library.

```html
<div x-data="{ open: false }">
    <button @click="open = true">Open Dialog</button>
    <span x-show="open" x-trap="open">…<button @click="open = false">Close</button></span>
</div>
```

`x-trap` traps focus inside the element while its expression is truthy and returns focus where it
was when it becomes falsy; nesting is handled recursively. Modifiers: `.inert` (sets
`aria-hidden="true"` on everything else while trapped — recommended for dialogs), `.noscroll`
(removes the scrollbar and blocks page scroll), `.noreturn` (don't restore focus), `.noautofocus`
(don't focus the first focusable element).

`$focus` utilities: `focus(el)`, `focusable(el)`, `focusables()`, `focused()`, `lastFocused()`,
`within(el)`, `first()`, `last()`, `next()`, `previous()`, `noscroll()`, `wrap()`, `getFirst()`,
`getLast()`, `getNext()`, `getPrevious()` — chainable, e.g.
`$focus.within($refs.buttons).first()` or `@keydown.right="$focus.wrap().next()"`.

**CSP:** `x-trap="open"` is a dot path ✅; every `$focus` call is a function call, so ❌ in markup
and ✅ from `Alpine.data()` methods via `this.$focus`. **Worth it** for modals and dialogs —
accessibility is not something to hand-roll, and `.inert` + `.noscroll` are exactly the two
things people forget. <https://alpinejs.dev/plugins/focus>

## Mask — `x-mask`

Formats a text input as the user types (phone numbers, cards, dates, money).

```html
<input x-mask="99/99/9999" placeholder="MM/DD/YYYY">
```

Wildcards: `*` any character, `a` alpha only, `9` numeric only. `x-mask:dynamic` computes the
mask per keystroke, receiving the current value as `$input`, and accepts a function reference
that gets `input` as its first parameter. `$money($input, decimalSeparator = '.', thousandsSeparator = ',', precision = 2)`
is a prebuilt dynamic mask for currency amounts.

```html
<input x-mask:dynamic="creditCardMask">
```

**CSP:** literal masks (`x-mask="99/99/9999"`) are plain strings ✅. `x-mask:dynamic` is only
CSP-safe in its **function-reference** form (`x-mask:dynamic="creditCardMask"`); the inline
ternary and `$money($input)` forms are ❌. **Worth it** for checkout/payment inputs where
formatting drives correctness. <https://alpinejs.dev/plugins/mask>

## Morph — `Alpine.morph()`

DOM-diffs a live element against a new HTML string and patches it, preserving browser state
(focus, scroll, input values) and Alpine state inside. The mechanism behind Livewire.

```js
Alpine.morph(el, newHtml, { /* options */ })
```

Options / lifecycle hooks: `updating(el, toEl, childrenOnly, skip)`, `updated(el, toEl)`,
`removing(el, skip)`, `removed(el)`, `adding(el, skip)`, `added(el)`, `key(el)` and
`lookahead` (boolean, default `false`; checks whether an element about to be removed should be
moved to a later sibling instead). Hook parameters: `el` is the real element being patched,
`toEl` a throwaway template element, `childrenOnly()` skips the element but patches children,
`skip()` skips the element and its children.

Add `key="…"` attributes to siblings in a list so reordering moves nodes instead of rewriting
their content. `Alpine.morphBetween(startMarker, endMarker, newHtml, options)` morphs a range
between two marker nodes (typically comments) when there is no single root.

**CSP:** it is a JavaScript API, never an attribute → CSP-safe by construction. **Worth it** only
if you are replacing server-rendered HTML fragments in place; for Hyvä, `hyva.replaceDomElement`
style patterns or just re-rendering an Alpine list from JSON are usually simpler.
<https://alpinejs.dev/plugins/morph>

## Anchor — `x-anchor`

Positions an element relative to another using Floating UI — dropdowns, popovers, tooltips.

```html
<div x-data="{ open: false }">
    <button x-ref="button" @click="toggle">Toggle</button>
    <div x-show="open" x-anchor="$refs.button">Dropdown content</div>
</div>
```

Position modifiers: `.bottom` `.bottom-start` `.bottom-end` `.top` `.top-start` `.top-end`
`.left` `.left-start` `.left-end` `.right` `.right-start` `.right-end`. Others: `.offset.10`
(px), `.noflip` (don't flip when there is no room), `.fixed` (use `position: fixed` so the
element escapes an `overflow: hidden`/`clip`/`auto` container — but a `transform`, `filter`,
`perspective`, `backdrop-filter`, `will-change` or `contain` on an ancestor creates a containing
block and makes `.fixed` behave like `absolute`), `.no-style` (skip Alpine's styling and use the
`$anchor` magic yourself):

```html
<div x-show="open" x-anchor.no-style="$refs.button"
     x-bind:style="{ position: 'absolute', top: $anchor.y+'px', left: $anchor.x+'px' }">
```

Anchoring to an id works too: `x-anchor="document.getElementById('trigger')"`.

**CSP:** `x-anchor="$refs.button"` is a dot path ✅. The `.no-style` style-object binding
(`{ position: … }`) and `document.getElementById('trigger')` are ❌ — use a getter for the style
object, and `x-ref` instead of `getElementById`. **Worth it** when a dropdown must not be clipped
and pure CSS positioning has failed; it pulls in Floating UI, so not for simple absolute
dropdowns. <https://alpinejs.dev/plugins/anchor>

## Resize — `x-resize`

`ResizeObserver` wrapper. The expression runs with `$width` and `$height` magics available.

```html
<div x-data="{ width: 0, height: 0 }" x-resize="width = $width; height = $height">
```

Modifier `.document` observes the whole document instead of the element.

**CSP:** the documented usage is assignments → ❌. Only a method reference works, and `$width` /
`$height` are then unreachable from the method, which makes the plugin close to useless under
CSP — read `this.$el.offsetWidth` in the handler instead, or use CSS container queries.
**Rarely worth it.** <https://alpinejs.dev/plugins/resize>

## Sort — `x-sort`

Drag-to-reorder via SortableJS. Kanban boards, sortable lists, admin ordering UIs.

```html
<ul x-sort="handleSort">
    <li x-sort:item="1">foo</li>
    <li x-sort:item="2">bar</li>
</ul>
```

`x-sort:item` marks the draggables and supplies the key. A handler on `x-sort` runs on every
reorder, receiving `item` and `position` (0-based) as its first two parameters — or, inline,
via the `$item` and `$position` magics. Other features: `x-sort:group="todos"` to drag between
two lists, `.ghost` modifier to leave a ghost of the dragged element, `x-sort:handle` to restrict
dragging to a child element, `x-sort:ignore` to exclude an element from dragging (it stays
interactive — buttons still click), `x-sort:config` to add or override SortableJS options, and a
`sorting` class Alpine puts on `<body>` while dragging (the documented fix for CSS `:hover`
sticking mid-drag: `[body:not(.sorting)_&]:hover:border`).

**CSP:** `x-sort="handleSort"` (function reference) ✅; `x-sort="alert($item + ' - ' + $position)"`
❌; `x-sort:config="{…}"` object literal ❌. **Worth it** only for genuine drag-ordering
requirements — it is a large dependency for a rare storefront need, and it is more at home in an
admin grid.
<https://alpinejs.dev/plugins/sort>

---

## Alpine UI Components — not a plugin

`alpinejs.dev/components` is a **commercial** copy-paste component library (dropdown, modal,
accordion, carousel, tabs, notifications, radio group, toggle, tooltip) plus screencasts and
third-party integration recipes (Chart.js, ApexCharts, Trix, Quill, SimpleMDE, Select2,
Choices.js, Flatpickr, Date Range Picker, FullCalendar, Glide, Splide). The snippets are written
for **standard Alpine** and use inline expressions freely, so **pasting one into a Hyvä template
will produce CSP violations** — every expression has to be lifted into `Alpine.data()` first.

For Hyvä work prefer the Hyvä UI Library (see the `hyva-ui-library` skill), whose components are
written against Hyvä's Alpine and Tailwind conventions.
<https://alpinejs.dev/components>
