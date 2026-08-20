# Payment integration

## What your integration owns

A Hyvä Checkout payment integration owns **only the customer-facing layer**. The existing Magento
Payment Method (its `PaymentMethodInterface`, gateway commands, validators, capture logic) is reused
unchanged — exactly the same backend code a Luma integration uses. Check whether a Magento payment
module already exists for the PSP before writing anything: usually you only build the Hyvä frontend
component.

Four responsibilities:

- render the payment UI (form, buttons, PSP iframe) when the method is selected;
- gather payment data (tokens, authorization codes);
- signal completion — `Evaluation\Success` when ready, `Evaluation\Blocking` (or better, an
  `ErrorMessage`) while waiting on the customer;
- hand the token to the Magento Payment Method through `additional_data` on the payment object.

The method **code is stored on the quote automatically** when the customer selects it — no code
needed for the selection event.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/payments/payment-in-hyva-checkout.html>

## Luma → Hyvä Checkout mapping

| Aspect | Luma | Hyvä Checkout |
|---|---|---|
| Renderer registration | `Magento_Checkout/js/model/payment/renderer-list` via `checkout_index_index.xml` `jsLayout` | a block aliased with the method code under `checkout.payment.methods` in `hyva_checkout_components.xml` |
| Renderer implementation | Knockout component + `.html` template | `.phtml` template, optionally with a Magewire component |
| Order placement | the renderer's `placeOrder()` | a **Place Order Service** (or the JS `placeOrder` override) |
| Step position | payment must be the last step | any step — never assume it is last |
| Data collection timing | immediately before order placement | whenever the payment step is visited |
| "can I continue" gate | KO observables + `Magento_Checkout/js/model/payment/additional-validators` | `EvaluationInterface::evaluateCompletion()` returning `Blocking`/`Success` |
| Send token to PHP | `setPaymentMethod` / `additional_data` on the REST call | `Magewire.find(<block name>).setPaymentToken(...)`, then `additional_data` on the quote payment |

Because placement is decoupled, merchants can add steps *after* payment (order review, gift options).
Always test the integration on a step that has a following step.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/payments/payment-in-hyva-checkout.html>,
<https://docs.hyva.io/hyva-checkout/getting-started/quickstart.html>

## Background: PSP flows

- **Offline methods** (e.g. Check / Money Order) need no external call — a template is enough.
- **Gateway methods** delegate card collection to the PSP for PCI-DSS reasons; Magento only handles
  result data such as an authorization token.
- **Redirect flow**: the customer leaves the store, completes the PSP page, returns; the token
  arrives on the redirect or via a webhook/side-channel API call.
- **Iframe / hosted-fields flow**: the PSP renders a form in an iframe inside the checkout page and
  passes the token to the page with `window.postMessage()`.
- A token proves the card data was valid and authorizes a single capture within a time window;
  capture may happen at order placement or later (e.g. at shipment).

**Always verify token validity server-side in PHP at order placement.** Any browser-side check is
trivially bypassed.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/payments/payment-introduction.html>

## Registering the renderer

Every method enabled in Magento system config already appears in the payment step. Register a block
only when the method needs UI. The **`as` alias must be exactly the Magento payment method code**, or
the template never renders. Display order comes from the method's system-config **Sort Order**, not
from block order.

```xml
<!-- view/frontend/layout/hyva_checkout_components.xml -->
<referenceBlock name="checkout.payment.methods">
    <block name="checkout.payment.method.checkmo"
           as="checkmo"
           template="Hyva_Checkout::component/payment/method/checkmo.phtml"/>
</referenceBlock>
```

With a Magewire component (needed for server roundtrips — token storage, session creation,
API calls):

```xml
<referenceBlock name="checkout.payment.methods">
    <block name="checkout.payment.method.cc" as="cc" template="My_Example::checkout/payment/method/cc.phtml">
        <arguments>
            <argument name="magewire" xsi:type="object">\My\Example\Magewire\Checkout\Payment\Method\Cc</argument>
        </arguments>
    </block>
</referenceBlock>
```

