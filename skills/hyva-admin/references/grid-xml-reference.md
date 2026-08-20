# Grid XML reference

Everything below is the content of `view/adminhtml/hyva-grid/<grid-name>.xml`. Configuration
is merged across modules per grid name like any other Magento XML, which is how you customize
someone else's grid.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/index.html>

## Full nesting skeleton

Element **order** inside `<grid>` is fixed by the XSD (`Hyva_Admin/etc/hyva-grid.xsd`) — check
it if the file fails validation. Every node below is real; only `<source>` is mandatory.

```xml
<?xml version="1.0"?>
<grid xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:noNamespaceSchemaLocation="urn:magento:module:Hyva_Admin:etc/hyva-grid.xsd">

    <source>
        <!-- exactly one provider element: -->
        <arrayProvider>Vendor\Module\Model\SomeArrayProvider</arrayProvider>
        <repositoryListMethod>Magento\Catalog\Api\ProductRepositoryInterface::getList</repositoryListMethod>
        <collection>Magento\Customer\Model\ResourceModel\Customer\Collection</collection>
        <query unionSelectType="all">
            <select>
                <from table="sales_order" as="main_table"/>
                <columns>
                    <column name="status" as="order_status"/>
                    <expression as="count">COUNT(*)</expression>
                </columns>
                <join type="left" table="catalog_product_entity_varchar" as="t_name">
                    <on>t_name.entity_id=main_table.entity_id AND attribute_id=47</on>
                    <columns>
                        <column name="value" as="name"/>
                    </columns>
                </join>
                <groupBy>
                    <column name="status"/>
                </groupBy>
            </select>
            <unionSelect>
                <from table="some_other_table_with_matching_columns"/>
            </unionSelect>
        </query>

        <defaultSearchCriteriaBindings combineConditionsWith="or">
            <field name="customer_id" requestParam="id"/>
            <field name="entity_id" method="Magento\Framework\App\RequestInterface::getParam" param="id"/>
            <field name="store_id" method="Magento\Store\Model\StoreManagerInterface::getStore" property="id"/>
            <field name="customer_ids" condition="finset" method="Magento\Customer\Model\Session::getCustomerId"/>
        </defaultSearchCriteriaBindings>

        <processors>
            <processor class="Vendor\Module\HyvaGridProcessor\SomeProcessor" enabled="true"/>
        </processors>
    </source>

    <entityConfig>
        <label>
            <singular>Product</singular>
            <plural>Products</plural>
        </label>
    </entityConfig>

    <columns rowAction="edit">
        <include keepAllSourceColumns="true">
            <column name="sku"
                    label="SKU"
                    type="price"
                    template="Vendor_Module::grid/cell/sku.phtml"
                    renderAsUnsecureHtml="false"
                    rendererBlockName="my-renderer-block"
                    sortOrder="10"
                    sortable="false"
                    source="Magento\Customer\Model\Customer\Attribute\Source\Website"
                    initiallyHidden="true">
                <option value="5" label="Spain"/>
            </column>
        </include>
        <exclude>
            <column name="internal_id"/>
        </exclude>
    </columns>

    <actions idColumn="id">
        <action id="edit" label="Edit" url="*/*/edit" idParam="id">
            <event on="click"/>
        </action>
    </actions>

    <massActions idColumn="id" idsParam="productIds">
        <action id="delete" label="Delete" url="*/massAction/delete" requireConfirmation="true"/>
    </massActions>

    <navigation useAjax="false">
        <buttons>
            <button id="add" label="Add" url="*/*/add"/>
            <button id="refresh" label="Refresh Grid" onclick="window.location.reload(true)" sortOrder="1"/>
            <button id="sync" template="Vendor_Module::sync-button.phtml" enabled="false"/>
        </buttons>
        <exports>
            <export type="csv" label="Export as CSV"/>
            <export type="custom" label="Export as my format"
                    class="Vendor\Module\Model\CustomGridExport"
                    fileName="example.foo" sortOrder="1" enabled="true"/>
        </exports>
        <pager enabled="true">
            <defaultPageSize>40</defaultPageSize>
            <pageSizes>20,40,100</pageSizes>
        </pager>
        <sorting>
            <defaultSortByColumn>created_at</defaultSortByColumn>
            <defaultSortDirection>desc</defaultSortDirection>
        </sorting>
        <filters>
            <filter column="sku"/>
            <filter column="store_id" source="Magento\Config\Model\Config\Source\Store"/>
            <filter column="category_links" filterType="Vendor\Module\Adminhtml\GridFilter\CategoryLinks"/>
            <filter column="images" template="Vendor_Module::grid/filters/image-filter.phtml"/>
            <filter column="color" enabled="true">
                <option label="reddish">
                    <value>16</value>
                    <value>17</value>
                </option>
            </filter>
        </filters>
    </navigation>
</grid>
```

