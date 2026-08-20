# Alpine.js, JavaScript patterns and the `hyva` API

## The core architectural difference from Luma

Luma loads small external JS files through RequireJS with `data-mage-init` / `x-magento-init`, and renders arrays with `<script type="text/x-magento-template">` + `mage/template` + underscore.js, with state in Knockout observables.

Hyvä inlines JavaScript **in the `.phtml` template that uses it**. There is no compiler, no bundler, no jQuery, no Knockout, no RequireJS. Consequences the docs call out explicitly:

- Component isolation: HTML + Tailwind classes + JS in one file, no cross-file tracing.
- Only what is rendered is loaded — mirroring how Tailwind handles CSS.
- No dead code: the JS is written for that one component.
- Replaceable templates: a well-written `.phtml` has no external dependencies, so the cart drawer or gallery can be moved anywhere or swapped wholesale.

You *can* add a build step, a `main.js`, or any JS tooling on top — Hyvä just does not need one, and the trade-offs (complexity, larger polyfilled bundles, worse debuggability, dead code) are why it does not.

Hyvä also uses `.phtml` templates as its smallest component unit rather than atomic input/button components: better for template-level swapping, better for making existing Magento extensions compatible, and more familiar to Magento devs.

<https://docs.hyva.io/hyva-themes/faqs/javascript-files-and-compilers.html>, <https://docs.hyva.io/hyva-themes/faqs/why-not-smaller-components.html>, <https://docs.hyva.io/hyva-themes/compatibility-modules/from-luma-to-hyva/migrating-js-and-templates.html>

## Inlining a Luma script

1. Declare a uniquely named function in a `<script>` tag in the template and register it with Alpine:

```html
<script>
    function initMyComponent() {
        // ...
    }
    document.addEventListener('alpine:init', () => {
        Alpine.data('initMyComponent', initMyComponent)
    });
</script>
```

2. Copy the RequireJS module body in.
3. Replace dependencies with native JS (jQuery is almost always unnecessary — see youmightnotneedjquery.com).
4. Call it at the right time: on `private-content-loaded` if it needs customer section data; on `DOMContentLoaded` if it is in the head and needs `window.hyva`; otherwise inline right after the definition.

`<script type="text/x-magento-template">` loops become Alpine `x-for`:

```html
<template x-for="(product, index) in products" :key="index">
    <div><span x-html="product.qty"></span> x <span x-html="product.name"></span></div>
</template>
```

jQuery `$(el).data('example')` (which caches and auto-parses JSON) becomes `element.dataset.example` — a **live** view. Cache manually if you need the old behaviour:

```js
element.__example = JSON.parse(element.dataset.example);
element.removeAttribute('data-example');
```

Underscore equivalents: `_.isObject(x)` → `x === Object(x)`; `_.isArray` → `Array.isArray`; `_.has(x,p)` → `x === Object(x) && x.hasOwnProperty(p)`; `_.isEqual` → `JSON.stringify(x) === JSON.stringify(y)` for simple values.

## Keeping global scope tidy

Only Alpine initialization functions *need* global scope (they are referenced by name in `x-data`). Event subscribers and helpers should be private. Wrap them in an IIFE:

```html
<script>
(() => {
    function myEventCallback() { /* … */ }
    window.addEventListener('DOMContentLoaded', myEventCallback);
})();
</script>
```

Avoid conflict-prone names: `init()` is bad, `myCompanyMyModuleThisComponentInit()` is fine. For per-instance data, prefer passing config into the constructor over generating a unique function per item (unique functions inflate the DOM):

```html
<div x-data="initMyComponent({productId: <?= (int) $product->getId() ?>})">
```

<https://docs.hyva.io/hyva-themes/writing-code/patterns/keeping-global-scope-tidy.html>, <https://docs.hyva.io/hyva-themes/writing-code/patterns/avoid-conflicting-state-between-alpine-components.html>

## Communication between components

Events, not shared state.

```html
<button @click.prevent="$dispatch('name-changed', { name: 'John Doe' })">John Doe</button>
<div x-data="initComponent()" @name-changed.window="handleNameChange(event)">
```

Handler reads `event.detail.name`. With many listeners, move them into the component via `x-bind` (`x-spread` on Alpine v2):

