# Architecture, installation & Magewire

## What Hyvä Checkout is

Commercial, licensed replacement for the Luma checkout (`hyva-themes/magento2-hyva-checkout`).
Server-rendered, driven by **Magewire** (a port of Laravel Livewire to Magento) with **Alpine.js**
on the client. It is *not* the community `magento2-react-checkout` project — no shared code,
architecture, or team.

Mental model: the checkout is an **empty component shell**. Address forms, shipping method list,
payment method list, quote summary, navigation buttons are independent components registered in
layout XML and *moved* into steps. Steps and their order come from `etc/hyva_checkout.xml`.

Key departures from Luma/Knockout checkout:

| Aspect | Luma | Hyvä Checkout |
|---|---|---|
| Order placement | the payment method places the order | a **Place Order Service** places it |
| Payment step position | must be last | any step; never assume it is last |
| Payment data collection | just before order placement | whenever the payment step is visited |
| Implementation style | Knockout + UI components, JS-heavy | Magewire (PHP) first, JS where needed |
| Frontend JS entrypoint | `Magento_Checkout/js/*`, RequireJS | `window.hyvaCheckout.*`, `window.Magewire` |
| Client validation | `Magento_Ui` validators | `hyva.formValidation` + Magewire `rakit/validation` |

Source: <https://docs.hyva.io/hyva-checkout/getting-started/quickstart.html>,
<https://docs.hyva.io/hyva-checkout/devdocs/payments/payment-in-hyva-checkout.html>,
<https://docs.hyva.io/hyva-checkout/faq/hyva-checkout-vs-react-checkout.html>

## Requirements and installation

- Magento Open Source / Adobe Commerce 2.4.5 – 2.4.9 (latest patch). PHP 8.1–8.5.
- **Hyvä Themes 1.3.12 or newer** (hard dependency, not a composer requirement of the checkout).
- Hyvä Checkout `1.3.0`+ requires the Magento CSP Nonce Provider; `1.3.x` is the current standard
  release line and is fully Alpine-CSP compliant. `1.4.0-beta*` is the Magewire v3 line.

```bash
composer require hyva-themes/magento2-hyva-checkout
bin/magento config:set dev/template/minify_html 0   # only if minification is on
bin/magento setup:upgrade
npm --prefix vendor/hyva-themes/magento2-default-theme/web/tailwind/ ci --ignore-scripts
npm --prefix vendor/hyva-themes/magento2-default-theme/web/tailwind/ run build
```

Upgrades: `composer update --with-dependencies hyva-themes/magento2-hyva-checkout[:x.y.z]`.
Magewire is pulled in as a dependency — never install it separately.

**Containerised stacks:** run the CLI through your container, e.g.
`bin/magento cache:flush`; Tailwind rebuilds via `make build` / `make watch`.

Admin: *Stores > Configuration > Hyvä Themes > Checkout*. The **General > Checkout** select
defaults to "Magento Luma (original)"; switch it to "Hyvä Default" (or a custom checkout) per
website/store view. An optional **Mobile** checkout is chosen by a user-agent regex configured in
*Hyvä Themes > Checkout > Developer*. Flush the cache after any config change.

Source: <https://docs.hyva.io/hyva-checkout/getting-started/index.html>,
<https://docs.hyva.io/hyva-checkout/upgrading/index.html>

## Running Hyvä Checkout on a Luma store

Hyvä Checkout requires a Hyvä theme, but only for the checkout route. Use
`hyva-themes/magento2-theme-fallback`: set `hyva_theme_fallback/general/enable=1`,
`hyva_theme_fallback/general/theme_full_path=frontend/Hyva/default`, and add
`hyva_checkout/index` to `hyva_theme_fallback/general/list_part_of_url`.
Conversely `hyva-themes/magento2-luma-checkout` keeps a Luma checkout on a Hyvä store.

Source: <https://docs.hyva.io/hyva-checkout/faq/hyva-theme-requirement.html>,
<https://docs.hyva.io/hyva-checkout/faq/luma-checkout-faq.html>

## Styling

Checkout markup is plain Tailwind and compiles into the theme's `styles.css` — nothing extra to
configure. To drop the module's own defaults
(`vendor/hyva-themes/magento2-hyva-checkout/src/view/frontend/tailwind/tailwind-source.css`):

- Tailwind v4: add to `web/tailwind/hyva.config.json` →
  `{"tailwind":{"exclude":[{"src":"vendor/hyva-themes/magento2-hyva-checkout/src"}]}}`, then
  `npx hyva-sources`. Add `"keepSource": true` to keep class scanning but skip the CSS import.
