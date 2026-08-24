# Directives

Every directive Alpine v3 core ships. "CSP" column refers to the `@alpinejs/csp` 3.14.3 build
Hyvä ships (dot-path expressions only — see `references/csp-mode.md`).

Most directives require an ancestor (or same-element) `x-data`; the exceptions are `x-init`,
`x-ignore`, `x-cloak` and `x-data` itself.

| Directive | In bundle | CSP status |
|---|---|---|
| `x-data` | yes | ✅ registered component name only, no `()`, no inline object |
| `x-init` | yes | ✅ method reference only |
| `x-text` | yes | ✅ dot path |
| `x-html` | yes | ✅ dot path (works in 3.14.3; upstream doc lists it as unsupported in newer CSP builds) |
| `x-show` | yes | ✅ dot path / getter |
| `x-if` | yes | ✅ dot path / getter, on `<template>` |
| `x-for` | yes | ✅ `item in items` form; **not** `i in 10` |
| `x-bind` / `:` | yes | ✅ dot path / getter; also the object form via a registered `Alpine.bind` |
| `x-on` / `@` | yes | ✅ method reference only, all modifiers OK |
| `x-model` | yes | ✅ dot path, all modifiers OK |
| `x-modelable` | yes | ✅ dot path |
| `x-effect` | yes | ⚠️ method reference only — the "run this expression" use is impossible; prefer `$watch` in `init()` |
| `x-ref` | yes | ✅ plain string |
| `x-transition` | yes | ✅ class strings and modifiers |
| `x-cloak` | yes | ✅ no value |
| `x-ignore` | yes | ✅ no value |
| `x-teleport` | yes | ✅ CSS selector string |
| `x-id` | yes | ⚠️ takes an array literal `['name']` → **breaks under CSP**; use explicit ids from PHP instead |
| `x-defer` | yes (Hyvä plugin) | ✅ string `interact` / `intersect` / `idle` / `eager` |

---

## `x-data`

Defines a chunk of HTML as an Alpine component and provides its reactive data. Properties are
visible to all descendants, including nested `x-data` components; a child property of the same
name shadows the parent's. Data can hold methods and getters; inside the object you must use
`this.`.

```html
<!-- normal Alpine -->
<div x-data="{ open: false, toggle() { this.open = ! this.open }, get isOpen() { return this.open } }">
```

CSP-safe rewrite — the object moves to `Alpine.data()` and `x-data` names it:

```html
<div x-data="dropdown">
```

```js
Alpine.data('dropdown', () => ({
    open: false,
    get isOpen() { return this.open },
    toggle() { this.open = ! this.open },
}))
```

`x-data` with no value ("data-less Alpine") is valid and useful when you only need directives:
`<div x-data>`. Passing initial parameters (`x-data="dropdown(true)"`) is **not** CSP-safe.
<https://alpinejs.dev/directives/data> <https://alpinejs.dev/essentials/state>

## `x-init`

Runs when Alpine begins initializing the element. Works on any element, inside or outside an
`x-data` block. If the data object has an `init()` method it is called automatically, **before**
the `x-init` directive.

```html
<!-- ❌ --> <div x-init="posts = await (await fetch('/posts')).json()">
<!-- ✅ --> <div x-data="postList" x-init="load">
```

```js
Alpine.data('postList', () => ({
    posts: [],
    async load() { this.posts = await (await fetch('/posts')).json() },
}))
```

Prefer the automatic `init()` method over `x-init` in Hyvä templates — fewer attributes, no CSP
risk. <https://alpinejs.dev/directives/init>

## `x-text` / `x-html`

Set `textContent` / `innerHTML` from the expression.

```html
<strong x-text="username"></strong>
<span x-html="richLabel"></span>
```

`x-text="1 + 2"` or `x-text="count * 2"` → CSP violation; use a getter. `x-html` only ever gets
trusted content — dynamically rendering third-party HTML is a straight XSS route, and in Magento
that means escaping server-side (`$escaper->escapeHtml($value, ['br'])`) before it reaches the
component.
<https://alpinejs.dev/directives/text> <https://alpinejs.dev/directives/html>

