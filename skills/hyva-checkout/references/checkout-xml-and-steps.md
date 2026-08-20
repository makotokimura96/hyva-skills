# `hyva_checkout.xml`, layout handles, steps & conditions

## `etc/hyva_checkout.xml`

Defines **checkout variants and their step sequence** — not step *content*. Place it at
`etc/hyva_checkout.xml` in a module **or a theme** (in a theme it is still `etc/hyva_checkout.xml`,
*not* `Hyva_Checkout/etc/hyva_checkout.xml` — a common mistake).

Schema: `vendor/hyva-themes/magento2-hyva-checkout/src/etc/hyva_checkout.xsd`. The module also
ships a reference `src/etc/hyva_checkout.xml` with the default checkouts.

Merge order (later overrides earlier):

1. all module `etc/hyva_checkout.xml` in module load order
2. the base theme file
3. other themes in the fallback chain
4. the current theme

Theme files merge only when that theme is active for the current store view.

Assign a checkout to a website/store view in *Hyvä Themes > Checkout > General > Checkout*.

### `<checkout>` attributes

| Attribute | Req. | Meaning |
|---|---|---|
| `name` | yes | unique id; used in other XML and to build layout handles |
| `label` | yes | shown in the admin dropdown |
| `layout` | no | default step structure, e.g. `2columns` |
| `parent` | no | name of a checkout to inherit from |
| `visible` | no | whether it appears in the admin dropdown |

### `<step>` attributes

| Attribute | Req. | Meaning |
|---|---|---|
| `name` | yes | step id; used in layout handles |
| `label` | yes | shown in step navigation; passed through `__()` |
| `route` | no | URL segment for deep links; defaults to the step name |
| `layout` | no | overrides the checkout-level layout for this step |
| `remove` | no | remove a step declared in another file |
| `ifconfig` | no | only use the step if the system config path is truthy; prefix `!` to negate |
| `before` / `after` | no | position relative to another step |
| `clone` | no | replicate a step from another checkout: `{checkout_name}.{step_name}` (since 1.1.17) |

### `<condition>` attributes (step visibility)

All conditions on a step must be true for the step to show.

| Attribute | Req. | Meaning |
|---|---|---|
| `name` | yes | identifier, referenced from other files |
| `if` | no | condition class implementing `Hyva\Checkout\Model\CustomConditionInterface`, or a registered identifier |
| `remove` | no | remove a condition declared elsewhere |
| `before` / `after` | no | evaluation order |
| `method` | no | method to call on the condition class (default `validate`) |

### `<update>` attributes (conditional layout handle)

| Attribute | Req. | Meaning |
|---|---|---|
| `handle` | yes | layout handle to include in the step |
| `if` | no | condition identifier or class name |
| `method` | no | alternative method name (default `validate`) |
| `processor` | no | advanced: different layout handle processor |
| `remove` | no | remove the handle from the step |

### Full example

```xml
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:module:Hyva_Checkout:etc/hyva_checkout.xsd">
    <checkout name="my-checkout" label="My Checkout" layout="2columns">
        <step name="login" label="Customer Login" route="login" layout="1column">
            <condition name="is_customer_required" if="is_customer_required"/>
            <condition name="is_guest" if="is_guest"/>
            <update handle="my_virtual_quote_layout" if="is_virtual"/>
        </step>
    </checkout>
</config>
```

Source: <https://docs.hyva.io/hyva-checkout/devdocs/custom-checkout/hyva-checkout-xml.html>

## Step conditions

Built-in identifiers: `is_always_allow`, `is_customer`, `is_device` (mobile), `is_guest`,
`is_physical`, `is_virtual`. They are aliases declared in
`vendor/hyva-themes/magento2-hyva-checkout/src/etc/frontend/di.xml` on
`Hyva\Checkout\Model\CustomConditionFactory` → argument `customConditionTypes`:

```xml
<type name="Hyva\Checkout\Model\CustomConditionFactory">
    <arguments>
        <argument name="customConditionTypes" xsi:type="array">
            <item name="is_customer" xsi:type="string">Hyva\Checkout\Model\CustomCondition\IsCustomer</item>
            <!-- IsAlwaysAllow, IsGuest, IsPhysical, IsVirtual, IsDevice -->
        </argument>
    </arguments>
</type>
```