- Tailwind v3: `excludeDirs: ["vendor/hyva-themes/magento2-hyva-checkout/src"]` on
  `postcssImportHyvaModules()` in `web/tailwind/postcss.config.js`
  (needs `@hyva-themes/hyva-modules` >= 1.0.7).

Source: <https://docs.hyva.io/hyva-checkout/devdocs/styling/index.html>

---

# Magewire

## Declaring a component

Any block becomes a Magewire component by adding a `magewire` object argument:

```xml
<block name="checkout.shipping-details" template="Hyva_Checkout::component/shipping-details.phtml">
    <arguments>
        <argument name="magewire" xsi:type="object">\Hyva\Checkout\Magewire\ShippingDetails</argument>
    </arguments>
</block>
```

Component classes extend `\Magewirephp\Magewire\Component` and live in `Magewire/` inside the
module (for checkout components: `Magewire/Checkout/...`). Templates live in
`view/frontend/templates/magewire/`, and a component `My\Module\Magewire\ExampleForm` defaults to
`magewire/example-form.phtml` when the block has no explicit template.

Inside the template the instance is available as `$magewire` — no `$block->getData('magewire')`.

**Public properties** are synced between PHP and the browser automatically.

Source: <https://docs.hyva.io/hyva-checkout/magewire/index.html>,
<https://docs.hyva.io/hyva-checkout/magewire/component-templates.html>

## Hard rules

- **Exactly one root DOM element** per component template. Leading text counts as a second root
  node and breaks DOM patching.
- **Reserved property names** — never redeclare on your component: public `$id`, `$name`;
  protected `$dispatchQueue`, `$renderedChildren`, `$request`, `$response`, `$eventQueue`,
  `$errors`, `$listeners`, `$flashMessage`, `$uncallables`, `$queryString`, `$redirect`,
  `$skipRender`, `$loader`, `$validator`, `$rules`, `$messages`. Use `$entityId`, `$productName`…
- There are **magic getters/`has`ers but no magic setters**: `$magewire->getFoo()`,
  `$magewire->hasFoo()` work; `$component->setFoo($v)` does not. Assign directly: `$this->foo = $v`.
- `wire:ignore` on an element tells Magewire to leave that subtree alone on re-render — required
  around anything a third-party SDK renders (iframes especially).

Source: <https://docs.hyva.io/hyva-checkout/magewire/component-intro.html>,
<https://docs.hyva.io/hyva-checkout/examples/example-payment-integration-iframe.html>

## Request lifecycle

Two request types: the **preceding request** (initial HTML render) and **subsequent requests**
(Ajax, triggered by interaction). State survives across requests via **hydration** (restore
previous property values) → **property updates** → **dehydration** (serialize and send to client).

| Hook | Preceding | Subsequent | Hydrated | Props updated |
|---|:--:|:--:|:--:|:--:|
| `boot($blockData, $request)` | yes | yes | | |
| `mount($blockData, $request)` | yes | | | |
| `hydrate()` / `hydrateFoo($value)` | | yes | yes | |
| `booted()` | yes | yes | yes | |
| `updating($value, $prop)` / `updatingFoo($value)` | | yes | yes | |
| `updated($value, $prop)` / `updatedFoo($value)` | | yes | yes | yes |
| `dehydrate()` / `dehydrateFoo($value, $response)` | yes | yes | yes | yes |

- `$blockData` is `$block->getData()`; `$request` is `\Magewirephp\Magewire\Model\RequestInterface`;
  `$response` is `\Magewirephp\Magewire\Model\ResponseInterface`.
- Any hook that receives `$value` **must return it** — the return value becomes the stored value.
- Property hook names are PascalCase of the property: `$fooBar` → `updatingFooBar`,
  `$bar_baz` → `updatingBarBaz`. Nested array keys concatenate: `address.street` →
  `updatedAddressStreet`.
- `updatedFoo()` only fires when the update comes *through* Magewire (`$set()`, `wire:model`,
  an action). Plain PHP assignment `$this->foo = 'x'` does not trigger it.
- On a **full-page-cached** hit no lifecycle hook runs during the preceding request. Subsequent
  requests always bypass FPC.

Source: <https://docs.hyva.io/hyva-checkout/magewire/component-lifecycle.html>,
<https://docs.hyva.io/hyva-checkout/magewire/lifecycle-hook-methods.html>,
<https://docs.hyva.io/hyva-checkout/magewire/array-properties.html>,
<https://docs.hyva.io/hyva-checkout/magewire/running-php-code-after-property-updates.html>