---

## `grid > source`

Required. Exactly one provider type; four are supported today: `repositoryListMethod`,
`arrayProvider`, `collection`, `query`.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/source/index.html>

### `arrayProvider`

Content is a fully qualified class name implementing
`Hyva\Admin\Api\HyvaGridArrayProviderInterface` (single method
`getHyvaGridData(): array`, returning one sub-array per row). Columns come from the array keys
of the **first** record. Filtering, sorting and pagination are applied by Hyva_Admin after the
provider returns everything.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/source/arrayprovider.html>

### `repositoryListMethod`

Content is `FQCN::method`. The method must accept a
`Magento\Framework\Api\SearchCriteriaInterface` and return something
`Magento\Framework\Api\SearchResultsInterface`-like. The name need not be `getList`. Fields are
discovered by reflection: system attributes, custom EAV attributes **and extension
attributes** all become columns.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/source/repositorylistmethod.html>

### `collection`

Content is a DB collection class (a descendant of
`Magento\Framework\Data\Collection\AbstractDb`) — that is required because sorting, paging and
filtering are applied through the select. Fields are discovered by reflection: system
attributes (getter methods) and custom EAV attributes become columns.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/source/collection.html>

### `query`

Renders a SQL select straight into the grid with no PHP classes at all. Minimum config is a
table name. One optional attribute:

- `unionSelectType` — `all` or `distinct`; default `all`; no effect without `<unionSelect>`.

Requires exactly one `<select>` child, plus zero or more `<unionSelect>` children. Initial
filters come from `defaultSearchCriteriaBindings`; pagination and sorting are applied by
Hyva_Admin.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/source/query/index.html>

`<select>` — one required child `from`, three optional: `columns`, `join`, `groupBy`.

| Node | Attributes | Notes |
|---|---|---|
| `from` | `table` (required), `as` | The only required child of `select`; no children. |
| `columns` | none | Zero or more `column` / `expression`. **Under `select`: omitting it selects all columns** (`SELECT *`). |
| `columns > column` | `name` (required), `as` | One result column. |
| `columns > expression` | `as` | Element content is an unvalidated SQL expression, wrapped in `Zend_Db_Expr` unchanged, e.g. `COUNT(*)`. |
| `join` | `type` (`inner`/`left`/`right`/`full`/`cross`/`natural`, default `left`), `table` (required), `as` | One required `on` child, one optional `columns` child. |
| `join > on` | none | Element content is the join condition, e.g. `t_name.entity_id=main_table.entity_id AND attribute_id=47`. |
| `join > columns` | none | Same syntax as `select > columns`, but **omitting it selects nothing** from the joined table. |
| `groupBy` | none | Zero or more `column` children. |
| `unionSelect` | none | Accepts the same children as `select`; combined with the primary select. |

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/source/query/select/index.html>
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/source/query/select/join/index.html>
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/source/query/unionselect.html>

### `defaultSearchCriteriaBindings`

Automatic filters against current application state — the mechanism for embedding a grid on
another entity's page (all orders of the customer being edited, etc.). Multiple bindings are
`AND`-combined; `combineConditionsWith="or"` makes them alternatives. Contains zero or more
`<field>`.

`<field>` attributes:

