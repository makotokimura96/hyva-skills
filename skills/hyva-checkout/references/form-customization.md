# Customizing the shipping / billing address forms

"Entity Form" is Hyvä's PHP abstraction for collecting structured (EAV-backed) data — not the HTML
`<form>`. It renders all configured address attributes with the right input type and validation, and
merges customizations from several modules without conflict. For a form that is not EAV-backed
(contact form, survey), a plain Magewire component is simpler.

The two concrete implementations you will meet:
`\Hyva\Checkout\Model\Form\EntityForm\EavAttributeShippingAddressForm` and
`\Hyva\Checkout\Model\Form\EntityForm\EavAttributeBillingAddressForm`. Writing your own
`EntityFormInterface` is possible but almost never necessary.

Interfaces:

| Interface | Role |
|---|---|
| `\Hyva\Checkout\Model\Form\EntityFormInterface` | the whole form; being deprecated in favour of `AbstractEntityForm` |
| `\Hyva\Checkout\Model\Form\EntityFormElementInterface` | any component: fields, text, images, separators, containers; supports parent/child grouping |
| `\Hyva\Checkout\Model\Form\EntityFieldInterface` | an input field; extends `EntityFormElementInterface` |
| `\Hyva\Checkout\Model\Form\EntityFormModifierInterface` | your entry point |
| `\Hyva\Checkout\Model\Form\EntityFormElement\RendererInterface` | element → HTML; configure rather than reimplement |
| `\Hyva\Checkout\Model\Form\EntityFormSaveServiceInterface` | persistence; built-in services cover shipping + billing |

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-customization/index.html>,
<https://docs.hyva.io/hyva-checkout/devdocs/form-customization/entity-form-interfaces.html>

## Writing and registering a modifier

```php
namespace Hyva\Example\Model\FormModifier;

use Hyva\Checkout\Model\Form\EntityFormInterface;
use Hyva\Checkout\Model\Form\EntityFormModifierInterface;

class ExampleBillingAddressModifier implements EntityFormModifierInterface
{
    public function apply(EntityFormInterface $form): EntityFormInterface
    {
        $form->registerModificationListener(
            'myCallbackIdentifier',        // unique id, used to unregister later
            'form:build',                  // hook name
            [$this, 'applyMyModification'] // any PHP callable
        );
        return $form;
    }

    public function applyMyModification(EntityFormInterface $form)
    {
        // since 1.1.21: modifyField/modifyFields/modifyElement/modifyElements
        // do the existence check for you — prefer them over manual null checks
        $form->modifyField('telephone', fn ($field) => $field->setLabel('Phone Number'));
        $form->modifyFields(['firstname', 'lastname'], fn ($field) => $field->addValidationRule('alpha-spaces-only'));
    }
}
```

```xml
<!-- etc/frontend/di.xml -->
<type name="Hyva\Checkout\Model\Form\EntityForm\EavAttributeBillingAddressForm">
    <arguments>
        <argument name="entityFormModifiers" xsi:type="array">
            <item name="hyva_example" xsi:type="object" sortOrder="1000">
                Hyva\Example\Model\FormModifier\ExampleBillingAddressModifier
            </item>
        </argument>
    </arguments>
</type>
```

Swap in `EavAttributeShippingAddressForm` for the shipping form. **Always set `sortOrder`** —
modifiers run ascending, later ones can override earlier ones. Core modifiers use 0–999, so use
**1000** as your default and bump higher (1100…) to override a third party. Since 1.1.5 passing
`null` as an array item disables a specific modifier; since 1.1.25 `AbstractEntityForm::modify()`
lets you inject a callback without a modifier class at all.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-customization/entity-form-modifiers.html>

## HTML attributes on fields

```php
$field->setAttribute('data-attribute-address', 'true');
$field->removeAttribute('data-attribute-address');
$field->setAttribute('@input', 'onChange');                       // Alpine event (CSP: method ref)
$field->setAttribute(':class', '{"border-red-500": isValid}');     // Alpine class binding
$field->setAttribute('wire:loading.class', 'loading');             // Magewire directive
$current = $field->getAttributes()['data-example'] ?? '';
```

Read attribute values with **`getAttributes()[$code]`**, never `getAttribute($code)` — that returns
the **EAV attribute model** for EAV-backed fields, not an HTML attribute. Attributes can be set in
any hook. (`addAttribute()` is deprecated since 1.1.0; use `setAttribute()`.)

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-customization/field-attributes.html>

## Setting field values — only in `form:*:updated`

`setValue($value)` and `empty()` on `EntityFieldInterface` **only take effect inside
`form:billing:updated` / `form:shipping:updated`**. Called in `form:build` or any other hook they
are silently ignored, because the form overwrites them with submitted data later in the lifecycle.

```php
public function apply(EntityFormInterface $form): EntityFormInterface
{
    $form->registerModificationListener('empty-value-if-field-disabled', 'form:billing:updated', [$this, 'emptyMyField']);
    return $form;
}

public function emptyMyField(EntityFormInterface $form)
{
    $country = $form->getField('country_id')->getValue();
    if (! $this->isExampleAvailable($country)) {
        $form->getField('my_field')->empty();
        $form->getField('other_field')->setValue('nope');
    }
}
```

Guard fields that may not exist: `if ($zoneField = $form->getField('shipping_zone')) { … }`.

