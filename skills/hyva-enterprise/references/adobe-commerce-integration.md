# Adobe Commerce integration: Commerce features, GTM, Live Search, Product Recs, Data Services

## Adobe Commerce-only feature modules

The `commerce-metapackage` provides Hyvä storefront compatibility for the Adobe
Commerce-only features: **Gift Card, Gift Wrapping, Reward Points, RMA, Multiple
Wishlist, Customer Balance, Customer Custom Attributes, Catalog Events, Gift
Registry (initial), Versions CMS** and more. Module names follow
`Hyva_Magento<Feature>` (`Hyva_MagentoGiftCard`, `Hyva_MagentoReward`,
`Hyva_MagentoRma`, `Hyva_MagentoMultipleWishlist`, `Hyva_MagentoCustomerBalance`,
`Hyva_MagentoGiftWrapping`, `Hyva_MagentoAdvancedCheckout`,
`Hyva_MagentoCatalogEvent`, `Hyva_MagentoCustomerCustomAttributes`,
`Hyva_MagentoVersionsCms`), plus the shared `Hyva_Enterprise` module.

The Hyvä Checkout side (`commerce-checkout-metapackage`, `Hyva_EnterpriseCheckout`)
covers store credit / customer balance, reward points and gift wrapping in checkout.

`Hyva_Enterprise` also ships an admin side: an admin theme `Hyva/commerce` whose
LESS variables are overridden at compile time by
`\Hyva\Enterprise\Plugin\AdminThemeLessVariableOverrides` (registered in `di.xml`),
and a "Hyvä Enterprise" admin configuration tab (`hyva_commerce`, declared in
`src/etc/adminhtml/system.xml`). `Hyva_Enterprise` declares a hard `sequence`
dependency on `Hyva_Commerce` in `module.xml`.

<https://docs.hyva.io/hyva-enterprise/upgrading/commerce/theme-upgrading-to-1.0.0.html>

## The switcher component (`Hyva_Enterprise` >= 1.0.7)

A reusable abstract "action switcher": a container for a set of actions that
orchestrates their rendering and the invocation of their business logic. Template:
`Hyva_Enterprise::form/actions/switcher.phtml`. Used e.g. by the
`Magento_NegotiableQuote` compatibility module for quote item mass actions.

```xml
<block name="quote_items.mass_actions.switcher"
       template="Hyva_Enterprise::form/actions/switcher.phtml">
    <arguments>
        <argument name="switcher_name" xsi:type="string">quoteItems</argument>
        <argument name="target_element_id" xsi:type="string">form-quote-items-update</argument>
        <argument name="item_selector" xsi:type="string">input[type="checkbox"][name^="quote-item-"]:checked</argument>
    </arguments>
    <block name="quote_items.mass_actions.remove"
           template="Hyva_MagentoNegotiableQuote::quote/item/actions/mass/remove.phtml">
        <arguments>
            <argument name="action_name" xsi:type="string">removeItems</argument>
        </arguments>
    </block>
</block>
```

Switcher arguments: `switcher_name` (**required**; prefixes the component name, its
`x-ref`, and the switcher-specific event listeners), `target_element_id` (id of the
associated element, typically a `<form>`), `item_selector` (query selector applied
to the target element to get the elements actions operate on), `label` (rendered
above the switcher, passed through the translation function). Action blocks require
`action_name`, used to register and execute the callback.

No block class is needed - just the template plus arguments.

**Registration.** A callback receives `targetElement` (element matching
`target_element_id`) and `items` (`targetElement.querySelectorAll(item_selector)`).
Child actions inherit the switcher's properties and can self-register:

```html
<div x-data="actionComponentFoo" x-init="init">
    <?= $escaper->escapeHtml(__('Foo')); ?>
</div>
<script>
    'use strict';
    function actionComponentFoo()
    {
        return {
            init()
            {
                this.registerAction('foo', (targetElement, items) => {
                    // ...
                });
            },
        }
    }
</script>
```

External registration and execution use events named
`register-{{switcher_name}}-action` and `execute-{{switcher_name}}-action`. Event
names are always lowercase because HTML attributes are not case sensitive
(`fooSwitcher` -> `fooswitcher`).

```js
window.dispatchEvent(new CustomEvent('register-fooswitcher-action', {
    detail: { name: 'foo', callback: (targetElement, items) => { /* ... */ } },
}));

window.dispatchEvent(new CustomEvent('execute-fooswitcher-action', {
    detail: { name: 'foo' },
}));
```

Self-registered actions are executed automatically by a click handler on each
action's containing element. The switcher component is merged with the
`hyva.modal()` view utility, so modal helpers are available inside action code.
Remove an action with layout XML:

```xml
<referenceBlock name="quote_items.mass_actions.remove" remove="true"/>
```