In the template the quote payment method is on the block's `method` data key:

```php
/** @var \Magento\Quote\Api\Data\PaymentMethodInterface $method */
$method = $block->getData('method');
$methodCode  = $method->getCode();   // "checkmo"
$methodTitle = $method->getTitle();  // "Check / Money Order"
```

Reference implementation:
`hyva-themes/magento2-hyva-checkout/src/view/frontend/templates/component/payment/method/checkmo.phtml`.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/payments/payment-integration-api.html>

## Display metadata (icon, subtitle)

`metadata` extends a method with frontend-only properties without touching the payment model.

```xml
<referenceBlock name="checkout.payment.methods">
    <block name="checkout.payment.method.checkmo" as="checkmo"
           template="Hyva_Checkout::component/payment/method/checkmo.phtml">
        <arguments>
            <argument name="metadata" xsi:type="array">
                <item name="icon" xsi:type="array">
                    <!-- SVG (since 1.0.5): icon-pack-name/icon-name, or your module's view/frontend/web/svg -->
                    <item name="svg" xsi:type="string">payment-icons/light/paypal</item>
                    <item name="attributes" xsi:type="array">
                        <item name="fill" xsi:type="string">none</item>
                    </item>
                </item>
                <!-- Static subtitle (since 1.0.5) … -->
                <item name="subtitle" xsi:type="string">Visa, Mastercard &amp; More</item>
            </argument>
        </arguments>
    </block>
</referenceBlock>
```

- Raster images (since **1.1.22**) use `src` instead of `svg`, with Magento asset notation and
  optional `<img>` attributes:
  `<item name="src" xsi:type="string">Magento_Payment::images/cc/vi.png</item>` plus
  `attributes` items like `width`, `loading`, `alt` (`translate="true"`).
- `subtitle` accepts either a literal string or a **system config path**
  (`payment/my-psp/my-awesome-subtitle`) resolved at runtime.

Metadata is backed by `Hyva\Checkout\Model\AbstractMethodMetaData` (1.1.22), shared with shipping
methods.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/payments/payment-integration-api.html>,
<https://docs.hyva.io/hyva-checkout/upgrading/feature-history.html>

## Gating the Proceed / Place Order button

Implement `\Hyva\Checkout\Model\Magewire\Component\EvaluationInterface` on the payment component.
`evaluateCompletion()` is only called for the **selected** method — unselected methods never affect
the flow.

```php
public function evaluateCompletion(EvaluationResultFactory $factory): EvaluationResultInterface
{
    return $this->isRequiredDataPresent()
        ? $factory->createSuccess()    // enables Proceed / Place Order
        : $factory->createBlocking();  // disables it
}
```

| Result | Button |
|---|---|
| `Blocking` | disabled — required customer action still pending |
| `Success` | enabled — all required payment data present |

`Blocking` has **no automatic unblock** (only a later `Success` from the same component, or a manual
frontend call), so a customer who cannot authorize gets stuck even after switching methods. Prefer
an `ErrorMessage` result, optionally with a `Validation` + `withFailureResult()` for async checks —
see `evaluation-and-place-order.md`.

Typical flows:

**Redirect** — 1) payment step, nothing selected → "Please select a payment method"; 2) method
selected, redirect button shown → `Blocking`; 3) customer leaves to the PSP; 4) PSP sends the token;
5) back in checkout, "Payment Authorized" → `Success`.

**Iframe / hosted form** — 1) nothing selected; 2) selected, iframe rendered → `Blocking`;
3) data entered, waiting for the token → `Blocking`; 4) token received → `Success`.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/payments/payment-integration-api.html>

## Three implementation approaches

- **PHP / Magewire** — best when the PSP has a PHP SDK, server-side token generation, or a redirect
  flow with little JavaScript.
- **JavaScript / Frontend Payment API** — best for browser-only SDKs (Stripe.js, Braintree hosted
  fields), client-side tokenization, complex JS flows.
- **Hybrid** — Magewire for server state (e.g. create a session token) plus JS for the SDK/iframe.
  This is the common shape for real PSP integrations.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/payments/payment-in-hyva-checkout.html>

