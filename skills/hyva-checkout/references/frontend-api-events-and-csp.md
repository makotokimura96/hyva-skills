# Frontend API (`window.hyvaCheckout`), JS events & strict CSP

## Sub-namespaces

| Sub-namespace | Purpose |
|---|---|
| `hyvaCheckout.api` | initialization timing / callback execution order (since 1.3.3) |
| `hyvaCheckout.evaluation` | process backend evaluation results, register validators/processors/executables |
| `hyvaCheckout.payment` | register and manage JS-driven payment methods (since 1.0.0, rewritten 1.3.6) |
| `hyvaCheckout.storage` | key/value browser session storage feeding the Place Order Service (since 1.1.13) |
| `hyvaCheckout.validation` | the validation stack run before navigation / order placement |
| `hyvaCheckout.navigation` | step navigation and history |
| `hyvaCheckout.message` / `hyvaCheckout.messenger` | messages, dialogs, notifications |
| `hyvaCheckout.main` | orchestrates initialization and the checkout lifecycle |
| `hyvaCheckout.config` | backend configuration passed at init (since 1.1.13) |

Keep custom sub-namespaces **one level deep**: `hyvaCheckout.storage.setLocalValue(...)`, never
`hyvaCheckout.storage.local.setValue(...)`.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/frontend-api/index.html>

## How it is loaded and initialized

Files live in `Hyva_Checkout::page/js/api`: `v1.phtml` (the whole namespace, marked `@internal` and
deliberately not split), `init.phtml` (bootstraps on `DOMContentLoaded`), plus `/alpinejs`,
`/evaluation`, `/message`, `/navigation` directories of complementary UX elements. `/directive` is
**deprecated** (legacy Alpine directives).

Layout (mostly in `hyva_checkout_index_index.xml`): block `hyva.checkout.api` renders
`Hyva_Checkout::page/js/api/v1.phtml` after `hyva.checkout.main`; container
`hyva.checkout.api-v1.after` (alias `after`) is where all Alpine components and `init-*` blocks go,
so nothing can run before the API exists. Every sub-namespace has an `init-<name>.phtml` with its own
`after` container.

```js
// Hyva_Checkout::page/js/api/V1/init.phtml
window.addEventListener('DOMContentLoaded', () => {
    hyvaCheckout.main.init(
        'hyva-checkout-main',       // main Magewire wrapper component id
        'hyva-checkout-container',  // container holding all step components
        exception => console.log(exception)
    )
})
```

`init()` walks every sub-namespace; if it is an object with an `initialize()` method, that method
runs with the backend config object. After each one,
`window.dispatchEvent(new CustomEvent('checkout:init:${subnamespace}'))` fires. When all are done the
API is marked active and `checkout:init:after` fires on `window`.

### Extending the API

Add a whole sub-namespace by injecting a block into `hyva.checkout.api-v1.after`:

```xml
<referenceBlock name="hyva.checkout.api-v1.after">
    <block name="hyva.checkout.utils-extend"
           template="My_Example::page/js/hyva-checkout/api/v1/company-name-analytics.phtml"/>
</referenceBlock>
```

```html
<script>
'use strict';
if (hyvaCheckout && !hyvaCheckout.hasOwnProperty('companyNameAnalytics')) {
    hyvaCheckout.companyNameAnalytics = {
        clicksHistory: [],
        initialize() { document.addEventListener('click', e => this.clicksHistory.push(e.target)); },
        getClicksHistory() { return this.clicksHistory; }
    };
}
</script>
<?php $hyvaCsp->registerInlineScript() ?>
```

Add a method to an existing sub-namespace via its `after` container (one `.phtml` per method):

```xml
<referenceContainer name="hyva.checkout.init-navigation.after">
    <block name="hyva.checkout.navigation.to-first-step"
           template="My_Example::page/js/hyva-checkout/api/v1/navigation/step-to-first.phtml"/>
</referenceContainer>
```

```php
$navigator = $viewModels->require(\Hyva\Checkout\ViewModel\Navigation::class)->getNavigator();
$first = $navigator->getActiveCheckout()->getFirstStep();
```

