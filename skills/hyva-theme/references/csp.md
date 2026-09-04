# Content Security Policy, Alpine CSP and inline scripts

## Why this matters

Since **1 April 2025**, PCI-DSS 4.0 requirement 6.4.3 requires disallowing the `unsafe-eval` and `unsafe-inline` CSP directives for scripts on payment-related pages. Modern card skimming does not attack the payment form: injected JavaScript intercepts customers before the PSP, redirects them to a phishing clone, then forwards them to the real provider. Strict CSP blocks unauthorized script execution, so injected scripts never run — whether they arrive via a compromised dependency, XSS, or a browser extension.

The exact scope of "payment page" is ambiguous. Checkout pages definitively require strict CSP; whether pages carrying in-context payment buttons (PayPal Express, Apple Pay) do is unclear and depends on the merchant's country, goods, security history and PSP requirements. **Each merchant is responsible for evaluating their own compliance requirements** — Hyvä provides CSP-compatible versions of theme and checkout but cannot make that call.

Three implementation strategies:

| Strategy | Best for |
|---|---|
| Strict CSP on checkout only | Hyvä Checkout users with no in-context payment buttons outside checkout; minimal migration effort |
| Strict CSP checkout + redirect-based in-context buttons | Stores using PayPal Express / Apple Pay on catalog or cart pages that want to keep that UX |
| Full theme CSP compatibility (Alpine CSP site-wide) | Maximum protection, new builds, or a PSP that demands strict CSP everywhere |

<https://docs.hyva.io/hyva-themes/writing-code/csp/index.html>, <https://docs.hyva.io/hyva-themes/faqs/security-compliance.html>

## The two restrictions

### `unsafe-eval`

Forbids `eval()` and the `Function` constructor. Standard Alpine.js compiles every attribute expression (`:class="{'hidden': !open}"`) into a function at runtime, so it cannot work without `unsafe-eval`. Hyvä's answer is the **Alpine CSP build**, in which attributes may only reference pre-defined properties and methods.

### `unsafe-inline`

Forbids inline `<script>` execution and inline event handlers (`onclick='…'`). Scripts must be authorized either by a per-request **nonce** or by a **SHA-256 hash** of their exact content. Hyvä uses both: nonces on uncached pages, hashes on full-page-cached pages.

To authorize an inline script, call `$hyvaCsp->registerInlineScript()` **immediately after** the closing `</script>` tag, with no HTML in between — the method hashes the immediately preceding script content:

```php
<script>
    // Your JavaScript code here
</script>
<?php $hyvaCsp->registerInlineScript() ?>
```

Call it after **every** inline script block. `$hyvaCsp` exists in Hyvä theme and Hyvä Admin theme templates only — in a module that also supports Luma, reference it exclusively from templates declared inside `hyva_*` layout handles, or you get an undefined-variable error on Luma store views.

For comparison, Luma uses `$secureRenderer`:

```php
<?= $secureRenderer->renderTag('script', [], 'console.log("Luma supports CSP")', false); ?>
```

<https://docs.hyva.io/hyva-themes/writing-code/csp/csp-compatibility.html>, <https://docs.hyva.io/hyva-themes/writing-code/csp/nonce-and-sha-hashes.html>

## Nonce vs hash

- **Nonce**: cryptographically random, generated per HTTP request, sent in the CSP header and repeated as a `nonce` attribute on the script. Must match exactly, cannot be reused between requests. Right for dynamic inline scripts.
- **SHA-256 hash**: stable as long as the script bytes are identical, so it survives cached HTML. Right for static scripts on cached pages. **Byte-exact**: whitespace, indentation, line endings, a trailing newline or minification all change the hash. One hash per `<script>` block. A poor fit for scripts containing per-request data (prices, form keys, URLs, timestamps, personalization).

Neither authorizes **external** scripts — those need `csp_whitelist.xml` entries.

Under strict CSP unauthorized scripts simply do not execute, silently. Always check the browser console for CSP violations when debugging.

## Configuring Magento for strict CSP

Set this up in development so violations surface immediately. Enable the "Warning" log level in the browser console — Alpine reports the offending expression and element.

`app/etc/env.php`:

```php
'system' => [
    'default' => [
        'csp' => [
            'mode' => ['storefront' => ['report_only' => 0]],
            'policies' => ['storefront' => ['scripts' => ['eval' => 0, 'inline' => 0]]]
        ]
    ]
]
```