There is **no hook for setting initial values on page load** — `form:*:updated` never fires on the
preceding request. Use Magento-level mechanisms instead: a plugin on address loading, an observer on
an address event, or a customized data provider, so the values are already in place when the form is
built. (`AbstractEntityField::getPreviousValue()` exists since 1.1.2.)

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-customization/setting-field-values.html>

## Interdependent fields (conditional visibility)

Read other field values and add/remove fields in **`form:build`**. Position new fields with
`assignRelative()` on an existing field.

```php
public function initMyFormField(EntityFormInterface $form)
{
    $country  = $form->getField('country_id')->getValue();
    $postcode = $form->getField('postcode')->getValue();

    if ($country === 'DE' && $myField = $form->getField('my_field')) {
        $form->removeField($myField);
        return;
    }

    $myField = $form->createField('my_field', 'text');
    $myField->addData(['label' => 'Additional Information']);
    $form->addField($myField);
    $form->getField('country_id')->assignRelative($myField);

    $select = $form->createField('my_select', 'select');
    $select->addData([
        'label'    => 'Delivery Preference',
        'required' => 1,
        'options'  => ['' => 'Please Choose', '0' => 'Standard Delivery', '1' => 'Priority Delivery'],
    ]);
    $form->addField($select);
    $form->getField('country_id')->assignRelative($select);
}
```

Options: array keys are values, array values are labels; `''` acts as the placeholder.
**Dynamically added fields do not persist automatically** — implement your own save logic.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-customization/interdependent-fields.html>

## Related form elements (ancestor / relatives)

Assigning B as a relative of A makes A the **ancestor**; by default B renders below A. For **fields**
the ancestor's Magewire property becomes an **array** — the ancestor value is item 0, relatives
follow. That is exactly how street lines work: one street field means `address.street` is a string,
two or more make it an array. How relatives render depends on the ancestor's field type (street uses
a grid).

```php
$formElementA->assignRelative($formElementB);
$relatives = $formElementA->getRelatives();
$formElementA->removeRelative($formElementB);
$level = $element->getLevel();   // 0 = top level, 1 = relative of a top-level element, …
```

`assignAncestor()` / `removeAncestor()` also exist but can leave the hierarchy inconsistent — always
use `assignRelative()` / `removeRelative()` on the ancestor. Never change relationships in
`form:build:magewire` (fields render twice).

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-customization/related-form-elements.html>

## Custom address EAV attributes (1.3.1000-beta1 / 1.4.0-beta3, beta only)

EAV attribute rendering in the checkout address forms arrived in **1.3.1000-beta1** — beta, do not
run it in production. Supported frontend input types: `text`, `textarea`, `date`, `select`,
`boolean` (Yes/No), `multiselect`, `multiline`. **`file` and `image` are not supported.**

Two steps, both standard Magento, plus one Hyvä-specific requirement.

```php
// Vendor/Module/Setup/Patch/Data/AddCheckoutAddressAttribute.php
$customerSetup->addAttribute(
    \Magento\Customer\Api\AddressMetadataInterface::ENTITY_TYPE_ADDRESS,
    'example_attribute',
    ['label' => 'Example Attribute', 'type' => 'varchar', 'input' => 'text',
     'required' => false, 'system' => false, 'user_defined' => true, 'sort_order' => 100]
);

$attribute = $customerSetup->getEavConfig()->getAttribute(
    \Magento\Customer\Api\AddressMetadataInterface::ENTITY_TYPE_ADDRESS, 'example_attribute'
);
// customer_register_address is what makes it appear in Hyvä Checkout
$attribute->setData('used_in_forms', ['customer_register_address', 'customer_address_edit', 'adminhtml_customer_address']);
$this->attributeResource->save($attribute);
```

Then `bin/magento setup:upgrade && bin/magento cache:flush`.

- `select`/`multiselect` also need a source model and options (e.g.
  `Magento\Eav\Model\Entity\Attribute\Source\Table` + `'option' => ['values' => [...]]`);
  `multiselect` additionally needs `Magento\Eav\Model\Entity\Attribute\Backend\ArrayBackend`.
- `multiline` needs `multiline_count`.
- Min/max length validation comes from `validate_rules`, e.g.
  `['min_text_length' => 3, 'max_text_length' => 20]`.

**Persistence:** on **Magento Open Source** Hyvä Checkout renders and validates custom address
attributes but does **not** save them — you must implement a save service. On **Adobe Commerce**
`Magento_CustomerCustomAttributes` saves them automatically (parity with Luma).

Enabling 1.3.1000-beta1 runs two data patches: `MigrateAddressConfig` (backs the current address
form config up to a `..._legacy` path and splits the legacy `enabled`/`required` flags into their own
values) and `RemoveCustomerAttributesFromAddressConfig` (drops customer-entity attributes such as
`dob`, `taxvat`, `gender`, which cannot be stored on an address). Roll back with
`bin/magento hyva:checkout-attributes:restore` (`--dry-run` / `-d` to preview). From this version the
admin grid's **Enabled** and **Required** columns are derived from the EAV definition and no longer
configurable.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/form-customization/adding-custom-address-attributes.html>,
<https://docs.hyva.io/hyva-checkout/upgrading/upgrading-to-1.3.1000-beta1.html>
