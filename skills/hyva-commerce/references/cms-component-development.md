# Hyvä CMS component development

Platform-level topics (module split, storage, editor, Tailwind, scheduling, translations,
import/export, APIs, config paths) live in `cms-liveview.md`. This file covers writing, overriding
and extending components and content types.

A component is **two artifacts**: a JSON declaration in `etc/hyva_cms/components.json`, and a PHTML
template. Both live in your own Magento module (here: a `vendor/<vendor>/*` package, since the project
has no `app/code`).
<https://docs.hyva.io/hyva-commerce/features/cms/creating-components.html>

## Minimal component

```json
{
  "my_component": {
    "label": "My Component",
    "template": "Vendor_Module::elements/my_component.phtml",
    "content": {
      "title": { "type": "text", "label": "Title", "default_value": "Default Title" },
      "description": {
        "type": "textarea",
        "label": "Description",
        "attributes": { "placeholder": "Enter description here" }
      }
    }
  }
}
```

```php
<?php
declare(strict_types=1);
use Hyva\CmsLiveviewEditor\Block\Element;
use Magento\Framework\Escaper;
/** @var Element $block */
/** @var Escaper $escaper */
$title = $block->getTitle() ?? null;
$description = $block->getDescription() ?? null;
?>
<div>
    <h2 <?= /** @noEscape */ $block->getEditorAttrs('title') ?>>
        <?= $escaper->escapeHtml($title) ?>
    </h2>
    <div <?= /** @noEscape */ $block->getEditorAttrs('description') ?>>
        <?= $escaper->escapeHtml($description) ?>
    </div>
</div>
```

Field identifiers become camelCase getters (`title` → `getTitle()`). Root editor attributes
(`data-liveview-element`, block `id`, root `getEditorAttrs()`) are **injected automatically** into the
first HTML element since Hyvä CMS `1.2.0`; **field-level** `getEditorAttrs('field')` calls are not
auto-injected and are what enable click-to-edit. All editor attributes are stripped from public
output.

Opt out when the component has multiple root elements or you need precise placement (must be the
boolean `false`):

```php
<?php $block->setData('auto_attributes', false) ?>
<div
    <?= /** @noEscape */ $block->getEditorAttrs() ?>
    <?= /** @noEscape */ $block->renderBlockId() ?>
    data-liveview-element="my_component"
>
```

## Declaration schema reference

JSON Schema Draft 2020-12, schema id `hyva-liveview://schema/component-declaration.json`. The
authoritative file in an install is
`vendor/hyva-themes/magento2-hyva-cms/src/liveview-editor/etc/hyva_cms/jsonschema/component-declaration.json`.
Developer mode throws precise exceptions on validation failure.

Root data type: an object whose **keys are component identifiers** (≥3 chars; letters, digits, `-`,
`_` only; must be unique across the whole install).

### Component properties

| Property | Type | Notes |
|---|---|---|
| `label` | string | **Required** (except when disabled). Shown in the picker and structure tree |
| `disabled` | bool (`false`) | Removes it from the picker; existing instances keep working. Use to retire a component |
| `hidden` | bool (`false`) | Stays registered and renders; only removed from the manual picker. For programmatically inserted components (root containers) |
| `category` | string (`"Other"`) | Groups components in the picker |
| `template` | string \| bool | `[Vendor]_[Module]::[path].phtml`. Default: `[Vendor]_[Module]::elements/[component-identifier].phtml`. `false` = no standalone template (child rendered by its parent) |
| `icon` | string | `[Vendor]_[Module]::[path].(jpg\|jpeg\|png\|gif\|webp\|svg\|avif)` or a JSON emoji object. Default `Hyva_CmsLiveviewEditor::images/components/default.svg`. SVG recommended |
| `children` | bool \| object | Root-level only (not inside `content`/`design`/`advanced`). `true` = unrestricted; object with `config` to restrict |
| `require_parent` | bool (`false`) | Only offered inside parents that accept it; hidden from the top-level picker |
| `context_flags` | array | Flags other Hyvä systems use to identify a component for a context (e.g. `hyva_menu_root`, `hyva_form_root`, `email`) |
| `description` | string | 50–1000 chars; used in doc output and `hyva:cms:describe-components` |
| `build_from` | string | `[Vendor]_[Module]::[path].html` — base HTML scaffold for new instance variants |
| `content` / `design` / `advanced` | object | Field-group objects shown as editor sections. Content = main content, design = visual styling, advanced = technical (CSS classes, data attributes, conditional display). **Field identifiers must be unique across all three groups** — a duplicate throws in developer mode |
| `custom_properties` | array | Reserved for third-party metadata; ignored by validation and core |

<https://docs.hyva.io/hyva-commerce/features/cms/component-declaration-schema.html>

### Field properties

