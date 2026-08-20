# Form API — construction, rendering, hooks, validation

The Form API (since 1.1.0) defines form **structure in PHP classes**, **rendering in layout XML**,
and **presentation in templates**, so third parties extend forms through modifiers and factories
instead of overriding `.phtml`. All address forms in Hyvä Checkout are built on it.

Use it when a form must be extensible by other modules. For a fixed set of fields, a plain `.phtml`
with a Magewire component is perfectly fine.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-api/index.html>

## The four pieces of a Magewire-driven form

### 1. Layout XML

```xml
<block name="magewire-driven-form" template="Hyva_Example::checkout/magewire-driven-form.phtml">
    <block name="magewire-driven-form.form" as="form"
           template="Hyva_Checkout::magewire/component/form.phtml">
        <arguments>
            <argument name="magewire" xsi:type="object">\Hyva\Example\Magewire\Checkout\MagewireDrivenForm</argument>
        </arguments>
    </block>
</block>
```

`Hyva_Checkout::magewire/component/form.phtml` is the ready-made template for Magewire forms.

### 2. Magewire component — extends `\Hyva\Checkout\Magewire\Component\AbstractForm`

```php
class MagewireDriven extends \Hyva\Checkout\Magewire\Component\AbstractForm
{
    public function __construct(
        \Rakit\Validation\Validator $validator,
        \Hyva\Example\Model\Form\MagewireDrivenForm $form,
        \Psr\Log\LoggerInterface $logger,
        \Hyva\Checkout\Model\Magewire\Component\Evaluation\Batch $evaluationResultBatch
    ) {
        parent::__construct($validator, $form, $logger, $evaluationResultBatch);
    }
}
```

`AbstractForm` was introduced in 1.1.13; it replaces the deprecated
`\Hyva\Checkout\Magewire\Checkout\AddressView\AbstractMagewireAddressForm`. Inside the template use
`$magewire->getPublicForm()`.

### 3. Form class — extends `\Hyva\Checkout\Model\Form\AbstractEntityForm`

```php
class MagewireDrivenForm extends \Hyva\Checkout\Model\Form\AbstractEntityForm
{
    public const FORM_NAMESPACE = 'my_form';   // required, unique, used for renderer lookups

    public function __construct(
        \Hyva\Checkout\Model\Form\EntityFormFieldFactory $entityFormFieldFactory,
        \Magento\Framework\View\LayoutInterface $layout,
        \Psr\Log\LoggerInterface $logger,
        \Hyva\Example\Model\Form\SaveService\MagewireDrivenFormSaveService $formSaveService,
        \Magento\Framework\Serialize\Serializer\Json $jsonSerializer,
        array $entityFormModifiers = [],
        array $factories = []
    ) {
        parent::__construct($entityFormFieldFactory, $layout, $logger,
            $formSaveService, $jsonSerializer, $entityFormModifiers, $factories);
    }

    public function populate(): EntityFormInterface
    {
        $this->addField($this->createField('firstname', 'text', ['data' => ['label' => 'Firstname']]));
        $this->addElement($this->createElement('submit', ['data' => ['label' => 'Save']]));
        $this->setAttribute('wire:submit.prevent="submit"');
        return $this;
    }

    public function getTitle(): string { return 'My form'; }
}
```

All *essential* fields belong in `populate()`. `\Hyva\Checkout\Model\Form\EntityFormInterface` is
being deprecated — extend `AbstractEntityForm` for new forms.

### 4. Save service — extends `\Hyva\Checkout\Model\Form\AbstractEntityFormSaveService`

```php
class MagewireDrivenFormSaveService extends \Hyva\Checkout\Model\Form\AbstractEntityFormSaveService
{
    public function save(\Hyva\Checkout\Model\Form\EntityFormInterface $form): \Hyva\Checkout\Model\Form\EntityFormInterface
    {
        // persist wherever you want: DB, session, external API
        return $form;
    }
}
```

Where data goes is entirely up to you. `EntityFormSaveServiceInterface` only needs implementing if
you write a custom `EntityFormInterface`, which is rare.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-api/index.html>,
<https://docs.hyva.io/hyva-checkout/devdocs/form-api/form-construction.html>

## Elements vs fields