## `x-show`

Toggles `display: none` inline. Modifier `.important` sets `display: none !important` for when a
stylesheet rule with `!important` wins over Alpine's inline style.

```html
<div x-show="open" x-cloak>…</div>
<div x-show.important="open">…</div>
```

Pair with `x-cloak` whenever the initial state is hidden, to avoid a flash of content.
Combine with `x-transition` (not with `x-if`). <https://alpinejs.dev/directives/show>

## `x-if`

Adds/removes the element instead of hiding it. **Must** be on a `<template>` containing exactly
one root element. Does **not** support `x-transition`.

```html
<template x-if="open">
    <div>Contents…</div>
</template>
```

<https://alpinejs.dev/directives/if>

## `x-for`

Must be on a `<template>` with a single root element.

Forms: `item in items`, `(item, index) in items`, `(value, index) in someObject` for objects,
and `i in 10` for a plain range — **the range form breaks under CSP** because `10` is evaluated
as a property lookup; keep an array in state instead.

```html
<template x-for="color in colors" :key="color.id">
    <li x-text="color.label"></li>
</template>
```

Always set `:key` when items can be added, removed or reordered, otherwise Alpine mis-tracks the
nodes. `:key="index"` is legal and `index` is available inside the loop.
<https://alpinejs.dev/directives/for>

## `x-bind` / `:`

Sets attributes from expressions. `:attr` is the shorthand.

```html
<input type="text" :placeholder="placeholderText">
```

`class` is special-cased: Alpine **preserves** existing classes on the element rather than
overwriting them, and additionally accepts an object where keys are classes and values booleans.
Object syntax does *not* preserve pre-existing classes, which is the only way to have a class
present before Alpine loads and still let Alpine remove it. `style` also accepts an object form.

```html
<!-- ❌ ternary / object literal in the attribute -->
<div :class="open ? '' : 'hidden'">
<div :class="{ hidden: ! open }">
<div :style="{ color: 'red' }">

<!-- ✅ getters returning the string / object -->
<div :class="panelClass">
<div :style="panelStyle">
```

```js
Alpine.data('panel', () => ({
    open: false,
    get panelClass() { return { hidden: ! this.open } },
    get panelStyle() { return { color: this.open ? 'red' : 'gray' } },
}))
```

`x-bind` with **no** attribute name binds a whole object of directives and attributes at once —
values are plain strings, or callbacks for dynamic Alpine directives. This is CSP-safe because
the JavaScript lives in the object, not the attribute:

```html
<div x-data="dropdown">
    <button x-bind="trigger">Open Dropdown</button>
    <span x-bind="dialogue">Dropdown Contents</span>
</div>
```

```js
Alpine.data('dropdown', () => ({
    open: false,
    trigger: {
        ['x-ref']: 'trigger',
        ['@click']() { this.open = true },
    },
    dialogue: {
        ['x-show']() { return this.open },
        ['@click.outside']() { this.open = false },
    },
}))
```

When the bound directive is `x-for`, return the expression string: `['x-for']() { return 'item in items' }`.
<https://alpinejs.dev/directives/bind>

## `x-on` / `@`

Listens for any DOM event, including custom ones. Event names must be lower case (HTML
attributes are case-insensitive) — use `.camel` or `x-bind` for camelCase events. Methods
referenced without parentheses receive the event object as their first argument, which is the
CSP-safe way to get at the event.

```html
<!-- ❌ --> <button @click="open = ! open">
<!-- ✅ --> <button @click="toggle">
<!-- ✅ --> <input @keyup.shift.enter="submit">
<!-- ✅ --> <div @click.outside="close" @keydown.window.escape="close">
```

```js
toggle(event) { /* event is passed automatically */ this.open = ! this.open }
```

`$event` is available inside a listener scope, so `@click="handle"` plus `$event.detail.value`
style dot paths work; anything with parentheses does not.