```html
<script>
if (hyvaCheckout.navigation && !hyvaCheckout.navigation.hasOwnProperty('stepToFirst')) {
    hyvaCheckout.navigation.stepToFirst = function () {
        hyvaCheckout.navigation.stepTo('<?= $escaper->escapeJs($first->getRoute()) ?>', false);
    };
}
</script>
<?php $hyvaCsp->registerInlineScript() ?>
```

**Never target elements by `id`, `class` or `data-` attribute in an API extension** — the checkout is
dynamic and the element may not exist yet. Pass required elements in as arguments. For very specific
behaviour write an Alpine plugin instead of extending the API.

**Complementary UX elements** are the counterpart pattern: an API method dispatches an event
(`hyvaCheckout.message.dialog()` → `checkout:dialog:new`) and a separate Alpine component in
`hyva.checkout.init-message.after` renders the UI. One complementary element per API method.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/frontend-api/architecture.html>

## Where to put JS templates

All directories below are relative to `view/frontend/hyva/checkout/page/js/v1/`.

| API area | Reference container | Template dir |
|---|---|---|
| Storage | `hyva.checkout.init-storage.after` | `/storage` |
| Config | `hyva.checkout.init-config.after` | `/config` |
| Validation | `hyva.checkout.init-validation.after` | `/validation` |
| Evaluation | `hyva.checkout.init-evaluation.after` | `/evaluation` |
| Evaluation executables | `hyva.checkout.evaluation.executables` | `/evaluation/executables` |
| Navigation | `hyva.checkout.init-navigation.after` | `/navigation` |
| Payment | `hyva.checkout.init-payment.after` | `/payment` |
| Shipping | `hyva.checkout.init-shipping.after` | `/shipping` |
| Message | `hyva.checkout.init-message.after` | `/message` |
| Loader | `hyva.checkout.init-loader.after` | `/loader` |
| Viewport | `hyva.checkout.init-viewport.after` | `/viewport` |
| Debug | `hyva.checkout.init-debug.after` | `/debug` |

When unsure, use `view/frontend/hyva/checkout/page/js/api/v1` with the
`hyva.checkout.api-v1.after` container — also the recommended home for Alpine component templates.
JS payment-method registration blocks go in `hyva.checkout.api-v1.payment-methods`. Scripts that must
exist on **every** step (PSP SDKs, extracted component scripts) go in the
`magewire.plugin.scripts` container via the `hyva_checkout` handle.

Source: <https://docs.hyva.io/hyva-checkout/getting-started/quickstart.html>,
<https://docs.hyva.io/hyva-checkout/examples/js-payment-method.html>

## `hyvaCheckout.api` (since 1.3.3)

```js
hyvaCheckout.api.after(callback, { stackPosition: 400 })   // Promise<void>
    .then(() => console.log('registered'));
```

`after(callback, options)` runs the callback once the API is fully initialized, or immediately if it
already is. `stackPosition` orders callbacks — lower first, default **500**. This is the correct
wrapper for registering validators, payment methods, or anything touching `hyvaCheckout.*`. Use the
`checkout:init:after` window event instead when you only need "everything is ready" with no result.

`hyvaCheckout.api.priority(callback)` (since 1.3.4) wraps `after()` with a fixed `stackPosition` of
**20** and is **reserved for core contributions**; positions below 20 are core-only.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/frontend-api/V1/api.html>

## `hyvaCheckout.storage` (since 1.1.13)

Two predefined groups automatically travel to the backend Place Order Service: **`payment`** and
**`shipping`**. Custom groups are allowed but not transferred.

```js
hyvaCheckout.api.after(() => {
    hyvaCheckout.storage.setValue('pin', 123, 'payment')      // Promise since 1.3.4, void before
        .then(stored => console.log(stored));
    hyvaCheckout.storage.getValue('pin', 'payment');           // value | undefined
    hyvaCheckout.storage.getGroupData('payment');              // object | null
    hyvaCheckout.storage.removeValue('pin', 'payment');        // void
    hyvaCheckout.storage.clearGroup('payment');                // void
});
```