| Property | Notes |
|---|---|
| `type` | **Required.** One of: `boolean`, `color`, `date`, `datetime`, `html`, `image`, `link`, `multiselect`, `number`, `preset`, `range`, `products`, `richtext`, `select`, `searchable_select`, `text`, `text-align`, `textarea`, `url`, `variant`, `widget`, `category_importer`, `category_selector`, `custom_type` |
| `custom_type` | Required only when `type` is `custom_type`; names a registered custom field type |
| `label` | **Required.** Shown next to the input |
| `translate` | bool (`false`) — opt in to the translation panel; without it the field never appears in the translation workflow |
| `default_value` | Must match the field's type |
| `show_if` / `hide_if` | `{ "field-identifier": ["value1","value2"] }`. Prefer `show_if`; use both sparingly — complex conditionals confuse editors |
| `attributes` | HTML attributes + validation (below) |
| `options` | Static array of `{label, value}` objects, **or** a PHP class string |
| `config` | Field/child configuration (below) |
| `custom_properties` | Reserved, ignored by core |
| `includes` | Field-**group** level only (inside `content`/`design`/`advanced`), not per field |

`attributes` supports: `class`, `placeholder`, `required`, `pattern`, `min`, `max`, `minlength`,
`maxlength`, `step`, `comment` (help text below the field). Data-attribute variants validate without
triggering browser-native validation: `data-required`, `data-min`, `data-max`, `data-pattern`.
Custom messages: `data-required-msg`, `data-min-msg`, `data-max-msg`, `data-pattern-msg`
(`data-min-msg`/`data-max-msg` cover `min`/`max`/`minlength`/`maxlength`; Hyvä picks the right one).

```json
{
  "text_field": {
    "type": "text",
    "label": "Text Field",
    "attributes": {
      "required": true,
      "minlength": "1",
      "maxlength": "100",
      "pattern": ".*(foo|bar|Foo|Bar).*",
      "comment": "This is a comment",
      "placeholder": "Enter text here"
    }
  },
  "email_field": {
    "type": "text",
    "label": "Email Address",
    "attributes": {
      "required": true,
      "pattern": "[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$",
      "data-validation-message": "Please enter a valid email address"
    }
  }
}
```

Backslashes in a JSON `pattern` must be escaped. Validation runs in the browser before save.
<https://docs.hyva.io/hyva-commerce/features/cms/component-fields.html>

### Dynamic and preset options

```json
"options": "Vendor\\Module\\Model\\Source\\HeadingLevels"
"options": "Vendor\\Module\\Model\\Source\\Options::getCustomOptions"
```

A fully qualified class implementing `OptionSourceInterface` (escaped backslashes); append
`::methodName` to call something other than `toOptionArray()`.

The `preset` type is a **stateless** visual picker: it stores nothing itself, writes the values from
the selected option's `fields` map onto other fields, and derives the highlighted option by comparing
each option's `fields` to current values (so the highlight stays honest after manual edits). Set
`config.preview` to `"grid"` to render each option as a mini CSS-grid thumbnail; otherwise options may
supply an `emoji` or `icon` like the `variant` type. The built-in Columns component uses it.

```json
"layout": {
  "type": "preset",
  "label": "Layout",
  "config": { "preview": "grid" },
  "options": [
    { "label": "3 Columns", "fields": { "columns_mobile": 1, "columns_tablet": 2, "columns_desktop": 3 } },
    { "label": "Featured Center", "fields": { "columns_mobile": 1, "columns_desktop": 3, "grid_style": "center" } }
  ]
}
```

### Reusable field groups (`includes`)

```json
"design":   { "includes": "Hyva_CmsBase::etc/hyva_cms/default_design.json" },
"advanced": { "includes": "Hyva_CmsBase::etc/hyva_cms/default_advanced.json" }
```

Accepts a single path or an array of paths (`[Vendor]_[Module]::[path].json`). With an array, later
files win on a repeated key. Inline keys beat included keys, and included fields are laid out first —
so overriding an included key moves it to the end of the tab. `Hyva_CmsBase` ships
`default_design.json`, `default_design_typography.json` and `default_advanced.json`.

### Style variants

```json
"variants": {
  "type": "variant",
  "label": "Style Variant",
  "options": [
    { "label": "Default",     "value": "Vendor_Module::elements/my_component/default.phtml" },
    { "label": "Alternative", "value": "Vendor_Module::elements/my_component/alternative.phtml" }
  ]
}
```

One component, multiple templates, selected by the editor from a dropdown.

## Parent / child components

```json
{
  "row": { "label": "Row", "children": true },

  "usp_list": {
    "label": "USP List",
    "children": { "config": { "accepts": ["usp"], "max_children": 4 } },
    "content": { "title": { "type": "text", "label": "USP List Title", "default_value": "USP List Title" } }
  },

  "child_component": {
    "label": "Child Component",
    "require_parent": true,
    "template": false,
    "content": { "title": { "type": "text", "label": "Child Title" } }
  }
}
```

`children.config` keys:

- `accepts` (array) — allowed child identifiers; omit to allow anything (subject to `require_parent`).
- `excludes` (array) — prohibited children, even if otherwise allowed.
- `max_children` (int) — hard cap in the editor.
- `max_nesting_level` (int) — used by the `category_importer` field to bound category-tree import
  depth. **Not** a general nesting cap.

`config` also carries field-type-specific keys (e.g. for `category_importer`, `category_selector`).
For a child that is only ever rendered by its parent, set `template: false` **and**
`require_parent: true`.
<https://docs.hyva.io/hyva-commerce/features/cms/component-nesting.html>

## `Hyva\CmsLiveviewEditor\Block\Element` helpers

| Method | Signature / purpose |
|---|---|
| `getEditorAttrs` | `getEditorAttrs(string $field = '', ?string $childUid = null): string` — preview-only attributes that open the right form field on click |
| `renderEditorMessage` | `renderEditorMessage(array $arguments = [], ?string $type = null, ?string $template = null): string` — message visible only in the editor preview |
| `validPreview` | `validPreview(): bool` — `true` in the editor or a preview tab, `false` on the public storefront |
| `getImagePath` | `getImagePath(string $imagePath): string` — media-relative path → full URL |
| `getResponsiveImageData` | `getResponsiveImageData(array $image, ?string $type = null, array $attributes = []): array` — one `<picture>` source (width, height, srcset, media). `$type` is a **unique tracking id** — use `vendor_component-name_type` |
| `getLinkData` | `getLinkData(array $link): array` → `['url' => …, 'label' => …, 'open_in_new' => bool]` |
| `buildClasses` | `buildClasses(array $baseClasses, ?string $configKey = null, bool $includeElementClasses = true): string` — merges template classes with editor-configured ones |
| `getCssClasses` | returns the classes configured in the component's advanced section |
| `renderBlockId` | renders the block `id` attribute (needed only when opting out of auto attributes) |
| `createChildHtml` | `createChildHtml(array $elementData, ?string $prefix = 'child'): string` — render a child without parent/child layout relationships |
| `hasChildren` / `getChildren` | child presence and child node array |
| `renderRichText` | safely render a `richtext` field's stored HTML |

<https://docs.hyva.io/hyva-commerce/features/cms/component-templates.html>

### `renderRichText()` processing order

1. HTML escaped against a tag allow-list (common formatting tags plus `wbr` and `img`).
2. `Hyva\CmsLiveviewEditor\Model\RichText\DirectiveProcessor` replaces `{{hyva_image}}` and
   `{{hyva_link}}`.
3. Magento's standard CMS template filter resolves `{{config}}`, `{{customVar}}`, `{{var}}`,
   `{{trans}}`, `{{store}}`, `{{widget}}`, `{{media}}`.

Identical in the preview iframe and on the storefront.

```php
<?= /** @noEscape */ $block->renderRichText($block->getText()) ?>
```

Register extra TipTap extensions before the editor initialises:

```js
window.hyvaTiptapUtility.extend([MyCustomExtension]);
```

### Links and children

```php
$link = $block->getLinkData($block->getData('link') ?? []);
?>
<a href="<?= $escaper->escapeHtmlAttr($link['url']) ?>"
   <?= $link['open_in_new'] ? 'target="_blank" rel="noopener"' : '' ?>>
    <?= $escaper->escapeHtml($link['label']) ?>
</a>
```

```php
<?php foreach ($block->getChildren() ?: [] as $elementData): ?>
    <?= $block->createChildHtml($elementData, 'child_prefix') ?>
<?php endforeach; ?>
```

The second `createChildHtml()` argument is a unique block-name prefix that avoids naming conflicts.

### CSP and JavaScript in component templates

Never put inline `<script>` in a component template. Add JS via layout XML into `before.body.end`, so
it is present both on initial load and when the editor updates the preview dynamically:

```xml
<!-- view/frontend/layout/default.xml -->
<page xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:noNamespaceSchemaLocation="urn:magento:framework:View/Layout/etc/page_configuration.xsd">
    <body>
        <referenceContainer name="before.body.end">
            <block class="Magento\Framework\View\Element\Template"
                   name="vendor.my-component.script"
                   template="Vendor_Module::my-component/script.phtml"/>
        </referenceContainer>
    </body>
</page>
```

### Responsive images

Render image fields through `getResponsiveImageData()` + `Hyva\Theme\ViewModel\Media`. With Media
Optimization installed the sources are resized and converted; without it a plain `<picture>` is
emitted. Full pattern in `media-and-images.md`.

Reference implementations: the `Hyva_CmsBase` element templates
(`src/components-base/view/frontend/templates/elements` in `module-cms`).

## Overriding existing components

Two distinct approaches:

**1. Template override — visual changes only.** Place the file in the theme under the original
module path. To override `Hyva_CmsBase::elements/image.phtml`, create
`{themedir}/Hyva_CmsBase/templates/elements/image.phtml`. Fields, config and behaviour are preserved.