- **Elements** (`\Hyva\Checkout\Model\Form\AbstractEntityFormElement`) provide structure and
  interactivity but hold **no value**: buttons, links, banners.
  - `EntityFormElement\Clickable` — abstract base for anything clickable
  - `EntityFormElement\Button` — renders `<button>`
  - `EntityFormElement\Submit` — Button subclass, default "Submit" label, own `layoutAlias`
  - `EntityFormElement\Url` — own `url` layout alias; value is the `src` attribute, set with
    `setValue(string $url)`
- **Fields** (`\Hyva\Checkout\Model\Form\EntityField\AbstractEntityField`) extend elements and hold
  values, validation, data binding. Fields fall back to the `text` template when nothing specific
  is assigned.

```php
$form->createElement(\Hyva\Checkout\Model\Form\EntityFormElement\Submit::class, ['data' => ['label' => 'Submit form']]);
$form->createElement(\Hyva\Checkout\Model\Form\EntityFormElement\Url::class, ['data' => ['url' => 'https://hyva.io', 'label' => 'Hyvä Themes']]);
```

### Built-in system fields/elements

| Name | Kind | Abstraction | HTML | Input type | EAV |
|---|---|---|---|---|:--:|
| `submit` | element | Button | Button | – | no |
| `id` | field | AbstractEntityField | Input | hidden | no |
| `save` | field | AbstractEntityField | Input | checkbox | no |
| `telephone` | field | EavAttributeField | Input | tel | yes |
| `street` | field | EavAttributeField | Input | text | yes |
| `region` | field | EavAttributeField | Input/Select | text/select | yes |
| `country_id` | field | EavAttributeField | Select | select | yes |
| `postcode` | field | EavAttributeField | Input | text | yes |
| `prefix` | field | EavAttributeField | Select | – | yes |
| `gender` | field | EavAttributeField | Select | – | yes |

Hyvä is considering an `eav_` name prefix for address EAV fields via a dedicated EAV field
factory — planned without a BC break.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-api/form-construction.html>

## Factories

`$form->createField()` uses `Hyva\Checkout\Model\Form\EntityFormFieldFactory`;
`$form->createElement()` uses `Hyva\Checkout\Model\Form\EntityFormFactory`. Both are injected into
`AbstractEntityForm` under the names `fields` and `elements`.

Map element and field names in `etc/frontend/di.xml` (both go into the `elements` argument of
`EntityFormFactory`):

```xml
<type name="Hyva\Checkout\Model\Form\EntityFormFactory">
    <arguments>
        <argument name="elements" xsi:type="array">
            <item name="promotional_banner" xsi:type="string">My\Example\Model\Form\EntityFormElement\PromotionalBanner</item>
            <item name="delivery_date" xsi:type="string">My\Example\Model\Form\EntityFormField\DeliveryDate</item>
            <item name="example_form.delivery_date" xsi:type="string">My\Example\Model\Form\EntityFormField\ExampleForm\DeliveryDate</item>
        </argument>
    </arguments>
</type>
```

```php
$form->createElement('promotional_banner', $arguments ?? []);
$form->createField('delivery_date', 'date', $arguments ?? []);
```

Passing a FQCN directly also works, but the default element renderer then needs a hook to find a
template — either implement `getLayoutAlias()` returning e.g. `'promotional_banner'`, or pass
`['data' => ['id' => 'promotional_banner']]`.

Custom global factories are registered on `AbstractEntityForm` and reached with
`$form->getFactoryFor('my_example')->create(...$args)`:

```xml
<type name="Hyva\Checkout\Model\Form\AbstractEntityForm">
    <arguments>
        <argument name="factories" xsi:type="array">
            <item name="my_example_factory" sortOrder="30" xsi:type="object">My\Example\Model\Form\EntityFormFactory\MyExampleFactory</item>
        </argument>
    </arguments>
</type>
```

### Field factory fallback order (most specific first)

| Level | Alias |
|---|---|
| 6 | `{form_namespace}.{field_name}.{input_type}` |
| 5 | `{form_namespace}.{field_name}` |
| 4 | `{field_name}.{input_type}` |
| 3 | `{field_name}` |
| 2 | `{form_namespace}.{input_type}` |
| 1 | `{input_type}` |

Elements have no fallback — their names are arbitrary and untyped.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-api/form-construction.html>

## Rendering

