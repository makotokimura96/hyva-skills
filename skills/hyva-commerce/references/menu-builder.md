# Menu Builder

Builds storefront navigation menus visually with the Hyvä CMS editor. Adds a **Menu** option under
`Content → Elements` in the admin. Package `hyva-themes/commerce-module-menu-builder`, module
`Hyva_MenuBuilder`. **Requires Hyvä CMS** — menus are Hyvä CMS content and use its component system.
<https://docs.hyva.io/hyva-commerce/features/menu-builder/index.html>

```bash
composer require hyva-themes/commerce-module-menu-builder
bin/magento setup:upgrade
# then clear the browser cache
```

No additional setup steps. GitLab install additionally needs the `commerce-module-commerce` and
`commerce-module-menu-builder` repositories configured (see `installation-and-licensing.md`).
<https://docs.hyva.io/hyva-commerce/features/menu-builder/installation.html>

## Creating menus

`Content → Elements → Menus` → **Add New Menu** → build the structure in the Hyvä CMS editor → Save.

Four built-in menu components:

| Component | Use |
|---|---|
| **Mega Menu Columns** | Traditional mega menu: top-level items expanding into column panels |
| **Mega Menu Drilldown** | Progressive drilldown for deeply nested structures |
| **Mobile Menu** | Mobile drilldown with an integrated search bar and CTA button |
| **Footer Columns** | Multi-column footer navigation |

The link picker covers Categories, Products, CMS Pages, Magento pages (contact, my account,
wishlist), and Custom URLs, with search over existing content.

Most layouts support a **Menu Content** component that accepts any Hyvä CMS content type — images,
banners, promotional blocks, custom layouts, or fields grouped with their content. Individual menu
items can be emphasised through design settings (text colour, background colour, font weight).

**Preview locking**: hover a menu item in the preview and click the blue lock icon so the menu stays
expanded across preview reloads — essential when editing deep structures.

**Category import** vs **dynamic category tree**:

- *Import Categories* is a one-time action that creates ordinary, independently editable menu items
  (including nested sub-categories); repeated imports add items without replacing existing ones.
- A *Category Tree* component generates its items from the live catalog at render time, so it updates
  automatically when categories change — at the cost of not being individually editable. Ideal for
  ERP-driven catalogs.

Menu item labels, footer column titles, menu content labels and menu item links can be translated
inline in the editor or through the Hyvä CMS Translations panel.
<https://docs.hyva.io/hyva-commerce/features/menu-builder/creating-menus.html>

## Displaying menus (no code)

- **Design Configuration** — `Content → Design → Configuration`, pick a store view, then the Header
  and Footer sections expose **Header Topmenu Navigation** and **Footer Menu** slots.
- **Hyvä CMS editor** — `Add Component` → **CMS Menu** (content section) → choose the menu.
- **Magento widget** — `Content → Elements → Widgets` → `Add Widget` → type **Hyvä CMS Menu** → set
  storefront properties + a layout update → pick the menu in the widget options.

<https://docs.hyva.io/hyva-commerce/features/menu-builder/displaying-menus.html>

## Rendering menus in code

**Widget shortcode** (CMS content, static blocks, anywhere widget directives are processed):

```html
{{widget type="Hyva\MenuBuilder\Block\Widget\Menu" menu_identifier="my_menu"}}
```

**Layout XML:**

```xml
<referenceContainer name="content">
    <block class="Hyva\MenuBuilder\Block\Menu">
        <arguments>
            <argument name="menu_identifier" xsi:type="string">my_menu</argument>
        </arguments>
    </block>
</referenceContainer>
```

**PHTML, approach 1 (preferred)** — declare in layout, render with `getChildHtml()`:

```xml
<!-- your_module/view/frontend/layout/default.xml -->
<block class="Hyva\MenuBuilder\Block\Menu" name="hyva_menu_block">
    <arguments>
        <argument name="menu_identifier" xsi:type="string">my_menu</argument>
    </arguments>
</block>
```

```php
<?= $block->getChildHtml('hyva_menu_block') ?>
```

