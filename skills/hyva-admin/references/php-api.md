# PHP classes and interfaces

Interfaces meant for implementation live in the module's `Api/` directory. The docs rank how
likely you are to need each one:

| Class / interface | Likelihood | Implement it to… |
|---|---|---|
| `Hyva\Admin\Api\HyvaGridArrayProviderInterface` | likely | feed a grid from a plain array |
| `Hyva\Admin\Model\Grid\Source\AbstractGridSourceProcessor` | likely | hook grid loading with minimal boilerplate |
| `Hyva\Admin\Api\DataType\ValueToStringConverterInterface` | maybe | render a value type as string/HTML without a template |
| `Hyva\Admin\Model\Grid\ExportType\AbstractExportType` | maybe | add an export format |
| `Hyva\Admin\Api\HyvaGridFilterTypeInterface` | unlikely | build a custom filter type |
| `Hyva\Admin\Api\HyvaGridSourceProcessorInterface` | unlikely | same as the abstract, when you need both methods |
| `Hyva\Admin\Api\DataTypeGuesserInterface` | very unlikely | teach Hyva_Admin to recognise a type |
| `Hyva\Admin\Api\DataTypeInterface` | very unlikely | guesser + converter in one class |

Not for implementation, only for use — mostly inside templates:
`Hyva\Admin\Block\Adminhtml\HyvaGrid` (layout XML), `…\ViewModel\HyvaGrid\CellInterface` (cell
templates), `…\ViewModel\HyvaGrid\ColumnDefinitionInterface` (cell and filter templates),
`…\ViewModel\HyvaGrid\GridFilterInterface` (filter templates). These are undocumented; add a
PHPDoc type hint in the template and let the IDE guide you, and read the templates shipped in
`Hyva_Admin` as reference.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/php-classes-and-interfaces/index.html>

> **FQCN caveat.** The documentation is inconsistent about two namespaces: the processor base
> class appears both as `Hyva\Admin\Model\GridSource\AbstractGridSourceProcessor` (API
> reference) and `Hyva\Admin\Model\Grid\Source\AbstractGridSourceProcessor` (walkthrough); the
> export base class appears both as `Hyva\Admin\Model\GridExport\Type\AbstractExportType` (API
> reference) and `Hyva\Admin\Model\Grid\ExportType\AbstractExportType` (walkthrough). Verify
> against the installed module before writing the `use` statement.

---

## HyvaGridArrayProviderInterface

```php
namespace Hyva\Admin\Api;

/**
 * Implement this interface and specify that class as an array source type for a hyva grid.
 * Return an array with one sub-array for each row of the grid.
 */
interface HyvaGridArrayProviderInterface
{
    /** @return array[] */
    public function getHyvaGridData(): array;
}
```

Each sub-array is a row; the array keys of the **first** record define the columns.

```php
public function getHyvaGridData(): array
{
    return [
        ['col-A' => 'the first value', 'col-B' => 'another value'],
        ['col-A' => 'more data',       'col-B' => 'even more data'],
    ];
}
```

`Magento\Framework\Reflection\DataObjectProcessor::buildOutputDataArray` is a handy way to turn
entities into arrays, but anything fulfilling the contract works. Configure with
`<source><arrayProvider>…</arrayProvider></source>`.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/php-classes-and-interfaces/hyvagridarrayproviderinterface.html>

---

## HyvaGridSourceProcessorInterface / AbstractGridSourceProcessor

Low-level access to the grid load, for when declarative config runs out — e.g. a filter that
involves an external entity. A grid may have any number of processors; they run in module load
order (no sort order available).

```php
interface HyvaGridSourceProcessorInterface
{
    public function beforeLoad($source, SearchCriteriaInterface $searchCriteria, string $gridName): void;

    public function afterLoad($rawResult, SearchCriteriaInterface $searchCriteria, string $gridName);
}
```

`afterLoad` must return the new result **or null**; null keeps the pre-`afterLoad` value.

Extend the abstract class when you need only one of the two methods — it provides null-op
implementations and you do not have to call the parent:

```php
abstract class AbstractGridSourceProcessor implements HyvaGridSourceProcessorInterface
{
    public function beforeLoad($source, SearchCriteriaInterface $searchCriteria, string $gridName): void
    {
    }

    public function afterLoad($rawResult, SearchCriteriaInterface $searchCriteria, string $gridName)
    {
        return $rawResult;
    }
}
```

### Argument types per source type

| Source type | `$source` in `beforeLoad` | `$rawResult` in `afterLoad` |
|---|---|---|
| Repository | the object the list method is called on | `Magento\Framework\Api\SearchResultsInterface` |
| Collection | collection **before** search criteria applied | collection **after** search criteria applied (possibly already loaded) |
| Array | the array provider instance | array result after filtering, before pagination/sorting |
| Query | `Magento\Framework\DB\Select` **after** search criteria applied | `['data' => $rows, 'count' => $count]` |

`$searchCriteria` is informational only — **never mutate it**. `GridSource` memoizes grid data
by search-criteria signature (see `Hyva\Admin\Model\GridSource\SearchCriteriaIdentity`), so a
changed signature re-runs the query. `$gridName` is informational too, useful in exception
messages.