then `bin/magento app:config:import`. With Magerun:

```bash
n98-magerun config:env:set system/default/csp/policies/storefront/scripts/inline 0
n98-magerun config:env:set system/default/csp/policies/storefront/scripts/eval 0
n98-magerun config:env:set system/default/csp/mode/storefront/report_only 0
bin/magento app:config:import
```

Website scope uses `system/websites/<code>/csp/...`, store-view scope `system/stores/<code>/csp/...`.

Per-route enforcement is possible — `Magento_Checkout`'s `etc/config.xml` does exactly this:

```xml
<csp>
    <mode><storefront_checkout_index_index><report_only>0</report_only></storefront_checkout_index_index></mode>
    <policies>
        <storefront_checkout_index_index>
            <scripts><inline>0</inline><event_handlers>1</event_handlers></scripts>
        </storefront_checkout_index_index>
    </policies>
</csp>
```

Three consequences to plan for:

- **Disabling `unsafe-eval` makes Hyvä automatically use the Alpine CSP build** instead of regular Alpine.
- **Disabling `unsafe-inline` breaks scripts in CMS content** — inline scripts in CMS blocks/pages can no longer be authorized.
- **The built-in PHP full-page cache does not support strict CSP.** Varnish and Fastly cache the CSP header with the page and return it; the built-in FPC does not store the header, so inline scripts on cached pages are unauthorized. Uncached pages (checkout) are unaffected.

<https://docs.hyva.io/hyva-themes/writing-code/csp/csp-magento-configuration.html>

## CSP and the `block_html` cache

Cached blocks containing inline scripts break under strict CSP, in two different ways.

**Uncached pages**: the nonce must differ per request. The request that writes the block into `block_html` works; every later request serves the cached HTML with a stale nonce and the browser refuses to run the script.

**Cached pages**: SHAs of registered scripts are added to the CSP header. If the block is already in `block_html` when the page is rendered, the script is never registered, so its SHA is missing from the header. This happens routinely when the same cached block appears on both cacheable and non-cacheable pages.

The only fix is to keep scripts out of `block_html`-cached blocks: either exclude the block from `block_html`, or extract the script into a separate uncached template block (which keeps the caching benefit for the expensive part).

A block is cached when its `cache_lifetime` data is not `false`/`null` (`0` means never expires). It can be set in layout XML, the block class, or the template — and must be unset **at the same level**:

```xml
<referenceBlock name="example">
    <arguments>
        <argument name="cache_lifetime" xsi:type="boolean">false</argument>
    </arguments>
</referenceBlock>
```

The **top menu** is such a block on every page. On custom uncached routes, exclude it:

```xml
<referenceBlock name="topmenu_generic">
    <arguments>
        <argument name="cache_lifetime" xsi:type="boolean">false</argument>
    </arguments>
</referenceBlock>
```

In PHP, `$this->layout->isCacheable()` tells you whether the page will be stored in the FPC.

**Disabling the full page cache with site-wide strict CSP breaks every page** (stale nonces from `block_html`). Either keep the FPC enabled, or disable `full_page` **and** `block_html` together.

<https://docs.hyva.io/hyva-themes/writing-code/csp/csp-and-block-caching.html>

## Installing the CSP theme

```bash
composer require hyva-themes/magento2-default-theme-csp
```

Theme code is `Hyva/default-csp`, so a child theme's `theme.xml` becomes:

```xml
<theme xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:noNamespaceSchemaLocation="urn:magento:framework:Config/etc/theme.xsd">
    <title>My Theme</title>
    <parent>Hyva/default-csp</parent>
</theme>
```

Also switch the Tailwind content path to `vendor/hyva-themes/magento2-default-theme-csp`. Both themes can be installed side by side, which is useful while migrating. Alpine CSP requires `hyva-themes/magento2-theme-module` >= 1.3.11 (and Hyvä Checkout >= 1.3.0 for the checkout). Both the standard and CSP theme versions will be maintained for the foreseeable future.

There is **no CSP build of Alpine v2** — a theme on Alpine v2 must move to v3 first. Check with `Alpine.version` in the console.

Comparing a template from `magento2-default-theme` with its `magento2-default-theme-csp` counterpart is the fastest way to see what a CSP conversion looks like.

