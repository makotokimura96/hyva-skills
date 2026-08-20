# Hyvä Enterprise B2B

Requires the Adobe Commerce **B2B add-on** (`magento/extension-b2b` >= 1.4.0) and
Adobe Commerce 2.4.6+. Metapackages: `hyva-themes/magento2-hyva-enterprise-b2b`
(theme) and `hyva-themes/magento2-hyva-enterprise-b2b-checkout` (checkout).

## Modules in the B2B theme metapackage

`Hyva_EnterpriseB2b` (shared code: default header/footer link containers, the shared
merge/replace-cart-items modal template, sales-order-view reference container),
`Hyva_MagentoCompany`, `Hyva_MagentoCompanyCredit`, `Hyva_MagentoNegotiableQuote`,
`Hyva_MagentoNegotiableQuoteTemplate` (quote templates, B2B 1.5.2),
`Hyva_MagentoOrderHistorySearch`, `Hyva_MagentoPurchaseOrder`,
`Hyva_MagentoQuickOrder`, `Hyva_MagentoReCaptchaCompany`,
`Hyva_MagentoRequisitionList`.

<https://docs.hyva.io/hyva-enterprise/upgrading/b2b/changelog-theme.html>

## How the Hyvä B2B storefront differs from Luma

Established with the 1.0.0 stable release and still the design of the modules:

- **All grids are server-side rendered.** Listing pages (my quotes, my purchase
  orders, company credit, …) are reimplemented with view models, collections and
  the default pager block, with standardized table markup matching "my orders", and
  filtering via query parameters. This replaces Luma's client-side UI components.
  All list view models inherit from `\Hyva\Enterprise\ViewModel\AbstractList`.
- **Company structure and company permission trees are server-side rendered.**
  Node moves are still handled client-side but avoid a full re-paint of the tree.
- The company shipping block on company view/edit **respects company role
  permissions** (Luma always shows it).
- The inline toggleable "add to requisition list" panel is replaced with a single
  **modal** instance receiving product ID/data on trigger, instead of duplicating
  markup per product on category pages.
- Detail pages (quotes, purchase orders, requisition lists) have dedicated
  "current entity" view models to avoid duplicated model calls.
- Negotiable quote / purchase order detail pages use HTML `<details>` sections
  instead of tabs, hide (rather than disable) non-interactive elements, and render
  quote item notes inline instead of in a modal.
- Customer custom attributes for company users work correctly (in Luma many
  attribute types break the add/edit user modal with JS errors).
- Custom form validation is implemented as additions to Hyvä's advanced JavaScript
  form validation: URL, file type, file size, image dimensions, date from/to,
  value min/max and more. **Since Commerce theme 1.0.0 these rules live in the base
  `Hyva_Theme` module, not in `Hyva_Enterprise`.**

<https://docs.hyva.io/hyva-enterprise/upgrading/b2b/theme-upgrading-to-1.0.0.html>

## Company permissions API

Two supported ways, chosen by whether the page is full-page cached:

```php
// Non-FPC pages (account area): view model + class constants covering the
// permissions of the whole B2B suite.
/** @var \Hyva\MagentoCompany\ViewModel\CompanyPermissions $companyPermissions */
if ($companyPermissions->isAllowed(/* permission constant */)) { /* ... */ }
```

```js
// FPC pages: a JS event carrying all relevant permission data, used exactly like
// Hyvä's private-content-loaded event.
window.addEventListener('company-permissions-loaded', (event) => {
    // event.detail holds the permission data
});
```

Note that several older `CompanyPermissions::VIEW_*` / `EDIT_*` constants were
**removed** in 1.0.0 along with `CompanyRolesTree`, `CompanyUserEditModal` and
`CustomerData` view models - check the current class before referencing constants.

<https://docs.hyva.io/hyva-enterprise/upgrading/b2b/theme-upgrading-to-1.0.0.html>

## Company account layouts in Hyvä Checkout

Requires `Hyva_EnterpriseCheckoutB2b` >= 0.1.3 (introduces the `is_company`
condition). By default company users get the same checkout layout as regular
customers (**Stores > Configuration > Hyvä Themes > Checkout**).

Two configurations exist:

- **B2B Company Layout - Desktop** - custom checkout for company users on desktop.
- **B2B Company Layout - Mobile** - overrides both the default checkout and the
  desktop B2B layout for mobile company users. Mobile detection is based on the
  `User-Agent`. If not enabled, mobile company users fall back to the desktop B2B
  layout, or the standard checkout.

**No B2B/company-specific layouts ship by default** - you must author your own
checkout via `hyva_checkout.xml`.

The `is_company` custom condition gates steps and layout handles:

```xml
<step name="example-step">
    <!-- include example_handle.xml only when the customer is a company user -->
    <update handle="example_handle" if="is_company"/>
    <!-- show the step only when the customer is a company user -->
    <condition name="example" if="is_company"/>
</step>
```

<https://docs.hyva.io/hyva-enterprise/devdocs/b2b/checkout/company-layouts.html>

