# Patterns

Recipes for the things Alpine components actually have to do, written CSP-first.

## State

Three scopes, in order of preference:

1. **Local** — `x-data` on the wrapper, properties + getters + methods in `Alpine.data()`.
2. **Inherited** — data is nestable: a child `x-data` component can read a parent's properties,
   and a same-named child property shadows the parent's. Works like JavaScript closures.
3. **Global** — `Alpine.store()`, read via `$store` dot paths from anywhere on the page.

```html
<div x-data="parentPanel">
    <div x-data="childPanel">
        <span x-text="label"></span>   <!-- child's own -->
        <span x-show="open"></span>    <!-- parent's -->
    </div>
</div>
```

Alpine's own first recommendation for re-use in a backend-templated app is to **extract the HTML
into a template partial**, not to invent an abstraction — in Magento that means a `.phtml` you
include, with `Alpine.data()` registered once. <https://alpinejs.dev/essentials/state>
<https://alpinejs.dev/directives/data>

**Computed values are getters.** This is the single most important CSP pattern: anything that
would have been an inline expression becomes a getter. Getters are re-evaluated on access (not
cached like Vue's computed), and reactivity works because Alpine tracks the properties the getter
reads.

```js
Alpine.data('productList', () => ({
    search: '',
    items: [],
    get filteredItems() {
        return this.items.filter(i => i.startsWith(this.search));
    },
    get hasResults() {
        return this.filteredItems.length > 0;
    },
    get emptyClass() {
        return this.hasResults ? 'hidden' : 'block text-gray-500';
    },
}))
```

```html
<div x-data="productList">
    <input x-model.debounce="search">
    <template x-for="item in filteredItems" :key="item">
        <li x-text="item"></li>
    </template>
    <p :class="emptyClass"><?= $escaper->escapeHtml(__('No results')) ?></p>
</div>
```

Inside the data object always use `this.` — you are in a plain JavaScript object, not in
directive scope. <https://alpinejs.dev/start-here>

## Events

Within a component, methods are enough. Between components, dispatch on `window`:

```js
// producer
Alpine.data('addToCart', () => ({
    async submit() {
        await fetch(this.endpoint, { method: 'POST' });
        this.$dispatch('cart-updated', { count: 1 });
    },
}))

// consumer
Alpine.data('miniCart', () => ({
    count: 0,
    onCartUpdated(event) { this.count = event.detail.count },
}))
```

```html
<div x-data="miniCart" @cart-updated.window="onCartUpdated">
    <span x-text="count"></span>
</div>
```

Why `.window`: dispatched events bubble to the common ancestor, so a listener on a **sibling**
never fires. `<div x-data><span @notify="…"></span><button @click="notify"></button></div>` does
not work; `@notify.window` does. Both halves here are method references, so it is CSP-safe.

Other event facts worth having: `$dispatch`'s return value tells you if a handler cancelled the
event; a third argument overrides options (`{bubbles: false}`); dispatching an `input` event from
inside a wrapper lets a custom component be driven by an outer `x-model`.
<https://alpinejs.dev/essentials/events> <https://alpinejs.dev/magics/dispatch>

For Magento-side events, Hyvä's own `window` events (`private-content-loaded`,
`user-allowed-save-cookie`, …) are consumed with exactly the same `@event.window="method"` shape.

## Lifecycle

| Hook | When | CSP |
|---|---|---|
| `alpine:init` (window/document event) | Alpine loaded, **before** it initializes the page | ✅ the only place to register `data`/`store`/`bind`/`directive`/`magic` |
| `init()` on the data object | before the component renders | ✅ preferred |
| `x-init="method"` | when Alpine initializes that element; runs **after** the data object's `init()` | ✅ method reference only |
| `destroy()` on the data object | before the component is cleaned up | ✅ |
| `$nextTick` | after Alpine's reactive DOM updates | ✅ from JS |
| `alpine:initialized` (event) | after Alpine finished initializing | ✅ |