<https://docs.hyva.io/hyva-themes/writing-code/csp/hyva-default-theme-csp-installation.html>, <https://docs.hyva.io/hyva-themes/upgrading/upgrading-to-1-3-11-csp.html>

## Writing Alpine CSP-compatible code

In the CSP build, attribute values are **lookup keys on the component**, not expressions. Reading a property works, including dot notation for nested properties; if the property is a function it is executed. Anything that transforms a value must become a method.

| Feature | Standard Alpine | Alpine CSP |
|---|---|---|
| Property read | `x-show="open"` | same |
| Negation | `x-show="!open"` | `x-show="isNotOpen"` (method) |
| Expression | `:class="{'hidden': !open}"` | `:class="isHiddenClass"` (method) |
| Mutation | `@click="open = false"` | `@click="close"` (method) |
| Method arguments | `@click="setTab('info')"` | `@click="setTab"` + `data-tab="info"` |
| `x-model` | supported | **not supported** |
| `x-for` provider | `x-for="i in getItems('cat')"` | `x-for="item in items"` (no arguments) |
| `x-for` over a range | `x-for="i in 10"` | **not possible** |
| Component constructor | `x-data="initComponent()"` or inline object | `x-data="initComponent"` + `Alpine.data()` registration |

Features that behave identically: `x-for` iteration (without method arguments), `x-if`/`x-show` with property references, event handling, `x-ref`, `x-init`, lifecycle methods.

CSP-compatible code also runs in the standard build, so writing it this way from the start costs nothing and removes future migration work.

### Constructor functions

`x-data` must reference a function registered with `Alpine.data()`. Register it inside an `alpine:init` subscriber, since `Alpine.data` is usually not yet defined when the script is parsed. Keep the function itself in global scope so it stays overridable:

```html
<div x-data="initMyComponent">…</div>
<script>
    function initMyComponent() {
        return { open: false }
    }
    window.addEventListener(
        'alpine:init',
        () => Alpine.data('initMyComponent', initMyComponent),
        {once: true}
    );
</script>
```

Object composition must move out of the attribute into the constructor. Use `.call(this)` for functions that expect the Alpine context:

```js
function exampleCspComponent() {
  return Object.assign(
      hyva.modal.call(this),
      hyva.formValidation(this.$el),
      { myValue: '' }
  );
}
```

### Value transformation and `!` method names

```html
<span x-show="isItemNotDeleted"></span>
<span x-text="itemLabel"></span>
```

```js
return {
    isNotItemDeleted() { return ! this.item.deleted; },
    itemLabel() { return this.item.title || this.item.value }
}
```

A method may be named with a `!` prefix (`['!deleted']() { return !this.deleted }`), which is convenient while converting — but it works **only** in the CSP build. For code that must run in both builds, use a `notDeleted`-style name.

### Passing arguments: dataset attributes

Arguments cannot be passed from attributes. Move them to `data-*` and read them from `this.$el.dataset` (or `this.$root.dataset` for component-level data). Change the escaping from `escapeJs` to `escapeHtmlAttr` — the encodings differ and the wrong one silently breaks the code:

```html
<button @click="selectItem" data-item-id="<?= (int) $item->getId() ?>">Select</button>
<input :value="calcValue" data-config="<?= $escaper->escapeHtmlAttr($block->getConfig()) ?>">
```

```js
selectItem() { this.selected = this.$el.dataset.itemId; }
```

Alpine magics are available as properties of `this`: `this.$event` in any event callback, `this.$el`, `this.$root`, and `x-for` iteration variables (`this.item`, `this.index`).

### Replacing `x-model`

Text-like inputs — `:value` plus `@input`:

```html
<input type="text" :value="prop" @input="setProp">
```
```js
setProp() { this.prop = this.$event.target.value; }
```

Textarea — the value is content, not an attribute: `<textarea @input="setProp" x-text="prop"></textarea>`.

Checkbox / radio — `@change` plus `:checked="isChecked"`:

```js
updateSelection() {
    const checkbox = this.$event.target;
    if (checkbox.checked && ! this.prop.includes(checkbox.value)) this.prop.push(checkbox.value);
    if (! checkbox.checked && this.prop.includes(checkbox.value))
        this.prop.splice(this.prop.indexOf(checkbox.value), 1);
},
isChecked() { return this.prop.includes(this.$el.value); }
```