<https://docs.hyva.io/hyva-enterprise/devdocs/commerce/switcher-component.html>

## Google Tag Manager

Covers **only** Adobe Commerce's native GTM implementation plus its Hyvä
compatibility module (`Hyva_MagentoGoogleTagManager`); third-party GTM extensions
are out of scope. Requires Hyvä default theme **>= 1.3.10**. Admin configuration is
Adobe's standard GTM configuration.

Architecture: an initialization template plus per-scenario event templates pushing
structured data to `dataLayer`, with a view model
`Hyva\MagentoGoogleTagManager\ViewModel\GoogleTagManager` formatting product/order
data. Configuration is via layout XML arguments, so customisation rarely needs
template overrides.

Initialization: `Hyva_MagentoGoogleTagManager::google_tagmanager_analytics.phtml`
loads the GTM script, initialises `dataLayer`, then dispatches the `ga-initialized`
JavaScript event - the entry point for all other GTM tracking.

### Events and blocks

| Scenario | Block name(s) | Template(s) |
|---|---|---|
| Banner / dynamic block | `gtm.banner` | `Hyva_MagentoGoogleTagManager::banner.phtml` |
| Add to cart | `gtm.cart.add`, `gtm.product.list.add`, `gtm.product.detail.add` | `cart/add.phtml`, `product/add.phtml`, `product/bundle/add.phtml`, `product/grouped/add.phtml` |
| Empty cart | `gtm.cart.empty` | `cart/empty.phtml` |
| Remove from cart | `gtm.cart.remove` | `cart/remove.phtml` |
| Update cart | `gtm.cart.update` | `cart/update.phtml` |
| Checkout success | `gtm.checkout.success` | `Hyva_EnterpriseCheckout::checkout/success.phtml` |
| Checkout step navigation | `checkout.gtm.navigator` | `Hyva_EnterpriseCheckout::checkout/gtm/navigator.phtml` |
| PDP view | `product_view_detail` | `Hyva_EnterpriseCheckout::detailproduct.phtml` |
| Product list impressions/clicks | `gtm.impression`, `crosssell_products_impression`, `search_result_impression`, `advanced_result_impression` | `Hyva_EnterpriseCheckout::impression.phtml` |

Custom JS events: `cart-item-added` (products added or qty increased),
`cart-item-removed` (products removed or qty reduced), `ga-initialized`.

Details worth knowing:

- The banner script renders on **every** page and records an impression for any
  banner present, with **no viewport visibility check** (mirrors Adobe's behaviour).
- `cart-item-added` / `cart-item-removed` listeners always expect `event.detail` to
  be an **array of products**, even for a single product. `cart-item-removed` is also
  dispatched by the default theme's
  `Magento_Checkout/templates/php-cart/item/renderer/actions/remove.phtml` and
  `Magento_Theme/templates/html/cart/cart-drawer.phtml`.
- `product/add.phtml` is generic for PLP and PDP; the `is_product_page` flag
  (default `false`) switches: product source (parent `<block>` vs
  `Hyva\Theme\ViewModel\ProductPage`), an early return when the product has
  required custom options, the configurable-selection event
  (`listing-configurable-selection-changed` vs `configurable-selection-changed`),
  the price element selector, qty source (minimum sale qty vs input value) and the
  trigger (Add to Cart click vs form submission). Bundle and grouped PDPs use
  dedicated templates because of dynamic price/SKU and per-child tracking.
- Update-cart tracking re-binds its click listener after the cart DOM is replaced.
- Checkout step navigation listens to Hyvä Checkout's `checkout:step:loaded` event
  and pushes step name, position and cart products; checkout success pushes order id,
  grand total, tax, shipping, discount code and purchased products.
- Impressions support category, search, advanced search, cross-sell, related and
  upsell lists. On category pages the category name is used; the keyword `category`
  is reserved for this in `impression_list`.

### Layout arguments

| Block group | Argument | Default |
|---|---|---|
| banner | `impression_event_name` / `click_event_name` | `promotionView` / `promotionClick` |
| banner | `banner_selector` (`querySelectorAll`) | `[data-banner-id]` |
| add to cart | `event_name` | `addToCart` |
| add to cart | `button_selector` | `button[data-addto="cart"]` |
| add to cart | `skip_product_types` (array, keys = type code, values boolean) | `bundle`, `giftcard`, `grouped` |
| add to cart | `is_product_page` | `false` |
| empty cart | `event_name` / `button_selector` | `removeFromCart` / `#empty_cart_button` |
| remove from cart | `event_name` | `removeFromCart` |
| update cart | `button_selector` | `button[name="update_cart_action"]` |
| update cart | `cart_item_selector` / `cart_item_qty_selector` | `#shopping-cart-table tbody` / `[data-role="cart-item-qty"]` |
| checkout success | `event_name` | `purchase` |
| checkout step nav | `event_name` | `checkout` |
| PDP | `event_name` (since `0.1.1`) | `productDetail` |
| PDP | `show_category` | `true` |
| impressions | `impression_event_name` / `click_event_name` | `productImpression` / `productClick` |
| impressions | `click_selector` | `a` |
| impressions | `impression_list` (array, children `product_selector` + `list_name`) | - |

Scripts are **not rendered at all** when `banner_selector`, the update-cart
`button_selector`, or `impression_list` is missing or empty. `show_category` uses
`Magento\GoogleTagManager\Block\ListJson::getCurrentCategory()` via the
`current_category` registry key, so the category can be empty. `list_name` is looked
up in the view model's `listTypeConfigMap`, configured in `di.xml`.

### Customisation

Plugin the view model rather than copying templates:

| Data | Method |
|---|---|
| Cart items | `getCartItemData()` |
| Order items (checkout success) | `getOrderItemData()` |
| Checkout step items | `getCheckoutItemData()` |
| Product page | `getProductPageData()` |

```xml
<referenceBlock name="gtm.cart.add">
    <arguments>
        <argument name="event_name" xsi:type="string">custom_add_to_cart</argument>
    </arguments>
</referenceBlock>
```

<https://docs.hyva.io/hyva-enterprise/devdocs/commerce/google-tag-manager.html>

## Data Services (`Hyva_MagentoDataServices`)

Foundation for eventing on an Adobe Commerce storefront: access to the Adobe data
layer plus an event publishing service. **All Sensei/Services modules build on it.**

```bash
composer require hyva-themes/magento2-ee-magento-data-services
bin/magento setup:upgrade
```

Debug with the Snowplow Analytics Debugger or Snowplow Inspector Chrome extensions.
It wraps Adobe's `@adobe/magento-storefront-events-sdk` and
`@adobe/magento-storefront-event-collector` npm SDKs (bumped over time to 1.17.0).

**Every page load must generate a `page-view` event** - Commerce ML jobs depend on
it. Required event sets:

- Live Search dashboard: `page-view`, `search-request-sent`,
  `search-response-received` for unique/zero-result/popular searches; plus
  `search-results-view` and `search-product-click` for avg. click position and CTR;
  plus `product-view`, `add-to-cart` and `place-order` for conversion rate.
- Product Recommendations dashboard: `page-view`, `recs-request-sent`,
  `recs-response-received`, `recs-unit-render` for impressions; plus
  `recs-unit-view` for views/vCTR; plus `recs-item-click` and
  `recs-add-to-cart-click` for clicks/CTR; plus `place-order` for revenue.

Tracked beyond catalog pages: Hyvä Checkout (page type + cart data on checkout
initialization) and customer account actions - account create/register, login,
logout, account edit and address book edit, the edit events including account type
(personal vs company/B2B).

Other behaviours: a `ds-cart` local-storage entry holds cart items; an API-key view
model suppresses output when no keys are configured; plugin output is suppressed on
non-Hyvä storefronts; `\Hyva\MagentoDataServices\ViewModel\CheckoutSuccessContextProvider`
re-implements public methods that Adobe removed or retyped in
`\Magento\DataServices\ViewModel\Checkout\SuccessContextProvider` 7.5.0.

<https://docs.hyva.io/hyva-enterprise/devdocs/sensei/data-services/index.html>
<https://docs.hyva.io/hyva-enterprise/upgrading/sensei/changelog.html>

## Data Connection (`Hyva_MagentoExperienceConnector`)

Separate metapackage (`hyva-themes/magento2-hyva-enterprise-data-connection`)
providing Hyvä compatibility for `Magento_ExperienceConnector`, i.e. sending
storefront behavioural data to **Adobe Experience Platform**. Requires
`magento/module-experience-connector`. Independent from Live Search and Product
Recommendations, but shares `Hyva_MagentoDataServices`.

<https://docs.hyva.io/hyva-enterprise/upgrading/data-connection/changelog.html>

## Live Search (`Hyva_MagentoLiveSearch`)

```bash
composer require hyva-themes/magento2-ee-magento-live-search
bin/magento setup:upgrade
```

Overrides default search behaviour with a "search as you type" popover. One Hyvä
module bundles compatibility for `magento/module-live-search`,
`-live-search-metrics`, `-live-search-product-listing`,
`-live-search-storefront-popover` and `-live-search-terms`, so **all Live Search
customisation happens in this one module**. Depends on Data Services for eventing.

- Adobe's Search SDK is **deprecated** but still used for search-as-you-type (as in
  Luma). It cannot query additional custom attributes - for that, implement a custom
  solution on the GraphQL **Catalog Service**.
- Popover appearance is customised by overriding the frontend templates/classes;
  Adobe documents the CSS class names.