Register your own there only when the condition is reused; otherwise put the FQCN directly in
`if=""`. A condition class implements `Hyva\Checkout\Model\CustomConditionInterface` with
`public function validate(): bool`. Use `method="required"` on `<condition>` to call an alternative
method on the same class and avoid duplicating condition classes.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/custom-checkout/step-conditions.html>

## Layout handles

Step **content** is layout XML. Add `Hyva_Checkout` to your module's `<sequence>` in
`etc/module.xml` so the base checkout layout is evaluated first (not needed for theme layout XML):

```xml
<module name="My_Module"><sequence><module name="Hyva_Checkout"/></sequence></module>
```

Processing order — **base checkout** (no `parent`):

1. `hyva_checkout_components`
2. `hyva_checkout_layout_<step-layout>` — e.g. `hyva_checkout_layout_2columns`
3. `hyva_checkout_<checkout-name>` — e.g. `hyva_checkout_default`
4. `hyva_checkout_<checkout-name>_<step-name>` — e.g. `hyva_checkout_default_login`

**Child checkout** (`parent="default"`): the parent's handles run first, then the child's.

1. `hyva_checkout_components`
2. `hyva_checkout_layout_<step-layout>`
3. `hyva_checkout_<parent-name>`
4. `hyva_checkout_<parent-name>_<step-name>`
5. `hyva_checkout_<checkout-name>`
6. `hyva_checkout_<checkout-name>_<step-name>`

The handle for a checkout named `client` with `parent="onepage"` is `hyva_checkout_client.xml`,
**not** `hyva_checkout_client_onepage.xml`.

Other handles you will use: `hyva_checkout` (loaded on every checkout page — the right place for
scripts that must exist on all steps), `hyva_checkout_index_index` (the checkout page itself, where
the frontend API containers live), `hyva_checkout_form_elements` (Form API renderer templates).

Source: <https://docs.hyva.io/hyva-checkout/devdocs/custom-checkout/layout-handles.html>,
<https://docs.hyva.io/hyva-checkout/faq/two-column-onepage-checkout.html>

## Declaring reusable components: `hyva_checkout_components`

Components declared in this handle become children of the `hyva.checkout.components` block, which
is **never rendered directly** — it is a virtual container. You then `<move>` components into steps.

```xml
<!-- view/frontend/layout/hyva_checkout_components.xml -->
<page xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:noNamespaceSchemaLocation="urn:magento:framework:View/Layout/etc/page_configuration.xsd">
    <body>
        <referenceBlock name="hyva.checkout.components">
            <container name="checkout.guest-details.section">
                <block name="checkout.guest-details" template="Hyva_Checkout::magewire/component/form.phtml">
                    <arguments>
                        <argument name="magewire" xsi:type="object">\Hyva\Checkout\Magewire\Checkout\GuestDetails</argument>
                    </arguments>
                </block>
            </container>
        </referenceBlock>
    </body>
</page>
```

```xml
<!-- view/frontend/layout/hyva_checkout_default_shipping.xml -->
<body>
    <move element="checkout.guest-details.section" destination="column.main" before="-"/>
</body>
```

Named core containers/blocks you will target: `checkout.shipping-details.section`,
`checkout.quote-summary.section`, `checkout.payment.methods`, `checkout.shipping.methods`,
`price-summary.total-segments`, `column.main`, `column.right`, `columns.main`, `columns.sidebar`,
`hyva.checkout.columns`, `hyva.checkout.breadcrumbs`, `hyva.checkout.navigation`,
`magewire.plugin.scripts`, `before.body.end`.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/custom-checkout/layout-handles.html>,
<https://docs.hyva.io/hyva-checkout/devdocs/form-api/magewire-driven-forms.html>

## Recipe: two-column onepage checkout

```xml
<!-- etc/hyva_checkout.xml -->
<checkout name="client" label="Client Two-Column Onepage" layout="2columns" parent="onepage"/>
```

`bin/magento cache:flush`, select the checkout in admin, then move any component out of the
now-removed third column in `view/frontend/layout/hyva_checkout_client.xml`:

```xml
<body>
    <move element="checkout.shipping.methods" destination="columns.main" after="-"/>
</body>
```

Source: <https://docs.hyva.io/hyva-checkout/faq/two-column-onepage-checkout.html>

## Recipe: two-column accordion checkout (requires ^1.1.18)

Create a `hyva_checkout_layout_accordion` handle that inherits `hyva_checkout_layout_2columns`,
swaps the `hyva.checkout.columns` template and removes breadcrumbs (this also removes the
sign-in / registration button):

