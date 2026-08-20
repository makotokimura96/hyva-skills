# Admin Dashboard

Replaces (or augments) the Magento admin landing page with a grid of configurable widgets, plus named
dashboard **views** that can be shared with admin roles.
<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/index.html>

## Packages and modules

| Composer package | Magento module(s) | Purpose |
|---|---|---|
| `hyva-themes/commerce-module-admin-dashboard-api` | `Hyva_AdminDashboardApi` | Stable widget contract: interfaces, `WidgetContext`, XSD, constants. No controllers, no templates, no runtime. **OSL-3.0** licensed |
| `hyva-themes/commerce-module-admin-dashboard` | `Hyva_AdminDashboardFramework` + `Hyva_AdminDashboardWidgets` | Runtime (controllers, repositories, schema, setup patches, system config, view models, layout, base templates, JS chart infra) + the default widget catalogue |
| `hyva-themes/commerce-module-admin-dashboard-cms-widgets` | `Hyva_AdminDashboardCmsWidgets` | Optional CMS-focused widgets, incl. Hyvä CMS integration |
| `hyva-themes/commerce-module-admin-dashboard-google-crux-history-widget` | `Hyva_AdminDashboardGoogleCruxHistoryWidget` | Optional Google CrUX History widget |

`Hyva\AdminDashboardFramework\Model\WidgetType\WidgetTypeDispatcher` checks at runtime whether each
widget implements the new `Hyva\AdminDashboardApi\Api\V1\WidgetTypeInterface` or the legacy
inheritance-based contract and dispatches accordingly, so both coexist on one dashboard. The
framework module also owns Dashboard Views & Roles.
<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/module-structure.html>

### Install

```bash
composer require hyva-themes/commerce-module-admin-dashboard
composer require hyva-themes/commerce-module-admin-dashboard-google-crux-history-widget   # optional
composer require hyva-themes/commerce-module-admin-dashboard-cms-widgets                  # optional
composer require hyva-themes/commerce-theme-adminhtml                                     # optional, recommended
bin/magento setup:upgrade
```

The API package is installed transitively and does not need to be required explicitly — but a
**custom widget module should require it directly** so it compiles without the dashboard runtime.
No additional setup steps. The Hyvä Admin Theme is recommended but the default
Magento/Adobe/Mage-OS admin themes are supported.
<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/installation.html>

## System configuration

`Stores → Settings → Configuration → Hyvä Commerce → Admin Dashboard`:

| Config path | Default | Effect |
|---|---|---|
| `hyva_admin_dashboard/general/enable` | `Yes` | Master switch; `No` removes Hyvä dashboard content and blocks widget view/create/edit/delete |
| `hyva_admin_dashboard/general/keep_default` | `No` | Keep the default Magento dashboard blocks, buttons and store switcher |
| `hyva_admin_dashboard/general/dashboard_position` | `After` | Hyvä content before or after the default content; only applies when **both** `enable` and `keep_default` are `Yes` |
| `hyva_admin_dashboard/toasts/duration` | `3000` | ms a dashboard message is shown |
| `hyva_admin_dashboard/charts/theme` | `Light` | Light or dark chart theme |
| `hyva_admin_dashboard/charts/fill_type` | `Solid Colors` | Solid colours or pattern fill |
| `hyva_admin_dashboard/charts/monochrome` | `No` | Shades of one colour instead of separate colours |
| `hyva_admin_dashboard/charts/monochrome_color` | `#003A7D` | Hex colour when monochrome is on |
| `hyva_admin_dashboard/charts/colors` | `#003A7D,#C701FF,#5940FF,#4ECBBD,#F9E858,#D83034,#FF9D3A,#008DFF,#FF73B6` | Chart palette when monochrome is off |
| `hyva_admin_dashboard/google_crux_history/api_key` | – | Google CrUX History API key; group only present when `Hyva_AdminDashboardGoogleCruxHistoryWidget` is installed |
| `hyva_admin_dashboard/developer/batching/enable` | `Yes` | Batch widget content requests |
| `hyva_admin_dashboard/developer/batching/max_batch_size` | `4` | Widget instances per content request |
| `hyva_admin_dashboard/developer/batching/debounce_ms` | `250` | Wait before sending a batch |
| `hyva_admin_dashboard/developer/batching/max_wait_ms` | `600` | Hard cap before a batch is released |
| `hyva_admin_dashboard/developer/batching/max_concurrent_requests` | `3` | In-flight batch requests; extra batches queue |

Widget content loads when the instance enters the viewport; the request fires when the max batch size
or the debounce limit is reached. Scrolling more widgets into view either joins the current batch
(resetting the debounce) or starts a new batch and releases the previous one. The widget-instance
Alpine component is deferred with `x-defer="intersect"`.
<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/system-configuration.html>

## Widget types vs widget instances

- A widget **type** is a reusable definition: one XML node plus one PHP class implementing
  `WidgetTypeInterface`. One type has many instances.
- A widget **instance** is a saved configuration of a type, stored in
  `hyva_admin_dashboard_widget_instance`, associated with the admin user who created it and with a
  dashboard view.

<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/index.html>

## Widget XML configuration

File: `etc/adminhtml/hyva_dashboard_widget.xml`. The XSD ships in `Hyva_AdminDashboardApi`.

```xml
<?xml version="1.0"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:module:Hyva_AdminDashboardApi:etc/adminhtml/hyva_dashboard_widget.xsd">
    <widget id="order_volume">
        <title>Order Volume</title>
        <class>Acme\OrderVolumeWidget\Model\Widget\OrderVolume</class>
        <display_type>bar_chart</display_type>
        <category>sales</category>
        <icon>chart-column</icon>
        <min_height>6</min_height>
        <min_width>2</min_width>
    </widget>
</config>
```