## Sending a token from JS to the Magewire component

```js
if (document.querySelectorAll('[wire\\:id=checkout.payment.psp_method_xyz]').length) {
    Magewire.find('checkout.payment.psp_method_xyz').setPaymentToken({token: myToken});
}
```

```php
class PspMethodXyz extends \Magewirephp\Magewire\Component
{
    public function setPaymentToken(array $data)
    {
        $paymentInfo = json_serialize(['token' => $data['myToken']]);
        $this->checkoutSession->getQuote()->getPayment()->setAdditionalData($paymentInfo);
    }
}
```

`Magewire.find()` takes the **layout block name** (`$block->getNameInLayout()`). Magewire method calls
return a Promise that never resolves to the PHP return value — read a public property with `get()`
afterwards if you need data back.

Source: <https://docs.hyva.io/hyva-checkout/magewire/vanilla-js.html>

## Iframe / hosted-fields pattern (SDK + `wire:ignore`)

Load the PSP SDK **in the initial page render** — strict CSP blocks any script injected at runtime,
and scripts inside a Magewire template are not re-evaluated on subsequent updates. Use the
`magewire.plugin.scripts` container via the `hyva_checkout` handle (present on every checkout page):

```xml
<!-- view/frontend/layout/hyva_checkout.xml -->
<body>
    <referenceContainer name="magewire.plugin.scripts">
        <block name="checkout.payment.psp.sdk-loader" template="Example_Psp::checkout/payment/psp-sdk-loader.phtml"/>
    </referenceContainer>
</body>
```

```html
<script src="<?= $block->getViewFileUrl('Example_Psp::js/sdk.js') ?>"></script>
<script>
function initExamplePspPayment() {
    return {
        init() {
            const componentName = this.$el.dataset.componentName;
            window.ExamplePaymentSdk.configure({
                merchantKey: this.$el.dataset.merchantKey,
                callback: ({ token }) => Magewire.find(componentName).setPaymentToken(token)
            }).then(paymentMethod => paymentMethod.mount('#examplePspFormContainer'));
        }
    }
}
window.addEventListener('alpine:init', () => Alpine.data('initExamplePspPayment', initExamplePspPayment), {once: true});
</script>
<?php $hyvaCsp->registerInlineScript() ?>
```

```html
<!-- Example_Psp::checkout/payment/method/example-psp.phtml -->
<div x-data="initExamplePspPayment"
     data-merchant-key="<?= $escaper->escapeHtmlAttr($magewire->getMerchantKey()) ?>"
     data-component-name="<?= $escaper->escapeHtmlAttr($block->getNameInLayout()) ?>">
    <div id="examplePspFormContainer" wire:ignore></div>
</div>
```

**`wire:ignore` on the iframe container is mandatory.** Without it the next Magewire roundtrip
re-renders an empty container and the SDK-rendered iframe disappears.

Source: <https://docs.hyva.io/hyva-checkout/examples/example-payment-integration-iframe.html>

## Frontend Payment API — `hyvaCheckout.payment` (V1)

Rewritten in **1.3.6**; methods written against it require Hyvä Checkout **1.3.5 or higher**. On older
installs either use the `hyva-themes/magento2-hyva-checkout-frontend-api` backport package or the
deprecated `activate` approach.

Register the JS block in the `hyva.checkout.api-v1.payment-methods` container via
`hyva_checkout_index_index.xml`, and always wrap registration in `hyvaCheckout.api.after()`:

```xml
<referenceContainer name="hyva.checkout.api-v1.payment-methods">
    <block name="hyva.checkout.alpinejs.payment-method-hyva"
           template="Example_Module::hyva/checkout/page/js/api/v1/alpinejs/payment/method/hyva.phtml"/>
</referenceContainer>
```