```js
eventListeners: {
    ['@keydown.window.escape']() { /* … */ },
    ['@name-changed.window'](event) { this.handleNameChange(event); }
}
```

Debug from the console: `window.dispatchEvent(new CustomEvent('name-changed', {detail: {name: 'Test'}}))`, or `window.dispatchEvent(new Event('toggle-cart'))` to open the mini-cart on any Hyvä page.

<https://docs.hyva.io/hyva-themes/writing-code/patterns/communication-between-alpine-components.html>

## Hyvä JavaScript events

| Event | Direction | Notes |
|---|---|---|
| `private-content-loaded` | dispatched by Hyvä | All customer section data in `event.detail.data`, keyed by section name. Fires on every page load. Section data is **not** Knockout observables — changes propagate only via this event. |
| `reload-customer-section-data` | dispatch to Hyvä | Reload section data. No automatic per-section invalidation like Luma. |
| `toggle-mobile-menu` | dispatch | Show/hide the mobile menu overlay. |
| `toggle-authentication` | dispatch | Hyvä's authentication-popup equivalent. Redirects to checkout if logged in or guest checkout allowed; otherwise opens the auth slider. Override the redirect with `{detail: {url: '/'}}`. |
| `toggle-cart` | dispatch | Open the mini-cart. Since 1.3.0, `{detail: {isOpen: false}}` closes it (earlier versions would still open it). |
| `clear-messages` | dispatch (since 1.1.2) | Clears all splash messages. No payload. |
| `configurable-selection-changed` | dispatched (since 1.1.4) | PDP. Payload `{productId, optionId, value, productIndex, selectedValues, candidates}`; one candidate = selection complete. |
| `listing-configurable-selection-changed` | dispatched (since 1.2.4) | Same payload, on PLP. |
| `update-product-final-price` | dispatched | PDP, when options affect the price. |
| `update-prices-<productId>` | both | PDP/PLP. Keys `oldPrice`/`finalPrice` (incl. tax) or `baseOldPrice`/`basePrice` (excl. tax) on PDP; always `finalPrice`/`oldPrice` on PLP. `tierPrices` must be present, even as `[]`. |
| `update-qty-<productId>` | both | New qty in `event.detail`. |
| `update-custom-option-active`, `update-custom-option-prices` | both | Custom-option price tracking on the PDP. |
| `update-gallery` | both | Array of `{thumb, img, full, caption, position, isMain, type, videoUrl}`. Dispatch with `detail: []` to reset. |
| `init-external-scripts` | dispatched (1.1.20/1.2.0+) | Fired once on the first `touchstart`/`mouseover`/`wheel`/`scroll`/`keydown`. Fired on page load on the order success page so conversion tracking always runs. |
| `alpine:init`, `alpine:initialized` | Alpine | Register `Alpine.data()` / plugins in `alpine:init`. |
| `hyva-modal-show` | dispatch | `{detail: {dialog: 'my-modal'}}` — see the UI reference. |
| `pageshow` (with `event.persisted`) | browser | bfcache restore; reset stale state. |

<https://docs.hyva.io/hyva-themes/writing-code/hyva-javascript-events.html>

## Customer section data

- Loaded via Ajax and stored in local storage; broadcast on every page load with `private-content-loaded`.
- **All sections are always one object.** You cannot subscribe to a single section like in Luma.
- Automatically invalidated after HTTP POST requests; refreshed on the next page load.
- After an Ajax POST, dispatch `reload-customer-section-data` manually.
- Data is refetched only if local storage is empty, older than 1 hour, or `private_content_version` changed.
- Force a refresh: `hyva.setCookie('mage-cache-sessid', '', -1, true);` then dispatch `reload-customer-section-data`.
- **Never** delete `private_content_version` or `cookieVersion` cookies — section data then stops reloading correctly.
- Invalidate without reloading: `hyva.getBrowserStorage()?.removeItem('mage-cache-storage')`.
- Server side: inject `Magento\Framework\App\PageCache\Version` and call `$version->process()` during a POST. Magento already does this for frontend and GraphQL POSTs (not REST).

Visitors without a server session get **default section data** rendered into the page source rather than fetched (since 1.3.6), reducing requests. Extensions that need a section always populated declare defaults in `etc/frontend/di.xml`:

```xml
<type name="Hyva\Theme\ViewModel\CustomerSectionData">
    <arguments>
        <argument name="defaultSectionDataKeys" xsi:type="array">
            <item name="directory-data" xsi:type="boolean">true</item>
            <item name="wishlist" xsi:type="string">{"items": []}</item>
        </argument>
    </arguments>
</type>
```

Inspect live data from the console:

```js
addEventListener('private-content-loaded', event => console.log(event.detail.data));
dispatchEvent(new Event('reload-customer-section-data'));
```

Run code only once when data first loads with `{ once: true }`:

```js
window.addEventListener('private-content-loaded', initMyCode, { once: true });
```

<https://docs.hyva.io/hyva-themes/writing-code/working-with-sectiondata.html>, <https://docs.hyva.io/hyva-themes/writing-code/patterns/running-code-once-when-private-data-is-loaded.html>

## The `window.hyva` object

Defined in `vendor/hyva-themes/magento2-theme-module/src/view/frontend/templates/page/js/hyva.phtml`.

| Method | Since | Purpose |
|---|---|---|
| `hyva.getCookie(name)` | | Read a cookie. |
| `hyva.setCookie(name, value, days, skipSetDomain)` | | `skipSetDomain` avoids duplicate cookies when Magento itself sets one without a domain (e.g. `mage-messages`). |
| `hyva.setSessionCookie(name, value, skipSetDomain)` | 1.2.9 / 1.3.5 | Same, without expiry. |
| `hyva.getBrowserStorage()` | | `localStorage`, falling back to `sessionStorage`, else logs a warning and returns `false` (iOS Safari private mode). |
| `hyva.postForm({action, data, skipUenc})` | `skipUenc` 1.2.4 | Builds and submits a hidden form; adds `uenc` and `form_key`. |
| `hyva.getFormKey()` | | Form key from the `form_key` cookie, generated if missing. |
| `hyva.getUenc()` | 1.1.17 | Base64 of `window.location.href`, encoded compatibly with `\Magento\Framework\Url\Encoder::encode()`. |
| `hyva.trapFocus(el)` / `hyva.releaseFocus(el)` | 1.2.6 | Keyboard focus trap. |
| `hyva.formatPrice(value, showSign, options = {})` | `options` 1.3.6; `groupSeparator`/`decimalSeparator` 1.3.10 | `options` is passed to `Intl.NumberFormat`. |
| `hyva.str(string, ...args)` | 1.1.17 | `%1`-based positional replacement, matching PHP `__()`. `%%2` yields a literal `%2`. |
| `hyva.strf(string, ...args)` | 1.1.14 | Same but `%0`-based. Prefer `hyva.str` so phrases can be shared with PHP. |
| `hyva.replaceDomElement(targetSelector, content)` | 1.1.14 | Replace a DOM subtree with the same selector from an HTML string; extracts `<script>` tags into the head so they execute. |
| `hyva.activateScripts(node)` | 1.3.6 | Move script children of an Element into the head so the browser parses them. |
| `hyva.alpineInitialized(callback)` | 1.2.8 / 1.3.4 | Runs after Alpine is initialized regardless of Alpine version. Safer than `load` on cached pages in mobile Safari. |
| `hyva.createBooleanObject(name, value, additionalMethods)` | 1.3.11 | CSP-friendly toggle object — see the CSP reference. |
| `hyva.safeParseNumber(rawValue)` | 1.3.11 | Same logic as Alpine's `x-model.number`. |

`window.dispatchMessages(messages, timeoutMs)` shows messages; each entry is `{type, text}` with `type` one of `success`, `notice`, `warning`, `error`. HTML and `<br/>` are allowed in `text`. Without a timeout the message persists until dismissed.

Cookie consent: by default cookies are only stored with visitor consent. Force one to always be stored by pushing its name into the necessary list:

```js
window.addEventListener('load', () => {
  window.cookie_consent_config = window.cookie_consent_config || {};
  window.cookie_consent_config.necessary = window.cookie_consent_config.necessary || [];
  window.cookie_consent_config.necessary.push('my-new-cookie')
})
```

<https://docs.hyva.io/hyva-themes/writing-code/the-window-hyva-object.html>, <https://docs.hyva.io/hyva-themes/writing-code/window-dispatchmessages.html>

## URLs in JavaScript

No `mage/url`. Use the globals:

```js
`${BASE_URL}example/path/action`
`${BASE_URL}rest/${CURRENT_STORE_CODE}/example/path/action`
```

Or render with PHP: `'<?= $escaper->escapeUrl($block->getBaseUrl()) ?>example/path/action'`.

<https://docs.hyva.io/hyva-themes/writing-code/building-urls-in-js.html>

## `fetch()` instead of `$.ajax`

```js
const body = new URLSearchParams({form_key: hyva.getFormKey(), foo: 'bar'});
fetch(url, {method: 'post', body, headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'}})
```

Header names may be camelCase or 'Kebab-Case'. To mimic an XHR Ajax request add `{'X-Requested-With': 'XMLHttpRequest'}`. GraphQL from JS: POST `BASE_URL + "graphql"` with `JSON.stringify({query})`, or GET `/graphql?` + `new URLSearchParams({query})`.

Abort in-flight requests with `AbortController` (the `$.ajax().abort()` equivalent) — always create a **new** controller after aborting, an aborted signal cannot be reused:

```js
let controller;
function onUpdate() {
    if (controller) controller.abort();
    controller = new AbortController();
    window.fetch(url, {signal: controller.signal, method: 'post', headers, body}).then(/* … */);
}
```

<https://docs.hyva.io/hyva-themes/writing-code/using-fetch.html>, <https://docs.hyva.io/hyva-themes/writing-code/patterns/aborting-ajax-requests.html>

## Overriding JavaScript without copying the template

Copying a `.phtml` into a child theme masks upstream JS changes and makes upgrades expensive. Instead, render a **second template after the original** and redeclare only the function/method/property you need.

Recipe: find the template with the original JS → find its layout XML block → declare a new block rendered after it (`after="…"` in the same container, or `before.body.end`) → override just what changes.

```html
<script>
  (() => {
    const origFormatPrice = hyva.formatPrice;
    // `function` (not arrow) so `arguments` captures future parameters
    hyva.formatPrice = function (value, showSign, options = {}) {
      if (value > 0) return origFormatPrice.apply(this, arguments);
      return '<?= $escaper->escapeJs(__('FREE!')) ?>';
    }
  })()
</script>
```

For Alpine components (`init*` constructor functions), mutate the returned instance:

```html
<script>
  (() => {
    const origInit = initConfigurableOptions;
    window.initConfigurableOptions = function () {
      const instance = origInit.apply(this, arguments)
      const origInitMethod = instance.init;
      instance.init = function () {
        origInitMethod.apply(instance, arguments)
        for (const [attributeId, options] of Object.entries(instance.allowedAttributeOptions)) {
          if (options.length === 1) instance.changeOption(attributeId, Object.values(options)[0].id)
        }
      }
      return instance;
    }
  })()
</script>
```

