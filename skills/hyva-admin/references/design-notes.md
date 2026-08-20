# Design notes (deep docs)

The "Deep Docs" section holds design documents and detail mostly useful when building **custom
column types and filters**. None of it is required knowledge to use Hyvä Admin grids.
<https://hyva-themes.github.io/magento2-hyva-admin/guides/design-docs/index.html>

## Design principles

Hyva_Admin exists to let developers get work done efficiently and enjoy it. The stated guiding
principles:

- Defaults that accomplish the task with as little code as possible — good enough for 80% of use
  cases.
- Leverage IDE/editor support as much as possible (hence the XSD and the `$cell` / `$filter` /
  `$button` template variables).
- Use existing, well-understood technology: layout XML, blocks, XML merging, `.phtml` templates.
- Add extensibility only for understood use cases, without compromising usability — simple cases
  must not require lots of code.
- Long-term backward compatibility: once an API aspect is released as stable it never changes;
  only new features are added, backward compatibly.
- Make using Hyva_Admin fun.

Practical consequence: reach for grid XML first, then a column `template`, then
a `type`/`ValueToStringConverter`, then a grid source processor, and only then events or plugins.
<https://hyva-themes.github.io/magento2-hyva-admin/guides/design-docs/design-principles.html>

## Rationale

The module is a deliberate alternative to Magento 2 UI Components for admin grids, written by
Vinai Kopp after being inspired by Willem Wigman's Hyvä frontend theme. Installing it changes
nothing about existing UI-component grids and forms; it only adds a second way to build new
ones.
<https://hyva-themes.github.io/magento2-hyva-admin/guides/design-docs/rationale.html>
<https://hyva-themes.github.io/magento2-hyva-admin/index.html>

## Sorting columns

Default: **all columns are sortable when possible**. Disable per column with
`sortable="false"`.

When *can* a column not be sorted? It depends on the source:

- **Array providers** — every column is sortable, because Hyva_Admin sorts the data itself.
- **Repository** (and collection/query) — sorting is delegated to the source when the search
  criteria is mapped onto the underlying ORM/select. That works well for columns loaded as part
  of the main query, but **not** for values loaded in a separate query.

For that reason Hyva_Admin automatically forces `sortable` to false for:

- columns containing an **extension attribute** value,
- **product category IDs**,
- the **product media gallery**.

Other special cases may exist; symptoms are an exception about sorting by a non-existent column,
or sorting silently doing nothing, depending on the source repository implementation.

To sort by such a field anyway, set `sortable="true"` explicitly **and** write a plugin that
applies the sorting after the repository has loaded the data.
<https://hyva-themes.github.io/magento2-hyva-admin/guides/design-docs/sorting-columns.html>
<https://hyva-themes.github.io/magento2-hyva-admin/guides/hyva-admin-grid-walkthrough/default-sort-order.html>

## Filtering extension attribute columns

No column has a filter until a `<navigation><filters><filter column="…"/>` element exists, and
the filter type follows the column type. Not every column type maps to a filter type — those
need an explicit `filterType` class.

The documented approach for extension attributes (values loaded after the main record, so a
plain SearchCriteria filter cannot reach them): observe
`hyva_grid_source_prefetch_<grid_name>`, which the repository grid source type dispatches every
time grid data is about to load. An observer can

- modify or replace the `SearchCriteria` outright, or
- **remember** the posted filter values and apply them when the extension attribute is loaded
  after the main record data, or
- map attribute codes to internal column names.

See `references/events.md` for the container API and the dispatch code.
<https://hyva-themes.github.io/magento2-hyva-admin/guides/design-docs/filtering-extension-attribute-columns.html>
<https://hyva-themes.github.io/magento2-hyva-admin/guides/hyva-admin-grid-walkthrough/filtering.html>

## Admin forms — **WIP, do not plan around it**

`Hyva_Admin` currently supports **grids only**. Forms are stated as a future goal on the module
front page, and the design document for them is explicitly a brain dump that has been
superseded: the docs page now just points at two GitHub issues.

- Discussion: <https://github.com/hyva-themes/magento2-hyva-admin/issues/27>
- Implementation state: <https://github.com/hyva-themes/magento2-hyva-admin/issues/36>

Treat admin forms as **unreleased and unspecified**. There is no `hyva-form.xsd`, no documented
XML, no documented PHP API. For an admin form, use a normal Magento adminhtml
form (or UI component form) and keep Hyvä Admin for the grid.
<https://hyva-themes.github.io/magento2-hyva-admin/guides/design-docs/hyva-admin-forms-wip.html>
