# Magics and globals

## Magics available in the Hyvä CSP bundle

Nine magics are registered in `alpine3-csp.js`: `$data` `$dispatch` `$el` `$id` `$nextTick`
`$refs` `$root` `$store` `$watch`. `$event` is not a registered magic but is injected into the
scope of `x-on` listeners, so it is usable too.

Everything else (`$persist`, `$focus`, `$anchor`, `$width`/`$height`, `$item`/`$position`,
`$money`, `$input`) belongs to plugins that are **not bundled** — see `references/plugins.md`.

**The CSP rule applies to magics as well.** A magic used as a *value* is a dot path and works;
a magic *called* with arguments in an attribute does not. So:

| In an attribute | CSP |
|---|---|
| `x-text="$el.dataset.label"` | ✅ dot path |
| `x-show="$store.filters.open"` | ✅ dot path |
| `@click="$store.cart.reload"` | ✅ resolved function is auto-invoked |
| `@click="$store.cart.reload()"` | ❌ parentheses |
| `@click="$dispatch('foo')"` | ❌ → wrap in a method |
| `x-init="$watch('open', …)"` | ❌ → use `init()` |
| `:id="$id('x')"` | ❌ → render ids from PHP |

Inside `Alpine.data()` all magics are reachable through `this.$…` with full JavaScript, which is
where you should use them.

---

## `$el`

The current DOM element (in v3 always the current element, never the component root — that is
`$root`).

```html
<!-- ❌ --> <button @click="$el.innerHTML = 'Hello World!'">
<!-- ✅ --> <button @click="fill">
```

```js
fill() { this.$el.innerHTML = 'Hello World!' }
```

Reading a dot path off `$el` in an attribute is fine: `x-text="$el.dataset.value"`.
<https://alpinejs.dev/magics/el>

## `$refs`

The elements marked with `x-ref` inside the component — a scoped, succinct
`document.querySelector`.

```html
<!-- ❌ --> <button @click="$refs.text.remove()">Remove Text</button>
<!-- ✅ --> <button @click="removeText">Remove Text</button>
<span x-ref="text">Hello</span>
```

```js
removeText() { this.$refs.text.remove() }
```

Limitation: `x-ref` cannot be bound dynamically in v3 (`:x-ref="item.name"` stores the literal
string `'item.name'`), so refs only work for statically created elements — inside `x-for` use the
loop item or an event instead. <https://alpinejs.dev/magics/refs>

## `$store`

Reads global state registered with `Alpine.store()`.

```html
<div x-data :class="darkClass">…</div>
<button x-data @click="$store.darkMode.toggle">Toggle Dark Mode</button>
```

Dot paths into a store are the cleanest CSP-safe cross-component communication Alpine offers:
`x-show="$store.miniCart.open"` works verbatim. Assignment does not
(`@click="$store.darkMode = ! $store.darkMode"` ❌) — put a `toggle()` method on the store and
reference it. <https://alpinejs.dev/magics/store>

## `$watch`

Watches a component property and calls back with the new and previous value. Watches nested
properties by dot notation and watches deeply — but on a deep change the callback receives the
**whole watched property**, not the changed subproperty.

```js
Alpine.data('dropdown', () => ({
    open: false,
    foo: { bar: 'baz' },
    init() {
        this.$watch('open', (value, oldValue) => console.log(value, oldValue));
        this.$watch('foo.bar', value => console.log(value));
    },
}))
```

Requires a callback, so it is **only** usable from JavaScript — never from an attribute under
CSP. Do not mutate a property of the watched object inside its own callback: infinite loop, then
error. <https://alpinejs.dev/magics/watch>

## `$dispatch`

Shorthand for `element.dispatchEvent(new CustomEvent(...))`. Data passed as the second argument
arrives as `event.detail`. A third argument overrides the event options (e.g.
`{bubbles: false}`). The return value tells you whether the event was cancelled.

```js
notify() { this.$dispatch('notify', { message: 'Hello World!' }) }
```

```html
<div x-data="listener" @notify.window="handleNotify">…</div>
```

Events bubble, so **siblings must listen with `.window`** — a `@notify` listener on a sibling
`<span>` never fires for an event dispatched by another child of the same parent. That
`.window` pattern is how independent Alpine components talk to each other, and it is fully
CSP-safe as long as both sides are method references. `$dispatch('input', value)` on a wrapper
element is also how you make a custom component drive an outer `x-model`.
<https://alpinejs.dev/magics/dispatch>

## `$nextTick`

Runs after Alpine has finished its reactive DOM updates — the equivalent of Vue's `mounted` /
React's `useEffect(..., [])` for a single update. Returns a promise, so `await $nextTick()` works
with no argument.

```js
async setTitle() {
    this.title = 'Hello World!';
    await this.$nextTick();
    console.log(this.$el.innerText); // reflects the new title
}
```

<https://alpinejs.dev/magics/nextTick>

## `$root`

The component's root element — the closest ancestor with `x-data`.

```js
readMessage() { return this.$root.dataset.message }
```

<https://alpinejs.dev/magics/root>

## `$data`

The current Alpine data scope as a real object, for handing the whole scope to an external
function. Rarely needed.

```html
<!-- ❌ --> <button @click="sayHello($data)">Say Hello</button>
<!-- ✅ --> <button @click="sayHello">
```

