# Category Merchandiser and Linked Products

Both are **beta** (`0.1.0`) at the time these docs were written: features and configuration are still
evolving and may change in backwards-incompatible ways before GA, they are not recommended for
production, and upgrading may require rework. See `installation-and-licensing.md` for the beta channel
and the release-status list.

---

# Category Merchandiser (beta)

Replaces Magento's default "Products in Category" grid with a visual, drag-and-drop merchandiser, so
merchants control which products appear in a category and in what order without editing position
numbers. Package `hyva-themes/commerce-module-category-merchandiser`.
<https://docs.hyva.io/hyva-commerce/features/category-merchandiser/index.html>

**Not currently supported on Adobe Commerce**, which ships its own conflicting Visual Merchandiser. A
dedicated compatibility module for **Hyvä Enterprise** is documented as coming soon for full Adobe
Commerce compatibility.

## What it does

- **Drag-and-drop reordering** — drag cards, type an exact position, or nudge a product one step at a
  time. Every path also works from the keyboard.
- **Product search** — by name or SKU, showing stock status, catalog visibility and whether the product
  is already assigned to the category, with paged loading.
- **Per-admin preferences** — grid columns, page size, minimum search query length,
  add-to-top-or-bottom, and which products search includes. Each has a site-wide default that an
  individual admin can override, remembered for next time.
- **Store scope awareness** — product status, visibility and price reflect the store view currently
  selected on the category page.
- **One switch to turn it off** — disabling **Enable Visual Merchandiser** falls back to Magento's own
  grid.
- **Unsaved-changes guard** — warns before you navigate away.
- **Accessible by default** — reordering, searching, paging and removing products all announce to
  screen readers and work end to end from the keyboard.

Where to find it: `Catalog → Categories`, select a category, open the **Products in Category** section.
**No extra admin permission is required** beyond the existing `Magento_Catalog::categories` permission
used for managing categories — anyone who can edit a category can use the merchandiser.

## Install

```bash
composer require hyva-themes/commerce-module-category-merchandiser
bin/magento setup:upgrade
```

Follow the beta notes for the stability constraint the root `composer.json` needs. Once installed it is
**enabled by default** and immediately replaces the default grid on every category.
<https://docs.hyva.io/hyva-commerce/features/category-merchandiser/installation.html>

## Configuration

`Stores → Settings → Configuration → Hyvä Commerce → Category Merchandiser`. Every setting below is a
site-wide default that an individual admin can override from inside the merchandiser.

**General**

- **Enable Visual Merchandiser** — `Yes` (default) replaces the "Products in Category" grid on every
  category; `No` falls back to Magento's own grid.

**Search Results**

- **Include Assigned Products in Search** — `Yes` (default) keeps already-assigned products in the
  results; `No` leaves them out.
- **Include Disabled Products in Search** — default `No`.
- **Include Non-Visible Products in Search** — `Yes` includes products whose catalog visibility is
  "Not Visible Individually" or "Search"; default `No`, so only products visible in catalog or search
  appear.
- **Minimum Search Query Length** — `1`–`10`, default `3`.

**Product Grid**

- **Add New Products to Top of Grid** — `Yes` (default) places search-added products at the top; `No`
  at the bottom.
- **Product Grid Columns** — `1`–`8`, default `4`.
- **Products per Page** — `12`–`100`, default `24`.

**Scope**: configuration supports **only the default (global) scope** — there are no per-website or
per-store-view settings, and the values are shared across the whole installation. Product status,
visibility and price shown in the grid do respect the store view selected on the category page.

**Per-admin overrides**: inside the merchandiser each admin can adjust grid columns, page size, minimum
search length, add-to-top-or-bottom and the search inclusion options. Changes save automatically and
are remembered next time, without affecting the site-wide defaults or any other admin's preferences.
<https://docs.hyva.io/hyva-commerce/features/category-merchandiser/configuration.html>
<https://docs.hyva.io/hyva-commerce/features/category-merchandiser/faqs.html>

---

# Linked Products (beta)

Introduces a new entity, the **Linked Product Group**, that groups different product types by a shared
attribute such as colour or size. Package `hyva-themes/commerce-module-linked-products`.
<https://docs.hyva.io/hyva-commerce/features/linked-products/index.html>

Positioning per the docs: more flexible than rigid Related / Cross-sell / Upsell relations, far less
complex than Configurable, Grouped and Bundle product relations, and groups can be created directly
from the Product Edit page.

## Attribute constraints

An attribute can be used for linking only when:

- `frontend_input` = `select` — **dropdown attributes only**
- `is_user_defined` = `1` — **custom attributes only**
- the product has a **non-empty value** for that attribute

Catalog input types supported by the frontend:

- **Visual swatch**
- **Text swatch**
- **Dropdown** — supported, but rendered as a Text swatch

## Install

```bash
composer require hyva-themes/commerce-module-linked-products
bin/magento setup:upgrade
```

<https://docs.hyva.io/hyva-commerce/features/linked-products/installation.html>