```html
<script>
(() => {
    hyvaCheckout.api.after(() => {
        hyvaCheckout.payment.registerMethod({
            code: 'my_payment_method',       // must match the Magento payment method code exactly
            method: {
                // selected, or the payment step (re)entered: SDK init, iframe load, listeners
                initialize: async function () {},
                // switching away from this method or step: remove listeners, clear intervals
                uninitialize: async function () {},
                // runs before step progression, auto-registered with hyvaCheckout.validation.
                // does NOT run before placeOrder unless payment is on the final step —
                // put pre-order checks inside placeOrder instead
                validate: async function () { return true; },
                // primary order placement; fallback() = default Magewire-driven Place Order Service
                placeOrder: async function ({ fallback }) { await fallback(); },
                // false prevents placement and uses your getRedirectUrl; a redirect always happens
                canPlaceOrder: async function () { return true; },
                // handle the error yourself, or call fallback({ exception }) for default handling
                handleException: async function ({ exception, fallback }) { fallback({ exception }); },
                // normally true; false only when the quote has not become an order yet (rare,
                // discouraged — components depend on the quote, which is gone after placement)
                canRedirect: async function () { return true; },
                // internal path ('/checkout/success') or absolute URL; fallback() = success page
                getRedirectUrl: async function ({ fallback }) { return fallback(); }
            }
        });
    });
})();
</script>
<?php $hyvaCsp->registerInlineScript() ?>
```

Every override is optional, may be async, and receives its context object. Since 1.3.6 a registered
method is **activated automatically** when selected.

Other methods:

| Call | Returns |
|---|---|
| `hyvaCheckout.payment.registerMethod({code, method})` | the registered method object |
| `hyvaCheckout.payment.getActive()` | active method object, or `null` |
| `hyvaCheckout.payment.hasActive()` | `boolean` |
| `hyvaCheckout.payment.getByCode(code)` | registered method object, or `null` |
| `hyvaCheckout.payment.getDefaultMethod()` (1.3.6) | the default order-placement handler — the same object passed as `fallback` to `placeOrder`; from `hyvaCheckout.config` path `payment.method_default` |

**Deprecated in 1.3.6** — do not use in new code:

- `activate` — `registerMethod` handles activation; the system picks the right method at placement.
  Since 1.3.7 legacy methods still using it are flagged with `__viaHcPaymentActivate = true`.
- `isVisibleInStep` — payment methods can live on several steps, so DOM visibility is unreliable;
  be data-driven instead.
- `placeOrderViaJs` — since 1.3.6 **all** orders are placed via JavaScript.
- `isWireComponent` — the API no longer prescribes an implementation technology.

Hyvä deliberately does not prescribe where sensitive payment data is stored — that is the
integrator's decision.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/frontend-api/V1/payment.html>

### JS payment recipes

Minimal method: one `.phtml` calling `registerMethod`. A renderer block is only needed for UI.

**Validation before progression** — `validate` must resolve `true`/`false`; surface failures yourself,
e.g. `hyvaCheckout.message.dialog('Please confirm to proceed.')`.

**Errors from `placeOrder`** — `throw new Error('…')` inside `placeOrder`; it is caught and routed to
`handleException`, giving one place to handle all failures:

```js
placeOrder: async function ({ fallback }) {
    if (prompt('Password?') !== '123') throw new Error('Wrong password, please use "123".');
    await fallback();
},
handleException: async function ({ exception, fallback }) {
    hyvaCheckout.message.dialog(exception);
    await fallback({ exception });
}
```

**Typed errors** — attach a `code` to the Error and branch in `handleException`; always pass the
exception when delegating: `fallback({ exception })`. `hyvaCheckout.message.dialog()` accepts
`(message, title, type, callback, options)` — e.g. `{ cancelable: false }` to force confirmation.

**Several codes, one handler** — `['hyva','checkmo'].forEach(code => hyvaCheckout.payment.registerMethod({code, method}))`;
inside the overrides `this.code` is the current method code.

**Redirect to the PSP after placement** — `canRedirect: () => true` plus `getRedirectUrl` returning
an absolute URL or a relative path like `onepage/success`; throw to abort.