## `wire:` bindings and magic actions

```html
<button wire:click="registerClick">…</button>       <!-- calls PHP method -->
<input  wire:model="address.street">                 <!-- two-way sync, dot notation ok -->
<input  wire:model.lazy="foo">                       <!-- sync at rest -->
<input  wire:model.defer="foo">                      <!-- sync only on next action -->
<div    wire:init="loadData">…</div>                 <!-- call method right after render -->
<button wire:click="$set('foo','bar')">…</button>
<button wire:click="$toggle('flag')">…</button>
<button wire:click="$refresh()">…</button>
<button wire:click="$emit('doSomething', {foo: 123})">…</button>
<button wire:click="$emitTo('some.block.name','doSomething',{foo:123})">…</button>
```

`wire:foo="bar"` listens for any DOM event `foo` and calls PHP `bar`. Unlike Alpine's `x-on:`,
`wire:*` always calls the **PHP** component (a server roundtrip).

Source: <https://docs.hyva.io/hyva-checkout/magewire/component-interaction.html>

## Emit messages (pub/sub between components)

Subscribe with `protected $listeners`; only listed methods are reachable via emit.

```php
class MyComponent extends \Magewirephp\Magewire\Component
{
    protected $listeners = [
        'shipping_method_selected' => 'refresh',   // map message => method
        'coupon_code_applied'      => 'refresh',
        'doSomething',                             // shorthand: method name == message
    ];
    public function doSomething($value) { /* … */ }
}
```

Emit from PHP `$this->emit('doSomething', ['id' => 69])` / `$this->emitTo('some.block.name', …)`
— **no effect during the preceding request**, subsequent requests only. From JS:
`Magewire.emit(...)`, `Magewire.emitTo(...)`, and subscribe with `Magewire.on('foo', e => …)`.

Every emit is also dispatched as a **Magento event** named `magewire_<message>` with the
associative payload as event data, so a normal observer can react. Prefer the associative-array
payload form over Livewire's positional args.

**Checkout emit messages** shipped by the core (general + guest/customer variants):
`shipping_address_added|submitted|saved` (+ `guest_…`, `customer_…`), `shipping_address_activated`,
`billing_address_added|submitted|saved` (+ variants), `billing_address_activated`,
`coupon_code_applied`, `coupon_code_revoked`, `payment_method_selected`,
`shipping_method_selected`.

To change a core component's listeners, plugin `afterGetListeners()` (from Magewire's `Event`
trait) in `etc/frontend/di.xml`:

```php
public function afterGetListeners(\Hyva\Checkout\Magewire\Checkout\Foo $subject, array $listeners): array
{
    $listeners['foo'] = 'refresh';
    unset($listeners['bar']);
    return $listeners;
}
```

Source: <https://docs.hyva.io/hyva-checkout/magewire/emit-messages.html>,
<https://docs.hyva.io/hyva-checkout/devdocs/miscellaneous/checkout-emit-messages.html>

## Magewire form components (server-side validation)