### `<widget>` attributes

- **`id`** (required) — unique, non-empty alphanumeric; `-`, `_`, `.` allowed.
- **`disabled`** (optional, default `false`) — admins cannot create/edit/delete instances and existing
  instances stop rendering.

### `<widget>` child arguments

| Argument | Required | Notes |
|---|---|---|
| `class` | yes | Must implement `Hyva\AdminDashboardApi\Api\V1\WidgetTypeInterface` (or, for legacy widgets, `Hyva\AdminDashboardFramework\Model\WidgetType\WidgetTypeInterface`) somewhere in its hierarchy, else an exception is thrown |
| `display_type` | yes | Selects the render template via `Converter::displayTypeTemplateMap` (configured in `di.xml`, item name = display type, value = template). Using `template` requires `<template>`; any other unmapped value throws |
| `acl` | no | Restricts create/edit/delete/view. Defaults to `Magento_Backend::admin`; change the default via the `defaultAclRole` argument of `Hyva\AdminDashboardFramework\Model\Config\Widget\Converter` |
| `cache_lifetime` | no | Seconds; default `86400`. Change the default via `Converter::$defaultCacheLifetime` |
| `category` | no | Groups widgets in the creation modal. Uncategorised → `Other`, appended last. Default name configurable via `Converter::$defaultCategoryName` |
| `full_screen` | no | Adds a full-screen toggle to the instance menu |
| `icon` | no | Must match an icon available to the `Hyva\Theme\ViewModel\LucideIcons` view model (i.e. a Lucide icon name). No icon when omitted |
| `min_height` | no | Minimum rows; default `1` |
| `min_width` | no | Minimum columns; default `1` |
| `tags` | no | Comma-separated keywords used by widget search |
| `template` | no | `Vendor_Module::path/to/template.phtml`, for display types the standard map does not cover |
| `title` | no | Falls back to the `id` with special characters replaced by spaces and words capitalised |
| `trailing_action` | no | Key/value pairs for `getTrailingAction()`; currently a footer link with `<label>`, `<route>` (URL or admin route path) and `<target>` |

<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/widget-xml.html>

## Widget PHP implementation — current (composition) API

Interfaces live in `Hyva\AdminDashboardApi\Api\V1\`. Implement `WidgetTypeInterface` directly, or one
of the **chart-type marker interfaces** in `Hyva\AdminDashboardApi\Api\V1\ChartType\` (they add no
methods; they tell `WidgetContextFactory` to wire the matching defaults provider into the context):

| Marker interface | Matching `display_type` | Bundled defaults |
|---|---|---|
| `BarChartWidgetTypeInterface` | `bar_chart` | chart appearance options |
| `LineChartWidgetTypeInterface` | `line_chart` | chart appearance options |
| `PieChartWidgetTypeInterface` | `pie_chart` | chart appearance options |
| `NumberWidgetTypeInterface` | `number` | number tile formatting |
| `DateIntervalWidgetTypeInterface` | varies | `default_interval` display property + helpers |

### `WidgetContextInterface`

Every `WidgetTypeInterface` method receives
`Hyva\AdminDashboardApi\Api\V1\WidgetContextInterface $ctx` as its first argument. It is a read-only
value object built by `WidgetContextFactory` from the merged widget XML plus chart-type defaults.
Wherever a legacy widget called `parent::method()`, a new-contract widget calls `$ctx->method()`.

- `getId(): string` — the XML `id`
- `getTitle(): Phrase`
- `getAcl(): ?string`
- `getTrailingAction(): array` — `array{title?, href?, target?}`
- `getOption(string $key): mixed`
- `toArray(): array` — full merged config, used by the framework `GetHtml` controller as the
  `type_data` JS payload
- `isAllowed(?WidgetInstanceInterface $widgetInstance): bool` — default ACL + ownership check
- `getDisplayProperties(): array` / `getConfigurableProperties(): array` — chart-type defaults

Default implementation: `Hyva\AdminDashboardApi\Model\WidgetContext`.

### Minimal widget

```php
use Hyva\AdminDashboardApi\Api\V1\ChartType\BarChartWidgetTypeInterface;
use Hyva\AdminDashboardApi\Api\V1\WidgetContextInterface;
use Hyva\AdminDashboardApi\Api\V1\WidgetInstanceInterface;
use Magento\Framework\Phrase;

class OrderVolume implements BarChartWidgetTypeInterface
{
    public function __construct(private OrderRepositoryInterface $orderRepo) {}