**Reaching `$wire` from a JS method** — either put the Alpine component on the renderer root
(`x-data="hyvaCheckoutJsOnlyPaymentMethod"`, then `this.$wire` inside `init()`), or look the component
up lazily with `const wire = () => Magewire.find('hyva.checkout.alpinejs.payment-method-hyva')`.
`registerMethod` throws if a code is already registered — guard with
`if (!hyvaCheckout.payment.getByCode('hyva_js_only')) { … }`.

Source: <https://docs.hyva.io/hyva-checkout/examples/js-payment-method.html>

## Availability: which methods the customer sees

The visible list comes from Magento. `Magento\Payment\Api\PaymentMethodListInterface::getActiveList()`
filters active methods, so a disabled method can never be selected without extra customization.

To decide availability dynamically (PSP API response, customer country, purchase history), add an
**after-plugin on `\Magento\Quote\Api\PaymentMethodManagementInterface::getList()`** and remove
methods from the returned array. Declare it in **`etc/frontend/di.xml` only** — never global or
adminhtml, or you also filter admin order creation:

```xml
<!-- etc/frontend/di.xml -->
<type name="Magento\Quote\Api\PaymentMethodManagementInterface">
    <plugin name="example_payment_method" type="Example\PaymentProvider\Plugin\AvailableMethodsFilterPlugin"/>
</type>
```

Source: <https://docs.hyva.io/hyva-checkout/devdocs/miscellaneous/dynamically-determining-available-payment-methods.html>

### Security: never write the method code to the quote yourself

The **1.3.12** fix (CVSS 7.5) replaced a bare setter with `PaymentMethodManagement::set()`, which
enforces `isAvailable()` before persisting the method; an unavailable code is now rejected with a
user-facing error and the component keeps its last server-confirmed value. `boot()` and
`evaluateSelection()` also read the quote through `CartRepositoryInterface` instead of the checkout
session cache. Backported from `1.0.7.1` upward — `~x.y.z` + `composer update` resolves to the right
patch. On `1.0.7`–`1.3.0` the first backport accidentally dropped the
`checkout:payment:method-activate` browser event that some methods rely on, fixed in the `x.y.z.2`
tags. Take the same lesson in custom code: persist a selected method through
`PaymentMethodManagement::set()` and read the quote from `CartRepositoryInterface`.

Source: <https://docs.hyva.io/hyva-checkout/upgrading/security-changelog.html>

### Zero subtotal orders

By default Magento allows only `free` for a zero total. Hyvä Checkout replaces
`Magento\Payment\Model\Checks\ZeroTotal` with `Hyva\Checkout\Model\Payment\Checks\ZeroTotal`, dropping
that restriction, and filters the list with
`Hyva\Checkout\Plugin\Magento\Quote\Api\PaymentMethodManagementInterface::afterGetList()`. Two settings
under *Hyvä Themes > Checkout > Components > Payment* (both default `No`): remove non-zero payment
methods when the total is zero, and pick which methods survive (default `No Payment Information
Required` = `free`; disabled methods are listed with a `(disabled)` suffix). Feature added in 1.1.29.

Source: <https://docs.hyva.io/hyva-checkout/features/zero-subtotal-checkout.html>

### Auto-select (experimental, 1.1.26)

*Hyvä Themes > Checkout > Developer > Experimental* can pre-select the first available payment and/or
shipping method (both default `No`). Availability is evaluated **once per checkout session** during
`Hyva\Checkout\Controller\Index\Index::initCheckout()`, by
`Hyva\Checkout\Observer\Frontend\HyvaCheckoutHyvaCheckoutInitAfter`. A customer's own choice is never
overridden, and the selection is *not* updated when available methods change later. The one exception:
`Hyva\Checkout\Magewire\Checkout\Payment\MethodList::boot()` auto-selects a payment method when it is
the only one available (useful with zero subtotal checkout).

Source: <https://docs.hyva.io/hyva-checkout/features/method-auto-select.html>

## Shipping methods use the same mechanism

Register under `checkout.shipping.methods` with the alias **`carrierCode_methodCode`** (e.g.
`flatrate_flatrate`, `tablerate_bestway`), optionally with a `magewire` argument for server logic
(pickup points, delivery windows), and the same `metadata`/`icon` structure (`svg` or `src` +
`attributes`) — shipping icons since **1.1.27**. Listen for `checkout:shipping:method-activate`
(`event.detail.method`) on the frontend.

