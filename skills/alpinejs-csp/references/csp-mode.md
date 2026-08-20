# CSP mode — the rules that actually apply

## Why a separate build exists

To evaluate `x-on:click="console.log()"` Alpine has to turn an attribute string into
executable JavaScript. It does not use `eval()` (slow, problematic) — it uses `Function`
declarations, which still violate the `unsafe-eval` Content Security Policy. Alpine therefore
ships an alternate build that does not need `unsafe-eval`.
<https://alpinejs.dev/advanced/csp>

An example CSP that works with it (note the absent `unsafe-eval`):

```text
Content-Security-Policy: default-src 'self'; script-src 'nonce-[random]' 'strict-dynamic';
```

## What Hyvä actually ships — verify before trusting the upstream docs

Verified in this repo:

- Build file: `vendor/hyva-themes/magento2-theme-module/src/view/base/web/js/alpine3-csp.js`
  (plus `alpine3-csp.min.js`), built from `packages/alpinejs` + `packages/csp`.
- Version string in the bundle: **`3.14.3`**.
- CSP-compatible theme package: `hyva-themes/magento2-default-theme-csp` ("Hyvä Default CSP").

**This matters a lot.** The current `alpinejs.dev/advanced/csp` page documents a *newer,
much more permissive* CSP evaluator that claims to support `count++`, `count = 0`,
`count > 5`, `'Hello ' + name`, `count === 5 ? 'Yes' : 'No'` and `items.push('c')`. The
evaluator in the 3.14.3 build Hyvä ships supports **none of that**. Its entire implementation is
a dot-path lookup:

```js
function generateEvaluator(el, expression, dataStack) {
  return (receiver = () => {}, { scope: scope2 = {}, params = [] } = {}) => {
    let completeScope = mergeProxies([scope2, ...dataStack]);
    let evaluatedExpression = expression.split(".").reduce(
      (currentScope, currentExpression) => {
        if (currentScope[currentExpression] === void 0) {
          throwExpressionError(el, expression);
        }
        return currentScope[currentExpression];
      },
      completeScope
    );
    runIfTypeOfFunction(receiver, evaluatedExpression, completeScope, params);
  };
}
```

Consequences, straight from that code:

1. An expression is split on `.` and each segment is looked up as a property. **A property
   name, or a dot path of property names, is the only legal expression.**
2. If the resolved value is a function it is invoked, bound to the component scope, with the
   directive's params — that is why `@click="toggle"` works.
3. Any `undefined` segment logs
   `Alpine Error: Alpine is unable to interpret the following expression using the CSP-friendly build: "<expr>"`
   as a `console.warn`. **It does not throw** — the component silently does nothing, which is
   exactly how CSP bugs reach production. Watch the console.

So: write **only** dot paths. Every operator, every parenthesis, every literal, every space
belongs in JavaScript inside `Alpine.data()`.

## Forbidden vs. compliant

| Want to… | ❌ Normal Alpine (breaks under Hyvä CSP) | ✅ CSP-safe |
|---|---|---|
| toggle a flag | `@click="open = ! open"` | `@click="toggle"` + `toggle() { this.open = ! this.open }` |
| call a method | `@click="toggle()"` | `@click="toggle"` |
| increment | `@click="count++"` | `@click="increment"` |
| negate | `x-show="!open"` | `x-show="isClosed"` + `get isClosed() { return ! this.open }` |
| compare | `x-show="count > 5"` | `x-show="hasMany"` + getter |
| concatenate | `x-text="'Hello ' + name"` | `x-text="greeting"` + `get greeting() { return 'Hello ' + this.name }` |
| template literal | `x-text="\`Hello ${name}\`"` | getter, as above |
| ternary class | `:class="open ? '' : 'hidden'"` | `:class="dropdownClass"` + getter returning the string |
| class object | `:class="{ hidden: ! open }"` | getter returning `{ hidden: ! this.open }` |
| set a nested prop | `@click="user.name = 'John'"` | `@click="setName"` (method) |
| arrow function | `@click="() => doThing()"` | `@click="doThing"` |
| globals | `x-text="Math.max(a, b)"`, `x-text="document.title"`, `@click="console.log('hi')"` | do it inside the component's JS |
| dispatch an event | `@click="$dispatch('foo')"` | `@click="notify"` + `notify() { this.$dispatch('foo') }` |
| watch | `x-init="$watch('open', v => …)"` | `init() { this.$watch('open', v => …) }` |
| store method | `@click="$store.cart.reload()"` | `@click="$store.cart.reload"` (dot path, function auto-invoked) |
| spread defaults | `x-data="{ ...defaults }"` | build the object in `Alpine.data()` |
| pass args to a component | `x-data="dropdown(true)"` | `x-data="dropdown"`, bake the value into the registered factory |
| loop a range | `x-for="i in 10"` | put the array in state: `x-for="i in tenItems"` |