| Attribute | Meaning |
|---|---|
| `name` | **Required.** The field to filter on. |
| `requestParam` | Bind to an HTTP request param. Shorthand for `method="Magento\Framework\App\RequestInterface::getParam"` + `param`. Most common form. |
| `method` | `Class::method` to call for the value, e.g. `Magento\Customer\Model\Session::getCustomerId` — resolved as `$objectManager->get('…')->getCustomerId()`. |
| `param` | Single string argument for `method` (handy with generic `getData($key)`). |
| `property` | Read one value out of the method's return: array index for arrays; for objects a matching getter, else `getData()`, else a public property, else `ArrayAccess`. |
| `condition` | Search-criteria condition, default `eq`. Allowed: `eq`, `is`, `neq`, `lteq`, `from`, `to`, `gteq`, `moreeq`, `gt`, `lt`, `like`, `nlike`, `in`, `nin`, `notnull`, `null`, `finset`. |

Chained or more complex calls must be wrapped in a custom class and referenced from `method`.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/source/defaultsearchcriteriabindings/field.html>
<https://hyva-themes.github.io/magento2-hyva-admin/guides/hyva-admin-grid-walkthrough/declaring-source-search-bindings.html>

### `processors`

Zero or more `<processor class="FQCN" enabled="true|false"/>`. `class` is required and points at
a `Hyva\Admin\Api\HyvaGridSourceProcessorInterface` implementation (usually via the abstract
base class). `enabled` defaults to `true` and exists so another module's processor can be
switched off through XML merging. Processors run in module load order — there is no sort order.
See `references/php-api.md`.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/source/processors/processor.html>

---

## `grid > entityConfig`

Currently only supplies the entity name for the "no records" message. Optional.

```xml
<entityConfig>
    <label>
        <singular>Product</singular>
        <plural>Products</plural>
    </label>
</entityConfig>
```

Renders `No Products found.` If `plural` is missing, `singular` + `s` is used. If both are
missing, the grid name is used: `No product-grid records found.` `<label>` is only a grouping
element.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/entityconfig/index.html>
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/entityconfig/label/plural.html>

---

## `grid > columns`

Attribute: `rowAction` — the `id` of an `<actions><action>`; that action then fires when a row
is clicked.

Include/exclude resolution:

| include | exclude | result |
|---|---|---|
| – | – | all available columns |
| yes | – | only the included ones, in XML order |
| – | yes | all except the excluded ones |
| yes | yes | included minus excluded |

`<include keepAllSourceColumns="true">` changes the first rule: included columns keep their
explicit config and are rendered first, then all remaining source columns follow. Use it to
tweak or reorder a few columns without listing every field.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/columns/index.html>
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/columns/include/index.html>

### `columns > exclude > column`

Single required attribute `name`.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/columns/exclude/column.html>

### `columns > include > column`

`name` is the only required attribute.

| Attribute | Purpose |
|---|---|
| `name` | Column key used to read the value from the record. |
| `label` | Column title; derived from `name` if absent. |
| `type` | Data type code deciding how the raw value becomes a string, e.g. `type="price"`, `type="datetime"`, `type="magento_product_image"`. Often guessed; set it when the guess is wrong or the value is a custom object. Built-in types live in `Hyva/Admin/Model/DataType`. |
| `template` | Per-cell template in `Vendor_Module::file.phtml` notation. The current cell is injected as `$cell`; type-hint with `/** @var \Hyva\Admin\ViewModel\HyvaGrid\CellInterface $cell */`. |
| `renderAsUnsecureHtml` | `true` renders unescaped HTML and switches the value converter from `toString()` to `toHtmlRecursive()`. Needed for images and links. Default `false` (escaped). |
| `rendererBlockName` | Layout-XML name of a block used to render each cell — roughly `$layout->getBlock($name)->setData('cell', $this)->toHtml()`. Read the cell via `$this->getData('cell')` in the block or `$block->getData('cell')` in its template. The block must be declared in layout XML **on every page** showing the grid, and using this **automatically disables Ajax navigation**. |
| `sortOrder` | Ascending numeric order; mainly for reordering another module's grid through XML merging. |
| `sortable` | `false` disables title-click sorting on that column. |
| `source` | EAV attribute source model mapping values to labels; must implement `Magento\Eav\Model\Entity\Attribute\Source\SourceInterface`. Select/multiselect EAV attributes resolve their source automatically. |
| `initiallyHidden` | `true` hides the column on first load while keeping it available in the grid's "Display" dropdown. Only affects initial state — the visible-column set is then kept in session storage. |

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/columns/include/column/index.html>