- Feature parity added over time: Minimum Query Length and Autocomplete Limit config
  options; search filtered by product visibility, stock status and customer group; no
  price for composite product types; placeholder-image fallback; popover image `alt`;
  AlpineCSP support. `Hyva\MagentoLiveSearch\ViewModel\ProductData` is
  **deprecated** in favour of `Hyva\Theme\ViewModel\Image` (theme module 1.3.10+).

<https://docs.hyva.io/hyva-enterprise/devdocs/sensei/live-search/index.html>

### The PLP Widget (Adobe's React product listing app)

Supported from Live Search compatibility **1.0.5**. When enabled it replaces the
entire server-side rendered product list - products, facets and pagination - on both
category and search pages with Adobe's React application. Enable it under
**Stores > Configuration > Live Search > Storefront Features**.

**Experimental features** (Hyvä-provided admin toggles under
**Stores > Configuration > Hyvä Themes > Live Search > PLP Widget**): search box,
image carousel, price slider (replaces the price range facet), list view toggle,
and image optimization via Fastly query parameters.

Trade-offs Hyvä documents explicitly: tighter Adobe integration and extra features
(category merchandising, more facet control) versus **looser Hyvä integration, a
different customisation approach, slower full render because content loads in
requests after page load, and some CLS impact** (mostly mitigated).

Styling: add a custom Post-CSS file to the theme and include it from
`tailwind-source.css` in `web/tailwind/`. Hyvä's own base styles live in
`plp-widget.css` inside `Hyva_MagentoLiveSearch` and can be extended - or excluded
entirely:

```json
{
    "tailwind": {
        "exclude": [
            { "src": "vendor/hyva-themes/magento2-ee-magento-live-search/src" }
        ]
    }
}
```

(Tailwind v4, `hyva.config.json`.) For Tailwind v3, exclude via `postcss.config.js`:

```js
const { postcssImportHyvaModules } = require("@hyva-themes/hyva-modules");
module.exports = {
    plugins: [
        postcssImportHyvaModules({
            excludeDirs: ["vendor/hyva-themes/magento2-ee-magento-live-search/src"],
        }),
        require("postcss-import"),
        require("tailwindcss/nesting"),
        require("tailwindcss"),
        require("autoprefixer"),
    ],
};
```

Functional changes beyond admin configuration require forking
`github.com/adobe/storefront-product-listing-page`; to ship a fork, override
`Hyva_MagentoLiveSearch::plp_script.phtml` and replace the `<script src>` (default
`https://plp-widgets-ui.magento-ds.com/v2/search.js`) with your build's URL or view
file path. The old plugin that suppressed PLP Widget output is disabled in XML and
the class deprecated.

<https://docs.hyva.io/hyva-enterprise/devdocs/sensei/live-search/plp-widget.html>

## Product Recommendations

```bash
composer require hyva-themes/magento2-ee-magento-product-recommendations
bin/magento setup:upgrade

composer require hyva-themes/magento2-ee-magento-page-builder-product-recommendations
bin/magento setup:upgrade
```

Supports Adobe's recommendation unit types: related products, up-sell, cross-sell,
personalized, trending, recently viewed, most viewed, new arrivals, recommended for
you (Adobe's docs hold the complete list). Configure in the admin under
**Marketing > Promotions > Product Recommendations**. Events flow back to Adobe
through the Data Services module. Appearance is customised by overriding the
modules' frontend templates and classes.

Behaviours to expect after recent versions: recommendations no longer persist
between PDPs; add-to-cart reloads the initiating page instead of redirecting to the
homepage; no price for composite product types; placeholder image fallback; responses
are **merged** rather than replaced; units are normalized (empty units filtered,
products limited to each unit's `displayNumber`, sorted by `displayOrder`); duplicate
unit rendering prevented by tracking rendered unit ids; `recsUnitRender` published
after processing completes rather than inside the `recsResponseReceived` subscriber;
Page Builder requests pass `storeCode` / `storeViewCode` to `RecommendationsClient`
(fixing cross-store-view 404s). SDK moved 2.0.7 -> 2.0.9.

<https://docs.hyva.io/hyva-enterprise/devdocs/sensei/product-recs/index.html>
<https://docs.hyva.io/hyva-enterprise/upgrading/product-recommendations/changelog.html>

## Installing on a non-Hyvä storefront

The Sensei/Services metapackage is safe to install when the storefront uses Luma:
Hyvä-specific output is suppressed by `hyva_`-prefixed layout handles (which only
apply to Hyvä themes) and by `Hyva\Theme\Service\CurrentTheme::isHyva()`. This lets
a Luma storefront with Hyvä Checkout still get Sensei event tracking in checkout.

<https://docs.hyva.io/hyva-enterprise/devdocs/sensei/index.html>