```js
Alpine.data('poller', () => ({
    interval: null,
    data: null,
    init() {
        this.$watch('data', value => value && this.$dispatch('poller-updated', value));
        this.interval = setInterval(() => this.refresh(), 30000);
        this.refresh();
    },
    destroy() {
        clearInterval(this.interval);   // components inside x-if really are destroyed
    },
    async refresh() {
        this.data = await (await fetch('/endpoint')).json();
    },
}))
```

Anything registered with a browser API or a third-party library must be torn down in
`destroy()`, or you leak handlers every time an `x-if` toggles.
<https://alpinejs.dev/essentials/lifecycle> <https://alpinejs.dev/globals/alpine-data>
<https://alpinejs.dev/directives/init>

## Reactivity

Two primitives underpin everything: `Alpine.reactive(obj)` returns a Proxy-wrapped version of an
object that Alpine can observe, and `Alpine.effect(fn)` runs `fn` immediately, tracks every
reactive get/set it touched, and re-runs it when any of them change.

```js
let data = Alpine.reactive({ count: 1 })

Alpine.effect(() => {
    span.textContent = data.count      // re-runs whenever data.count changes
})
```

(Alpine uses Vue's `@vue/reactivity` engine under the hood.) You rarely call these directly, but
they explain the three practical rules:

- Mutating a property re-renders everything that read it, including getters.
- `$watch` is lazy (fires on change, gives new **and** old value); `x-effect` runs immediately and
  auto-detects dependencies but gives no old value. Under CSP `x-effect` is nearly unusable, so
  reach for `$watch` in `init()`.
- Do not mutate a watched object inside its own `$watch` callback — guaranteed infinite loop.

<https://alpinejs.dev/advanced/reactivity> <https://alpinejs.dev/directives/effect>
<https://alpinejs.dev/magics/watch>

## Async

Alpine supports `async` functions almost everywhere it supports sync ones. In normal Alpine you
can even `await` in an attribute (`x-text="await getLabel()"`), and a method referenced *without*
parentheses is detected as async and handled — `x-text="getLabel"` works for an async
`getLabel`. Under CSP the bare-reference form is the only one available, which happens to be the
recommended one anyway.

```js
Alpine.data('label', () => ({
    async getLabel() {
        let response = await fetch('/api/label');
        return await response.text();
    },
}))
```

```html
<span x-data="label" x-text="getLabel"></span>
```

For anything more than a value, load into state from `init()` and render from the property — it
gives you a loading flag and error handling for free:

```js
Alpine.data('orders', () => ({
    orders: [],
    loading: false,
    error: '',
    get hasError() { return this.error !== '' },
    async init() {
        this.loading = true;
        try {
            const response = await fetch(this.endpoint, { headers: { Accept: 'application/json' } });
            if (! response.ok) throw new Error(response.statusText);
            this.orders = await response.json();
        } catch (e) {
            this.error = e.message;
        } finally {
            this.loading = false;
        }
    },
}))
```

`await this.$nextTick()` when you need the DOM to reflect a state change before measuring it.
<https://alpinejs.dev/advanced/async> <https://alpinejs.dev/magics/nextTick>

## Extending

Registration must happen after Alpine is available but before it initializes — the `alpine:init`
listener. (Bundled builds instead register between `import Alpine` and `Alpine.start()`.)

### Custom directives

```js
Alpine.directive('[name]', (el, { value, modifiers, expression }, { Alpine, effect, cleanup }) => {})
```

| Argument | Meaning |
|---|---|
| `name` | directive name **without** the `x-` prefix; `'foo'` → `x-foo` |
| `el` | the element |
| `value` | the part after a colon — `'bar'` in `x-foo:bar` |
| `modifiers` | array of dot-separated suffixes — `['baz','lob']` from `x-foo.baz.lob` |
| `expression` | the attribute value — `law` from `x-foo="law"` |
| `effect` | reactive effect that auto-cleans when the directive is removed (use this, not `Alpine.effect`) |
| `cleanup` | register teardown callbacks run when the directive/element goes away |

```js
Alpine.directive('uppercase', el => {
    el.textContent = el.textContent.toUpperCase();
})
```

Reading the expression's value needs the evaluator. `evaluate(expression)` is fine once;
`evaluateLater(expression)` + `effect()` is the correct reactive form, and the receiver-callback
shape is what makes async expressions work:

```js
Alpine.directive('log', (el, { expression }, { evaluateLater, effect }) => {
    let getThingToLog = evaluateLater(expression);

    effect(() => {
        getThingToLog(thingToLog => console.log(thingToLog));
    })
})
```

Turning a string into a function is expensive, so always prefer `evaluateLater` when evaluating
more than once. Cleanup example:

```js
Alpine.directive('...', (el, {}, { cleanup }) => {
    let handler = () => {};
    window.addEventListener('click', handler);
    cleanup(() => window.removeEventListener('click', handler));
})
```

Ordering: custom directives run after most built-ins (except `x-teleport`); chain `.before('bind')`
to move one earlier.

**Under CSP a custom directive is a power tool**: its own logic is plain JavaScript, so behaviour
you cannot express in an attribute can be moved into a directive whose value is a simple string
or dot path. That is exactly what Hyvä's `x-defer` does. But note `evaluate`/`evaluateLater`
still go through the CSP evaluator, so a directive's *expression* remains dot-path-only.

### Custom magics

```js
Alpine.magic('[name]', (el, { Alpine }) => {})
```

The getter is re-evaluated on every access, so returning a function gives you a magic "function":

```js
Alpine.magic('now', () => (new Date).toLocaleTimeString())        // $now
Alpine.magic('clipboard', () => subject => navigator.clipboard.writeText(subject))  // $clipboard('x')
```

`x-text="$now"` is a dot path ✅; `@click="$clipboard('hello')"` is a call ❌ — under CSP prefer a
method on the component that uses the magic through `this`.

### Packaging

For script-tag distribution just register inside `alpine:init` and ensure the file loads
**before** Alpine's. For a bundle, export a function taking `Alpine` and let consumers call
`Alpine.plugin(yourPlugin)`:

```js
export default function (Alpine) {
    Alpine.directive('foo', /* … */)
    Alpine.magic('foo', /* … */)
}
```

<https://alpinejs.dev/advanced/extending> <https://alpinejs.dev/essentials/installation>

## V2 leftovers to reject in review

If a snippet came from an old Hyvä/Alpine v2 example, these are all wrong for v3: `$el` used as
the component root (that is `$root` now), `x-show.transition` (now `x-transition`),
`x-transition` on `x-if` (unsupported), `x-spread` (now `x-bind`),
`Alpine.deferLoadingAlpine()` (use the global lifecycle events), dynamically bound `:x-ref`
(static only), returning `false` from a handler to prevent default (use `.prevent`), `x-init`
returning a callback (use `$nextTick`), and the event modifier `.away` (now `.outside`). Alpine
also explicitly prefers `Alpine.data()` over global function data providers, and IE11 is no
longer supported. <https://alpinejs.dev/upgrade-guide>

## Project mechanics

- Component markup lives in a `.phtml` inside the relevant `vendor/<vendor>/module-*` package;
  changes take effect immediately but must be committed in that package's own repo to survive a
  fresh `composer install`.
- Template edits need a cache flush: `bin/magento cache:flush`.
- New Tailwind classes need a rebuild: `make build`, or `make watch` while iterating. Tailwind
  lives at `vendor/hyva-themes/magento2-default-theme/web/tailwind/`.
- Icons: `$heroiconsoutline->xxxHtml()` / `$heroiconssolid->xxxHtml()` resolve via `__call` to a
  kebab-cased `.svg` in the icon set directory, so the method name must match an existing file —
  `xHtml()` → `x.svg`; there is no `cross.svg`.