```xml
<referenceBlock name="checkout.shipping.methods">
    <block name="checkout.shipping.method.custom-shipping" as="carrierCode_methodCode"
           template="Hyva_Checkout::component/shipping/method/custom-shipping.phtml">
        <arguments>
            <argument name="magewire" xsi:type="object">Hyva\Checkout\Magewire\Checkout\Shipping\CustomShipping</argument>
        </arguments>
    </block>
</referenceBlock>
```

Source: <https://docs.hyva.io/hyva-checkout/devdocs/shipping/shipping-integration-api.html>

## Existing integrations and abstraction layers

Before building, check the tracked integrations: the
[Checkout Feature Matrix](https://www.hyva.io/hyva-checkout-feature-matrix) and the
[integration tracker board](https://gitlab.hyva.io/hyva-public/checkout-integration-tracker/-/boards/87).
Tracker tickets are labelled `Vendor` or `Community` to show who owns first-line support. Many
integrations install straight from the Hyvä repo, e.g.
`hyva-themes/magento2-hyva-checkout-adyen-payment-v2`,
`hyva-themes/magento2-hyva-checkout-braintree`,
`hyva-themes/magento2-hyva-checkout-adobe-payments`,
`hyva-themes/magento2-hyva-checkout-airwallex`; others live in the PSP's own GitHub org.

**Abstraction layers** exist so an integration only has to wire the third-party module's own API into
the checkout UX. Each one exposes an adapter interface plus system config to enable the feature and
pick the adapter; your module sits between the third-party module and the layer.

- **Autocomplete** — `composer require hyva-themes/magento2-hyva-checkout-autocomplete`
  (`Hyva_CheckoutAutoComplete`, PHP 8.1+). Add a `<sequence>` on `Hyva_CheckoutAutoComplete`, extend
  `Hyva\CheckoutAutoComplete\Model\AddressAutoCompleteServiceAdapter\AbstractServiceAdapter` and
  implement `getServiceName()`, `accessServiceApi(): object`,
  `canApplyEntityFormModifications(): bool`, `modifyEntityForm(AbstractEntityForm $form): void`
  (which applies injected `EntityFormModifierInterface`s). Register it on
  `Hyva\CheckoutAutoComplete\Model\AddressAutoCompleteServiceAdapterProvider` → argument `adapters`.
- **Guest to Customer** — `composer require hyva-themes/magento2-hyva-checkout-guest-to-customer`
  (`Hyva_CheckoutGuestToCustomer`, PHP 8.1+). Adds an opt-in checkbox under the email field
  (*Components > Guest Details > Enable Guest to Customer*; adapter chosen at
  *Developer > Adapters > Guest to Customer*). Extend
  `Hyva\CheckoutGuestToCustomer\Model\AbstractGuestToCustomerAdapter` with
  `transform(\Magento\Quote\Api\Data\CartInterface $quote): bool` and `getServiceName(): string`;
  register on `Hyva\CheckoutGuestToCustomer\Model\GuestToCustomerManagement` → argument `adapters`.
  It runs during `sales_model_service_quote_submit_before`; exceptions are logged but **never**
  interrupt order placement.
- Reference address integrations to copy from: `hyva-themes/magento2-hyva-checkout-postnl`
  (server-side Magewire) and `hyva-themes/magento2-hyva-checkout-loqate` (JavaScript SDK).

Source: <https://docs.hyva.io/hyva-checkout/integrations/available-payment-methods.html>,
<https://docs.hyva.io/hyva-checkout/integrations/abstraction-layers/index.html>,
<https://docs.hyva.io/hyva-checkout/integrations/abstraction-layers/autocomplete.html>,
<https://docs.hyva.io/hyva-checkout/integrations/abstraction-layers/guest-to-customer.html>,
<https://docs.hyva.io/hyva-checkout/faq/address-autocomplete.html>