Wrap page-load calls in `hyvaCheckout.api.after()`; calls from user interaction do not need it.
Read the data server-side with `getData()` on the Place Order Service (returns
`\Hyva\Checkout\Model\Magewire\Payment\AbstractOrderData`). Local session storage is cleared when
place order succeeds (since 1.1.25).

Source: <https://docs.hyva.io/hyva-checkout/devdocs/frontend-api/V1/storage.html>

## `hyvaCheckout.evaluation`

Registration functions, all safest inside `hyvaCheckout.api.after()` or a
`checkout:init:evaluation` listener:

```js
hyvaCheckout.evaluation.registerValidator(name, cb)   // pairs with backend createValidation(name); returns Promise (1.3.5)
hyvaCheckout.evaluation.registerExecutable(name, cb)  // pairs with createExecutable(name)
hyvaCheckout.evaluation.registerProcessor(type, cb)   // handles a whole result type (since 1.1.12)
```

Callback signatures as documented: validators receive `(component, element, evaluation)` per the
1.3.5 API reference, while older examples show `(element, component)`; executables receive
`(result, element, component)`; processors receive `(component, el, result)`. Return `true`/`false`,
or a Promise that resolves/rejects. Before 1.1.12 processors were assigned directly:
`hyvaCheckout.evaluation.processors['event'] = () => {}`.

```html
<script>
window.addEventListener('checkout:init:evaluation', () => {
    hyvaCheckout.evaluation.registerValidator('validateExampleComponent', (element, component) => {
        const field = element.querySelector('#secret');
        if (!field) return false;
        return new Promise((resolve, reject) =>
            setTimeout(() => field.value === '1234' ? resolve(true) : reject(), 2500));
    });
});
</script>
<?php $hyvaCsp->registerInlineScript() ?>
```

`hyvaCheckout.validation.register(name, callback[, el, id])` registers directly into the validation
stack (async allowed); when a validator fails you own the UX — e.g.
`hyvaCheckout.messenger.dispatch('payment:method', 'Invalid credit card details provided.')` or
`hyvaCheckout.message.dialog(title)` (since 1.1.18).

Source: <https://docs.hyva.io/hyva-checkout/devdocs/frontend-api/V1/evaluation.html>,
<https://docs.hyva.io/hyva-checkout/devdocs/evaluation-api/evaluation-examples.html>

## Window events

All dispatched on `window` as `CustomEvent`; data in `event.detail`.

| Event | Fires when | `detail` |
|---|---|---|
| `checkout:init:<subnamespace>` | that sub-namespace finished initializing (`storage`, `evaluation`, `payment`, `validation`, `navigation`, `messenger`, `main`, `config`) | – |
| `checkout:init:after` | all sub-namespaces ready — the general-purpose hook | – |
| `checkout:init:done` | after every `checkout:init:after` handler finished | – |
| `checkout:storage:changed` | any session-storage value added/updated/removed | – |
| `checkout:validation:register` | a validator was added to the stack (debugging) | – |
| `checkout:step:loaded` | a step finished loading and is visible | `route` (string), `subsequent` (bool: `true` navigation, `false` initial load) |
| `checkout:navigation:success` | navigation to next/previous step completed (**not** on initial load) | – |
| `checkout:shipping:method-activate` | shipping method selected, or step rendered with one pre-selected | `method` (code) |
| `checkout:payment:method-activate` | payment method selected, or step rendered with one pre-selected | `method` (code) |
| `payment:method:registered` | a JS-driven payment method registered with the API | – |
| `payment:method:success` | payment component rendered with no backend errors, method selected | – |
| `checkout:evaluation-process:after` | all backend evaluation results processed | – |
| `checkout:dialog:new` | `hyvaCheckout.message.dialog()` was called | `title` |
| `clear-messages` | dispatch it to clear all flash messages; listen to clear your own | – |
| `order:place:success` | order placed (pushed into the evaluation batch by the POS processor) | – |
| `order:place:error`, `order:place:{payment_method_code}:error` | place-order exception; no core listener by default | – |
| `magewire:load` (on `document`) | `window.Magewire` is available | – |