**2. Declaration override — functional/structural changes.** Sequence your module after the declaring
module, then redeclare the component under the **same key**:

```xml
<!-- etc/module.xml -->
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:framework:Module/etc/module.xsd">
    <module name="Vendor_Module">
        <sequence><module name="Hyva_CmsBase"/></sequence>
    </module>
</config>
```

```json
{
  "components": {
    "image": {
      "_comment": "Override of Hyva_CmsBase image component with custom fields",
      "template": "Vendor_Module::elements/image.phtml",
      "content": {
        "mobile_image":  { "type": "image", "label": "Mobile Image" },
        "tablet_image":  { "type": "image", "label": "Tablet Image" },
        "desktop_image": { "type": "image", "label": "Desktop Image" }
      }
    }
  }
}
```

Overrides are **full replacements, never partial merges**: anything omitted is gone. Hyvä chose this
deliberately for complete control, a clear ownership boundary at upgrade time, and manageable scope
(most sites need only 20–30 components).

**Always pin `template` in an override.** With `template` omitted, Hyvä resolves the *declaring
module's* convention path — your module's — which usually does not exist, and the component stops
rendering. Variant templates must keep the original **filename** while the directory may change
(`Hyva_CmsBase::elements/banner/text.phtml` → `MyCompany_Module::elements/my-banners/text.phtml`).

### Disabling and replacing

```json
{
  "components": {
    "image": { "_comment": "Disable the original", "disabled": true },
    "custom_image": {
      "template": "Vendor_Module::elements/custom-image.phtml",
      "content": { "solo_image": { "type": "image", "label": "Image" } }
    }
  }
}
```

### Legacy template support

Disabling or removing a component can break pages that already use it. Whitelist the old templates so
existing content keeps rendering:

```xml
<!-- etc/di.xml -->
<type name="Hyva\CmsLiveviewEditor\Model\Security\ComponentValidator">
    <arguments>
        <argument name="legacyComponents" xsi:type="array">
            <item name="banner" xsi:type="string">Hyva_CmsBase::elements/banner/basic.phtml</item>
            <item name="cta" xsi:type="array">
                <item name="0" xsi:type="string">Hyva_CmsBase::elements/cta/image.phtml</item>
                <item name="1" xsi:type="string">Hyva_CmsBase::elements/cta/split.phtml</item>
                <item name="2" xsi:type="string">Hyva_CmsBase::elements/cta/text.phtml</item>
            </item>
        </argument>
    </arguments>
</type>
```

Use `xsi:type="string"` for a single template, `xsi:type="array"` for a component with variants.
<https://docs.hyva.io/hyva-commerce/features/cms/overriding-existing-components.html>

## Choosing an approach

- New content type → new component.
- Styling / HTML only → template override in the theme.
- New fields or changed behaviour → declaration override in a module.
- Input type the built-ins don't cover → custom field type.
- Quick reusable admin-created section → instance component (see `cms-liveview.md`), moved into code
  later if it becomes permanent.

Design components **for editors, not developers**: merchants should never need to type CSS classes or
understand JS. Use dedicated fields and variant templates. Too many components signals inconsistent
content structure.
<https://docs.hyva.io/hyva-commerce/features/cms/working-with-components.html>

## Built-in component library (`Hyva_CmsBase`)

Declarations in `Hyva_CmsBase::etc/hyva_cms/components.json`. Intentionally generic — a starting point
for a design system, not a fixed page-builder library.

- **Layout**: Grid/Columns (per-breakpoint counts and gaps, one-click layout presets), Group/Row
  (section width control), Slider (arrows/pagination), Marquee (auto-scrolling image band).
- **Content**: Text, Heading (H1–H6), Spacer (responsive spacing + dividers), Link Button, HTML Code,
  Accordion + Accordion Item (native `details`).
- **Media/marketing**: Image (mobile/desktop variants, loading strategy, link, alt), Media Embed
  (YouTube/Vimeo, poster, aspect ratio, deferred loading), Card, Banner, Testimonial, USP List + USP.
- **Navigation/Magento**: Menu List + Menu List Item, CMS Block (by identifier), Product Slider (SKUs
  take priority over categories when both are set), Widget.

Notable patterns: Media Embed uses the `url` type; Product Slider uses catalog category selectors;
Widget uses the `widget` type; translatable fields opt in with `"translate": true`; Menu List carries
a context flag for menu contexts; Image/Banner/Card/Testimonial/USP expose a loading strategy whose
high-fetch-priority option emits `loading="eager" fetchpriority="high"` — use above-the-fold only.
<https://docs.hyva.io/hyva-commerce/features/cms/built-in-components.html>

## Custom field types

Advanced topic — expect to debug cases specific to your implementation.

**1. Register in `etc/adminhtml/di.xml`:**

