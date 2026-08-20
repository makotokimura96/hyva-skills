# Events

Hyva_Admin dispatches three PHP events plus one optional JavaScript event per grid action.

The PHP event names are suffixed with the grid name. Because the Magento `events.xml` schema
only allows alphanumeric characters in event names, every non-alphanumeric character in the grid
name becomes an underscore: grid `product-grid` gives
`hyva_grid_source_prefetch_product_grid`, not `hyva_grid_source_prefetch_product-grid`.

- `'hyva_grid_source_prefetch_' . $gridNameEventSuffix`
- `'hyva_grid_source_prefetch'` (no suffix — fires for every grid)
- `'hyva_grid_column_definition_build_after_' . $gridNameEventSuffix`
- `'hyva_grid_query_before_' . $gridNameEventSuffix`

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/event-reference/index.html>

All three PHP events pass a mutable **container** object rather than the value itself, so an
observer replaces the value through the container. Arguments other than the container
(`grid_name`, `record_type`) are informational and cannot be changed.

---

## `hyva_grid_source_prefetch` / `hyva_grid_source_prefetch_<grid>`

**When:** before grid data is loaded from the grid source object. Both the generic and the
grid-specific event are dispatched.

**Purpose:** customize the `SearchCriteria` that will be handed to the grid source.

**Arguments:**

```php
[
    'search_criteria_container' => $container, // Hyva\Admin\Model\GridSourceType\RepositorySourceType\SearchCriteriaEventContainer
    'grid_name'                 => $gridName,
    'record_type'               => $recordType,
]
```

`record_type` is the type of the grid records: a PHP class or interface name, the string
`array`, or a database table name, depending on the grid's source configuration.

**Observer:**

```php
public function execute(Observer $observer)
{
    /** @var SearchCriteriaEventContainer $searchCriteriaContainer */
    $searchCriteriaContainer = $observer->getData('search_criteria_container');
    $type = $observer->getData('record_type');

    $updatedSearchCriteria = $this->changeCriteria($type, $searchCriteriaContainer->getSearchCriteria());

    $searchCriteriaContainer->replaceSearchCriteria($updatedSearchCriteria);
}
```

The repository grid source type dispatches it like this — useful for understanding the contract:

```php
private function dispatchEvent(
    string $gridName,
    string $recordType,
    SearchCriteriaInterface $searchCriteria
): SearchCriteriaInterface {
    $eventName = 'hyva_grid_source_prefetch_' . $this->getGridNameEventSuffix($gridName);
    $container = new SearchCriteriaEventContainer($searchCriteria);
    $this->eventManager->dispatch($eventName, [
        'search_criteria_container' => $container,
        'grid_name'                 => $gridName,
        'record_type'               => $recordType
    ]);

    return $container->getSearchCriteria();
}
```

Besides replacing the criteria, observers can also just *remember* the posted values and apply
them later — which is the documented trick for filtering columns whose values are loaded after
the main record (extension attributes). It is also the place to map attribute codes to internal
column names.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/event-reference/grid-source-prefetch-events.html>
<https://hyva-themes.github.io/magento2-hyva-admin/guides/design-docs/filtering-extension-attribute-columns.html>

---

## `hyva_grid_column_definition_build_after_<grid>`

**When:** after the column definitions have been built from the grid record type and the grid
XML configuration.

**Purpose:** change column definitions programmatically, when a condition cannot be expressed
in XML. Prefer plain grid XML whenever the decision is static.

**Arguments:**

```php
[
    'grid_name'      => $gridName,
    'data_container' => $container, // Hyva\Admin\Model\GridSourceType\RepositorySourceType\HyvaGridEventContainer
]
```

The container holds an associative array of all column definition instances keyed by column ID.

**Observer:**

```php
public function execute(Observer $observer)
{
    /** @var \Hyva\Admin\Model\GridSourceType\RepositorySourceType\HyvaGridEventContainer $container */
    /** @var \Hyva\Admin\ViewModel\HyvaGrid\ColumnDefinitionInterface[] $columnsMap */
    $container  = $observer->getData('data_container');
    $columnsMap = $container->getContainerData(); // map of keys to column definitions

    $columnsMap['example'] = $columnsMap['example']->merge(['initiallyHidden' => 'true']);

    $container->replaceContainerData($columnsMap);
}
```

`ColumnDefinition::merge()` is **immutable** — it returns a new instance with the merged
properties, it does not modify the receiver. Its argument may be an associative array or
another `ColumnDefinitionInterface`.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/event-reference/grid-column-definition-build-after-event.html>

---

## `hyva_grid_query_before_<grid>`

**When:** only for grids using the **query** grid source type. A
`Magento\Framework\DB\Select` is created, the `<query>` configuration from the grid XML is
applied, then filters, sorting and pagination — and the event fires immediately before the SQL
is executed. (`Magento\Framework\DB\Select` is a thin wrapper around `Zend_Db_Select` with the
same API.)

**Purpose:** modify or wholly replace the select used to load the grid data.

**Arguments:**

```php
[
    'select_container' => $container, // Hyva\Admin\Model\Grid\Source\Type\QueryGridSource\Type\DbSelectEventContainer
    'grid_name'        => $this->gridName,
]
```

**Observer:**

```php
public function execute(Observer $observer)
{
    /** @var DbSelectEventContainer $container */
    $container = $observer->getData('select_container');
    $select    = $container->getSelect();

    $updatedSelect = $this->modifyQuery($select);

    $container->replaceSelect($updatedSelect);
}
```

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/event-reference/grid-query-before-event.html>

---

## JavaScript action events — **experimental**

Declared per action in grid XML with `<event on="…"/>`; flagged experimental, the API may be
removed or changed.

```xml
<actions idColumn="id">
    <action id="delete" label="Delete" url="*/*/delete" idParam="foo">
        <event on="click"/>
    </action>
</actions>
```

**Event name:** `hyva-grid-<grid-name>-action-<action-id>-<on>`, built as

```php
private function getEventName(): string
{
    $gridNameInEvent = $this->eventify($this->gridName);

    return sprintf('hyva-grid-%s-action-%s-%s', $gridNameInEvent, $this->eventify($this->targetId), $this->on);
}
```

so grid `products-query-grid` + action `delete` + `on="click"` gives
`hyva-grid-products-query-grid-action-delete-click`.

**Subscriber** — in a `.phtml` added to the grid page through layout XML:

```html
<script>
window.addEventListener('hyva-grid-products-grid-action-delete-click', e => {
    if (! confirm('<?= __('Are you sure?') ?>')) {
        e.detail.origEvent.preventDefault();
    }
});
</script>
```

**`event.detail` properties:**

| Property | Meaning |
|---|---|
| `origEvent` | the original user-interaction event; `preventDefault()` it to abort the action |
| `row` | the clicked grid table row element (lets you read rendered cell values, admittedly hackily) |
| `viewModel` | the grid's Alpine.js view model |
| `action` | the grid action id, e.g. `delete` |
| `params` | the parameter map that would be passed to the URL; with `idParam="foo"` above it is `{foo: idValue}` |

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/grid-xml-reference/actions/action/event.html>

Note: this inline `<script>` runs in **adminhtml**, where Magento's frontend CSP profile does
not apply the way it does in the Hyvä storefront. Do not copy this pattern into frontend
templates — see the `alpinejs-csp` skill.