Add `ttl` on the `Menu` block for shared ESI/Varnish block caching across pages
(`<block class="Hyva\MenuBuilder\Block\Menu" name="hyva_menu_block" ttl="3600">`). Without `ttl` the
menu is still cached as part of each page. **When using `ttl`, render via `getChildHtml()`** so
Magento goes through the layout pipeline (`renderElement`) where PageCache can process ESI
placeholders — `getChildBlock(...)->toHtml()` bypasses that path.

**PHTML, approach 2** — dynamic block, useful when the identifier is runtime-determined:

```php
<?= $block->getLayout()
    ->createBlock(\Hyva\MenuBuilder\Block\Menu::class)
    ->setMenuIdentifier('my_menu')
    ->toHtml(); ?>
```

<https://docs.hyva.io/hyva-commerce/features/menu-builder/devdocs/rendering-in-code.html>

## Custom menu components

Standard Hyvä CMS components (see `cms-component-development.md`) plus menu-specific `context_flags`.

A **root** menu component carries `hyva_menu_root`, which makes it appear when creating a new menu
entity. Without the flag it will not be offered:

```json
{
  "my_mobile_menu": {
    "label": "Mobile Menu",
    "context_flags": ["hyva_menu_root"],
    "children": {
      "config": {
        "accepts": ["hyva_menu_item", "hyva_menu_category_tree", "hyva_menu_content_container"],
        "max_nesting_level": 6
      }
    }
  }
}
```