The upstream "what's not supported" list (property assignment, arrow functions,
destructuring, template literals, spread, globals) is a **subset** of what the 3.14.3 build
rejects — treat it as the floor, not the ceiling.
<https://alpinejs.dev/advanced/csp>

### Things that still work, and why

These look like non-trivial expressions but are parsed by the directive itself, not by the
evaluator:

- `x-for="item in items"` and `x-for="(item, index) in items"` — the `for` directive parses
  the `… in …` form and only evaluates the `items` half. `:key="item.id"` is a dot path, fine.
- `x-transition:enter="transition ease-out duration-300"` — transition values are CSS class
  strings, not expressions.
- `x-transition.duration.500ms`, `@click.outside`, `@keydown.window.escape`,
  `x-model.debounce.500ms` — modifiers are part of the attribute *name*. All modifiers work.
- `x-teleport="body"`, `x-ref="text"`, `x-cloak`, `x-ignore` — plain strings or no value.
- `$event.detail` inside `x-on` — `$event` is injected into the listener scope, so any dot path
  under it resolves. `$event.target.remove()` does **not** (parentheses); `$event.target.remove`
  does, because the resolved function gets invoked.
- `x-html` — the 3.14.3 core sets `innerHTML` from the resolved value; Hyvä's own CSP theme uses
  `x-html="msrpPrice"` in `Magento_Msrp/templates/popup.phtml`. The upstream doc lists `x-html`
  under "HTML injection ❌"; that reflects the newer build. If you upgrade Alpine, re-verify.

## The one component pattern

Every Hyvä CSP component looks like this: an inline `<script>` defining a factory function,
registered on `alpine:init` under a name, referenced by name from `x-data`, plus
`$hyvaCsp->registerInlineScript()` so the script gets the page nonce.

```php
<?php
declare(strict_types=1);

use Hyva\Theme\Model\ViewModelRegistry;
use Hyva\Theme\ViewModel\HeroiconsOutline;
use Hyva\Theme\ViewModel\HyvaCsp;
use Magento\Framework\Escaper;

/** @var Escaper $escaper */
/** @var HyvaCsp $hyvaCsp */
/** @var ViewModelRegistry $viewModels */

/** @var HeroiconsOutline $heroicons */
$heroicons = $viewModels->require(HeroiconsOutline::class);
?>
<script>
    function initExampleDropdown() {
        // PHP-rendered values are closed over here, not passed through x-data arguments
        const endpoint = '<?= $escaper->escapeJs($block->getUrl('example/index/load')) ?>';

        return {
            open: false,
            items: [],
            get isClosed() {
                return ! this.open;
            },
            get triggerClass() {
                return this.open ? 'bg-primary text-white' : 'bg-white';
            },
            toggle() {
                this.open = ! this.open;
            },
            close() {
                this.open = false;
            },
            async load() {
                const response = await fetch(endpoint);
                this.items = await response.json();
            },
            init() {
                this.$watch('open', value => value && this.load());
            }
        }
    }
    window.addEventListener('alpine:init', () => Alpine.data('initExampleDropdown', initExampleDropdown), {once: true})
</script>
<?php $hyvaCsp->registerInlineScript() ?>

<div x-data="initExampleDropdown" x-defer="idle">
    <button @click="toggle" :class="triggerClass" aria-label="<?= $escaper->escapeHtmlAttr(__('Toggle')) ?>">
        <?= $heroicons->chevronDownHtml('', 24, 24, ['aria-hidden' => 'true']) ?>
    </button>
    <div x-show="open" x-cloak x-transition @click.outside="close">
        <template x-for="item in items" :key="item.id">
            <span x-text="item.label"></span>
        </template>
    </div>
</div>
```