```xml
<type name="Hyva\CmsLiveviewEditor\Model\CustomField">
    <arguments>
        <argument name="customTypes" xsi:type="array">
            <item name="foobar" xsi:type="string">YourVendor_YourModule::field-types/foobar.phtml</item>
        </argument>
    </arguments>
</type>
```

**2. Use it in a component:**

```json
"foobar_field": {
  "type": "custom_type",
  "custom_type": "foobar",
  "label": "Foo Bar Field",
  "attributes": { "pattern": ".*(foo|bar|Foo|Bar).*" }
}
```

**3. Write `view/adminhtml/templates/field-types/foobar.phtml`.** Block data available:
`uid`, `name`, `value`, `options`, `attributes`, `hasError`, `errorMessage`. Filter attributes with
`Hyva\CmsLiveviewEditor\ViewModel\Adminhtml\FieldTypes::getDefinedFieldAttributes()` (drops `class`,
`comment`; keeps validation attributes, validation messages and UI attributes).

Required markup patterns:

- Root element: `<div class="field-container" id="field-container-{uid}_{fieldName}" data-error?>` —
  the id format is required for validation to locate and highlight the field, and `data-error` must be
  added conditionally when `$hasError`.
- Every input: `name="{uid}_{fieldName}"` — required for frontend validation **and** for the editor to
  focus the field when its value is clicked in the preview.
- A `<ul id="validation-messages-{uid}_{fieldName}">` container. To place messages elsewhere, add
  `data-validation-messages-selector` (a CSS selector) to the field container.

Value update methods (Alpine, provided by Hyvä CMS):

- `updateWireField(uid, fieldName, value)` — **recommended default**; updates the preview *and* server
  state through Magewire immediately, so server-side validation runs on every change.
- `updateField(uid, fieldName, value)` — updates the preview via AJAX, bypassing Magewire; value is
  read from local state until save. Only for debounced inputs / request-minimising cases.

If you add your own Alpine component to the template you **cannot** call these from inside it — keep
inputs outside the Alpine component and update them with vanilla JS.

Validation state comes from **block data** (`$block->getData('hasError')`,
`$block->getData('errorMessage')`), never from `$magewire->errors`: panels are now loaded on demand via
separate HTTP requests, so the Magewire component is not in template scope. Remove any
`use Hyva\CmsLiveviewEditor\Magewire\LiveviewComposer;` / `@var LiveviewComposer $magewire` left over
from older implementations.

Templates have the full Magento backend environment: ViewModels, blocks, REST/GraphQL calls, external
APIs, third-party JS.

### Field handlers (complex UI)

Two architectures:

- **Pattern 1 — inline enhanced control** (e.g. Searchable Select): everything in the field template
  with Alpine; no modal template, no layout XML.
- **Pattern 2 — modal-based selection** (e.g. Product Handler, Link Handler): the field template shows
  a summary + trigger button and dispatches a window event; a separate handler template is an
  Alpine-powered `<dialog>` (uses the `x-htmldialog` plugin) rendered once per editor page.

Event protocol:

```js
// field → handler
$dispatch('toggle-handler-name', {
    isOpen: true,
    uid: 'component_123',
    fieldName: 'products',
    fieldValue: '[]',      // JSON string — always parse defensively
    maxSelected: 25
})

// handler → editor
$dispatch('editor-change', {
    name: this.uid,        // component UID, NOT the field name
    field: this.fieldName,
    value: this.selectedProducts,
    saveState: true        // true triggers Magewire sync
})
```

`editor-change` updates the hidden input, syncs Magewire when `saveState` is true, and updates the
preview; `value` can be any JSON-serialisable structure. **Using `fieldName` instead of `field` in the
save event makes the update fail silently.**

Register the handler modal once on the editor page:

```xml
<!-- view/adminhtml/layout/liveview_editor_index.xml -->
<page xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:noNamespaceSchemaLocation="urn:magento:framework:View/Layout/etc/page_configuration.xsd">
    <body>
        <referenceContainer name="content">
            <block name="product_selector_handler"
                   template="YourVendor_YourModule::handlers/product-selector-handler.phtml"/>
        </referenceContainer>
    </body>
</page>
```

Built-in handlers (all in `Hyva_CmsLiveviewEditor::page/js/`) to copy from:

| Handler | Architecture | Use case | File |
|---|---|---|---|
| Product Handler | modal | product selection with images | `product-handler.phtml` |
| Link Handler | modal | multi-type link config, tabs, conditional fields | `link-handler.phtml` |
| Searchable Select | inline | enhanced dropdown, keyboard nav, client filtering | `searchable-select-handler.phtml` |

<https://docs.hyva.io/hyva-commerce/features/cms/creating-custom-component-fields-types.html>

## Product and category attribute content

Provided by `Hyva_CmsMagentoAttributes`. The native Magento attribute stays in place; Hyvä renders
published CMS content over it. Enabled by default at `Stores > Configuration > Hyvä Commerce >
Hyvä CMS > Attributes` (Enable Product Attributes / Enable Category Attributes). Introduced in
Hyvä CMS `1.2.0`.