Typical `beforeLoad` uses: repository — set properties influencing how criteria are applied
(mostly relevant for custom repositories); collection — extra filters and flags; query — bind
values, or alter/remove parts of the select. `afterLoad` is source-agnostic: change or enrich
the loaded data. The same effects are achievable with plugins or events; processors just need
the least boilerplate.

```xml
<source>
    <processors>
        <processor class="Hyva\AdminTest\HyvaGridProcessor\ProductGridQueryProcessor"/>
    </processors>
</source>
```

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/php-classes-and-interfaces/hyvagridsourceprocessorinterface.html>
<https://hyva-themes.github.io/magento2-hyva-admin/guides/hyva-admin-grid-walkthrough/using-grid-source-processors.html>

---

## HyvaGridCollectionProcessorInterface

Extends `HyvaGridSourceProcessorInterface` with one collection-only callback:

```php
public function afterInitSelect(\Magento\Framework\Data\Collection\AbstractDb $source, string $gridName): void;
```

Called every time the collection grid source is instantiated, **before** the search criteria is
applied — the place to join additional fields so they become available as grid columns.
Configure the class as a normal `<processor>`; implement this interface in addition to extending
`AbstractGridSourceProcessor`.

```php
new class() extends AbstractGridSourceProcessor implements HyvaGridCollectionProcessorInterface {
    public function afterInitSelect(AbstractDbCollection $source, string $gridName): void
    {
        $select = $source->getSelect();
        // select expression
        $select->columns(['foo' => new \Zend_Db_Expr('foo')]);
        // select field from joined table
        $source->getSelect()->joinLeft(
            'catalog_category_product',
            'e.entity_id = catalog_category_product.product_id',
            ['test_field' => 'catalog_category_product.entity_id']
        );
    }
};
```

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/php-classes-and-interfaces/hyvagridcollectionprocessorinterface.html>

---

## HyvaGridFilterTypeInterface

Filter types supply the filter renderer block and apply posted values to a SearchCriteria.
Built-in types: `boolean`, `date-range`, `select`, `text`, `value-range`.

```php
namespace Hyva\Admin\Api;

use Hyva\Admin\ViewModel\HyvaGrid\ColumnDefinitionInterface;
use Hyva\Admin\ViewModel\HyvaGrid\GridFilterInterface;
use Magento\Framework\Api\SearchCriteriaBuilder;
use Magento\Framework\View\Element\Template;

interface HyvaGridFilterTypeInterface
{
    public function getRenderer(ColumnDefinitionInterface $columnDefinition): Template;

    public function apply(
        SearchCriteriaBuilder $searchCriteriaBuilder,
        GridFilterInterface $gridFilter,
        $filterValue
    ): void;
}
```

`getRenderer()` returns the template block for the filter. The current
`GridFilterInterface` instance is set on that block as the variable `$filter` before `toHtml()`
is called. A `template` attribute in the filter XML overwrites whatever template
`getRenderer()` set.

```php
public function getRenderer(ColumnDefinitionInterface $columnDefinition): Template
{
    /** @var Template $templateBlock */
    $templateBlock = $this->layout->createBlock(Template::class);
    $templateBlock->setTemplate('Hyva_Admin::grid/filter/date-range.phtml');

    return $templateBlock;
}
```

`apply()` translates the posted value onto the builder — from the built-in value-range type:

```php
public function apply(
    SearchCriteriaBuilder $searchCriteriaBuilder,
    GridFilterInterface $gridFilter,
    $filterValue
): void {
    $key = $gridFilter->getColumnDefinition()->getKey();
    if ($this->isValue($from = $filterValue['from'] ?? '')) {
        $searchCriteriaBuilder->addFilter($key, $from, 'gteq');
    }
    if ($this->isValue($to = $filterValue['to'] ?? '')) {
        $searchCriteriaBuilder->addFilter($key, $to, 'lteq');
    }
}
```

Wire it in XML: `<filter column="some_column" filterType="MyCustomGridFilterType"/>`.

Note: the XML reference calls this interface `Hyva\Admin\Api\GridFilterTypeInterface` while the
PHP reference calls it `HyvaGridFilterTypeInterface` — check the module.
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/php-classes-and-interfaces/hyvagridfiltertypeinterface.html>

---

## Data types: DataTypeGuesserInterface, DataTypeValueToStringConverterInterface, DataTypeInterface

A column's *type code* decides how a raw value becomes a cell. `DataTypeInterface` simply
combines the guesser and the converter, and is what most built-in Magento types implement. All
implementations are registered on `Hyva\Admin\Model\DataType\DataTypeFacade` in adminhtml
`di.xml`; **order matters** — generic types (`object`, `unknown`) must come after specific ones.

