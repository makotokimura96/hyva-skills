---
name: hyva-admin
description: Use when adding or changing a Magento 2 adminhtml grid: listing records in the backend, or replacing/avoiding a ui_component listing XML. Builds grids declaratively with the Hyva_Admin module (hyva-themes/module-magento2-admin) - one XML file in view/adminhtml/hyva-grid/ plus a Hyvä\Admin\Block\Adminhtml\HyvaGrid block in layout XML gives columns, paging, sorting, filters, row and mass actions, buttons and CSV/XML/XLSX export. Covers picking a data source (repository getList, ORM collection, array provider, SQL select), column renderers and types, custom filters, wiring action controllers, grid source processors, the hyva_grid_* events, and the ACL and escaping traps. Adminhtml only, never storefront theming. Keywords hyva-grid.xsd, hyva_admin_grid handle, HyvaGridArrayProviderInterface, HyvaGridSourceProcessorInterface, arrayProvider, repositoryListMethod, defaultSearchCriteriaBindings, massActions, Hyva_Admin.
---

# Hyvä Admin grids

Hyva_Admin is a Magento 2 module that adds a second, declarative way to build **admin
grids**. Existing UI-component grids and forms are untouched by installing it; nothing is
migrated automatically. Admin **forms** are not implemented — see `references/design-notes.md`.
<https://hyva-themes.github.io/magento2-hyva-admin/index.html>

Two files are the whole job:

1. Layout XML — `<update handle="hyva_admin_grid"/>` (loads Alpine.js + Tailwind for the
   admin area) plus a `Hyva\Admin\Block\Adminhtml\HyvaGrid` block.
2. `view/adminhtml/hyva-grid/<grid-name>.xml` — the grid definition. The file name matches
   the block's name-in-layout or its `grid_name` argument.

Grid XML is merged across modules per grid name, exactly like other Magento XML, so a grid
declared in another module can be extended or partly disabled from your own module.

When a project has no `app/code`, put the grid in the relevant
`vendor/<vendor>/module-*` package and remember it also has to be committed in that
package's own repo. Flush the cache after XML or PHP changes: `bin/magento cache:flush`.

## References

- `references/getting-started.md` — install, prerequisites, layout XML, grid file naming, minimal working examples.
- `references/grid-xml-reference.md` — **node-by-node reference of the whole grid XML** with a full nesting skeleton. Start here for any XML question.
- `references/php-api.md` — every documented interface / abstract class, what to implement it for, and the `di.xml` wiring.
- `references/events.md` — the three `hyva_grid_*` events, their containers and observer patterns.
- `references/design-notes.md` — sortability rules, filtering extension attributes, design principles, forms WIP status.

## Pitfalls

- Never omit `<update handle="hyva_admin_grid"/>`; without it the grid renders unstyled and dead (no Alpine, no Tailwind).
- Keep the grid XML file name identical to the block name or `grid_name` argument, or you get no grid.
- Declare the `xsi:noNamespaceSchemaLocation="urn:magento:module:Hyva_Admin:etc/hyva-grid.xsd"` so the IDE validates and autocompletes; the XSD in `etc/hyva-grid.xsd` is the final authority on element order.
- Columns are **not** filterable until you add `<navigation><filters><filter column="…"/>`; filters are opt-in per column.
- Cell values are escaped by default — an image or link column needs `renderAsUnsecureHtml="true"`, which switches rendering from `toString()` to `toHtmlRecursive()`.
- Using `rendererBlockName` silently disables Ajax navigation for the whole grid, and the renderer block must be declared in layout XML on every page showing the grid.
- Extension-attribute, product `category_ids` and `media_gallery` columns are forced `sortable="false"`; forcing `sortable="true"` needs your own plugin to sort after load.
- Never mutate the `SearchCriteriaInterface` inside a grid source processor — the grid memoizes by search criteria signature and will re-query.
- Hyvä grids ignore ACL — add `etc/acl.xml` and guard the controller yourself.
- Action and mass-action target controllers are not generated; write them.
- `<action><event on="click"/></action>` is flagged **experimental** and may change or be removed.
- The docs give two FQCNs for the processor base class and the export base class; trust the API reference ones and verify against the installed module before typing them.