Three parts: **storage** (one liveview row per product/category holding enabled attributes, draft
content, published content and store-view overrides), **providers** (load/save/version/publish/scope),
**rendering** (plugins plus the recommended ViewModel).

Shared abstractions keep per-entity code tiny:

- Repositories extend `Hyva\CmsMagentoAttributes\Model\Repository\AbstractLiveviewRepository`
  (itself extending `AbstractAttributeRepository`), which owns CRUD, exception formatting and a
  request-scoped row cache keyed by entity ID (invalidated on save/delete). A concrete repository only
  sets the `ENTITY_FIELD` constant.
- Save controllers extend
  `Hyva\CmsMagentoAttributes\Controller\Adminhtml\AbstractAttributeSave`, which sanitises enabled
  attribute IDs, reconciles draft content when the enabled set changes (keeping kept attributes,
  dropping disabled ones, seeding newly enabled ones) and builds the JSON response.
- Schedule providers are one class,
  `Hyva\CmsMagentoAttributes\Model\Provider\AttributeScheduleProvider`, configured per entity type
  with a `virtualType`.

Key services: `AttributeCompatibilityResolver`, `AttributeHtmlRenderer`, `AttributeCodeResolver`,
`AttributeTypeResolver`, `Model\Config` (per-entity-type switches, DI-extendable),
`ViewModel\AttributeContent`.

Storefront plugins and GraphQL resolvers both gate published content and rendered HTML on the
per-entity liveview-enabled flag, and stored content is always passed through `ContentRedactor`.

### Rendering — use the ViewModel

Rules: render through `Hyva\CmsMagentoAttributes\ViewModel\AttributeContent`; pass the entity and the
attribute code to `getHtml()`; check the **returned CMS HTML**, not the native attribute value; never
guard on `$entity->getData('attribute_code')`; output with `@noEscape`; keep wrapper markup in the
theme template.

```php
<?php
declare(strict_types=1);
use Hyva\CmsMagentoAttributes\ViewModel\AttributeContent;
use Hyva\Theme\Model\ViewModelRegistry;
use Magento\Catalog\Block\Category\View;
use Magento\Framework\Escaper;
/** @var View $block */
/** @var ViewModelRegistry $viewModels */
/** @var Escaper $escaper */
$category = $block->getCurrentCategory();
if (!$category || !$category->getId()) { return; }
/** @var AttributeContent $attributeContent */
$attributeContent = $viewModels->require(AttributeContent::class);
$html = $attributeContent->getHtml($category, 'my_attribute');
if ($html === null || trim($html) === '') { return; }
?>
<section class="my-attribute-content" aria-label="<?= $escaper->escapeHtmlAttr(__('More information')) ?>">
    <?= /** @noEscape */ $html ?>
</section>
```

Wire it with layout XML — `catalog_category_view.xml` into `content` (e.g. `after="category.products"`,
block class `Magento\Catalog\Block\Category\View`), or `catalog_product_view.xml` into
`product.info.main` (e.g. `after="product.info.price"`, block class
`Magento\Framework\View\Element\Template`, reading the product from
`Hyva\Theme\ViewModel\ProductPage::getProduct()`).

**Anti-pattern** — this hides valid CMS content, because Hyvä content can exist while the native EAV
value is `null`:

```php
$value = $product->getData('my_attribute');
if (!$value) { return; }
echo $block->helper('Magento\Catalog\Helper\Output')->productAttribute($product, $value, 'my_attribute');
```

The ViewModel calls `AttributeHtmlRenderer::render()` directly. The legacy plugin path goes through
Magento's output helper first (HTML filtering, event dispatch, output processing) and then discards
that work when CMS content exists. Store scoping, preview support and Tailwind CSS are automatic in
both paths.

### Compatibility rules

`AttributeCompatibilityResolver` is the single source of truth for the admin checkbox list, first-time
auto-detection and editor availability. Defaults: product attributes must be `textarea` with Page
Builder enabled; category attributes `textarea` with Page Builder **or** WYSIWYG.

```xml
<!-- etc/di.xml — Magento merges DI arrays, so declare only the delta -->
<type name="Hyva\CmsMagentoAttributes\Model\AttributeCompatibilityResolver">
    <arguments>
        <argument name="rules" xsi:type="array">
            <item name="product_attribute" xsi:type="array">
                <item name="flags" xsi:type="array">
                    <item name="wysiwyg" xsi:type="string">is_wysiwyg_enabled</item>
                </item>
            </item>
        </argument>
    </arguments>
</type>
```

To make a new attribute eligible, add it with a data patch using `EavSetupFactory` and
`ScopedAttributeInterface::SCOPE_STORE`, `'input' => 'textarea'`,
`'is_html_allowed_on_front' => true`, and `'is_pagebuilder_enabled' => true` (products) or
`'is_wysiwyg_enabled' => true` (categories).