Renderer classes (1.1.0): `Hyva\Checkout\Model\Form\EntityFormElement\Renderer\Element` and
`Hyva\Checkout\Model\Form\EntityField\EntityFieldRenderer`. Only elements/fields **inside the
`Main` component** are rendered.

In templates: `$element->render()` (shortcut for `$element->getRenderer()->render($element)`).

Templates are bound in the **`hyva_checkout_form_elements`** handle, under two renderer blocks:
`entity-form.element-renderers` and `entity-form.field-renderers`. The renderer looks for a child
block whose `as` alias matches.

### Element alias lookup

| Level | Alias |
|---|---|
| 2 | `{form_namespace}.{element_id}` |
| 1 | `{element_id}` |

```xml
<!-- view/frontend/layout/hyva_checkout_form_elements.xml -->
<referenceBlock name="entity-form.element-renderers">
    <block name="form-element.promotion-banner" as="promotion-banner"
           template="My_Example::form/element/promotion-banner.phtml"/>
</referenceBlock>
```

### Field alias lookup (falls back to `text`, which always has a template)

| Level | Alias |
|---|---|
| 7 | `{form_namespace}.{field_id}.{input_type}` |
| 6 | `{form_namespace}.{field_id}` |
| 5 | `{field_id}.{input_type}` |
| 4 | `{field_id}` |
| 3 | `{form_namespace}.{input_type}` |
| 2 | `{input_type}` |
| 1 | `text` |

Core ships templates for `text`, `select`, `checkbox`, `hidden`, `password`; 1.1.7 added `hidden`
and a single-row street renderer, 1.1.1 the checkbox template, 1.1.16 radio/image/URL renderers, and
1.3.1000-beta1 `date`, `textarea`, `multiline`, `multiselect`.

### Accessories

Reusable helper templates around an element/field, aliased `accessory.*`. They are **not
interchangeable between elements and fields**.

| Accessory | Element | Field | Template | Method |
|---|:--:|:--:|---|---|
| before | yes | yes | `Hyva_Checkout::form/element/html/container.phtml` | `renderBefore` |
| after | yes | yes | `Hyva_Checkout::form/element/html/container.phtml` | `renderAfter` |
| label | no | yes | `Hyva_Checkout::form/element/html/label.phtml` | `renderLabel` |
| comment | no | yes | `Hyva_Checkout::form/element/html/comment.phtml` | `renderComment` |
| tooltip | no | yes | `Hyva_Checkout::form/element/html/tooltip.phtml` | `renderTooltip` |

```xml
<referenceBlock name="entity-form.field-renderers">
    <block name="form-field.global.label" as="accessory.label"
           template="Hyva_Checkout::form/element/html/label.phtml"/>
</referenceBlock>
<referenceBlock name="entity-form.element-renderers">
    <block name="form-element.global.before" as="accessory.before"
           template="Hyva_Checkout::form/element/html/container.phtml">
        <block name="element-script-block" template="My_Example::page/js/element-script.phtml"/>
    </block>
</referenceBlock>
```

Always call `renderBefore()` / `renderAfter()` in your own field templates so others can inject
markup without overriding you:

```php
<?= $element->getRenderer()->renderBefore($element) ?>
<?= $element->getRenderer()->renderLabel($element) ?>
<input <?= /* @noEscape */ $element->renderAttributes($escaper) ?> />
<?= $element->getRenderer()->renderComment($element) ?>
<?= $element->getRenderer()->renderAfter($element) ?>
```

Only the built-in accessories have dedicated `render*` methods; custom accessories use
`renderAccessory()` (since 1.1.11). Accessory blocks receive the element as the `element` block
data, sometimes with a `parent` too.

### Advanced rendering

**Targeted accessory** — override just the label of one field without a new field template:

```xml
<referenceBlock name="entity-form.field-renderers">
    <block name="specific-shipping-firstname" as="shipping.firstname">
        <block name="specific-shipping-firstname.label" as="label"
               template="My_Example::form/shipping/field/firstname-label.phtml"/>
    </block>
</referenceBlock>
```

```php
$element = $block->getData('element');   // automatically injected
echo $escaper->escapeHtml($element->getLabel());
```

**Wrapping** — reuse the core template inside your own wrapper via `renderWithTemplate()`:

```xml
<block name="save_address_book_shipping" as="shipping.save.checkbox"
       template="My_Example::form/shipping/field/save-address-book.phtml"/>
```

```php
<div class="bg-gray-100 px-6 py-4">
    <?= $element->getRenderer()->renderWithTemplate('Hyva_Checkout::form/field/checkbox.phtml', $element) ?>
</div>
```

Include the `.checkbox` input type in the alias so the custom template is skipped if a modifier
later changes the input type.

**Conditional rendering** — plain `ifconfig` on the renderer block; the field silently falls back
to `text`:

```xml
<block name="form-field.street" as="street" template="Hyva_Checkout::form/field/street.phtml"
       ifconfig="hyva_themes_checkout/developer/address_form/use_street_renderer"/>
```

**Street field variants** (since 1.1.1) — beyond the default vertical stack, *Hyvä Checkout >
Developer > Address Forms* offers "Two Column Grid" and "One Column Row".

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-api/form-rendering.html>

## Modification hooks

Hooks are registered from a modifier (see `form-customization.md`) with
`$form->registerModificationListener($uniqueName, $hook, $callable)`; remove with
`unregisterModificationListener()`; core dispatches them with `dispatchModificationHook()`.

Lifecycle order:

1. `form:init` — construction; add/remove fields (1.1.0)
2. `form:populate` — right after `form:init`, after built-in modifiers ran (1.1.0)
3. `form:boot` — form fully constructed, fields filled with data (1.1.2)
4. `form:build` — **visual-only** changes before rendering (1.1.0)
5. `form:build:magewire` — Magewire attributes before rendering (1.1.0)
6. `form:updated` — field values changed, **subsequent requests only** (1.1.2)
7. `form:field:updated` — a specific field changed, subsequent requests only (1.1.0)
8. `form:action:edit` — "Edit Address" clicked (1.1.0)
9. `form:action:create` — "New Address" clicked (1.1.0)

Plus `form:execute:submit:magewire` for submit handling on Magewire forms.

Callback signatures and associated hook aliases:

| Hook | Callback params | Preceding | Subsequent | Associated |
|---|---|:--:|:--:|---|
| `form:init` | `EntityFormInterface $form` | yes | yes | `form:populate` |
| `form:populate` | `EntityFormInterface $form` | yes | yes | – |
| `form:boot` | `$form`, `MagewireAddressFormInterface $addressComponent` | yes | yes | `form:[ADDRESS_NAMESPACE]:boot` |
| `form:build` | `$form` | yes | yes | – |
| `form:build:magewire` | `$form` | yes | yes | – |
| `form:updated` | `$form`, `MagewireAddressFormInterface $addressComponent` | no | yes | `form:[ADDRESS_NAMESPACE]:updated` (`form:shipping:updated`, `form:billing:updated`) |
| `form:field:updated` | `$form`, `EntityFieldInterface $field`, `$addressComponent` | no | yes | `form:[FIELD_ID]:updated`, `form:[ADDRESS_NAMESPACE][FIELD_ID]:updated` |
| `form:action:edit` | `$form`, `AddressInterface $address` | no | yes | `form:[FORM_NAMESPACE]:action:edit` |
| `form:action:create` | `$form` | no | yes | `form:[FORM_NAMESPACE]:action:create` |

Hook order beats modifier `sortOrder`: a `form:build` modifier with a high sort order still runs
before a `form:build:magewire` modifier with a low one.

Do **not** add or remove fields in `form:build` (visual only), and do not change element
relationships in `form:build:magewire` (structure is already final — fields render twice).

```php
// auto-fill street from postcode
$form->registerModificationListener('applyMyBillingModifications', 'form:billing:updated',
    function (EntityFormInterface $form, MagewireAddressFormInterface $addressComponent) {
        $postcode = $form->getField('postcode')->getValue();
        if ($street = $apiCall->getStreetByZipcode($postcode)) {
            $form->getField('street')->setValue($street);
        }
        return $form;
    });

// normalise a single field
$form->registerModificationListener('applyMyShippingPostcodeModifications', 'form:shipping:postcode:updated',
    fn (EntityFormInterface $form, EntityFieldInterface $field, $addressComponent)
        => $field->setValue(ucfirst($field->getValue())) ?: $form);
```

Hooks are for *minor* adjustments (labels, CSS classes, one extra field). For big changes build a
separate form and render it conditionally.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-api/form-modification-hooks.html>