```xml
<!-- view/frontend/layout/hyva_checkout_layout_accordion.xml -->
<page xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:noNamespaceSchemaLocation="urn:magento:framework:View/Layout/etc/page_configuration.xsd">
    <update handle="hyva_checkout_layout_2columns"/>
    <body>
        <referenceBlock name="hyva.checkout.columns" template="Example_Module::layout/accordion.phtml"/>
        <referenceBlock name="hyva.checkout.breadcrumbs" remove="true"/>
    </body>
</page>
```

Then `<checkout name="accordion" label="Hyvä Accordion" layout="accordion" parent="default"/>`.

The template iterates steps through the Navigation view model and renders one panel per step:

```php
$navigator   = $viewModels->require(\Hyva\Checkout\ViewModel\Navigation::class)->getNavigator();
$currentStep = $navigator->getActiveStep();
$checkout    = $navigator->getActiveCheckout();
foreach ($checkout->getAvailableSteps() as $step) {
    $isActiveStep = $checkout->isComparison($step, $navigator->getActiveStep());
    $canNavigateTo = $checkout->isStepBackwards($step, $currentStep) || $isActiveStep;
    // header button navigates with hyvaCheckout.navigation.stepTo($step->getRoute(), false)
    // panel body renders $block->getChildHtml('column.main') only when $isActiveStep
}
```

Only the active step's content is rendered — the accordion cannot pre-load several steps, and
there are no open/close transitions between steps.

Source: <https://docs.hyva.io/hyva-checkout/faq/two-column-accordion-checkout.html>

## Magento (server-side) events

- `hyva_checkout_init_after` — fires on the first checkout load and whenever the checkout session
  is reset, i.e. after `checkout_cart_save_after`, `checkout_quote_destroy`,
  `checkout_submit_all_after`, `customer_login`. To reset the session on your own event, wire
  `Hyva\Checkout\Observer\Frontend\HyvaCheckoutSessionReset` in `etc/frontend/events.xml`.
- `hyva_checkout_{checkout_name}_init` and `hyva_checkout_{checkout_name}_{step_name}_init` — fire
  when the step configuration loads **for the first step** (both fire on single-step checkouts).
- `hyva_checkout_{checkout_name}_booted` and `hyva_checkout_{checkout_name}_{step_name}_booted` —
  fire on **every** step load.
- `hyva_checkout_layout_process_before_hyva_checkout`,
  `…_hyva_checkout_{checkout_name}`, `…_hyva_checkout_{checkout_name}_{step_name}` — fire while
  step layout directives are processed; the payload carries a `page` argument
  (`Magento\Framework\View\Result\Page`), so you can add a layout handle conditionally. Prefer
  `<update handle=… if=…/>` in `hyva_checkout.xml` when a condition class is enough.

Checkout initialization runs **once per checkout session** in
`Hyva\Checkout\Controller\Index\Index::initCheckout()`.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/miscellaneous/magento-events.html>,
<https://docs.hyva.io/hyva-checkout/features/method-auto-select.html>

## Totals: adding a segment and controlling its order

Add a child block aliased with the total name to `price-summary.total-segments`:

```xml
<referenceBlock name="price-summary.total-segments">
    <block name="price-summary.total-segments.custom_fee" as="custom_fee" template="…"/>
</referenceBlock>
```

Layout `before`/`after` do **not** control the visible order — Hyvä Checkout honours Magento's
`sales/totals_sort` config so merchants can reorder totals from the admin. Ship a default in
`etc/config.xml` and expose a field in `etc/adminhtml/system.xml` under section `sales`,
group `totals_sort` (appears at *Sales > Sales > Checkout Totals Sort Order*):

```xml
<default><sales><totals_sort><custom_fee>69</custom_fee></totals_sort></sales></default>
```

Source: <https://docs.hyva.io/hyva-checkout/faq/totals-sort-order.html>

## Customer comment in order emails

Hyvä Checkout stores the customer comment in the order notes collection, not `customer_note`, so
it is absent from email templates. Map it during quote→order conversion with `etc/fieldset.xml`:

```xml
<scope id="global">
    <fieldset id="sales_convert_quote">
        <field name="customer_comment"><aspect name="to_order" targetField="customer_note"/></field>
    </fieldset>
</scope>
```

Then render `{{depend order_data.customer_note}}{{var order_data.customer_note|escape|nl2br}}{{/depend}}`.

Source: <https://docs.hyva.io/hyva-checkout/faq/customer-comment-in-email-template.html>