Source: <https://docs.hyva.io/hyva-checkout/devdocs/frontend-api/events.html>,
<https://docs.hyva.io/hyva-checkout/devdocs/place-order-service-api/service-processor.html>

## Frontend API backport module

`hyva-themes/magento2-hyva-checkout-frontend-api` brings the latest payment/security Frontend API
onto older Hyvä Checkout installs, so a PSP integration can target the current API without forcing
merchants to upgrade.

```bash
composer config --auth http-basic.hyva-themes.repo.packagist.com token <yourLicenseKey>
composer config repositories.private-packagist composer https://hyva-themes.repo.packagist.com/<project>/
composer require 'hyva-themes/magento2-hyva-checkout-frontend-api'
```

Structure: `view/` overrides only Frontend-API-related (mostly payment) templates via layout XML;
`Preference/` adds DI preferences for classes that exist but lack newer methods; `Origin/` holds
classes missing entirely from older versions, mirroring the core structure and marked `@deprecated`
on purpose. It can be installed alongside the latest checkout — but **the backport takes priority
over core files**, so review any customization of an overridden template (rare: most are `@internal`).
If several modules need it, install the newest version and use a loose constraint (`*`). Once the
merchant upgrades, remove it.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/frontend-api/backport.html>,
<https://docs.hyva.io/hyva-checkout/upgrading/index.html>

---

# Strict CSP (mandatory from 1.3.x)

Hyvä Checkout 1.3.x+ enforces **strict CSP on all checkout pages** for PCI-DSS 4.0, and it **cannot
be disabled**. `unsafe-inline` and `unsafe-eval` are off, every inline `<script>` needs a valid
per-request nonce, dynamically injected scripts never execute, and the **Alpine CSP build** is used
(no inline expressions). A CSP-only variant existed as `hyva-themes/magento2-hyva-checkout-csp`
(1.1.29-csp) before this landed in 1.3.0.