```xml
<type name="Hyva\Admin\Model\DataType\DataTypeFacade">
    <arguments>
        <!-- note: order matters - generic DataTypes come after more specific ones -->
        <argument name="dataTypeClassMap" xsi:type="array">
            <item name="datetime" xsi:type="string">Hyva\Admin\Model\DataType\DateTimeDataType</item>
            <item name="price" xsi:type="string">Hyva\Admin\Model\DataType\PriceDataType</item>
            <item name="magento_product" xsi:type="string">Hyva\Admin\Model\DataType\ProductDataType</item>
            <item name="magento_tier_price" xsi:type="string">Hyva\Admin\Model\DataType\TierPriceDataType</item>
            <item name="object" xsi:type="string">Hyva\Admin\Model\DataType\GenericObjectDataType</item>
            <item name="unknown" xsi:type="string">Hyva\Admin\Model\DataType\UnknownDataType</item>
        </argument>
    </arguments>
</type>
```

Array keys are the type codes usable as `<column type="…">`.

```php
interface DataTypeGuesserInterface
{
    public function valueToTypeCode($value): ?string;
    public function typeToTypeCode(string $type): ?string;
}
```

Return the type code when the input is yours, `null` otherwise. `$value` can be anything;
`$type` is a Magento internal type identifier — a class/interface name, an EAV backend type
code, or a special case like `gallery`.

```php
public function valueToTypeCode($value): ?string
{
    return is_object($value) && $value instanceof AddressInterface
        ? 'magento_customer_address'
        : null;
}

public function typeToTypeCode(string $type): ?string
{
    return is_string($type) && is_subclass_of($type, AddressInterface::class)
        ? 'magento_customer_address'
        : null;
}
```

```php
interface DataTypeValueToStringConverterInterface
{
    const UNLIMITED_RECURSION = -1;

    public function toString($value): ?string;
    public function toHtmlRecursive($value, $maxRecursionDepth = self::UNLIMITED_RECURSION): ?string;
}
```

`toString()` is used by default and must return **plain text** — an image becomes its URL, not
an `<img>` tag. `toHtmlRecursive()` is used only when the column sets
`renderAsUnsecureHtml="true"`; recursion is currently only meaningful for the `array` type, and
delegating to `toString()` is fine when both representations match. Return `null` when the type
does not match; an appropriate exception is raised elsewhere.

```php
public function toHtmlRecursive($value, $maxRecursionDepth = self::UNLIMITED_RECURSION): ?string
{
    return $this->canProcess($value)
        ? sprintf('<img src="%s"/>', $this->getImageUrl($value))
        : null;
}
```

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/php-classes-and-interfaces/datatypeguesserinterface.html>
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/php-classes-and-interfaces/datatypevaluetostringconverterinterface.html>
<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/php-classes-and-interfaces/datatypeinterface.html>

---

## Grid AbstractExportType

Base class of all export formats. Built-ins: `Hyva\Admin\Model\GridExport\Type\Csv`, `…\Xml`,
`…\Xlsx`. Either set `class` on the `<export>` node, or extend the type→class map in `di.xml`
(then no `class` attribute is needed):

```xml
<type name="Hyva\Admin\Model\GridExport\GridExportTypeLocator">
    <arguments>
        <argument name="gridExportTypes" xsi:type="array">
            <item name="csv" xsi:type="string">Hyva\Admin\Model\GridExport\Type\Csv</item>
            <item name="xml" xsi:type="string">Hyva\Admin\Model\GridExport\Type\Xml</item>
            <item name="xlsx" xsi:type="string">Hyva\Admin\Model\GridExport\Type\Xlsx</item>
        </argument>
    </arguments>
</type>
```

One abstract method to implement — `public function createFileToDownload(): void` — which
creates the export file on the filesystem. The file is deleted automatically after being sent to
the browser. The CSV implementation is the reference:

```php
public function createFileToDownload(): void
{
    $file      = $this->getFileName();
    $directory = $this->filesystem->getDirectoryWrite($this->getExportDir());
    $stream    = $directory->openFile($file, 'w+');
    $stream->lock();
    $stream->writeCsv($this->getHeaderData());
    foreach ($this->iterateGrid() as $row) {
        $stream->writeCsv(map(function (CellInterface $cell): string {
            return $cell->getTextValue();
        }, $row->getCells()));
    }
    $stream->unlock();
    $stream->close();
}
```

Helper methods from the parent (not `final`, but not meant to be overridden):

| Method | Returns |
|---|---|
| `getFileName(): string` | file name inside the Magento dir; the configured `fileName`, else grid name + type suffix |
| `getContentType(): string` | HTTP content type, default `application/octet-stream` (triggers a save dialog); rarely needs changing |
| `getExportDir(): string` | Magento directory code the file is written to; defaults to `var/` (see `Magento\Framework\App\Filesystem\DirectoryList`) |
| `getGrid(): HyvaGridExportInterface` (protected) | the grid being exported, e.g. `$this->getGrid()->getGridName()` |
| `getHeaderData(): array` (protected) | the grid's column names |
| `iterateGrid(): Iterator` (protected) | all grid rows, loaded in batches of **200** so memory is not exhausted |

<https://hyva-themes.github.io/magento2-hyva-admin/api-reference/php-classes-and-interfaces/grid-abstractexporttype.html>