### Adding attribute editing to a custom entity

1. Storage model, resource model, API interfaces, DI preferences; repository extends
   `AbstractLiveviewRepository` with `ENTITY_FIELD` set to your ID column.
2. Extend `AbstractAttributeProvider` and register it in
   `Hyva\CmsLiveviewEditor\Model\ProviderPool` under your content-type key.
3. Add a schedule provider as a `virtualType` — no new class:

```xml
<virtualType name="HyvaCmsMyAttributeScheduleProvider"
             type="Hyva\CmsMagentoAttributes\Model\Provider\AttributeScheduleProvider">
    <arguments><argument name="entityType" xsi:type="string">my_attribute</argument></arguments>
</virtualType>
<type name="Hyva\CmsLiveviewEditor\Model\ProviderPool">
    <arguments>
        <argument name="scheduleProviders" xsi:type="array">
            <item name="my_attribute" xsi:type="object">HyvaCmsMyAttributeScheduleProvider</item>
        </argument>
    </arguments>
</type>
```

4. Save controller extending `AbstractAttributeSave` (four hooks: repositories, factory, entity-ID
   setter, EAV type).
5. Compatibility rule for the new content type. 6. Admin UI for enabling attributes.
7. Frontend rendering via `AttributeHtmlRenderer::render()` or a ViewModel delegating to it.

Merchant workflow and troubleshooting (missing attribute, stale storefront content, wrong store view,
disabled attribute) are documented at
<https://docs.hyva.io/hyva-commerce/features/cms/features/product-category-attributes.html>;
architecture at
<https://docs.hyva.io/hyva-commerce/features/cms/attribute-content-development.html>.

## Extending Hyvä CMS to a custom content type

Advanced, and explicitly flagged as susceptible to breaking changes between releases. Use
`Hyva_CmsMagento` (`src/magento-cms` in `module-cms`) as the reference.

The editor identifies content by `type` (e.g. `cms_page`, `cms_block`) and `id`; `id = 0` means
"create a new record of this type". Hyvä CMS can be enabled per item, per type, or for all types.

1. **Name the type.** Pick an `entity_type` matching the table you are extending; name the module
   `Vendor_HyvaCms[ContentTypeName]`.
2. **Tables/models.** `db_schema.xml`, `db_schema_whitelist.json`, models, API interfaces. You need a
   main content table plus a version-history table (e.g. `hyva_commerce_cms_block`,
   `hyva_commerce_cms_page_version_history`), following `Hyva_CmsMagento`'s column naming — especially
   for version history.
3. **Admin settings and UI.**
   - System config to enable/disable liveview: `hyva_commerce_cms/[your_content_type]/enabled`.
   - Listing page: a Yes/No `is_liveview_enabled` column, optionally an "open in editor" action.
   - Form: an `is_liveview_enabled` toggle, a button/link to the editor, optionally a preview URL field.
   - Register preview routes for automatic CSP frame policies (required when the admin runs CSP in
     strict rather than report-only mode):

```xml
<type name="Hyva\CmsLiveviewEditor\Model\Security\IsValidAdminPreviewRequest">
    <arguments>
        <argument name="allowedRoutes" xsi:type="array">
            <item name="blog/page/edit" xsi:type="string">blog/page/edit</item>
        </argument>
    </arguments>
</type>
```

   - Save logic updating the liveview entity (cf. `Hyva_CmsMagento::Observer/CmsPageSaveAfter.php`).
     Until step 4 the form shows `No content provider found for type: [your type]`.
4. **Liveview provider** implementing `Hyva\CmsLiveviewEditor\Api\ProviderInterface`, registered in the
   pool:

```xml
<type name="Hyva\CmsLiveviewEditor\Model\ProviderPool">
    <arguments>
        <argument name="contentProviders" xsi:type="array">
            <item name="cms_page" xsi:type="object">Hyva\CmsMagento\Model\LiveviewCmsPageProvider</item>
        </argument>
    </arguments>
</type>
```

   Study `Hyva\CmsMagento\Model\Provider\CmsBlockProvider` and `CmsPageProvider`.
   `getScopeSelector()` is **required** (breaking change in CMS 1.2.0 — custom providers fatal without
   it); the deprecated `getTailwindClassPrefix()` must stay implemented as a stub:

```php
public function getScopeSelector(int $entityId): string
{
    return '.hcms-blog-' . $entityId;
}
```

   Also implement `isTailwindJitEnabled()`, `getTailwindTableName()` and the column getters, pointing
   at a per-entity/per-theme/per-edition CSS table; a provider not using JIT can return `false` and
   stub the rest.
5. **Editor core settings.** Add a `core-settings.[entity_type]` block to the `core-settings` block in
   **`liveview_editor.xml`** (not `liveview_editor_index.xml`, so scheduling etc. keep working). You
   also get a per-type layout handle `{entity_type}_liveview_editor` (e.g. `blog_post_liveview_editor`).
   The template must dispatch two events:

```js
window.dispatchEvent(new CustomEvent('set-content-label', { detail: { label: 'Page' } }));

window.dispatchEvent(new CustomEvent('after-content-entity-saved', {
    detail: {
        entity_id: this.entityId,
        entity_type: this.entityType,
        is_active: this.formData.is_active ? 1 : 0,
        is_tailwindcss_jit_enabled: this.formData.is_tailwindcss_jit_enabled ? 1 : 0,
        disabled_notice_message: this.disabledNoticeMessage
    }
}));
```

6. **Display logic** deciding when to show Hyvä content instead of Page Builder content —
   `Hyva_CmsMagento` uses plugins on `Magento\Cms\Api\Data\PageInterface` and `BlockInterface`.
7. **Navigator support**: an admin controller returning JSON (`pageSize`, `currentPage`, search by
   identifier/title, `StoreDataProvider` for store data, `liveview_url` of the form
   `liveview/editor/index/type/{entity_type}/id/{id}/`, response
   `{ total_count: int, items: [{id, value, name, liveview_url, stores}] }`), a listings template at
   `view/adminhtml/templates/listings/{entity_type}.phtml` (Alpine fetch grouped by store, listening
   for `@listings-slideout-tab.window` with `event.detail.tab === '{entity_type}'`, search, and a
   "Create New" link to `liveview/editor/index/type/{entity_type}/id/0/`), registered in
   `view/adminhtml/layout/liveview_editor.xml`.
8. **Scheduling (optional)**: include the `scheduledItemId` parameter in
   `ProviderInterface::getStoreContentData()`, implement
   `Hyva\CmsScheduling\Api\ScheduleProviderInterface`, and handle the `scheduled_item` URL parameter
   (cf. `Hyva\CmsMagento\Plugin\Model\Page`).
9. **Restricting root components**: components declare `context_flags`; when your entity emits
   `init-content-properties`, pass `allowed_root_component_context_flags` to allow only components
   carrying a matching flag as roots. Feature modules can also push flags onto
   `Alpine.store('global').disallowedRootComponentContextFlags` to hide flagged components from the
   picker. This is how menus and email templates limit their roots.

<https://docs.hyva.io/hyva-commerce/features/cms/extending-for-other-content-types.html>

### Registering an Import/Export handler

Handler-driven — no need to touch `Hyva_CmsImportExport`. A registered handler appears automatically
in the export picker, the JSON tools and ZIP packages.

Implement the `@api` interface
`Hyva\CmsImportExport\Model\ContentType\ContentTypeHandlerInterface` (or extend
`AbstractContentTypeHandler` for sensible defaults, e.g. `isExportable()` returning `true`) and
register it in the shared pool:

```xml
<type name="Hyva\CmsImportExport\Model\ContentType\HandlerPool">
    <arguments>
        <argument name="handlers" xsi:type="array">
            <item name="my_type" xsi:type="object">My\Module\Model\ImportExport\MyHandler</item>
        </argument>
    </arguments>
</type>
```

Declare a module sequence on `Hyva_CmsImportExport`. Shipped handlers: `cms_page`, `cms_block`,
`instance_component`, `product_attribute`, `category_attribute` (import/export module) plus
`template` and `snippet` (contributed by `Hyva_CmsTemplate` exactly as an integrator would —
`Hyva\CmsTemplate\Model\ImportExport\TemplateHandler` / `SnippetHandler` are concise references).

| Method | Purpose |
|---|---|
| `getLabel(): string` | Label in the Import/Export UI |
| `getEntityList(string $search = '', int $limit = 50): array` | Selectable entities: `['id','label','identifier']` + optional `'stores'` |
| `getEntityData(int $entityId): array` | Portable metadata (portable identifiers, not auto-increment IDs) |
| `getProviderType(): ?string` | Liveview provider key, or `null` |
| `getExportFilename(array $entityData): string` | Filename-safe identifier for ZIP naming |
| `isExportable(int $entityId): bool` | Gates UI **and** server; default `true`. CMS page/block handlers return `true` only for entities carrying Hyvä content |
| `resolveEntityId(array $entityData): ?int` | Map an exported entity back to a local ID |
| `createEntity(array $entityData): int` | Create a copy for **Import as new** |
| `saveContent(int $entityId, array $draftContent, array $publishedContent): void` | Persist liveview content |
| `updateEntity(int $entityId, array $entityData): void` | Entity metadata after content; default no-op |
| `normalizeContentForExport(array $content): array` | Local IDs → portable keys; default no-op |
| `normalizeContentForImport(array $content): array` | Portable keys → local IDs; default no-op |
| `getImportWarnings(): array` | Warnings from the last `normalizeContentForImport()` |

Import/Export runs through adminhtml controllers, so a handler is reached via the editor UI;
registering it in the pool is all that is needed for both ZIP and JSON transfers.