**Key modifiers** (any `KeyboardEvent.key` value in kebab-case works):
`.shift` `.enter` `.space` `.ctrl` `.cmd` `.meta` `.alt` `.up` `.down` `.left` `.right`
`.escape` `.tab` `.caps-lock` `.equal` `.period` `.comma` `.slash`, e.g. `.page-down`.

**Mouse modifiers** `.shift` `.ctrl` `.cmd` `.meta` `.alt` work on `click`, `auxclick`,
`context`, `dblclick`, `mouseover`, `mousemove`, `mouseenter`, `mouseleave`, `mouseout`,
`mouseup`, `mousedown`.

**Behaviour modifiers:**

| Modifier | Effect |
|---|---|
| `.prevent` | `event.preventDefault()` |
| `.stop` | `event.stopPropagation()` |
| `.outside` | fire only on clicks outside the element; only evaluated while the element is visible |
| `.window` | register the listener on `window` |
| `.document` | register the listener on `document` |
| `.once` | handle at most once |
| `.debounce` / `.debounce.500ms` | debounce, default 250ms |
| `.throttle` / `.throttle.750ms` | throttle, default 250ms |
| `.self` | only when the event originated on this element, not a child |
| `.camel` | `custom-event` → listens for `customEvent` |
| `.dot` | `custom-event.dot` → listens for `custom.event` |
| `.passive` | passive listener (important for touch/wheel scroll performance) |
| `.passive.false` | make touch/wheel events cancelable again so `preventDefault` works |
| `.capture` | listen in the capturing phase |

All modifiers are CSP-safe. <https://alpinejs.dev/directives/on> <https://alpinejs.dev/essentials/events>

## `x-model`

Two-way binds an input's value to a data property. Supported elements: `<input type="text">`,
`<textarea>`, `<input type="checkbox">` (boolean for a single box, array when several share a
property), `<input type="radio">`, `<select>` (incl. `multiple`), `<input type="range">`.

```html
<input type="text" x-model="search">
<input type="text" x-model.debounce.500ms="search">
```

**Modifiers:** `.lazy` (sync on blur when changed), `.change` (same as `.lazy`, native change),
`.blur` (sync on blur regardless of change), `.enter` (sync on Enter — does **not**
`preventDefault`, so a form still submits), combinable (`x-model.blur.enter="search"`),
`.number` (cast to number), `.boolean` (cast to boolean; accepts `1`/`0` and `true`/`false`),
`.debounce[.Nms]`, `.throttle[.Nms]` (both default 250ms), `.fill` (use the element's `value`
attribute to populate an empty bound property).

Programmatic access: an `x-model`ed element exposes `el._x_model.get()` and
`el._x_model.set(value)` — usable from component JavaScript, e.g.
`this.$refs.div._x_model.set('x')`. In an attribute, `$refs.div._x_model.get` is a legal dot
path but `set('x')` is not. <https://alpinejs.dev/directives/model>

## `x-modelable`

Exposes an inner Alpine property as the target of an outer `x-model`, so a component can behave
like a native input.

```html
<div x-data="outer">
    <div x-data="inner" x-modelable="count" x-model="number">
        <button @click="increment">Increment</button>
    </div>
    Number: <span x-text="number"></span>
</div>
```

Both attribute values are bare property names, so this is CSP-safe.
<https://alpinejs.dev/directives/modelable>

## `x-effect`

Re-runs its expression whenever any Alpine data it touched changes; same mechanism as `$watch`
but with automatic dependency detection, and it runs immediately (`$watch` is lazy and gives you
the old value too).

Under CSP the value must be a method reference, which makes `x-effect` far less useful — Alpine
would only ever call the method and track the properties that method reads. Prefer `$watch`
inside `init()`. <https://alpinejs.dev/directives/effect> <https://alpinejs.dev/essentials/lifecycle>

## `x-ref`

Names an element for retrieval via `$refs` — a scoped replacement for `getElementById` /
`querySelector`. The value is a static string; **binding it dynamically (`:x-ref="item.name"`)
does not work in v3** — `$refs` would contain the literal string.