```js
Alpine.data('greeter', () => ({
    greeting: 'Hello', name: 'Caleb',
    sayHello() { window.sayHello(this.$data) },
}))
```

<https://alpinejs.dev/magics/data>

## `$id`

Generates page-unique ids, scoped by the `x-id` directive, so a reusable component can pair
`<label for>` with `<input id>`. `$id('name')` optionally takes a second argument used as a
suffix, for keying ids inside a loop (`:id="$id('list-item', item.id)"` with
`:aria-activedescendant="$id('list-item', activeItem.id)"`).

Both `x-id="['name']"` and `$id('name')` are impossible under CSP (array literal, function call).
In Hyvä templates generate the id server-side instead:

```php
<?php $uid = $escaper->escapeHtmlAttr($block->getNameInLayout()); ?>
<label for="search-<?= $uid ?>"><?= $escaper->escapeHtml(__('Search')) ?></label>
<input id="search-<?= $uid ?>" x-model="search">
```

<https://alpinejs.dev/magics/id>

## `$event`

Inside an `x-on` listener, the native event object. In normal Alpine you would write
`@click="alert($event.target.getAttribute('message'))"`; under CSP put the logic in a method — a
method referenced **without parentheses** receives the event as its first argument, which
replaces `$event` entirely:

```html
<button @click="handleClick" message="Hello World">Say Hi</button>
```

```js
handleClick(event) { console.log(event.target.getAttribute('message')) }
```

Plain dot paths such as `x-text="$event.detail.value"` still resolve.
<https://alpinejs.dev/directives/on> <https://alpinejs.dev/essentials/events>

---

## Globals

Alpine's globals must be registered **after** Alpine is on the page but **before** it
initializes. In Hyvä that always means an `alpine:init` listener in an inline script followed by
`$hyvaCsp->registerInlineScript()`:

```html
<script>
    window.addEventListener('alpine:init', () => {
        Alpine.data('name', factory);
        Alpine.store('name', { /* … */ });
        Alpine.bind('Name', () => ({ /* … */ }));
    }, {once: true})
</script>
<?php $hyvaCsp->registerInlineScript() ?>
```

<https://alpinejs.dev/essentials/lifecycle> <https://alpinejs.dev/advanced/extending>

### `Alpine.data(name, factory)`

Registers a reusable `x-data` context. **This is the mandatory unit of composition under CSP** —
all real JavaScript lives here.

```js
Alpine.data('dropdown', () => ({
    open: false,
    toggle() { this.open = ! this.open },
}))
```

- Reference it as `x-data="dropdown"`. `x-data="dropdown(true)"` passes initial parameters in
  normal Alpine but **breaks under CSP**; bake the values into the factory instead.
- `init()` on the returned object runs automatically before the component renders.
- `destroy()` runs automatically before cleanup — use it to detach anything Alpine does not own
  (timers, third-party handlers). Components inside `x-if` are genuinely destroyed, so this
  matters:

```js
Alpine.data('timer', () => ({
    timer: null,
    counter: 0,
    init() {
        this.timer = setInterval(() => { this.counter++ }, 1000);
    },
    destroy() {
        clearInterval(this.timer);
    },
}))
```

- Magics work through `this` inside the object: `init() { this.$watch('open', …) }`.
- Bundled builds register with `Alpine.data('dropdown', dropdown)` between the import and
  `Alpine.start()`; Hyvä's templates use the `alpine:init` form.

<https://alpinejs.dev/globals/alpine-data>

### `Alpine.store(name, value)`

Global state, readable anywhere via `$store`. A store may be a full object with methods, or a
single primitive value.

```js
Alpine.store('darkMode', {
    init() { this.on = window.matchMedia('(prefers-color-scheme: dark)').matches },
    on: false,
    toggle() { this.on = ! this.on },
})
```

An `init()` method on a store runs right after registration — good for seeding state before
anything renders. Read or mutate a store from plain JavaScript with
`Alpine.store('darkMode').toggle()`, and from markup with dot paths only
(`x-show="$store.darkMode.on"`, `@click="$store.darkMode.toggle"`). Single-value stores are
convenient but need assignment to change, which is not CSP-safe from an attribute — prefer an
object with a mutating method. <https://alpinejs.dev/globals/alpine-store>

### `Alpine.bind(name, factory)`

Registers a reusable `x-bind` object — the same idea as `Alpine.data` but for attributes and
directives instead of state. Very useful under CSP because the callbacks are real JavaScript.

```html
<button x-bind="SomeButton"></button>
```

```js
Alpine.bind('SomeButton', () => ({
    type: 'button',
    '@click'() { this.doSomething() },
    ':disabled'() { return this.shouldDisable },
}))
```

<https://alpinejs.dev/globals/alpine-bind> <https://alpinejs.dev/directives/bind>

### Other globals worth knowing

- `Alpine.reactive(obj)` / `Alpine.effect(fn)` — the reactivity primitives (see
  `references/patterns.md`).
- `Alpine.directive(name, cb)` / `Alpine.magic(name, cb)` / `Alpine.plugin(fn)` — extension
  APIs; a custom directive is often the cleanest way to make complex behaviour CSP-safe, because
  its expression never has to be evaluated.
- `Alpine.start()` — only relevant to bundled builds, and must be called exactly once. Hyvä
  already starts Alpine; **never call it from a template.**

<https://alpinejs.dev/advanced/extending> <https://alpinejs.dev/essentials/installation>
