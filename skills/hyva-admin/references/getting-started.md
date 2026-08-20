# Getting started

## Requirements & install

- Magento 2.4.0 CE or newer (templates must have `$escaper` declared), PHP >= 7.3.
- Access to the Hyvä composer repository.

```bash
composer require hyva-themes/module-magento2-admin
# optional playground module with an example grid:
composer require hyva-themes/module-magento2-admin-test
```

The module is developed on PHP 7.4 and released from a rector-backported branch. The public
API is declared stable: released API aspects do not change, new features are added backward
compatibly.
<https://hyva-themes.github.io/magento2-hyva-admin/guides/installation.html>

If containerised, run composer/CLI inside the container:
`bin/magento cache:flush` after XML or PHP changes.

## Prerequisites for a grid

All standard Magento, nothing Hyvä-specific:

- `etc/adminhtml/routes.xml` — backend route.
- `Controller/Adminhtml/<Path>/<Action>.php` — the page controller.
- `etc/adminhtml/menu.xml` — a way to reach the page.
- `etc/acl.xml` — for the controller and menu entry. **Hyvä grids do not use the ACL**, so
  authorization stays your responsibility.
- `view/adminhtml/layout/<route>_<controller>_<action>.xml` — the page layout.

<https://hyva-themes.github.io/magento2-hyva-admin/guides/hyva-admin-grid-walkthrough/prerequisites-for-a-grid.html>

## Declaring the grid block

Two things are required in layout XML: the `hyva_admin_grid` handle (loads Alpine.js and
Tailwind) and the grid block.

```xml
<?xml version="1.0"?>
<page xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:noNamespaceSchemaLocation="urn:magento:framework:View/Layout/etc/page_configuration.xsd">
    <update handle="hyva_admin_grid"/>
    <body>
        <referenceContainer name="content">
            <block class="Hyva\Admin\Block\Adminhtml\HyvaGrid" name="demo-grid"/>
        </referenceContainer>
    </body>
</page>
```

The grid name comes from the block's name-in-layout, or from an explicit `grid_name`
argument (use this when the block name must differ, e.g. two grids on one page):

```xml
<block class="Hyva\Admin\Block\Adminhtml\HyvaGrid" name="walkthrough-demo-grid">
    <arguments>
        <argument name="grid_name" xsi:type="string">demo-grid</argument>
    </arguments>
</block>
```

Either form above resolves to `<Module_Dir>/view/adminhtml/hyva-grid/demo-grid.xml`.
<https://hyva-themes.github.io/magento2-hyva-admin/guides/hyva-admin-grid-walkthrough/declaring-the-grid-block.html>
<https://hyva-themes.github.io/magento2-hyva-admin/guides/quickstart/examples/adding-a-hyvagrid-block-in-layout-xml.html>

## The grid XML file

Lives in `view/adminhtml/hyva-grid/`, named after the grid. Skeleton:

```xml
<?xml version="1.0"?>
<grid xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:noNamespaceSchemaLocation="urn:magento:module:Hyva_Admin:etc/hyva-grid.xsd">
</grid>
```

The schema declaration is optional but always worth adding — PhpStorm then autocompletes and
validates every node. The XSD ships at `Hyva_Admin`'s `etc/hyva-grid.xsd` and is the
authority on element order and allowed values.

Grid XML is merged per grid name across all modules, so you can extend or neutralise a grid
declared elsewhere (most nodes take `enabled="false"` for exactly that).
<https://hyva-themes.github.io/magento2-hyva-admin/guides/hyva-admin-grid-walkthrough/the-grid-xml-file.html>

With only a `<source>` declared, **all** fields of the returned records are shown as columns
in a source-determined order. In many cases that is already enough.
<https://hyva-themes.github.io/magento2-hyva-admin/guides/quickstart/index.html>

## Minimal example 1 — array provider