    public function getDisplayData(WidgetContextInterface $ctx, WidgetInstanceInterface $i): mixed
    {
        return [
            'series' => [['name' => 'Orders', 'data' => $this->fetchSeries($i)]],
            'xaxis'  => ['categories' => ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']],
        ];
    }

    public function getTitle(WidgetContextInterface $ctx, ?WidgetInstanceInterface $i): Phrase                   { return $ctx->getTitle(); }
    public function getConfigurableProperties(WidgetContextInterface $ctx): array                                { return $ctx->getConfigurableProperties(); }
    public function getDisplayProperties(WidgetContextInterface $ctx): array                                     { return $ctx->getDisplayProperties(); }
    public function getTrailingAction(WidgetContextInterface $ctx, ?WidgetInstanceInterface $i): array           { return $ctx->getTrailingAction(); }
    public function isAllowed(WidgetContextInterface $ctx, ?WidgetInstanceInterface $i): bool                    { return $ctx->isAllowed($i); }
    public function beforeSave(WidgetContextInterface $ctx, WidgetInstanceInterface $i): WidgetInstanceInterface { return $i; }
    public function afterSave(WidgetContextInterface $ctx, WidgetInstanceInterface $i): WidgetInstanceInterface  { return $i; }

    private function fetchSeries(WidgetInstanceInterface $i): array { /* ... */ }
}
```

### Extending the chart-type defaults

Read everything from `$ctx`; only `array_merge(...)` when adding your own properties:

```php
use Hyva\AdminDashboardApi\Api\V1\ChartType\DateIntervalWidgetTypeInterface;
use Hyva\AdminDashboardApi\Api\V1\Service\WidgetDateIntervalHelperInterface;
use Hyva\AdminDashboardApi\Api\V1\WidgetContextInterface;
use Hyva\AdminDashboardApi\Api\V1\WidgetInstanceInterface;

class DailyOrderVolume implements DateIntervalWidgetTypeInterface
{
    public function __construct(private WidgetDateIntervalHelperInterface $intervalHelper) {}

    public function getDisplayProperties(WidgetContextInterface $ctx): array
    {
        return array_merge($ctx->getDisplayProperties(), [
            'highlight_today' => ['label' => __('Highlight today'), 'input' => ['type' => 'toggle']],
        ]);
    }

    public function getConfigurableProperties(WidgetContextInterface $ctx): array
    {
        return array_merge($ctx->getConfigurableProperties(), [
            'store_ids' => [
                'label' => __('Store Views'),
                'input' => ['type' => 'scope', 'attributes' => ['multiple' => true, 'required' => true]],
            ],
        ]);
    }