Select — `@change` on the `<select>` plus `:selected` on the options.

`x-model.number` has an equivalent: `hyva.safeParseNumber(this.$event.target.value)` (the same code Alpine's `.number` modifier uses). There are **no** utilities for `.lazy`, `.boolean`, `.debounce`, `.throttle` or `.fill`.

### `hyva.createBooleanObject` (since 1.3.11)

Boilerplate-killer for the very common show/hide component:

```js
hyva.createBooleanObject(name, value = false, additionalMethods = {})
```

`hyva.createBooleanObject('hidden', true)` yields `hidden()`, `notHidden()`, `toggleHidden()`, `setHiddenTrue()`, `setHiddenFalse()`. Underscored names camel-case the derived methods: `is_hidden` → `notIsHidden`, `toggleIsHidden`, `setIsHiddenTrue`, `setIsHiddenFalse`.

```html
<script>
  Alpine.data('example', () => hyva.createBooleanObject('hidden', true))
</script>
<div x-data="example">
    <template x-if="hidden"><div>Show if hidden</div></template>
    <template x-if="notHidden"><div>Show if visible</div></template>
</div>
```

**Use `notHidden`, not `!hidden`** — the deprecated `!` form works only in the CSP build.

`additionalMethods` extends the object, e.g. a type switcher, a class map, or a label:

```js
hyva.createBooleanObject('showPassword', false,
    {textOrPassword() { return !this.showPassword() ? 'text' : 'password' }})
hyva.createBooleanObject('hidden', false,
    {cardClasses() { return {'hidden': this.hidden()} }})
```

### Full example component

```php
<div x-data="exampleCspComponent"
     data-items="<?= $escaper->escapeHtmlAttr(json_encode($items))?>">
    <button type="button" class="btn" @click="toggle">Click</button>
    <span x-text="isActive"></span>
    <template x-if="isActive"><div>Hello</div></template>
    <template x-if="isNotActive"><div>Bye</div></template>
    <form>
        <label for="example">Input without x-model</label>
        <input type="text" id="example" @input="onInput" :value="value">
    </form>
    <ul>
        <template x-for="(item, index) in items">
            <li @click="registerClick" :class="listItemClasses">
                <span x-text="index"></span>: <span x-text="item.name"></span>
            </li>
        </template>
    </ul>
</div>
<script>
    function exampleCspComponent() {
        return {
            isActive: true,
            items: [],
            value: '',
            init() { this.items = JSON.parse(this.$root.dataset.items) },
            isNotActive() { return ! this.isActive; },
            toggle() { this.isActive = !this.isActive; },
            listItemClasses() {
                return {
                    'border-gray-200': this.index % 2,
                    'border': this.index % 2,
                    'bg-red-500': this.item.name === 'Buz'
                }
            },
            onInput() { this.value = this.$event.target.value; },
            registerClick() { console.log(this.index) },
        };
    }
    window.addEventListener(
        'alpine:init',
        () => Alpine.data('exampleCspComponent', exampleCspComponent),
        {once: true}
    )
</script>
```

<https://docs.hyva.io/hyva-themes/writing-code/csp/alpine-csp.html>, <https://docs.hyva.io/hyva-themes/writing-code/csp/alpine-csp-example-component.html>, <https://docs.hyva.io/hyva-themes/writing-code/csp/alpine-csp-constructor-functions.html>, <https://docs.hyva.io/hyva-themes/writing-code/csp/alpine-csp-properties.html>, <https://docs.hyva.io/hyva-themes/writing-code/csp/alpine-csp-property-mutation.html>, <https://docs.hyva.io/hyva-themes/writing-code/csp/alpine-csp-x-model.html>, <https://docs.hyva.io/hyva-themes/writing-code/csp/alpine-csp-x-for.html>, <https://docs.hyva.io/hyva-themes/writing-code/csp/alpine-csp-hyva-createbooleanobject.html>

## Migration checklist

| Pattern to find | Action |
|---|---|
| `x-data="functionName()"` | register with `Alpine.data()`, drop the parentheses |
| `x-data="{…}"` inline object | extract to a named function, register it |
| `x-show="!prop"` / `x-if="!prop"` | add a method returning the negated value |
| `:class="{ 'name': condition }"` | add a method returning the class object |
| `@click="prop = value"` | add a mutation method |
| `@click="method('arg')"` | `data-*` attribute + `event.target.dataset` |
| `x-model="prop"` | `:value` + `@input` (or `@change`/`:checked`/`:selected`) |
| `x-for="item in method('arg')"` | pre-compute the array, reference the property |
| `x-spread` | replace with `x-bind` (Alpine v3) |
| a directive that "needs a component" | check for an ancestor `x-data` **first** — scope is inherited, so a member on a grandparent already resolves. Repeating a component the ancestor already has duplicates the instance silently (no console warning): `init()` runs twice and the visible markup stays bound to the outer copy |

## The CSP migration tool

`hyva-themes/upgrade-helper-tools` ships `hyva-csp-helper`. It needs PHP >= 8.1 and no Magento installation; a `composer.json` of type `magento2-theme`/`magento2-module` is recommended.

```bash
composer require --dev hyva-themes/upgrade-helper-tools:dev-main
composer exec hyva-csp-helper app/design/frontend/MyTheme/default | tee CSP-updates.md
```

**Never run it in production** — it rewrites files in place. Output is Markdown describing every change, marked `@DONE!` (works out of the box) or `@TODO!` (needs review), so no diff is needed afterwards. Multiple directories can be passed at once; `composer global exec` works too.

What it does, in order: checks composer requirements (theme-module >= 1.3.11; Hyvä Checkout >= 1.3.0 if present) → applies Alpine CSP compatibility → moves checkout scripts to the footer → adds `registerInlineScript()` calls.

Its Alpine pass removes `x-spread` (Alpine v2 legacy, replaced by `x-bind` since Alpine v3.0), replaces `x-model`, normalizes empty `x-data` to `x-data="{}"`, moves inline PHP into `data-*` attributes (prefixed `hyvacsp` and numbered, `escapeJs` → `escapeHtmlAttr`, `JSON.parse(...)` for JSON, `parseInt(...)` for `(int)`, `(… === true)` for booleans — note everything becomes a string), then generates an Alpine component script whose names are derived from the module/theme name so they are unique and traceable, binding inline components to global scope so they remain overridable.

Limitations: **frontend `*.phtml` only**. PHP models and view models need manual migration. It matches `(x-|@|:).*=".*"`, so Alpine attributes inside PHP arrays (e.g. `[":class" => "hello"]`, a common SVG pattern) are not handled.

Bulk `x-spread` → `x-bind` by hand (watch for duplicate `x-bind` attributes):

```bash
grep -Rl 'x-spread=' src/view/frontend/templates | xargs sed -i 's/x-spread=/x-bind=/'
```

**Checkout modules only**: Magewire loads content over XHR and cannot evaluate injected scripts, so scripts must live on the initially loaded page. The tool splits `page/awesome.phtml` into the component and `page/awesome-csp-js.phtml`, and registers the latter in `layout/hyva_checkout.xml`:

```xml
<referenceContainer name="magewire.plugin.scripts">
    <block name="page.awesome" template="Awesome_Module::page/awesome-csp-js.phtml"/>
</referenceContainer>
```

**Avoid per-instance unique scripts.** Each unique inline script adds another `sha256-` to the CSP header, and enough of them cause "Header too large". Prefer one shared function plus dataset attributes:

```php
<div x-data="myFunction"
     data-product-id="<?= $escaper->escapeHtmlAttr($block->getProductId()) ?>"
     data-config="<?= $escaper->escapeHtmlAttr($block->getJsonConfig()) ?>">
</div>
<script>
function myFunction() {
    return {
        id: parseInt(this.$el.dataset.productId),
        config: JSON.parse(this.$el.dataset.config)
    }
}
</script>
```

<https://docs.hyva.io/hyva-themes/writing-code/csp/migration-tool.html>

## Reducing CSP header size

The **experimental** `hyva-themes/magento2-minification` module can merge all inline JS into a single `<script>` before `</body>`, collapsing 20+ SHA-256 hashes into one. It runs in PHP and works independently of the Node minifier daemon, only on FPC-cacheable pages (uncacheable pages use a single nonce anyway), only for `type="text/javascript"` or untyped scripts, and it is Varnish-ESI compatible. Disabled by default:

```bash
bin/magento config:set hyva_minification/general/merge_inline_js 1
```

See `deployment-and-performance.md` for the rest of that module.

## Optimized CSP allowlist

Magento merges every installed extension's `csp_whitelist.xml` into the header regardless of whether the extension renders anything on the page. On a vanilla 2.4.8-p1, 25 of 46 allowed domain entries were usable in an XSS technique — `*.google.com` is allowlisted by `magento/module-payment-services-paypal`, and `https://accounts.google.com/o/oauth2/revoke?callback=alert(1337)` reflects the callback parameter.

```bash
composer require hyva-themes/magento2-optimized-csp-allowlist
bin/magento setup:upgrade
```

Two modes at `Stores > Configuration > Security > Content Security Policy (CSP)`: **Fully disable module allowlists** (default `No`; safest — you can still ship a `csp_whitelist.xml` in the theme) and **Enable allowlist optimization** (default `Yes`; an extension's allowlist is only included when one of its `.phtml` files actually renders on the current page).

Domains and hashes can also be registered from a template, which keeps the header tight and handles dynamic per-store or per-locale domains:

```php
$cspViewModel = $viewModels->require(\Hyva\OptimizedCspAllowlist\ViewModel\Hosts::class);
$cspViewModel->add('script-src', 'https://lang.host.ext');
```

The view model works in any theme, not just Hyvä, by injecting it as a block argument in layout XML and reading it with `$block->getCspViewModel()`.

<https://docs.hyva.io/hyva-themes/writing-code/csp/content-security-policy-allowlist.html>

## In-context payment buttons under strict CSP

For merchants disabling `unsafe-eval`/`unsafe-inline` on checkout only, in-context payment buttons on catalog and cart pages are the problem. `hyva-themes/magento2-csp-in-context-payment` renders those buttons in an **iframe** whose source is served from a route that already runs strict CSP. Out of the box only PayPal Express is supported; other PSPs can extend it using that implementation as the model. **Do not use it if the whole site already runs strict CSP.**

```bash
composer require hyva-themes/magento2-csp-in-context-payment
bin/magento setup:upgrade
```

Install it explicitly only when PayPal Express in-context buttons are enabled; other providers pull it in as a dependency.

To support another provider: add the composer dependency, choose action codes (PayPal uses `paypal_cart` for cart + mini-cart and `paypal_pdp` for the PDP), then declare in-iframe templates in `view/frontend/layout/payincontext_button_display_<code>.xml`:

```xml
<referenceContainer name="main">
    <block class="Magento\Paypal\Block\Express\InContext\Minicart\SmartButton"
           name="incontext-paypal-button"
           template="Hyva_CspInContextPayment::paypal/in-context/shortcut/in-iframe-button.phtml"
           cacheable="false"/>
</referenceContainer>
```

Only add `cacheable="false"` when the template server-renders customer-specific data; templates that rely on section data should leave it off. PayPal's mini-cart templates are set through `etc/frontend/di.xml` rather than layout XML — replace them with a plugin before the button is added to the ShortcutButtons container (see `Hyva\CspInContextPayment\Plugin\ShortcutButtonsPlugin`).

Cart/mini-cart buttons usually need few changes because section data is available inside the iframe. PDP buttons must submit the product form from inside the iframe, which the module supports with:

- `hyva.submitProductForm()` — promise resolving when the form is submitted and section data has reloaded; rejects if the form cannot be submitted (missing required options).
- `hyva.submitProductForm.reset()` — reset after a cancelled payment so it can be retried.
- `hyva.getCurrentCart()` — current cart from section data.
- `hyva.onProductFormIsValid(callback)` — called with a boolean on every form change.
- `hyva.dispatchTopWindowMessages()` — dispatch messages into the top window, as if calling `window.dispatchMessages` there.

```js
onClick(data, actions) { return hyva.submitProductForm(); },
createOrder() {
    const cart = hyva.getCurrentCart();
    const params = 'quote_id=' + cart.cartId + '&customer_id=' + (config.customerId || '')
        + '&form_key=' + hyva.getFormKey() + '&button=' + config.button;
    return window.fetch(config.getTokenUrl, {
        headers: {'X-Requested-With': 'XMLHttpRequest'},
        body: params, method: 'POST', mode: 'cors', credentials: 'include'
    }).then(r => r.json()).then(d => d.token).catch(console.error);
},
```

<https://docs.hyva.io/hyva-themes/writing-code/csp/csp-in-context-payment-buttons.html>