## Purchase orders in Hyvä Checkout

Requires Hyvä Checkout >= 1.1.18 (new navigation system) and
`Hyva_EnterpriseCheckout` >= 0.1.1 (URL parameter functionality).

**Online vs offline payment.** The integration only affects orders placed with
**online** payment methods, determined by
`Magento\Payment\Model\MethodInterface::isOffline()`. Offline methods are untouched.

**Purchase order notice.** For online methods the payment method content is
replaced by a notice telling the customer they will enter payment details after
approval. It is a deliberately orphaned block in the
`hyva_checkout_components.xml` handle named
`checkout.payment.method.purchase.order.notice`, template
`Hyva_EnterpriseCheckoutB2b::checkout/payment/method/purchase-order.phtml`, loaded
dynamically in place of the payment method block. Not shown for offline methods.
See also `\Hyva\EnterpriseCheckoutB2b\ViewModel\Checkout\Payment\Method\PurchaseOrder`.

**Order placement.** An around plugin,
`Hyva\EnterpriseCheckoutB2b\Plugin\Hyva\Checkout\Model\Magewire\Payment\PlaceOrderServiceInterface\PlacePurchaseOrderService`,
decides whether Magento processes a normal order or a purchase order, and handles
both the initial placement and the later payment. On purchase-order placement the
customer is redirected to `/purchaseorder/purchaseorder/success`; after paying they
follow their payment method's own redirect.

Since B2B Checkout 1.0.0 placement delegates to
`\Magento\PurchaseOrder\Api\PurchaseOrderPaymentInformationManagementInterface::savePaymentInformationAndPlacePurchaseOrder()`
instead of `\Magento\PurchaseOrder\Model\ProcessorInterface::createPurchaseOrder()`,
so the purchase order runs through the same `create` + `determineStatus()` flow as
Luma. `determineStatus()` runs the `placePoValidatorComposite` approval-rule
validator, which auto-approves when the company has no approval rules. Calling
`createPurchaseOrder()` directly (pre-1.0.0) left purchase orders stuck in
`STATUS_PENDING`.

**Redirect PSPs.** The id returned on purchase-order placement is a
`purchaseOrderId`, not a sales-order id; redirect PSPs (e.g. Mollie) threw
`NoSuchEntityException` trying to load it. Redirect handling moved from
`afterGetRedirectUrl` to `aroundGetRedirectUrl` so the PSP redirect is bypassed and
the customer lands on the purchase-order success page.

**The dedicated purchase-order checkout.** Paying an approved purchase order loads
a hidden, single-step checkout defined in the module's `etc/hyva_checkout.xml`:

```xml
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:module:Hyva_Checkout:etc/hyva_checkout.xsd">
    <checkout name="ee_default_purchase_order"
              label="Hyvä Default Purchase Order"
              layout="2columns">
        <step name="payment"
              label="Review Purchase Order"
              route="payment"/>
    </checkout>
</config>
```

It is intentionally absent from the admin list of available checkouts. Its payment
step reuses the existing `checkout.payment.section` container from
`hyva_checkout_components.xml`, with discount blocks removed (Adobe advises against
further discounts during purchase-order payment). Layout handle:
`hyva_checkout_ee_default_purchase_order_payment.xml`. Clicking `Place Order` on
this step processes the quote as a real order.

Since B2B Checkout 1.0.0 this checkout also gets:

- the shipping summary - `Hyva_EnterpriseCheckoutB2b::view/frontend/layout/hyva_checkout_ee_default_purchase_order.xml`
  adds `checkout.shipping-summary` to the `checkout.quote-summary.section` container
  (the PO checkout does not inherit the default checkout, so it was missing); for
  fully virtual carts it is removed again via a `hyva_checkout_default_virtual`
  update gated by `if="is_virtual"` on the payment step.
- terms and conditions on the review step, by moving
  `checkout.section.quote-actions` into the main column in
  `hyva_checkout_ee_default_purchase_order_payment.xml`.

<https://docs.hyva.io/hyva-enterprise/devdocs/b2b/checkout/purchase-orders.html>
<https://docs.hyva.io/hyva-enterprise/upgrading/b2b/checkout-upgrading-to-1.0.0.html>

## Notable B2B fixes worth knowing

- Company hierarchy store switcher supported on the frontend (theme 1.0.3).
- Client-side validation of existing company/customer emails on the company create
  form, so form data is not lost on submit (1.0.2).
- Requisition lists: out-of-stock products can be added; merge/replace cart modal
  implemented; new lists refresh section data immediately; items cannot be
  moved/copied to the same list.
- `Hyva_MagentoQuickOrder`: correct qty when uploading SKUs by CSV.
- Company account creation page adds the `hyva_form_validation_input_additional`
  handle so company attribute validation rules run (1.1.1).
- B2B 1.5.2 compatibility arrived in theme metapackage 1.1.0.

<https://docs.hyva.io/hyva-enterprise/upgrading/b2b/changelog-theme.html>