## Client-side validation rules on fields

```php
$myField->setValidationRule('required');          // data-validate='{"required": true}'
$myField->setValidationRule('maxlength', 10);     // data-validate='{"required":true,"maxlength":10}'
$myField->removeValidationRule('maxlength');
```

`setValidationRule` merges without wiping existing rules. Never rely on client validation alone —
always validate server-side too.

Custom rule, three steps: (1) `setValidationRule('example')` on the field, (2) register a `.phtml`
that carries the rule's JS, (3) register the rule with `hyva.formValidation.addRule()`.

```xml
<!-- view/frontend/layout/hyva_checkout_index_index.xml -->
<referenceContainer name="before.body.end">
    <block name="my-js-validation-rule" template="My_Example::my-validation-rule.phtml"/>
</referenceContainer>
```

```html
<script>
(() => {
    if (hyva && hyva.formValidation) {
        hyva.formValidation.addRule('example', (value, options, field, context) => {
            const el = field.element;
            if (options && el.value.length && context.fields.country_id) {
                if (context.fields.country_id.element.value === 'DE' && !isPrime(parseInt(el.value))) {
                    return '<?= $escaper->escapeJs(__('Please enter a prime number.')) ?>';
                }
            }
            return true;   // true = pass, string = error message
        });
    }
})()
</script>
<?php $hyvaCsp->registerInlineScript() ?>
```

Callback args: `value`, `options` (whatever was passed to `setValidationRule`), `field`
(incl. `field.element`, the DOM node), `context` (all fields, for cross-field rules).

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-api/form-validations.html>

## Auto-save (since 1.1.27)

Before 1.1.27 Magewire forms auto-synced everything to the server. Now the developer decides.

Navigation buttons are the anchor: the Evaluation API injects a **navigation task** that runs
pending auto-save actions before the primary action (next step / place order) and can fail if
validation does not pass. Forms extending `Hyva\Checkout\Magewire\Components\AbstractForm` (or the
deprecated `AbstractMagewireAddressForm`) get this validation task automatically:

```php
$evaluationBatch->misses(
    fn (EvaluationResult $result) => $result->hasAlias('submit'),
    function (EvaluationResultBatch $batch) {
        $batch->push(
            $batch->getFactory()->createValidation('magewire-form')
                ->withDetails(['saveAction' => 'autosave'])
                ->withAlias('submit')
                ->withStackPosition(100)
        );
    }
);
```

Push your own validation with the alias `submit` to take precedence and suppress the default.

### `wire:auto-save` directive

Marks a field for saving when a navigation button is clicked. **Requires a matching
`wire:model.defer`** or the console throws an error.

```html
<form id="shipping">
    <input type="text" wire:model.defer="firstname" wire:auto-save/>
    <input type="text" wire:model.defer="firstname" wire:auto-save="shipping"/>      <!-- explicit form id -->
    <input type="text" wire:model.defer="firstname" wire:auto-save.self/>            <!-- self-save after 1.5s idle -->
    <input type="text" wire:model.defer="firstname" wire:auto-save.self.3000ms/>     <!-- custom delay -->
</form>
```

Since **1.1.29** each field in *Stores > Configuration > Hyvä Themes > Checkout > Components >
Shipping/Billing Address Form* has an **Auto Save** checkbox. If a field still auto-saves with the
box unchecked, a form modifier is overriding it.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-api/magewire-driven-forms.html>

## Reference: the Guest Details component

`\Hyva\Checkout\Magewire\Checkout\GuestDetails` extends `AbstractForm`, keeps a public
`bool $customerExists`, checks email availability in `boot()`, and uses the magic property hook
`updatedDataEmailAddress($value)` for `$this->data['email_address']` — it re-checks customer
existence and calls `$this->submit([GuestDetailsForm::FIELD_EMAIL => $value])`, then returns
`$value`. The optional password + submit button come from
`\Hyva\Checkout\Model\Form\EntityFormModifier\GuestDetailsForm\WithAuthenticationModifier`,
registered on `Hyva\Checkout\Model\Form\EntityForm\GuestDetailsForm`, using `form:init`,
`form:build:magewire` (twice — attributes and visibility) and `form:execute:submit:magewire`.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-api/magewire-driven-forms.html>