Extend `\Magewirephp\Magewire\Component\Form` instead of `Component`. Rules use
[rakit/validation](https://github.com/rakit/validation) syntax in `protected $rules`, custom
messages keyed `property:rule` in `protected $messages`.

```php
class MyComponent extends \Magewirephp\Magewire\Component\Form
{
    public $email; public $vatId;
    protected $rules = ['email' => 'required|email', 'vatId' => 'required|regex:/^[a-z0-9]+$/i'];
    protected $messages = [
        'vatId:required' => (string) __('Please specify a valid EU VAT ID to proceed'),
        'vatId:regex'    => (string) __('":value" is not a valid EU VAT ID'),
    ];

    public function updated($value, $prop) { $this->validate(); return $value; }  // validate on change
    public function save() { $this->validate(); $this->repository->save($this); } // validate on submit
}
```

`validate()` throws `Magewirephp\Magewire\Exception\AcceptableException` on failure: the component
lifecycle survives, but the calling method aborts. Messages are **not** rendered automatically —
use `$magewire->hasError('name')`, `$magewire->getError('name')`, `$magewire->getErrors()`.
`validateGroup()` (since 1.1.19) validates a subset of fields.

Source: <https://docs.hyva.io/hyva-checkout/magewire/form-components.html>

## Bridging Magewire server validation to the JS validation library

Hyvä Checkout registers a `magewire` rule in `hyva.formValidation`. Wire it up with three
attributes plus `novalidate` **in the template** (Magewire strips it on re-render otherwise):

```html
<form x-data="hyva.formValidation($el)" novalidate>
    <input id="my-input" type="text" wire:model.defer="myInput"
           data-validate='{"magewire": true}'
           data-magewire-is-valid="<?= (int) !$magewire->hasError('myInput') ?>"
        <?php if ($magewire->hasError('myInput')): ?>
           data-msg-magewire="<?= $escaper->escapeHtmlAttr($magewire->getError('myInput')) ?>"
        <?php endif; ?>
    >
</form>
```

`data-magewire-is-valid` must be the integer `1`/`0` — booleans do not work.

`wire:submit.prevent="submitForm"` **conflicts** with the JS validation library (it sets
`readonly` on all form elements before Alpine validates, so nothing gets validated). Use a button
instead:

```html
<button type="button" @click="validate().then(() => $wire.submitForm()).catch(() => {})">Save</button>
```

Source: <https://docs.hyva.io/hyva-checkout/magewire/magewire-js-form-validation.html>

## Alpine.js ↔ Magewire

`$wire` is available inside any Alpine component nested in a Magewire component. Because the
checkout runs the **Alpine CSP build**, all logic must live in named methods registered via
`Alpine.data()`, and `$wire` is reached as `this.$wire` (the event as `this.$event`).

```js
function exampleWireCalls() {
    return {
        foo: $wire.entangle('foo'),        // keep Alpine + PHP property in sync
        readLabel()  { console.log(this.$wire.get('label')); },   // no roundtrip
        writeFoo()   { this.$wire.foo = 'x'; },                   // roundtrip
        setFoo()     { this.$wire.set('foo', 'x'); },              // roundtrip
        trackClick() { this.$wire.track(Date.now()); },            // call PHP method
        interaction(){ this.$wire.call('interaction', this.$event.target.dataset.id); },
    }
}
window.addEventListener('alpine:init', () => Alpine.data('exampleWireCalls', exampleWireCalls), {once: true});
```

```html
<div x-data="exampleWireCalls"><button type="button" @click="trackClick">…</button></div>
```

Every `$wire` method call returns a Promise that resolves when the roundtrip finishes but **never
resolves to the PHP return value** — send data back via public properties / entanglement.
Bind `$wire` calls to low-frequency events only; each one is an Ajax request.

Source: <https://docs.hyva.io/hyva-checkout/magewire/alpine-js.html>

## Vanilla JS ↔ Magewire

`window.Magewire` exists whenever a component is on the page. Wait for it:

```js
document.addEventListener('magewire:load', () => {
    if (document.querySelectorAll('[wire\\:id=checkout.payment.psp_method_xyz]').length) {
        const c = Magewire.find('checkout.payment.psp_method_xyz'); // arg = layout block name
        c.get('config');                                            // read, no Ajax
        c.set('foo', 'bar');                                        // write, Ajax
        c.setPaymentToken({token: myToken});                        // call PHP method
        Magewire.find('hyva-checkout-main').call('navigateToStep', 'payment');
    }
});
```

`Cannot read properties of undefined (reading '$wire')` from `Magewire.find()` means no component
with that name is on the page — guard on the `wire:id` attribute first.

Source: <https://docs.hyva.io/hyva-checkout/magewire/vanilla-js.html>

## Troubleshooting

- **All Magewire POSTs return 404 on staging** — conflicting `PHPSESSID` cookies between a bare
  apex production domain (`test.com`) and a staging subdomain (`staging.test.com`). PHP loses the
  session, the step config disappears, the component is unknown → 404. Delete the apex-domain
  cookie and reload; permanently, use a subdomain for production, a separate TLD for staging, or
  `blackbird/cookie-domain-cleaner`.
- **`Main wire element could not be found` / `ReferenceError: Magewire is not defined`** — the
  theme fallback module still lists `checkout/index`, so Luma renders the checkout. Remove it from
  *Stores > Configuration > Hyvä Themes > Theme Fallback* and flush FPC.
- **Wrong/missing custom total segments** (e.g. Adobe Commerce gift cards) — enable
  *Hyvä Themes > Hyvä Checkout > Developer > Fixes & Workarounds > Collect Totals During Segment
  Retrieval* (since 1.1.23, on by default). Disable it if other customizations already recollect
  totals in the same request.

Source: <https://docs.hyva.io/hyva-checkout/faq/404-component-not-found.html>,
<https://docs.hyva.io/hyva-checkout/faq/main-wire-element-could-not-be-found.html>,
<https://docs.hyva.io/hyva-checkout/faq/missing-or-incorrect-totals.html>