Core config (`Hyva_Checkout`'s `etc/config.xml`):

```xml
<csp>
    <mode><storefront_hyva_checkout_index_index><report_only>0</report_only></storefront_hyva_checkout_index_index></mode>
    <policies>
        <storefront_hyva_checkout_index_index>
            <scripts><eval>0</eval><inline>0</inline><event_handlers>0</event_handlers></scripts>
        </storefront_hyva_checkout_index_index>
    </policies>
</csp>
```

Apply the same to your own payment/checkout routes. The config key is
`{area}_{routeId}_{actionPath}_{actionClass}` — area `storefront`/`admin`, `routeId` = the `id` in
`etc/frontend/routes.xml`, `actionPath` = controller folder, `actionClass` = action file basename
lowercased (`Index.php` → `index`). So `/payment/pay/index` with route id `payment_provider` becomes
`storefront_payment_provider_pay_index`. Set `<report_only>1</report_only>` while developing to log
violations without blocking, then back to `0`.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/csp/index.html>,
<https://docs.hyva.io/hyva-checkout/devdocs/csp/csp-force-strict-mode-for-checkout.html>

## Authorizing scripts

```html
<script>
    // your JS
</script>
<?php $hyvaCsp->registerInlineScript() ?>
```

`\Hyva\Theme\ViewModel\HyvaCsp` (declare `/** @var HyvaCsp $hyvaCsp */`) injects the nonce into the
**preceding** script tag. Call it immediately after every closing `</script>` that needs authorizing.

Inline event handlers (`onclick`, `onload`, `onerror`), `eval()`, `setTimeout('string')` and
`new Function()` are all blocked — move them into a nonced script block with
`addEventListener`. External script hosts are allowlisted through Magento's `csp_whitelist.xml`;
the Hyvä CSP Allowlist module can detect which hosts a page actually uses.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/csp/csp-script-validation.html>

## Move scripts to the initial page load

A script inserted into the DOM after the initial render **never executes**, even with a valid nonce.
That means **no inline `<script>` inside a Magewire component template**: Magewire swaps that markup
on subsequent requests and the script would arrive too late. In a multistep checkout, every step's
scripts must be present on the *first* page load.

The three-step refactor (core example: the payment method list):

1. Extract the script into its own `.phtml`, turn the logic into an `Alpine.data()` constructor
   function, and read parameters from `this.$el.dataset` instead of PHP variables.

```html
<script>
"use strict";
function hyvaCheckoutPaymentMethodListActivate() {
    const method = this.$el.dataset.method;
    window.addEventListener('checkout:step:loaded', () => {
        if (method && document.getElementById('payment-method-list')) {
            window.dispatchEvent(new CustomEvent('checkout:payment:method-activate', {detail: {method}}));
        }
    }, {once: true});
    return {}
}
window.addEventListener('alpine:init',
    () => Alpine.data('hyvaCheckoutPaymentMethodListActivate', hyvaCheckoutPaymentMethodListActivate), {once: true})
</script>
<?php $hyvaCsp->registerInlineScript() ?>
```

2. Register it in the `magewire.plugin.scripts` container using the `hyva_checkout` handle (loaded in
   the footer of every checkout page).

```xml
<referenceContainer name="magewire.plugin.scripts">
    <block name="hyva-checkout.checkout.payment.method-list-activate"
           template="Hyva_Checkout::checkout/payment/method-list-activate.phtml"/>
</referenceContainer>
```

3. Activate it from the component template with `x-data` and pass values as data attributes. Note the
   escaper change: `escapeJs()` becomes `escapeHtmlAttr()`.

```html
<ol id="payment-method-list" x-data="hyvaCheckoutPaymentMethodListActivate"
    data-method="<?= $escaper->escapeHtmlAttr($magewire->method) ?>">
```

Source: <https://docs.hyva.io/hyva-checkout/devdocs/csp/csp-move-scripts-page-load.html>

## Alpine CSP rules for checkout markup

- `x-data="initComponentName"` — a **registered function name, not a call** and not an inline object.
- `x-on:event="methodName"` / `@click="methodName"` — method **references** only, no inline
  expressions, no arguments. Access the event inside the method as `this.$event`.
- `x-init="checkAcceptCookies"` — method reference, not `checkAcceptCookies()`.
- **`x-model` is not CSP-safe**; replace with `x-bind:value="code"` + `x-on:input="updateCode"` and a
  method `updateCode(event) { this.code = event.target.value }`.
- Register with `window.addEventListener('alpine:init', () => Alpine.data('name', fn), {once: true})`.
- Alpine **v2 cannot be made CSP compatible** — check `Alpine.version` in the console; upgrade to v3
  first.

Migration pattern for any shared component: add the `HyvaCsp` view model, register with
`Alpine.data()`, convert inline expressions to named methods, call `registerInlineScript()`, and use
`x-data="componentName"` instead of `componentName()`.

## Shared theme components must be CSP-compatible

Header, footer, cookie notice, authentication drawer, newsletter form, language/store/currency
switchers, messages and Login-as-Customer notices render on checkout pages too. If they are not CSP
compatible they break the checkout. `hyva-themes/magento2-default-theme` **1.3.15+** ships
CSP-compatible versions of every shared component; older themes need the migration. Templates that
commonly need `registerInlineScript()`: configurable-product and swatch option scripts, Google
Analytics/Gtag, all `Magento_ReCaptchaFrontendUi` script/token templates, and
`Magento_Theme::html/mobile-safari-bug-workaround.phtml`. Alpine components needing CSP migration:
`Magento_Cookie::notices.phtml`, `Magento_Customer::account/authentication-popup.phtml`,
`Magento_Directory::currency.phtml`, `Magento_Newsletter::subscribe.phtml`,
`Magento_Store::switch/languages.phtml`, `Magento_Store::switch/stores.phtml`,
`Magento_LoginAsCustomerFrontendUi::html/notices.phtml` (+ `logout-link.phtml`),
`Magento_Theme::messages.phtml`. Use the Hyvä Theme CSP migration tool to scan a theme.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/csp/csp-checkout-with-non-csp-theme.html>