`max_nesting_level` prevents unbounded nesting (slow, unmanageable menus). A parent can control which
template renders each child by calling `setTemplate()` when creating child blocks — for that, the
child must declare `template: false` and `require_parent: true` ("don't render me with my own
template, let my parent decide"). Use this for recursive multi-level menus that pass state such as the
current level, `max_level` or `parent_is_category_tree` down the tree.

Built-in components to read as reference implementations in `module-menu-builder`:
`hyva_menu_mobile` (slide-out drawer), `hyva_menu_desktop_drilldown` (hover + click dropdown),
`hyva_menu_item`, `hyva_menu_category_tree`.
<https://docs.hyva.io/hyva-commerce/features/menu-builder/devdocs/creating-menu-components.html>

## Category tree expander

Add the built-in component by listing it in your root's `accepts`:

```json
"children": { "config": { "accepts": ["hyva_menu_item", "hyva_menu_category_tree", "hyva_menu_content_container"] } }
```

A custom category-tree component needs the `hyva_menu_category_tree` context flag and a
`category_ids` field — that flag is how `CategoryTreeExpander` recognises it:

```json
{
  "my_category_tree": {
    "label": "My Category Tree",
    "context_flags": ["hyva_menu_category_tree"],
    "template": false,
    "require_parent": true,
    "content": {
      "category_ids": { "type": "category_selector", "label": "Categories" }
    }
  }
}
```

In the parent's template, expand the trees before rendering items:

```php
<?php
use Hyva\MenuBuilder\ViewModel\CategoryTreeExpander;
use Hyva\Theme\Model\ViewModelRegistry;
/** @var ViewModelRegistry $viewModels */
$categoryTreeExpander = $viewModels->require(CategoryTreeExpander::class, $block);
$menuItems = $block->getData('children') ?? [];
$maxLevel = (int)($block->getData('max_level') ?? 4);
$menuItems = $categoryTreeExpander->expandCategoryTrees($menuItems, $maxLevel);
$block->setData('cache_tags', $categoryTreeExpander->getIdentities());
?>
```

`expandCategoryTrees()` replaces category-tree nodes with real category menu items;
`getIdentities()` returns cache tags for every category loaded, so the menu cache invalidates when
those categories change. **Call `expandCategoryTrees()` before `getIdentities()`** — the ViewModel
tracks IDs during expansion.

`$maxLevel`: `1` = only the selected categories, `2` = one level of children, `3` = two levels, …;
`false` = no limit.
<https://docs.hyva.io/hyva-commerce/features/menu-builder/devdocs/category-tree-expander.html>

## Category importer field

```json
"content": {
  "import_categories": {
    "type": "category_importer",
    "label": "Import Categories",
    "config": {
      "target_child_components": ["hyva_menu_item.link"],
      "max_nesting_level": 3
    }
  }
}
```

- `target_child_components` (**required**) — `"component_name.field_name"` entries: the component to
  create per imported category, and the field that receives the category link. Entries are tried in
  order as fallbacks, checking whether each component can be added given the parent's
  `children.config.accepts` — which lets you offer options that work at different menu levels, e.g.
  `["hyva_menu_item_level_0.link", "hyva_menu_item.link"]`.
- `max_nesting_level` (optional) — level 1 is the selected category, 2 adds direct children, 3
  grandchildren, …; omit for no depth limit.

Editor flow: **Import Categories** → modal category tree with checkboxes → select → **Import** →
nested menu items appear, linking to those category pages. `hyva_menu_mobile` and
`hyva_menu_desktop_drilldown` both use this pattern.
<https://docs.hyva.io/hyva-commerce/features/menu-builder/devdocs/importing-categories.html>

## Locking menus open in preview

Optional, preview-only. Implement it only for complex nested menus; it adds real complexity. The
global script `preview/menu-lock.js.phtml` is included on all frontend pages by Menu Builder's
`default.xml` and only loads in preview mode — check it only if locking fails and you use custom
layouts that do not inherit from the default.

Five pieces:

**1. `data-lock-id` on each expandable item container** (usually the `<li>`), preview only:

```php
<?php if ($block->validPreview()): ?>
    data-lock-id="<?= $escaper->escapeHtml($menuItem['uid'] . ($level > 0 ? '-' . $level : '')) ?>"
<?php endif; ?>
```

Including the level keeps the same item independently lockable at different depths.

**2. A `locked` boolean** on the Alpine component, alongside `open`.

**3. The lock button**, using the shipped template, preview only:

```php
<?= /** @noEscape */ $block->validPreview() ? $block->getLayout()
    ->createBlock(\Magento\Framework\View\Element\Template::class, '', ['data' => [
        'menu_id'  => $menuItem['uid'],          // or $menuItem['uid'] . '-' . $level when nested
        'template' => 'Hyva_MenuBuilder::html/preview/menu-lock-button.phtml'
    ]])->toHtml() : '' ?>
```

**4. `toggleLock()` plus lock-aware `toggle()`, `close()` and `canHover()`:**

```js
function initMyMenu(menuUid) {
    return {
        menuUid: menuUid,
        open: false,
        locked: false,
        toggleLock(uidToLock) {
            const menuState = window.hyvaMenu[menuUid];
            if (!menuState) return;
            this.locked = !this.locked;
            if (this.locked) {
                this.open = true;
                menuState.lockedMenuId = uidToLock ?? this.menuId;
            } else {
                menuState.lockedMenuId = null;
            }
        },
        toggle() { if (!this.locked) { this.open = !this.open; } },
        close()  { if (!this.locked) { this.open = false; } },
        canHover() {
            const hoverAllowed = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
            return hoverAllowed && !window.hyvaMenu['<menuUid>']?.lockedMenuId; // guard the second term with validPreview()
        }
    }
}
```

**5. Register the menu in preview mode:**

```php
<?php if ($block->validPreview()): ?>
    window.hyvaMenu?.initMenu?.('<?= $escaper->escapeJs($menuUid) ?>');
<?php endif; ?>
```

Always pass `menuUid` and `rootMenuId` explicitly into the Alpine init function via `x-data` — closure
scope or DOM lookups cause undefined references and silent failures.

**Nested menus**: lock state lives at the **root** menu level, so pass `root_menu_id` through block
data (`'root_menu_id' => $menuId`, or `$block->getData('root_menu_id')` when deeper), initialise
sub-items with both IDs (`x-data="initMyMenuSubItem('…menuId…', '…rootMenuId…')"`), and access
`window.hyvaMenu[this.rootMenuId]` inside `toggleLock()`. **Never** use `parentMenuId` or the item's
own `menuId` for lock state — it will not persist and behaves unpredictably.

Complete reference implementations:
`Hyva_MenuBuilder::elements/desktop_menu_drilldown/index.phtml` and
`Hyva_MenuBuilder::elements/mobile_menu/index.phtml`.
<https://docs.hyva.io/hyva-commerce/features/menu-builder/devdocs/locking-menus-in-preview.html>
<https://docs.hyva.io/hyva-commerce/features/menu-builder/faqs.html>