Notes on that template:

- `x-data="initExampleDropdown"` resolves through Alpine's data-provider registry, so the name
  in `Alpine.data(...)` and in `x-data` must match exactly. `x-data="initExampleDropdown()"`
  would break (parentheses).
- **No parameters can be passed via `x-data` under CSP.** Inject PHP values by closing over them
  in the factory, as above. Multiple instances needing different values need distinct
  registered names (or values read from the DOM inside `init()`).
- `init()` on the data object is called automatically before the rest of the component
  initializes — that is where `$watch`, `fetch` and any real JavaScript go.
  <https://alpinejs.dev/globals/alpine-data>
- Getters are the CSP escape hatch for every expression you cannot write in an attribute.
- Heroicon helper method names map to a kebab-cased `.svg` in the icon set, so
  `chevronDownHtml()` needs `chevron-down.svg` to exist; there is no `cross.svg` — the close
  icon is `$heroicons->xHtml()`.

## Nonce and `hyva.js`

- Every inline `<script>` in a Hyvä template must be followed by
  `<?php $hyvaCsp->registerInlineScript() ?>` — the `Hyva\Theme\ViewModel\HyvaCsp` view model
  (`vendor/hyva-themes/magento2-theme-module/src/ViewModel/HyvaCsp.php`) registers the script so
  it receives the page nonce; it also exposes `getScriptSrcPolicy(): FetchPolicy`. Without it the
  browser blocks the script and the component never registers.
- Never build the nonce by hand and never inline JavaScript into an attribute (`onclick="…"`) —
  that is an inline-handler CSP violation independent of Alpine.
- `hyva.*` global helpers are available to component JavaScript (verified in the CSP theme:
  `hyva.getCookie(name)`, `hyva.setCookie(name, value, days)`), so use them from inside the
  factory instead of reaching for cookie code in an attribute.
- Alpine's own extension points must run before Alpine initializes, hence the
  `alpine:init` listener; `{once: true}` is the Hyvä convention.
  <https://alpinejs.dev/advanced/extending>

## Hyvä's own extras

- `x-defer="interact|intersect|idle|eager"` — a Hyvä-supplied Alpine plugin (template
  `Hyva_Theme::page/js/plugins/v3/defer.phtml`, plus `alpine-defer-rules.phtml`) that postpones
  component initialization. Not part of upstream Alpine, so it is not in the alpinejs.dev docs.
  The value is a plain string, so it is CSP-safe.
- `[x-cloak] { display: none !important; }` is required CSS for `x-cloak` to do anything; the
  Hyvä theme ships it. <https://alpinejs.dev/directives/cloak>

## What is available in the shipped bundle

Grepped out of `alpine3-csp.js` — nothing else exists at runtime unless you load it yourself.

**Directives (18):** `x-bind` `x-cloak` `x-data` `x-effect` `x-for` `x-html` `x-id` `x-if`
`x-ignore` `x-init` `x-model` `x-modelable` `x-on` `x-ref` `x-show` `x-teleport` `x-text`
`x-transition`.

**Magics (9):** `$data` `$dispatch` `$el` `$id` `$nextTick` `$refs` `$root` `$store` `$watch`
(plus `$event`, injected by `x-on` into listener scope).

**Plugins: none.** No `x-intersect`, `x-collapse`, `x-trap`/`$focus`, `$persist`, `x-mask`,
`x-anchor`, `x-resize`, `x-sort`, `Alpine.morph`. See `references/plugins.md`.

## Debug checklist for "my component does nothing"

1. Console for `Alpine is unable to interpret the following expression using the CSP-friendly
   build` → an attribute contains something other than a dot path.
2. Console for a CSP `script-src` violation → missing `$hyvaCsp->registerInlineScript()`.
3. `x-data` name vs. `Alpine.data()` name mismatch, or the registration ran after
   `alpine:init`.
4. Reaching for a plugin directive that is not in the bundle (it is simply ignored as an
   unknown attribute).
5. An element using directives with no ancestor `x-data` — `x-bind`, `x-on`, `x-model`, `x-if`,
   `x-for`, `x-ref`, `x-id` and `x-transition` all require it.