```html
<button @click="removeText">Remove Text</button>
<span x-ref="text">Hello</span>
```

<https://alpinejs.dev/directives/ref> <https://alpinejs.dev/magics/refs>

## `x-transition`

Only works with `x-show`, never `x-if`. Bare `x-transition` applies default fade + scale.

**Helper modifiers:** `.duration.500ms` (defaults: 150ms enter, 75ms leave), `.delay.50ms`,
`.opacity`, `.scale`, `.scale.80`, `.origin.top` (`top`/`bottom`/`left`/`right`, combinable as
`.origin.top.right`). Enter and leave configurable separately via
`x-transition:enter.duration.500ms` / `x-transition:leave.duration.400ms`.

**Class form** (Tailwind, what Hyvä uses):

| Directive | Applied |
|---|---|
| `x-transition:enter` | during the whole entering phase |
| `x-transition:enter-start` | before insertion, removed one frame after |
| `x-transition:enter-end` | one frame after insertion, removed when the transition finishes |
| `x-transition:leave` | during the whole leaving phase |
| `x-transition:leave-start` | immediately on leave, removed after one frame |
| `x-transition:leave-end` | one frame after leave starts, removed when finished |

```html
<div x-show="open"
     x-transition:enter="transition ease-out duration-300"
     x-transition:enter-start="opacity-0 scale-90"
     x-transition:enter-end="opacity-100 scale-100"
     x-transition:leave="transition ease-in duration-300"
     x-transition:leave-start="opacity-100 scale-100"
     x-transition:leave-end="opacity-0 scale-90">…</div>
```

Fully CSP-safe. Remember these classes must survive Tailwind's purge — they are in the markup,
so rebuild Tailwind (`npm run build`, or `npm run watch` while iterating) after adding them.
<https://alpinejs.dev/directives/transition> <https://alpinejs.dev/essentials/templating>

## `x-cloak`

Hides the element until Alpine has initialized, killing the "blip". Requires the global CSS
`[x-cloak] { display: none !important; }` (Hyvä ships it). Works for elements whose content is
set by `x-text` too, not just `x-show`. An alternative trick is wrapping the markup in
`<template x-if="true">`, since browsers hide `<template>` natively.
<https://alpinejs.dev/directives/cloak>

## `x-ignore`

Stops Alpine crawling and initializing that subtree.

```html
<div x-data="{ label: 'From Alpine' }">
    <div x-ignore><span x-text="label"></span></div>
</div>
```

<https://alpinejs.dev/directives/ignore>

## `x-teleport`

On a `<template>`, appends the element to another place in the DOM — anything
`document.querySelector` accepts (`body`, `.my-class`, `#my-id`). Useful for modals that must
escape a stacking context. Teleported content keeps normal Alpine scope, `$refs`, `$root`.
Native events bubble from the real DOM position, but listeners registered on the
`<template x-teleport…>` element itself are "forwarded": Alpine stops propagation past the
teleported element and re-dispatches a copy from the template. Nesting teleports works and
renders the results as siblings.

```html
<div x-data="modal">
    <button @click="toggle">Toggle Modal</button>
    <template x-teleport="body" @click="close">
        <div x-show="open">Modal contents…</div>
    </template>
</div>
```

<https://alpinejs.dev/directives/teleport>

## `x-id`

Declares an id scope for `$id()` so repeated components get unique, matching ids for
`<label for>` / `<input id>` pairs. Scopes nest.

```html
<div x-id="['text-input']">
    <label :for="$id('text-input')">Username</label>
    <input type="text" :id="$id('text-input')">
</div>
```

**Both halves break under CSP:** `['text-input']` is an array literal and `$id('text-input')` is
a call. In a Hyvä template just render unique ids from PHP (e.g. from `$block->getNameInLayout()`
or an incrementing counter) and bind them as plain data properties. Keep `$id` in mind only for
non-CSP builds. <https://alpinejs.dev/directives/id> <https://alpinejs.dev/magics/id>