    public function getDisplayData(WidgetContextInterface $ctx, WidgetInstanceInterface $i): mixed
    {
        return ['intervals' => $this->intervalHelper->getIntervalDataWithTimestamps()];
    }
}
```

### Method reference (current contract)

```php
public function getDisplayData(WidgetContextInterface $ctx, WidgetInstanceInterface $widgetInstance): mixed
public function getTitle(WidgetContextInterface $ctx, ?WidgetInstanceInterface $widgetInstance): Phrase
public function getConfigurableProperties(WidgetContextInterface $ctx): array
public function getDisplayProperties(WidgetContextInterface $ctx): array
public function getTrailingAction(WidgetContextInterface $ctx, ?WidgetInstanceInterface $widgetInstance): array
public function isAllowed(WidgetContextInterface $ctx, ?WidgetInstanceInterface $widgetInstance): bool
public function beforeSave(WidgetContextInterface $ctx, WidgetInstanceInterface $widgetInstance): WidgetInstanceInterface
public function afterSave(WidgetContextInterface $ctx, WidgetInstanceInterface $widgetInstance): WidgetInstanceInterface
```

- `getDisplayData()` — data the widget renders; shape depends on `display_type` or the consuming
  template. Read saved config with `$widgetInstance->getPropertyValue(...)`.
- `getTitle()` — `$widgetInstance` is `null` before creation; fall back to `$ctx->getTitle()`.
- `getConfigurableProperties()` — inputs that configure **behaviour**; `getDisplayProperties()` —
  inputs that configure **appearance**. Shapes documented under "Configurable inputs" below.
- `getTrailingAction()` — the footer link, read from `<trailing_action>` via `$ctx`.
- `isAllowed()` — default returns `false` when the admin lacks the `<acl>` resource **or** when the
  instance was created by another admin user.
- `beforeSave()` / `afterSave()` — invoked by
  `Hyva\AdminDashboardFramework\Model\WidgetInstance\WidgetInstanceRepository::save()`; both must
  return a `WidgetInstanceInterface`. Used by the `Checklist`, `Links` and `Google CrUX History`
  widgets to transform config values or trigger external fetches.

<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/widget-php.html>

## Dashboard API package details

`Hyva_AdminDashboardApi` ships interfaces, `WidgetContext`, the widget XSD and constants only. A
widget module depending solely on it compiles with `bin/magento setup:di:compile` even when the
dashboard runtime is absent; end users only see the widget where the runtime is also installed.

```json
{ "require": { "hyva-themes/commerce-module-admin-dashboard-api": "^2.0" } }
```

Core contract in `Hyva\AdminDashboardApi\Api\V1\`:

- `WidgetTypeInterface`
- `WidgetContextInterface` (impl. `Hyva\AdminDashboardApi\Model\WidgetContext`)
- `WidgetInstanceInterface` — slim read-only view: `getInstanceId()`, `getWidgetTypeId()`,
  `getCreatedBy()`, `getConfiguration()`, `getPropertyValues(string $propertyType)`,
  `getPropertyValue(string $propertyType, string $propertyName)`
- `WidgetAuthInterface` — used by `WidgetContext::isAllowed()`; `isAllowedAcl(?string $resource)`,
  `getCurrentAdminUserId()`

Supporting interfaces:

- `Hyva\AdminDashboardApi\Api\V1\Defaults\WidgetTypeDefaultsInterface` — supplies chart-type default
  property definitions; implementations live in the framework, widget classes never reference it.
- `Hyva\AdminDashboardApi\Api\V1\Service\WidgetDateIntervalHelperInterface` — inject instead of
  extending `AbstractDateIntervalWidget`; `getDateIntervalsAsOptions()`,
  `getIntervalDataWithTimestamps()`.
- `Hyva\AdminDashboardApi\Api\V1\Source\WidgetDateIntervalSourceInterface` — extends
  `Magento\Framework\Data\OptionSourceInterface`, adds `getIntervals()`.

Constants (use instead of magic strings):

- `Hyva\AdminDashboardApi\Api\ConfigurationKeys::CONFIGURABLE_PROPERTIES` = `'configurable_properties'`
- `Hyva\AdminDashboardApi\Api\ConfigurationKeys::DISPLAY_PROPERTIES` = `'display_properties'`
- `Hyva\AdminDashboardApi\Api\WidgetOptions` — string constants for every widget XML element/attribute
  the framework reads

<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/dashboard-api.html>

## Legacy API (pre-2.0.0, still bridged)

Shipped with Admin Dashboard `1.0.0`. Widgets implemented
`Hyva\AdminDashboardFramework\Model\WidgetType\WidgetTypeInterface`, optionally extending
`Hyva\AdminDashboardFramework\Model\WidgetType\AbstractWidgetType` (extending was optional,
implementing the interface was required). **New widgets must use the composition API above.**

Legacy signatures (no `$ctx` argument):

```php
public function getProperties(string $propertyType): array
public function getPropertyByName(string $propertyType, string $propertyName): ?array
public function getConfigurableProperties(): array
public function getDisplayProperties(): array
public function getDisplayData(WidgetInstanceInterface $widgetInstance)
public function getTitle(?WidgetInstanceInterface $widgetInstance): Phrase
public function getTrailingAction(?WidgetInstanceInterface $widgetInstance): array
public function isAllowed(?WidgetInstanceInterface $widgetInstance): bool
public function beforeSave(WidgetInstanceInterface $widgetInstance): WidgetInstanceInterface
public function afterSave(WidgetInstanceInterface $widgetInstance): WidgetInstanceInterface
```

`beforeSave`/`afterSave` exist so integrators do not have to plugin
`WidgetInstanceRepository::save()` and filter by type. The XML, available-widget-types, configurable
inputs and styling docs apply to both APIs unchanged.
<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/legacy-api.html>

### Legacy → current migration map

| Legacy | Current |
|---|---|
| `Hyva\AdminDashboardFramework\Model\WidgetType\WidgetTypeInterface` | `Hyva\AdminDashboardApi\Api\V1\WidgetTypeInterface` |
| `Hyva\AdminDashboardFramework\Model\WidgetInstance\WidgetInstanceInterface` | `Hyva\AdminDashboardApi\Api\V1\WidgetInstanceInterface` (slim, read-only) |
| `Hyva\AdminDashboardFramework\Model\WidgetType\AbstractWidgetType` | *no replacement* — implement the interface, read defaults from `$ctx` |
| `AbstractBarChart` / Line / Pie / Number base classes | the matching `*WidgetTypeInterface` in `…\Api\V1\ChartType\` |
| `WidgetTypeInterface::KEY_CONFIGURABLE_PROPERTIES` / `KEY_DISPLAY_PROPERTIES` | `ConfigurationKeys::CONFIGURABLE_PROPERTIES` / `DISPLAY_PROPERTIES` |

Mechanical rule: **every method gains `WidgetContextInterface $ctx` as its first argument, and every
`parent::method(...)` becomes `$ctx->method(...)`.** The framework-side `WidgetTypeInterface` and
`WidgetInstanceInterface` were removed (DI preferences resolve them, but `use` statements need
updating); framework-internal code needing the wider repository interface should depend on
`Hyva\AdminDashboardFramework\Api\V1\WidgetInstance\WidgetInstanceRepositoryInterface`. The abstract
chart base classes remain for legacy widgets. Widget XML should move to the
`Hyva_AdminDashboardApi` XSD URN (the old framework URN still validates during the bridged period).
Also note `getPropertyValue()`/`getPropertyValues()` replaced
`getConfigurablePropertyValue()`/`getDisplayPropertyValue()`, removed in `1.0.0`:

```php
$storeIds = $widgetInstance->getPropertyValue(ConfigurationKeys::CONFIGURABLE_PROPERTIES, 'store_ids');
```

<https://docs.hyva.io/hyva-commerce/upgrading/upgrading-to-1.3.0.html>

## Widget instances

Stored in `hyva_admin_dashboard_widget_instance`. `WidgetInstanceInterface` has getters/setters for
every column (`getInstanceId()`, `setConfiguration(array $config)`, …) plus:

- `getConfigurationJson(): ?string` — raw JSON (vs `getConfiguration()` returning an array)
- `getPropertyValues(string $propertyType): array` — the matching property set, or `[]`
- `getPropertyValue(string $propertyType, string $propertyName): mixed` — the value, or `null`
- `getDisplayData(): mixed` — proxies the widget *type*'s `getDisplayData()`, serving from the
  `hyva_admin_dashboard` cache when possible and creating an entry otherwise
- `getWidgetType(): ?WidgetTypeInterface` — returns the API interface for new-contract widgets and
  the legacy framework interface for `AbstractWidgetType` widgets. Call sites that invoke widget
  methods should go through `WidgetTypeDispatcher`, not the widget object directly.

<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/widget-instances.html>

## Configurable inputs

`getConfigurableProperties()` / `getDisplayProperties()` return arrays of field definitions. Array
keys become the rendered input's `name` attribute.

```php
return [
    'input_name' => [
        'label' => __('My Awesome Input Label'),
        'note'  => __('Helper text below the input.'),
        'input' => [
            'type'    => 'select',
            'options' => [
                ['label' => 'Foo', 'value' => 'foo'],
                ['label' => 'Bar', 'value' => 'bar'],
            ],
            'attributes' => ['required' => true],
            'depends'    => ['configurable_properties[input_name]' => 0],
        ],
    ],
];
```

`input` keys:

- **`type`** — input type (below).
- **`subtype`** — with `text`: `email`, `url`, `tel`, `number`; with `select`: `multiselect`.
- **`options`** — for `select` types; nested arrays of `label`/`value` pairs, exactly like a Magento
  source model.
- **`groups`** — for `select` types; each group is `label` + `options`.
- **`attributes`** — catch-all `attribute => value` map mapped onto the input element. Used for
  `required`, `maxlength`/`minlength`, any HTML attribute, `data-*` attributes, Alpine bindings.
  Rendered by `Hyva\AdminDashboardFramework\ViewModel\Widget::renderHtmlAttributes()`. A `value`
  attribute sets the default; `select`/`textarea` templates handle defaults themselves, and `toggle`
  uses `checked`.
- **`inputs`** — nested field definitions, used with `dynamic-rows`.
- **`depends`** — array-notation keys targeting other properties
  (`configurable_properties[url_type] => 1`). **All** criteria must be satisfied, and matching is by
  equality. The Google CrUX History widget uses this to swap its `URL` and `Store View` fields.

Input types:

| `type` | Renders |
|---|---|
| `date` | HTML date picker |
| `dynamic-rows` | Magento-style dynamic rows; child fields via `inputs` |
| `select` | `<select>`; supports `groups` and `multiselect` subtype |
| `scope` | multiselect of store views grouped by website and store |
| `template` | custom template — pass `'template' => 'Vendor_Module::path/to/template.phtml'` |
| `text` | text input; `subtype` for `email`, `url`, `number` |
| `textarea` | textarea (e.g. `attributes => ['rows' => 5, 'cols' => 50]`) |
| `toggle` | toggle switch |

`note` supports a permitted-HTML-tag allow-list, passed as the `allowed_note_tags` array argument to
the `input.note` block in the `hyva_dashboard_widget` layout handle (`<a>` and `<br>` allowed by
default; array key = tag name, value = allow flag).
<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/configurable-inputs.html>

## Dashboard cache

Cache type `hyva_admin_dashboard`, class
`Hyva\AdminDashboardFramework\Model\Cache\Type\AdminDashboard`. Stores two things.

**Widget type configuration** — all `etc/adminhtml/hyva_dashboard_widget.xml` files compiled, parsed
and converted by `Hyva\AdminDashboardFramework\Model\Config\Widget\Converter`, readable via
`Hyva\AdminDashboardFramework\Model\WidgetConfig`, grouped as:

- `widget_pool` — keyed by widget type ID
- `widget_categories` — grouped by category
- `widget_tags` — grouped by tag
- `widget_templates` — template paths keyed by widget type ID

**Widget instance content** — the result of `getDisplayData()`, written when an instance is saved and
served from cache whenever possible. Entries expire with `cache_lifetime`, are removed when the
instance is deleted, or when the cache is flushed. Cache key:

```text
hyva_admin_dashboard:widget:{{WIDGET_TYPE_ID}}:display_data:{{WIDGET_INSTANCE_ID}}
```

Change the key format with a plugin on
`Hyva\AdminDashboardFramework\Model\Cache\Type\AdminDashboard::getWidgetInstanceDisplayDataCacheKey`.
<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/dashboard-cache.html>

## Layout handles

**Core handles**

- `hyva_dashboard_widget` — all containers/blocks for adding a widget dashboard to an admin page;
  places content in `content` and extra JS in `before.body.end`. Because `ifconfig` cannot be used on
  `<container>`, three "pseudo-container" blocks exist and use `ifconfig` themselves:
  - `widget-container.before` — houses the widget configuration form input blocks
  - `widget-container.content` — the dashboard, widget instances, instance skeleton, config forms
  - `widget-container.after` — the Alpine component templates
- `hyva_dashboard_widget_instance` — structure of a single widget instance (header, content, menu,
  footer) plus extra blocks for customisation. **Every block in this handle receives the widget
  instance object as a data argument named `widget_instance`.**

**Per-widget-type handles** — `hyva_dashboard_widget_instance_{{WIDGET_TYPE_ID}}`, loaded when
rendering a widget of that type.

**Default-dashboard handles** — `default_magento_dashboard_before` and
`default_magento_dashboard_after`. `Hyva\AdminDashboardFramework\Observer\Adminhtml\AddDashboardLayoutHandles`
picks one based on `hyva_admin_dashboard/general/dashboard_position` and appends it to the layout for
`dashboard_index_index`; loading is gated by `hyva_admin_dashboard/general/keep_default`.
<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/layout-handles.html>

## Styling

Widgets are styled with **LESS**, exactly like the rest of the Magento admin — add or override admin
LESS files the standard Magento way.
<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/styles.html>

## Tutorials / customisation recipes

**Widget instance menu** — create `hyva_dashboard_widget_instance.xml` (or the per-type handle
`hyva_dashboard_widget_instance_{{WIDGET_TYPE_ID}}` to scope it):

```xml
<page xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:noNamespaceSchemaLocation="urn:magento:framework:View/Layout/etc/page_configuration.xsd">
    <body>
        <referenceBlock name="widget-instance.menu.foo" remove="true"/>
        <referenceBlock name="widget-instance.menu">
            <block name="foo" template="Vendor_Module::path/to/foo.phtml"/>
        </referenceBlock>
        <referenceBlock name="widget-instance.menu.foo" before="widget-instance.menu.bar"/>
    </body>
</page>
```

**Custom configurable input type** — add a child block to `widget-form.inputs` in
`hyva_dashboard_widget.xml`; the block name **must** follow `input.{{TYPE}}` (or
`input.dynamic-rows.{{TYPE}}` for the dynamic-row variant) so Magento auto-renders it:

```xml
<referenceBlock name="widget-form.inputs">
    <block name="input.{{TYPE}}" template="Vendor_Module::path/to/the/input/template.phtml"/>
</referenceBlock>
```

Inside the template: `$block->getWidget()` / `getData('widget')` (widget type),
`$block->getWidgetInstance()` / `getData('widget_instance')` (`null` when not tied to an instance),
`$block->getInputName()`, `$block->getInputConfig()`, `$block->getInputId()`. Then use `{{TYPE}}` as
the input `type` in the widget's PHP.

**Widget categories** — configure `Hyva\AdminDashboardFramework\Model\Config\Widget\Converter` via
`etc/di.xml`. Magento merges the arrays, so declare only what changes:

```xml
<type name="Hyva\AdminDashboardFramework\Model\Config\Widget\Converter">
    <arguments>
        <argument name="categoryNames" xsi:type="array">
            <item name="foo" xsi:type="array">
                <item name="enabled" xsi:type="boolean">true</item>
                <item name="label" xsi:type="string">Foo</item>
                <item name="sortOrder" xsi:type="number">500</item>
            </item>
            <item name="sales" xsi:type="array">
                <item name="enabled" xsi:type="boolean">false</item>
            </item>
        </argument>
        <argument name="defaultCategoryName" xsi:type="string">foo</argument>
    </arguments>
</type>
```

Lower `sortOrder` appears first; `label` renames; `enabled=false` removes. Category names are
translated in the templates, so renaming for translation is unnecessary. **The default category must
be enabled.**
<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/tutorials.html>

## JavaScript event reference

The dashboard has **no Magento (PHP) events** — there is nothing to observe server-side. Components
communicate through browser custom events. Placeholder tokens such as `{{WIDGET_TYPE_ID}}` /
`{{INSTANCE_ID}}` are substituted at runtime, and **underscores in substituted values become dashes**
(e.g. `configure-widget-type-conversion_rate`).

**Widget configuration form**

| Event | Fired when |
|---|---|
| `configure-widget-type-{{WIDGET_TYPE_ID}}` | a type is selected to create, or an instance is edited (then the token is the *instance* ID); opens the config modal |
| `new-widget-menu` | `Add Widget` clicked; opens the selection modal |
| `force-close-widget-config-form` | `Cancel` in the customisation toolbar while a form has unsaved changes |
| `widget-config-form-open` / `widget-config-form-close` | config modal opened/closed for an existing instance |
| `widget-config-form-dirty-close` | modal closed with unsaved changes; triggers the confirmation modal |
| `widget-config-form-reset` | config modal closed |

**Widget instances**

| Event | Fired when |
|---|---|
| `widget-instance-created` | a new instance saved successfully; tells the container to insert it |
| `widget-instance-data-updated` | instance content updated (on first init and after config changes) |
| `widget-instance-updated-{{WIDGET_INSTANCE_ID}}` | existing instance saved; container updates that widget |
| `widget-instance-{{INSTANCE_ID}}-{{PROPERTY_TYPE}}-{{INPUT_NAME}}-updated` | property switcher value changed; `PROPERTY_TYPE` is `configurable-properties` or `display-properties` |
| `widget-filter-update` | filter option selected; detail `{id: instanceId, value: selectedFilter}` |
| `sort-checklist-items` | checklist sort action; detail `{id: instanceId}` |

**Container and edit mode**

`enabled-widget-container-edit-mode`, `disabled-widget-container-edit-mode`,
`widget-container-edit-mode-enabled` (disables the `Customize Dashboard` button),
`widget-container-edit-mode-disabled` (re-enables it), `widget-container-initialised`,
`widget-container-updated` (on init and whenever a widget is added/removed), `reset-widget-order`
(Cancel; restores the last stable state), `widget-dashboard-clear`.

**Dashboard views**

`create-new-dashboard-view`, `dashboard-view-new-modal-open`, `dashboard-view-edit-modal-open`,
`dashboard-view-duplicate-modal-open`, `dashboard-view-delete-modal-open`,
`dashboard-view-loaded` (after the `View/Load` controller returned instances and the grid rendered —
the hook for per-view widget init), `dashboard-view-changed`,
`dashboard-view-saved` (after `View/Save`), `dashboard-view-deleted` (after `View/Delete`),
`dashboard-view-permissions-changed`, `dashboard-view-access-revoked` (active view became
inaccessible — listeners should redirect to the default view), `dashboard-view-switch-proceed`,
`dashboard-view-switch-failed`.

**Charts** — `dashboard-charts-ready` (ApexCharts loaded and available as `window.ApexCharts`),
`update-chart-size-{{INSTANCE_ID}}` (full-screen toggled or resize requiring a chart resize).

**General UI** — `update-toast`.
<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/events.html>

## Charts infrastructure

Powered by **ApexCharts 4.7.0**, bundled with `Hyva_AdminDashboardFramework`:

- `Hyva/AdminDashboardFramework/view/adminhtml/web/js/lib/apexcharts-4.7.0.js` — minified library,
  version in the filename
- `Hyva/AdminDashboardFramework/view/adminhtml/requirejs-config.js` — maps it to the `ApexCharts`
  alias
- `Hyva_AdminDashboardFramework::js/charts/apex-charts.phtml` — loads the library, exposes
  `window.ApexCharts`, dispatches `dashboard-charts-ready`
- `Hyva_AdminDashboardFramework::js/widget/default-chart.phtml` — defines the `chartWidget` Alpine
  component: default chart options (toolbars, legend position), empty-state options (grid lines and
  axis labels removed in favour of a message), data receipt/init/render, plus `beforeRender()` and
  `afterRender()` extension points

Base chart implementations:

| Chart | Class | `display_type` | Templates | Alpine component |
|---|---|---|---|---|
| Bar | `Hyva\AdminDashboardFramework\Model\Widget\AbstractBarChart` | `bar_chart` | `…Framework::widget/bar-chart.phtml`, `…Framework::js/widget/bar-chart.phtml` | `barChartWidget` |
| Line | `…\Model\Widget\AbstractLineChart` | `line_chart` | `…Framework::widget/line-chart.phtml`, `…Framework::js/widget/line-chart.phtml` | `lineChartWidget` |
| Pie | `…\Model\Widget\AbstractPieChart` | `pie_chart` | `…Framework::widget/pie-chart.phtml`, `…Framework::js/widget/pie-chart.phtml` | `pieChartWidget` |

All three extend the base `chartWidget` component.

### The `table` display type

`display_type` `table`, template `Hyva_AdminDashboardFramework::widget/table.phtml`. No widget class —
any widget can return this shape:

```php
[
    'headings' => ['Foo', 'Bar', 'Baz'],
    'rows' => [
        ['href' => 'https://foo.bar/', 'values' => ['Foo', 'Bar', 'Baz']],
        ['href' => 'https://bar.baz/', 'values' => ['Bar', 'Baz', 'Foo']],
    ],
    'footer'  => ['Foo', 'Bar', 'Baz'],
    'caption' => 'FooBarBaz',
]
```

Omitted top-level keys simply do not render. A row with `href` becomes fully clickable.

## Built-in widget classes

Shipped by `Hyva_AdminDashboardWidgets` unless noted.

| Widget | Class | `display_type` | Template / Alpine |
|---|---|---|---|
| Abandoned Carts | `Hyva\AdminDashboardWidgets\Model\Widget\AbandonedCarts` | `date-interval-table` | `…Framework::widget/table.phtml` |
| Average Order Value | `…\Model\Widget\AverageOrderValue` | `template` | `…Widgets::widget/average-order-value.phtml` + `…Framework::js/widget/date-interval.phtml`, `dateIntervalWidget` |
| Best Selling Products | `…\Model\Widget\BestSellingProducts` | `table` | `…Framework::widget/table.phtml` |
| Checklist | `…\Model\Widget\CheckList` | `template` | `…Widgets::widget/checklist.phtml` + `…Widgets::js/widget/checklist.phtml`, `checklistWidget` |
| Customer Order Totals | `…\Model\Widget\CustomerOrderTotals` | `date-interval-table` | `…Framework::widget/table.phtml` |
| Google CrUX History | `Hyva\AdminDashboardGoogleCruxHistoryWidget\Model\Widget\GoogleCruxHistory` | `template` | `…GoogleCruxHistoryWidget::widget/google-crux-history.phtml` + its JS, `cruxHistoryChart` (bespoke chart, extends no base) |
| Hyvä CMS Scheduled Releases | `Hyva\AdminDashboardCmsWidgets\Model\Widget\CmsScheduledReleases` | `template` | `…CmsWidgets::widget/cms-scheduled-releases.phtml` |
| Launchpad | `…\Model\Widget\Launchpad` | `template` | `…Widgets::widget/launchpad.phtml` + JS, `initDashboardLaunchpad` |
| Links | `…\Model\Widget\Links` | `template` | `…Widgets::widget/links.phtml` |
| Module Versions | `…\Model\Widget\ModuleVersions` | `table` | `…Framework::widget/table.phtml` |
| Most Viewed Products | `…\Model\Widget\MostViewedProducts` | `table` | `…Framework::widget/table.phtml` |
| New Customers | `…\Model\Widget\NewCustomers` | `table` | `…Framework::widget/table.phtml` |
| Orders by Country | `…\Model\Widget\OrdersByCountry` | `template` | `…Widgets::widget/orders-by-country.phtml` + JS, `ordersByCountryWidget` (extends the pie chart component) |
| Order Volume | `…\Model\Widget\OrderVolume` | `template` | `…Widgets::widget/order-volume.phtml` + JS, `lineChartWidget` |
| Recent Orders | `…\Model\Widget\RecentOrders` | `table` | `…Framework::widget/table.phtml` |
| Recently Edited Categories | `…\Model\Widget\RecentlyEditedCategories` | `template` | `…Widgets::widget/recently-edited.phtml` |
| Recently Edited CMS Blocks | `…\Model\Widget\RecentlyEditedCmsBlocks` | `template` | `…Widgets::widget/recently-edited.phtml` |
| Recently Edited CMS Pages | `…\Model\Widget\RecentlyEditedCmsPages` | `template` | `…Widgets::widget/recently-edited.phtml` |
| Recently Edited Hyvä CMS Menus | `Hyva\AdminDashboardCmsWidgets\Model\Widget\RecentlyEditedHyvaCmsMenus` | `template` | `…Widgets::widget/recently-edited.phtml` |
| Recently Edited Products | `…\Model\Widget\RecentlyEditedProducts` | `template` | `…Widgets::widget/recently-edited.phtml` |
| Sales Figures | `…\Model\Widget\SalesFigures` | `template` | `…Widgets::widget/sales-figures.phtml` + `…Framework::js/widget/date-interval.phtml`, `dateIntervalWidget` |
| Sales Funnel Activity | `…\Model\Widget\SalesFunnelActivity` | `template` | same date-interval JS, `dateIntervalWidget` |
| Search Activity | `…\Model\Widget\SearchActivity` | `table` | `…Framework::widget/table.phtml` |
| Text | `…\Model\Widget\Text` | `template` | `…Widgets::widget/text.phtml` |
| Top Coupons | `…\Model\Widget\TopCoupons` | `date-interval-table` | `…Framework::widget/table.phtml` |

When `Hyva_AdminDashboardCmsWidgets` is installed, four widgets have their `class` **overridden** to
surface Hyvä CMS edits alongside the Magento defaults:

- Recently Edited Categories → `Hyva\AdminDashboardCmsWidgets\Model\Widget\RecentlyEditedHyvaCmsCategoryAttributes`
- Recently Edited CMS Blocks → `…\RecentlyEditedHyvaCmsBlocks`
- Recently Edited CMS Pages → `…\RecentlyEditedHyvaCmsPages`
- Recently Edited Products → `…\RecentlyEditedHyvaCmsProductAttributes`

<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/devdocs/available-widget-types.html>

### Widget configuration properties (merchant-facing)

Every data widget takes **Store Views** (which store views to include). Order-based widgets take
**Eligible Order Statuses**; list widgets take a "Number of X to Display"; interval widgets take a
**Default Interval** display property. Notable specifics:

- *Abandoned Carts*: customer types (registered / guest / both), subtotal vs grand total, minutes
  before a cart counts as abandoned; optional total item quantity, applied coupon codes, creation date.
- *Google CrUX History*: `Use Custom URL` toggle selects between **Store View** and **URL** (only one
  is required), plus "collect data for the origin?" and a logarithmic-scale display toggle.
- *Orders by Country*: number of countries, group non-top countries into "Other", and how the order
  country is determined.
- *Recently Edited …*: filters by store views / websites / root categories, and display toggles for
  ID, store views, websites, category path, root category in path, and including disabled entities.
- *Module Versions*: Composer **Vendors** (e.g. `hyva-themes`, `magento`) and an optional
  "show latest available versions" lookup.
- *Checklist* / *Links*: `dynamic-rows`-driven items (Add button / trash icon).
- *Sales Figures*: store views, order status, and which **Figures** to include.
- *Hyvä CMS Scheduled Releases*: number of releases, From/To date bounds, release status filter.

<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/widget-types.html>

## Dashboard views and roles

Introduced in Admin Dashboard `2.0.1`. A **view** is a saved layout (widgets at positions and sizes).
On upgrade, existing widgets are moved into a personal "My Dashboard" view automatically.

- **Create View** from the view switcher (starts empty); **Duplicate** copies the active view's
  widgets, positions, sizes and configuration.
- The switcher merges personal views and views assigned to any of the admin's roles; the last choice
  is persisted per user.
- Edits (add / resize / remove) save to the active view automatically.
- **Delete View** removes every widget on it — and, for a role-assigned view, removes it for every
  user in those roles.
- On save, a view can be assigned to one or more admin roles. A role can hold any number of views; a
  role with no views leaves its members on personal views only.

ACL resources under `Hyvä Admin Dashboard → Dashboard Views Management` (all granted to the default
administrator role; new custom roles need them explicitly):

- `Hyva_AdminDashboardFramework::dashboard_views_create` — create and duplicate
- `Hyva_AdminDashboardFramework::dashboard_views_save` — save edits
- `Hyva_AdminDashboardFramework::dashboard_views_delete` — delete
- `Hyva_AdminDashboardFramework::dashboard_views_assign` — assign to roles

Programmatic access: repository interfaces in `Hyva\AdminDashboardFramework\Api\V1\View\`,
`Api\V1\ViewRole\` and `Api\V1\UserActiveView\`.

Schema added by the release: `hyva_admin_dashboard_widget_instance.view_id` (nullable FK),
`hyva_admin_dashboard_view`, `hyva_admin_dashboard_view_role` (view↔role pivot),
`hyva_admin_dashboard_user_active_view`. The data patch
`Hyva\AdminDashboardFramework\Setup\Patch\Data\MigrateWidgetsToViews` runs during `setup:upgrade`,
creates a personal "My Dashboard" per admin user with orphaned widgets and reattaches them; it is
idempotent and short-circuits once every widget has a `view_id`. Non-destructive, but take a DB
backup before running on production.
<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/dashboard-views.html>

## Merchant widget management

- **Add Widget** (bottom of an empty dashboard, and always top-right) → selection modal with search,
  category filter buttons and one button per type → configuration form (`Display Properties` and
  `Configurable Properties` sections, both collapsible) → Save.
- Search matches a widget's name, category and tags.
- Not every widget is available to every admin — some require a role/resource (see `<acl>`).
- **Edit**: instance ellipsis menu → `Edit`.
- **Edit Mode**: `Customize Dashboard` (top-right) or `Resize` from an instance menu. Widgets become
  non-interactive; drag to reposition, drag a corner to resize (respecting `min_width`/`min_height`).
  `Save` (or `Enter`) persists; `Cancel` (or `Escape`) restores the last stable state.
- **Delete**: from the instance menu (with confirmation), several at once via Edit Mode delete
  buttons + Save, or **Clear Dashboard** in Edit Mode with confirmation.

<https://docs.hyva.io/hyva-commerce/features/admin-dashboard/managing-widgets.html>