### `columns > include > column > option`

Hardcodes value→label mapping when a source model would be overkill. Values may be strings.
Labels always pass through `__()`.

```xml
<column name="websites">
    <option value="5" label="Spain"/>
    <option value="2" label="Italy"/>
</column>
```

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/columns/include/column/option.html>

---

## `grid > actions`

No actions by default. When present they render as links in an extra right-most column.
Optional attribute `idColumn` — the column supplying the record identifier; defaults to the
first grid column.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/actions/index.html>

### `actions > action`

| Attribute | Purpose |
|---|---|
| `id` | Required. Reference handle for XML merging and for `columns rowAction="…"`; not rendered. |
| `label` | Required. Link text. |
| `url` | Required. Magento route notation; `*` means "current" at that position — `*/*/edit` = current route + current action path + `edit` action. |
| `idParam` | Optional query-parameter name for the id value. Defaults to the `idColumn` name. If no `idColumn` is set, `idColumn` falls back to `idParam`, and if that matches no column, to the first column. |

Target controllers are **not** generated for you.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/actions/action/index.html>

### `actions > action > event` — **experimental**

Marked experimental in the docs; the API may change or be removed. Only the trigger is
declared in XML:

```xml
<action id="delete" label="Delete" url="*/*/delete">
    <event on="click"/>
</action>
```

The JS event name is `hyva-grid-<grid-name>-action-<action-id>-<on>` with non-alphanumeric
characters in the grid name replaced — grid `products-query-grid` + action `delete` gives
`hyva-grid-products-query-grid-action-delete-click`. Subscribe from a `.phtml` added to the
page via layout XML:

```html
<script>
window.addEventListener('hyva-grid-products-grid-action-delete-click', e => {
    if (! confirm('<?= __('Are you sure?') ?>')) {
        e.detail.origEvent.preventDefault();
    }
});
</script>
```

`event.detail` carries: `origEvent` (the original user event — `preventDefault()` it to abort),
`row` (the clicked `<tr>`), `viewModel` (the grid's Alpine.js view model), `action` (the action
id), `params` (the map of parameters that would go into the URL).
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/actions/action/event.html>

---

## `grid > massActions`

None by default. When configured, a checkbox column is added leftmost and a dropdown of mass
actions above the grid; selecting an option immediately posts the selected IDs to the target
controller. With nothing selected an alert is shown instead.

Optional attributes: `idColumn` (column supplying the IDs, default first column) and
`idsParam` (query argument name, defaults to the `idColumn` value).

`massActions > action` attributes: `id` (merge handle, not rendered), `label`, `url` (Magento
route notation) — all required — plus optional `requireConfirmation="true"`, which prompts the
user after the option is selected and before the action fires. Use it for destructive or
expensive operations.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/massactions/index.html>
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/massactions/action.html>

---

## `grid > navigation`

Holds paging, sorting, filtering, buttons and exports. One attribute:

- `useAjax` — grids use Ajax navigation by default; `useAjax="false"` disables it. A column with
  `rendererBlockName` disables Ajax paging automatically, because the layout XML defining that
  renderer block is not loaded during an Ajax navigation request.

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/navigation/index.html>

### `navigation > pager`

Attribute `enabled` — `enabled="false"` hides the pager (the "Reset Filters" button, when
filters are active, and the column Display dropdown still render).

- `<defaultPageSize>` — records per page on first load. Default **20**.
- `<pageSizes>` — comma-separated dropdown options. Defaults **10,20,50**, defined in
  `Hyva\Admin\ViewModel\HyvaGrid\Navigation`.

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/navigation/pager/index.html>
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/navigation/pager/pagesizes.html>

### `navigation > sorting`

- `<defaultSortByColumn>` — initial sort column. Without it no sorting is applied by default.
- `<defaultSortDirection>` — `asc` or `desc`; default `asc`.

Users re-sort by clicking column titles; repeated clicks reverse the direction.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/navigation/sorting/index.html>
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/navigation/sorting/defaultsortdirection.html>

### `navigation > filters`