Because each override calls the previous reference, multiple modules can customize the same method without conflict. `Proxy` and `Object.defineProperty` are equivalent alternatives (a `Proxy` handler's `apply(target, thisArg, argArray)` is not the same as `Function.prototype.apply`).

Note: `hyva.formatPrice` only handles the JS side. Server-rendered prices come from `\Magento\Framework\Pricing\PriceCurrencyInterface::format`.

<https://docs.hyva.io/hyva-themes/writing-code/patterns/overriding-js.html>

## Rendering JS only once per page (since 1.3.6)

When a template is rendered many times (product list items), split the JS into its own template and declare it as a dependency so it renders once in `before.body.end`.

Layout XML (**preferred** — survives the `block_html` cache):

```xml
<block class="Magento\Catalog\Block\Product\AbstractProduct" name="product_list_item"
       template="Magento_Catalog::product/list/item.phtml">
    <arguments>
        <argument name="hyva_js_block_dependencies" xsi:type="array">
            <item name="category.products.list.js.wishlist" xsi:type="boolean">true</item>
        </argument>
    </arguments>
</block>
```

`hyva_js_template_dependencies` works the same way for templates. A `false`/`null`/empty value disables the dependency, so themes can opt out.

From PHP (breaks if the block is served from `block_html` cache):

```php
$pageJsRegistry = $viewModels->require(\Hyva\Theme\ViewModel\BlockJsDependencies::class);
$pageJsRegistry->setBlockNameDependency($block, 'category.products.list.js.wishlist');
$pageJsRegistry->setBlockTemplateDependency($block, 'Magento_Catalog::product/list/js/wishlist.phtml');
```

<https://docs.hyva.io/hyva-themes/writing-code/rendering-javascript-once.html>

## Loading external JavaScript

A plain `<script src="https://…">` in the head is the single biggest INP killer. Load programmatically, deferred:

```js
window.addEventListener('init-external-scripts', () => {
    // GTM, analytics, pixels, chat, HotJar, …
}, {once: true, passive: true});
```

For Hyvä < 1.1.20, subscribe to the interaction events directly:

```js
(events => {
  const loadMyLibrary = () => {
    events.forEach(type => window.removeEventListener(type, loadMyLibrary))
    // load here
  };
  events.forEach(type => window.addEventListener(type, loadMyLibrary, {once: true, passive: true}))
})(['touchstart', 'mouseover', 'wheel', 'scroll', 'keydown'])
```

Loading *many* libraries on `init-external-scripts` also hurts INP — prefer per-element triggers (load on form focus, on click, on `x-intersect`). Always escape generated URLs: `$escaper->escapeUrl()` in attributes, `$escaper->escapeJs()` in JS strings.

**Facade pattern** for anything that would otherwise cause CLS (live chat, search providers, video embeds): render a placeholder occupying the same space and looking like the real widget, load the real script on interaction, and programmatically re-click so the user does not need two clicks. The facade's class/ID/data attributes and DOM position must match the vendor's so it gets replaced.

Loading a library that provides an Alpine component: set `x-data`/`x-init` after the script loads and re-init the tree — `Alpine.initializeComponent(target)` on v2, `Alpine.initTree(target)` on v3. For a *nested* component, hide its markup from the parent scope in a `<script type="text/html">` and copy `innerHTML` into the target before init.

Caveat on browser HTTP caching / multiple tabs: a localStorage flag can trigger already-cached scripts on load, but parsing large cached scripts still costs main-thread time.

<https://docs.hyva.io/hyva-themes/writing-code/patterns/loading-external-javascript.html>

## Small patterns

**Mobile-only behaviour** — combine `matchMedia` with `<template x-if>` so hidden markup is not in the DOM at all (Google counts hidden DOM):

```js
init() {
    const matchMedia = window.matchMedia('(max-width: 768px)');
    this.isMobile = matchMedia.matches;
    if (typeof matchMedia.onchange !== 'object') {
        matchMedia.addListener(e => this.isMobile = e.matches);   // iOS 12/13 fallback
    } else {
        matchMedia.addEventListener('change', e => this.isMobile = e.matches);
    }
}
```

**Visual feedback** — often no JS at all is needed thanks to `x-ref`:

```html
<div x-data="{ isSelected: true }">
    <input type="checkbox" x-model="isSelected">
    <img :class="{ 'opacity-40': isSelected}">
</div>
```

**Auto-apply cart qty (PHP cart)** — the cart deliberately requires clicking "Update Shopping Cart". To auto-submit, add to the qty input in `Magento_Checkout/templates/php-cart/item/default.phtml`:

```html
@change.debounce.2000ms="$event.target.form && $event.target.form.dispatchEvent(new Event('submit', { cancelable: true }));"
```

Using `dispatchEvent` (not `.submit()`) triggers `hyva.postCart`, reloading the cart via Ajax. For a non-Ajax full submit use `x-on:change.debounce.2000ms="$event.target.form.submit()"`.

**Preselect configurable options** via URL: `?<attribute_code>=<optionId>` (query) or `#<attributeId>=<optionId>` (hash).

**Coming from PWA/SPA**: unregister service workers, Hyvä does not use them.

<https://docs.hyva.io/hyva-themes/writing-code/patterns/running-js-only-on-mobile.html>, <https://docs.hyva.io/hyva-themes/writing-code/patterns/visual-feedback-to-user-actions.html>, <https://docs.hyva.io/hyva-themes/faqs/auto-apply-qty-updates-in-php-cart.html>, <https://docs.hyva.io/hyva-themes/faqs/preselecting-configurable-options.html>, <https://docs.hyva.io/hyva-themes/faqs/moving-over-from-pwa.html>

## Alpine plugins shipped with Hyvä

| Directive | Availability | What it does |
|---|---|---|
| `x-intersect` | native in Alpine v3; backported to v2 since theme-module 1.1.10 | Trigger on viewport intersection. |
| `x-ignore` | native in Alpine v3; backported to v2 since 1.3.7 | Alpine skips the subtree. Used together with `x-defer`. |
| `x-defer` | Hyvä 1.3.7+ | Defer component initialization. |
| `x-snap-slider` | Hyvä 1.4+ | CSS scroll-snap sliders with JS nav/pager/a11y. |
| `x-htmldialog` | Hyvä 1.4+ | Native `<dialog>` integration with `x-show`. |
| `x-collapse` | Hyvä UI | On Hyvä 1.4+ this is handled by native CSS + `<details>`; if you still use the plugin set `[x-collapse] { interpolate-size: numeric-only; }` for the open animation. |

Add an official or third-party Alpine plugin as an inline script registered on `alpine:init`, loaded through layout XML:

```html
<script>
    (() => {
        const yourPlugin = (alpine) => {
            alpine.directive('your-directive', (el, { expression }, { evaluate }) => {
                console.log(evaluate(expression));
            });
        };
        document.addEventListener("alpine:init", () => { window.Alpine.plugin(yourPlugin); });
    })();
</script>
<?php $hyvaCsp->registerInlineScript() ?>
```

```xml
<referenceBlock name="script-alpine-js">
    <block name="alpine-plugin-custom" template="Acme_Module::page/js/plugins/custom.phtml"/>
</referenceBlock>
```

Reference implementations live in `Hyva_Theme` under `view/base/templates/page/js/plugins/v3/`.

<https://docs.hyva.io/hyva-themes/working-with-alpinejs/alpine-plugins/index.html>, <https://docs.hyva.io/hyva-themes/working-with-alpinejs/alpine-plugins/custom.html>

### `x-defer`

Placed on the same element as `x-data`. Values: `intersect` (most common — init when entering the viewport, immediately if already visible), `interact` (first `touchstart`/`mouseover`/`wheel`/`scroll`/`keydown`), `idle` (`requestIdleCallback`, with the admin timeout, default 4000 ms), `event:eventname` (observed on `window`).

Deferred components **miss earlier events**, most notably `private-content-loaded`. Workaround:

```html
<div x-data="{cart: null}"
     x-defer="intersect"
     x-init="$dispatch('reload-customer-section-data')"
     @private-content-loaded="cart = $event.details.data.cart">
```

Rules can also be injected by selector via layout XML:

```xml
<referenceBlock name="alpine-defer-rules">
  <arguments>
    <argument name="deferred_components" xsi:type="array">
      <item name=".product-slider > div > section[x-data]" xsi:type="string">intersect</item>
    </argument>
  </arguments>
</referenceBlock>
```

or via `Hyvä Themes > General > Deferred Alpine.js Components > Defer components`. Default backend selectors: `.product-slider section[x-data]`, `.product-info [x-data]`, `#filters-content [x-data]`, `#review_form`, `section[x-data^=initRecentlyViewedProductsComponent]`, `div[x-data^=initBundleOptions]`, `#product_addtocart_form [x-data]`, `#notice-cookie-block`.

Since 1.3.7 the Default Theme already carries `x-defer` in its templates, so on a theme based on 1.3.7+ the backend rules are redundant and removing them can reduce TBT further. Disable injection entirely with `<referenceBlock name="alpine-defer-rules" remove="true"/>`.

Be selective: `x-defer` on *every* component can increase main-thread blocking rather than reduce it.

<https://docs.hyva.io/hyva-themes/working-with-alpinejs/alpine-plugins/x-defer.html>

### `x-htmldialog` (Hyvä 1.4+)

```html
<div x-data="{ open: false }">
    <button @click="open = !open">Open</button>
    <dialog x-show="open" x-htmldialog="open = false">…</dialog>
</div>
```

It stops `x-show` from toggling `display`, calls `el.showModal()` instead, and evaluates the directive value when the dialog is closed by Escape or a backdrop click.

Modifiers: `.noscroll` (page scroll lock — unnecessary on Default Theme 1.4, which uses `:where(:root:has(dialog[open]:modal)) { overflow: hidden; }`); `.closeby.<value>` or a `closeby="…"` attribute (polyfilled) with `any` (ESC or backdrop), `closerequest` (default: ESC / `method="dialog"` submit only), `none` (programmatic close only).

<https://docs.hyva.io/hyva-themes/working-with-alpinejs/alpine-plugins/x-htmldialog.html>

### `x-snap-slider` (Hyvä 1.4+)

Progressive enhancement over CSS scroll-snap. Requires a container with `x-data` and a direct child with `[data-track]`. Manages the `inert` attribute for off-screen slides and adds ARIA labels.

```html
<section x-data x-snap-slider.auto-pager.loop>
    <div data-track><!-- slides --></div>
    <div data-pager></div>
</section>
```

Modifiers: `.auto-pager` (generates markers; insert point controlled by an empty `[data-pager]`; give it a `min-height` to avoid CLS), `.group-pager`, `.loop` (1.4.7+), `.force-pager` (1.5.2+).

Data attributes: `data-track` (**required**), `data-next`, `data-prev`, `data-pager`, `data-loop` (`false`), `data-force-pager` (`false`), `data-pager-class` (`snap-pager`), `data-marker-class` (`snap-marker`), `data-slide-label-sepparator` (`of`).

Custom pagers: each slide inside `[data-track]` needs a unique `id`; markers link via `href="#slideId"` or a `<button data-target-id="slideId">`.

**No autoplay, by design** (a11y). Alternatives via Hyvä UI: Marquee Slider for decorative motion, SplideJS for genuine autoplay requirements.

<https://docs.hyva.io/hyva-themes/working-with-alpinejs/alpine-plugins/x-snap-slider.html>

## Writing Alpine v2- and v3-compatible code (extension authors)

- Add **both** `x-spread="overlay()"` and `x-bind="overlay()"`.
- `$el` means the component root in v2 but the current binding element in v3 — only use `$el` on the `x-data` element; otherwise use `x-ref`/`querySelector`.
- `$root` does not exist in v2: avoid it, or alias it in `init(root)`.
- v3 calls `init` automatically, v2 does not — always write `x-init="init"` explicitly.
- `@click.away` (v2) was renamed `@click.outside` (v3): write `@click.away.outside="…"`.
- Avoid plugins that do not exist for both versions (`x-intersect` is safe because Hyvä backports it).
- Render version-specific templates via `etc/hyva-libraries.json` and `\Hyva\Theme\ViewModel\ThemeLibrariesConfig::getVersionIdFor`:

```php
$version = $themeLibrary->getVersionIdFor('intersect-plugin')
    ?: $themeLibrary->getVersionIdFor('alpine')
    ?: '2';
echo $block->fetchView($block->getTemplateFile("Hyva_Theme::page/js/plugins/v${version}/intersect.phtml"));
```

- Declare a minimum Alpine version with layout XML; a console warning naming the module is logged on older themes:

```xml
<referenceBlock name="require-alpine-v3">
    <block name="My_Module"/>
</referenceBlock>
```

There is no mechanism for declaring a *maximum* Alpine version. Check the running version in the console with `Alpine.version`.

<https://docs.hyva.io/hyva-themes/working-with-alpinejs/alpine-v2-and-v3-compatible-code.html>

## Supporting old iOS Safari (archived guidance)

Officially the minimum is Safari 16. Per Hyvä version: 1.4+ (Tailwind v4) → Safari 15.4; 1.3.x (v3) → 14.5; 1.1.x (v2) → 12.2. On 1.3.x you can extend support by relying on `postcss-preset-env` (bundled since 1.3.6) and replacing flexbox `gap-*` classes with `space-*` equivalents (flex `gap` needs Safari 14.5+). Polyfills for `queueMicrotask` (→ iOS 12.0) and `Array.prototype.flat`/`flatMap` can be added as a `head.additional` child block. Hyvä 1.1.x bundled a patched Alpine 3.12.3 supporting iOS 12.2 (native Alpine 3.12.3 needs 13.4 due to `??`). Hyvä 1.1.x is no longer supported.

Cloudflare Rocket Loader breaks Hyvä <= 1.2.3; add `data-cfasync="false"` to the affected scripts.

<https://docs.hyva.io/hyva-themes/faqs/supporting-older-mobile-safari.html>, <https://docs.hyva.io/hyva-themes/faqs/troubleshooting.html>