```php
<?php declare(strict_types=1);

namespace Hyva\AdminTest\Model;

use Hyva\Admin\Api\HyvaGridArrayProviderInterface;
use Magento\Framework\App\Filesystem\DirectoryList;
use Magento\Framework\Filesystem\Io\FileFactory;

class LogFileListProvider implements HyvaGridArrayProviderInterface
{
    private DirectoryList $directoryList;
    private FileFactory $fileFactory;

    public function __construct(DirectoryList $directoryList, FileFactory $fileFactory)
    {
        $this->directoryList = $directoryList;
        $this->fileFactory = $fileFactory;
    }

    public function getHyvaGridData(): array
    {
        $file = $this->fileFactory->create();
        $file->cd($this->directoryList->getPath(DirectoryList::LOG));

        return $file->ls();
    }
}
```

```xml
<?xml version="1.0"?>
<grid xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:noNamespaceSchemaLocation="urn:magento:module:Hyva_Admin:etc/hyva-grid.xsd">
    <source>
        <arrayProvider>Hyva\AdminTest\Model\LogFileListProvider</arrayProvider>
    </source>
    <columns>
        <exclude>
            <column name="leaf"/>
        </exclude>
    </columns>
</grid>
```

Columns are taken from the array keys of the **first** record. Even the `<exclude>` here is
optional.
<https://hyva-themes.github.io/magento2-hyva-admin/guides/quickstart/examples/array-grid-data-provider.html>
<https://hyva-themes.github.io/magento2-hyva-admin/guides/quickstart/examples/array-grid-provider-configuration.html>

## Minimal example 2 — repository, showing most features at once

```xml
<?xml version="1.0"?>
<grid xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:noNamespaceSchemaLocation="urn:magento:module:Hyva_Admin:etc/hyva-grid.xsd">
    <source>
        <repositoryListMethod>\Magento\Catalog\Api\ProductRepositoryInterface</repositoryListMethod>
    </source>
    <columns>
        <include>
            <column name="id"/>
            <column name="sku"/>
            <column name="name"/>
            <column name="image" type="magento_product_image" renderAsUnsecureHtml="true"
                    label="Main Image" template="Hyva_AdminTest::image.phtml"/>
            <column name="media_gallery" renderAsUnsecureHtml="true"/>
            <column name="price" type="price"/>
            <column name="short_description" initiallyHidden="true"/>
        </include>
        <exclude>
            <column name="category_gear"/>
        </exclude>
    </columns>
    <actions idColumn="id">
        <action id="edit" label="Edit" url="*/*/edit"/>
        <action id="delete" label="Delete" url="*/*/delete"/>
    </actions>
    <massActions idColumn="id">
        <action id="reindex" label="Reindex" url="*/massAction/reindex"/>
        <action id="delete" label="Delete" url="*/massAction/delete" requireConfirmation="true"/>
    </massActions>
    <navigation>
        <pager>
            <defaultPageSize>5</defaultPageSize>
            <pageSizes>2,5,10</pageSizes>
        </pager>
        <sorting>
            <defaultSortByColumn>sku</defaultSortByColumn>
            <defaultSortDirection>desc</defaultSortDirection>
        </sorting>
        <filters>
            <filter column="sku"/>
            <filter column="id"/>
        </filters>
    </navigation>
</grid>
```

<https://hyva-themes.github.io/magento2-hyva-admin/guides/quickstart/examples/repository-getlist-grid-data-provider.html>

## Choosing a source type

For one entity there are often three candidates, e.g. for orders:
`Magento\Sales\Api\OrderRepositoryInterface::getList`,
`Magento\Sales\Model\ResourceModel\Order\Collection`,
`Magento\Sales\Model\ResourceModel\OrderGridCollection`. Usually it does not matter — take
what you have. Differences that do matter:

- A repository may return **extension attributes** that plain models never load.
- A grid (index) collection may carry **aggregate columns** that neither the model nor the
  regular collection has — e.g. the order grid table has a single full-customer-name field,
  while the order model only has separate first/last name fields, which makes filtering by
  customer name much nicer.
- Array providers return everything at once; Hyva_Admin applies filtering, then sorting and
  pagination afterwards, so they are not suited to very large data sets. Use a collection or
  repository there.

<https://hyva-themes.github.io/magento2-hyva-admin/guides/hyva-admin-grid-walkthrough/setting-a-grid-data-source.html>