Nothing is filterable until listed here. Declaration order has no effect on rendering. Filter
type is derived from the column definition:

| Column | Filter type |
|---|---|
| type `bool` | `boolean` |
| type `datetime` | `date-range` |
| type `int` | `value-range` |
| has options | `select` |
| anything else | `text` |

Exception: a filter with `<option>` children or a `source` attribute always renders as a
`select`, whatever the column type.

`<filter>` attributes:

| Attribute | Purpose |
|---|---|
| `column` | Required. Column name to filter. |
| `template` | Custom filter template, `Vendor_Module::grid/filters/x.phtml`. The filter instance is injected as `$filter`; type-hint `/** @var Hyva\Admin\ViewModel\HyvaGrid\GridFilterInterface $filter */`. Built-in templates in `Hyva_Admin`'s `view/adminhtml/templates/filter` are the best reference. |
| `enabled` | `false` disables a filter declared in another module's grid XML. |
| `filterType` | Custom filter type class (see `references/php-api.md`). If a `template` is also given it overwrites whatever template the filter type set. |
| `source` | Source model class for select options; only requirement is a `toOptionArray()` returning `[['value' => …, 'label' => …], …]`. Forces a select filter. Currently a source model overrides XML `<option>`s, but that precedence is explicitly not guaranteed. |

`<filter> > <option label="…">` with one or more `<value>` children groups several values under
one label; selecting the group matches any of them (`OR` conditions on the SearchCriteria).
Values may be strings.

```xml
<filter column="color">
    <option label="reddish">
        <value>16</value>
        <value>17</value>
        <value>18</value>
    </option>
    <option label="blueish">
        <value>12</value>
    </option>
</filter>
```

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/navigation/filters/filter/index.html>
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/navigation/filters/filter/option.html>

### `navigation > buttons`

Buttons rendered above the grid. Effect comes from either `url` or `onclick`.

| Attribute | Purpose |
|---|---|
| `id` | Required unique handle, used for XML merging. |
| `label` | Button text, passed through `__()`. |
| `url` | Route in `routeid/action_path/action` notation, `*` = current. No way to add query arguments. |
| `onclick` | Arbitrary JavaScript executed on click. |
| `sortOrder` | Buttons with a `sortOrder` render before those without; smaller = further left. Otherwise declaration order. |
| `enabled` | `enabled="false"` removes a button — mostly used through XML merging. |
| `template` | Renders the **entire** button HTML from your `.phtml`. The button is assigned as `$button`; type-hint `/** @var Hyva\Admin\ViewModel\HyvaGrid\GridButtonInterface $button */`. |

```php
<a class="btn btn-primary inline-flex mx-2 cursor-pointer"
   onclick="<?= $button->getOnClick() ?>">
    <span><?= $escaper->escapeHtml(__($button->getLabel())) ?></span>
</a>
```

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/navigation/buttons/index.html>

### `navigation > exports`

Exports respect the current filters and sort order. Built-in types `csv`, `xml`, `xlsx` need no
`class`.

| `<export>` attribute | Purpose |
|---|---|
| `type` | Required. Identifier, also used as the default file-name suffix. |
| `label` | Link label; defaults to `'Export as ' . mb_strtoupper($type)`. |
| `enabled` | `false` disables an export declared elsewhere. |
| `class` | PHP class generating the file — required for custom types, optional to override a built-in one. |
| `fileName` | File name relative to the export dir; subdirectories work (`export/export.foo`). Defaults to grid name + type suffix. |
| `sortOrder` | Exports with a `sortOrder` render before those without. |

```xml
<navigation>
    <exports>
        <export type="csv" label="Export as CSV"/>
        <export type="xml" label="Export as XML" enabled="false"/>
        <export type="xlsx" label="Export as XLSX"/>
        <export type="custom" label="Export as my custom format"
                class="Vendor\Module\Model\CustomGridExport"
                fileName="example.foo" sortOrder="1"/>
    </exports>
</navigation>
```

Custom types extend the export base class and implement `createFileToDownload()` — see
`references/php-api.md`.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/navigation/exports/index.html>
<https://hyva-themes.github.io/magento2-hyva-admin/guides/hyva-admin-grid-walkthrough/exports.html>
