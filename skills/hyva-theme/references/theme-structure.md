# Theme structure, templates, view models and UI utilities

## Theme inheritance

A Hyvä child theme is a normal Magento theme with `<parent>Hyva/default</parent>` (or `Hyva/default-csp`) in `theme.xml`. Templates and layout XML are overridden the standard Magento way; the Tailwind build config is **not** inherited and must be copied (see `installation-and-setup.md`).

### Reset theme vs generated base layout resets

Hyvä is not based on Luma — it is a theme built from scratch, so all module layout XML block declarations from core/Adobe Commerce modules are removed. Up to default-theme 1.3.21 this was done by a parent `Hyva/reset` theme whose layout override files commented out the original declarations, e.g. for `Magento_Banner`:

```xml
<referenceContainer name="content">
    <!--
        <block name="banner.data" class="Magento\Banner\Block\Ajax\Data"
               template="Magento_Banner::js/banner.phtml"/>
    -->
</referenceContainer>
```

The comments document what would *normally* be there. Containers and extension points are preserved.

Since 1.3.21 `hyva-themes/magento2-base-layout-reset` generates those stripped layout files on the fly into `var/hyva-layout-resets/` instead. Benefits: fewer layout XML files on a cold layout cache (better TTFB), and new core modules are covered automatically.

```bash
bin/magento hyva:base-layout-resets:generate
bin/magento hyva:base-layout-resets:info                 # migration status per theme
bin/magento hyva:base-layout-resets:migrate Vendor/theme # automate the migration
```

Installed automatically with default-theme >= 1.3.21; otherwise `composer require hyva-themes/magento2-base-layout-reset && bin/magento module:enable Hyva_BaseLayoutReset && bin/magento setup:upgrade`. Custom generation directory via the **absolute** `hyva_layout_resets_generation_directory` key in `app/etc/env.php`.

Migrating a custom Hyvä **base** theme off `Hyva/reset` (optional): add `<update handle="default_hyva"/>` to `Magento_Theme/layout/default.xml`, copy `Magento_Theme/templates/root.phtml` from the reset theme, remove `<parent>Hyva/reset</parent>`, set the theme row's `parent_id` to `NULL`, register the theme in `hyvaBaseThemes`, clear the cache.

Because base Hyvä themes now have **no parent**, the old "walk the parents looking for a code starting with `Hyva/`" detection breaks. Use the service instead (available since theme-module 1.3.18):

```php
if (class_exists(HyvaThemes::class)) {
    return ObjectManager::getInstance()->get(HyvaThemes::class)->isHyvaTheme($theme);
}
// else: fall back to checking parent theme names
```

`\Hyva\Theme\Service\HyvaThemes` offers `isHyvaTheme(ThemeInterface $theme)` and `isHyvaThemeCode(string $themeCode)`. Register custom base themes via `di.xml`:

```xml
<type name="Hyva\Theme\Service\HyvaThemes">
    <arguments>
        <argument name="hyvaBaseThemes" xsi:type="array">
            <item name="Hyva/reset" xsi:type="boolean">true</item>
            <item name="Hyva/default" xsi:type="boolean">true</item>
            <item name="Hyva/default-csp" xsi:type="boolean">true</item>
        </argument>
    </arguments>
</type>
```

<https://docs.hyva.io/hyva-themes/advanced-topics/generated-base-layout-resets.html>, <https://docs.hyva.io/hyva-themes/compatibility-modules/core-magento-compat-modules.html>

## The `hyva_` layout handles

On a store view running a Hyvä theme, **every** applied layout handle gets a second handle with a `hyva_` prefix, loaded *after* the original. So `default`, `cms_index_index`, `cms_page`, `customer_logged_out` are followed by `hyva_default`, `hyva_cms_index_index`, `hyva_cms_page`, `hyva_customer_logged_out`.

This is the mechanism that lets one module serve Luma and Hyvä store views side by side: standard blocks/templates in the normal handles, Hyvä-specific overrides in `hyva_*` files. Luma store views never load them.

In PHP, inject `Hyva\Theme\Service\CurrentTheme` and call `$this->currentTheme->isHyva()`.

<https://docs.hyva.io/hyva-themes/writing-code/layout-and-templates/the-hyva_-layout-handles.html>

## Use `referenceBlock`, not `block`, in child themes

Magento processes layout from the lowest-priority fallback theme upwards. A `<block name="x">` tag **replaces** any existing record for that name (discarding its arguments and parent reference); `<referenceBlock name="x">` **updates** it. Copying a parent-theme `<block>` declaration into a child theme therefore masks any argument added or changed upstream — a classic source of subtle post-upgrade bugs.

<https://docs.hyva.io/hyva-themes/writing-code/layout-and-templates/referencing-parent-theme-blocks.html>

## Template conventions

Every Hyvä template has `$block`, `$escaper`, `$viewModels` and (in Hyvä themes only) `$hyvaCsp` available. Annotate them at the top with imported class names:

```php
<?php
declare(strict_types=1);

use Hyva\Theme\Model\ViewModelRegistry;
use Magento\Framework\Escaper;
use Magento\Framework\View\Element\Template;

/** @var Template $block */
/** @var Escaper $escaper */
/** @var ViewModelRegistry $viewModels */
```

Hyvä follows the Magento 2 coding standard (phpcs, phpmd). Disabling a rule is acceptable when it genuinely does not apply — always as narrowly as possible, e.g. `// phpcs:disable Generic.Files.LineLength.TooLong`.

Escaping rules that matter in practice: `$escaper->escapeHtml()` for text, `$escaper->escapeHtmlAttr()` for attribute values (including `data-*`), `$escaper->escapeUrl()` for URLs in attributes, `$escaper->escapeJs()` for JS string literals. The two encodings are **not** interchangeable — using `escapeJs` where `escapeHtmlAttr` is needed silently breaks the code (this bites when moving inline PHP into `data-*` attributes for CSP).

<https://docs.hyva.io/hyva-themes/compatibility-modules/development-guidelines.html>, <https://docs.hyva.io/hyva-themes/writing-code/csp/alpine-csp-properties.html>

## The view model registry

Hyvä's `$viewModels` (from `hyva-themes/magento2-theme-module`) fetches any class implementing `ArgumentInterface` without declaring it in layout XML:

```php
use Hyva\Theme\Model\ViewModelRegistry;
use Hyva\Theme\ViewModel\CurrentProduct;

/** @var ViewModelRegistry $viewModels */
$currentProduct = $viewModels->require(CurrentProduct::class);
```

View models are preferred over custom block classes: reusable, composable, and any number can be used per template.

### View model cache tags

A view model that implements `Magento\Framework\DataObject\IdentityInterface` has its `getIdentities()` collected automatically by the registry and merged into the `X-Magento-Tags` response header (FPC/Varnish) **and** into `block_html` cache records. This closes the standard-Magento gap where view models cannot contribute cache tags at all.

```php
public function getIdentities(): array
{
    $currentProduct = $this->registry->registry('current_product');
    return $currentProduct instanceof IdentityInterface ? $currentProduct->getIdentities() : [];
}
```

Collection is **lazy** — `getIdentities()` is only called when the response is finalized, so view models that accumulate data during rendering (e.g. Navigation walking the category tree) report complete tags. In developer mode `Hyva\Theme\Block\ViewModelCacheTagsBlock` (injected into `before.body.end` via `hyva_default`) renders an HTML comment near `</body>` listing all collected tags — use it to verify propagation.

**ESI blocks**: when a template is rendered inside an ESI section (a block with `ttl="…"`), pass `$block` as the second argument so the registry attributes the tags to the ESI cache record instead of the page:

```php
$currentProduct = $viewModels->require(CurrentProduct::class, $block);
```

Only do this for view models with cache tags used in ESI templates — in the default theme that is just `Magento_Theme/templates/html/header/menu/desktop.phtml` and `.../mobile.phtml`. For double-cached blocks (ESI **and** `block_html`) Hyvä stores the tags in a separate `block_html` record and re-attaches them via `Hyva\Theme\Plugin\PageCache\AddViewModelCacheTagsToEsiResponse`.

<https://docs.hyva.io/hyva-themes/writing-code/working-with-view-models/index.html>, <https://docs.hyva.io/hyva-themes/performance/view-model-cache-tags.html>

## Responsive images: the Media view model

```php
$mediaViewModel = $viewModels->require(\Hyva\Theme\ViewModel\Media::class);
echo $mediaViewModel->getResponsivePictureHtml($images, $imgAttributes, $pictureAttributes);
```

`$images` is an array of configs with keys `path` (required, relative to `pub/media/`), `width` (required), `height` (required), `media` (optional CSS media query), `fallback` (optional `true` to use as the `<img>` src). `$imgAttributes` sets attributes on the `<img>` (alt, class, `loading`, `fetchpriority`), `$pictureAttributes` on the `<picture>`.

```php
$desktopImage = ['path' => 'wysiwyg/hero.jpg', 'width' => 1920, 'height' => 600,
                 'media' => '(min-width: 768px)', 'fallback' => true];
$mobileImage  = ['path' => 'wysiwyg/hero-mobile.jpg', 'width' => 768, 'height' => 800,
                 'media' => '(max-width: 767px)'];
echo $mediaViewModel->getResponsivePictureHtml(
    [$desktopImage, $mobileImage],
    ['alt' => 'Summer Collection', 'class' => 'w-full h-auto',
     'loading' => 'eager', 'fetchpriority' => 'high']
);
```

Using the view model consistently keeps image rendering an extension point for third-party modules. For Media Gallery assets, inject `\Magento\MediaGalleryUi\Model\GetDetailsByAssetId` into a **custom view model** (not a template) — `execute([$assetId])` returns data in exactly the shape `getResponsivePictureHtml()` expects.

<https://docs.hyva.io/hyva-themes/writing-code/working-with-view-models/rendering-images.html>

## Product images and gallery configuration

Image sizes come from `etc/view.xml` in the theme (copy from `vendor/hyva-themes/magento2-default-theme/etc/view.xml` if absent):

```xml
<media>
    <images module="Magento_Catalog">
        <image id="category_page_grid" type="small_image">
            <width>360</width><height>360</height>
        </image>
    </images>
</media>
```

Luma Fotorama `view.xml` settings do **not** apply — the Hyvä gallery is driven by its `.phtml` template. Supported options:

```xml
<vars module="Magento_ConfigurableProduct">
    <var name="gallery_switch_strategy">append</var> <!-- 'append' or 'replace' -->
</vars>
```

From default-theme 1.3.6 all Product Video options except **Autostart base video** are supported (`Stores > Configuration > Catalog > Catalog > Product Video`).

<https://docs.hyva.io/hyva-themes/building-your-theme/product-images-and-gallery.html>

## SVG icons

Hyvä ships a customized **Lucide** set (stroke width 1.5 instead of 2). HeroIcons v1 is included for legacy themes and will not be updated to v2. Everything goes through `\Hyva\Theme\ViewModel\SvgIcons`.

```php
use Hyva\Theme\ViewModel\LucideIcons;
$lucideIcons = $viewModels->require(LucideIcons::class);
echo $lucideIcons->scaleHtml('text-gray-500', 24, 24, ['aria-hidden' => 'true']);
```

Every icon method has the signature `(string $classnames = '', ?int $width = 24, ?int $height = 24, array $attributes = [])`. The method name is the **camel-cased icon filename plus `Html`** — `rainbow-unicorn.svg` → `rainbowUnicornHtml()`. There is no icon called something you invented: the method must map to an existing `.svg`. `renderHtml('rainbow-unicorn', 32, 32)` is the dynamic equivalent. Passing `null` for width/height removes the attributes (not recommended).

Accessibility: pass `aria-hidden="true"` for decorative icons. Without both `role="img"` and `aria-hidden="true"`, `SvgIcons` injects a `<title>Icon Name</title>` into the `<svg>` (since 1.3.0).

**Theme-level custom icons**: drop files in `<theme>/web/svg/` and render via `SvgIcons`. Override a default Lucide icon by placing a same-named file at `Hyva_Theme/web/svg/lucideicons/<name>.svg` in your theme.

**In CMS content**, use the `{{icon}}` directive (processed by `Hyva\Theme\Model\Template\IconProcessor`):

```
{{icon "lucide/shopping-cart" width=24 height=24}}
{{icon "my-icon"}}
```

Optional packs (Hyvä license required): `composer require hyva-themes/magento2-heroicons2` (`Hyva\Heroicons2\ViewModel\Heroicons2Outline`, CMS path e.g. `heroicons2/24/outline/shopping-cart`) and `composer require hyva-themes/magento2-payment-icons` (`Hyva\PaymentIcons\ViewModel\PaymentIconsClean`; also Light, Dark, Mono, Outline variants; methods listed in `src/ViewModel/PaymentIconsInterface.php`). Both need `bin/magento setup:upgrade`. To let editors paste raw SVG into the WYSIWYG, install `hyva-themes/magento2-wysiwyg-svg` — a different purpose from the icon view models.

### Custom icon view model

Put lowercase `a-z0-9-` named `.svg` files in `view/frontend/web/svg` (optionally in `outline/`, `solid/`, … subdirectories), then:

```php
namespace My\Module\ViewModel;

use Hyva\Theme\ViewModel\SvgIcons;

/**
 * @method string bubbleBathHtml(string $classnames = '', ?int $width = 24, ?int $height = 24, array $attributes = [])
 */
class ExampleIcons extends SvgIcons {}
```

`SvgIcons` may only be extended outside the theme module since theme-module **1.1.12** — add `"hyva-themes/magento2-theme-module": ">=1.1.12"` to `composer.json`. Set the prefix in the **primary** `etc/di.xml`, not `etc/frontend/di.xml` (the frontend scope breaks the PageBuilder CMS preview of SVG icons):

```xml
<type name="My\Module\ViewModel\ExampleIcons">
    <arguments>
        <argument name="iconPathPrefix" xsi:type="string">My_Module::svg/solid</argument>
    </arguments>
</type>
```

Expose the set to CMS content with a `pathPrefixMapping` in `etc/frontend/di.xml`:

```xml
<type name="Hyva\Theme\ViewModel\SvgIcons">
    <arguments>
        <argument name="pathPrefixMapping" xsi:type="array">
            <item name="example" xsi:type="string">My_Module::svg</item>
        </argument>
    </arguments>
</type>
```

→ `{{icon "example/hot-shower" classes="w-6 h-6" width=12 height=12}}`.

<https://docs.hyva.io/hyva-themes/view-utilities/hyva-svg-icon-modules/index.html>, <https://docs.hyva.io/hyva-themes/writing-code/working-with-view-models/svgicons.html>, <https://docs.hyva.io/hyva-themes/writing-code/working-with-view-models/custom-svgicon-view-models.html>

## Modal dialogs

Since Hyvä **1.5.0** modals are built on the native HTML `<dialog>` element via the `x-htmldialog` plugin — focus trapping, Escape handling, backdrop click and focus restoration are all browser-native. Two approaches:

**Alpine only (recommended, works in CMS content too):**

```html
<div x-data="{ open: false }">
    <button @click="open = true" type="button" class="btn">Open</button>
    <dialog x-show="open" x-htmldialog="open = false">
        <p>Dialog content here.</p>
        <button @click="open = false" type="button" class="btn">Close</button>
    </dialog>
</div>
```

**PHP view model** — add `<update handle="hyva_modal"/>` to load the JS, then:

```php
$modalViewModel = $viewModels->require(\Hyva\Theme\ViewModel\Modal::class);
$modal = $modalViewModel->createModal()
    ->withTemplate('My_Module::dialog-content.phtml')
    ->positionBottom()
    ->overlayDisabled()
    ->addDialogClass('pb-10')
    ->withAriaLabel('My dialog');
```

Render inside `<div x-data="hyvaModal">` and open with `@click="<?= $escaper->escapeHtmlAttr($modal->getShowJs()) ?>"`. **Always use `getShowJs()`** in extensions rather than `@click="show"` — it generates a unique dialog name and handles focus return. Close from inside with `@click="hide"`. `x-focus-first` marks the element that should receive focus when the dialog opens.

Fluent API: `overlayEnabled()`/`overlayDisabled()`, `initiallyHidden()`/`initiallyVisible()`, `withCloseby('any'|'closerequest'|'none')` (1.5.0+), `positionCenter/Top/Right/Bottom/Left/TopLeft/TopRight/BottomRight/BottomLeft()`, `positionNone()` (1.3.10+), `withDialogClasses(...)` (defaults `['inline-block','bg-white','shadow-xl','rounded-lg','p-10']`), `addDialogClass(...)`, `removeDialogClass(...)`, `withAriaLabel()`, `withAriaLabelledby()`, `withTemplate()`, `withBlockName()`, `withContent()`, `getContentRenderer()` (1.1.9+, returns the Template block so you can `assign()`/`setData()` before rendering — but echo `$modal`, not the block), `withDialogRefName()`/`getDialogRefName()`.

Deprecated since 1.5.0 (still work, log a warning): `withOverlayClasses`, `addOverlayClass`, `removeOverlayClass` → use `addDialogClass('backdrop:…')`; `withContainerTemplate`, `withContainerClasses`, `addContainerClass`, `removeContainerClass` → the container wrapper is gone, use `addDialogClass()` or the position methods.

**Heredoc caveat**: Magento's HTML minifier expects a `;` after the closing heredoc delimiter, which is invalid PHP when the heredoc is used as an expression. Either disable minification (recommended for Hyvä anyway) or assign the heredoc to a variable first.

**Confirmation dialogs** (since 1.1.13) build on modals; default template `Hyva_Theme::modal/confirmation.phtml`:

```php
$confirmation = $modalViewModel->confirm(__('Are you sure?'))
    ->withDetails('<em>This action cannot be undone.</em>')   // not escaped
    ->withOKLabel(__('Yes, delete'))
    ->withCancelLabel(__('No, keep it'));
```

`getShowJs()` returns a promise; `.then(result => result && doSomething())`. `withContent()` bypasses the default template entirely (no title, no buttons) — use `withDetails()` to keep the standard layout. For more than two outcomes, pass distinct values to `hide('a')`, `hide('b')`, … and the promise resolves to that value.

**Opening from outside the component**: dispatch a custom event and listen on the `x-data` element (`@open-my-dialog.window="open = true"`), or with the PHP view model dispatch `hyva-modal-show`:

```js
window.dispatchEvent(new CustomEvent('hyva-modal-show', {detail: {dialog: 'my-modal'}}))
```

Nested dialogs only require unique `x-ref` names, which the PHP view model handles automatically.

Pre-1.5.0 projects that cannot migrate can install a compatibility module to restore `hyva.modal()` (see the legacy modal install page). The legacy JS-only pattern required an overlay element with `x-spread="overlay()" x-bind="overlay()"` and content wrapped in `x-ref="dialog"`; `focusAfterHide` in the `hyva-modal-show` payload is also legacy-only.

<https://docs.hyva.io/hyva-themes/view-utilities/modal-dialogs/index.html>, <https://docs.hyva.io/hyva-themes/view-utilities/modal-dialogs/modal-view-model-reference.html>, <https://docs.hyva.io/hyva-themes/view-utilities/modal-dialogs/confirmation-dialogs.html>, <https://docs.hyva.io/hyva-themes/view-utilities/modal-dialogs/opening-a-modal-from-anywhere.html>, <https://docs.hyva.io/hyva-themes/view-utilities/modal-dialogs/keyboard-focus.html>

## Sliders

**Product sliders** are server-side rendered since 1.1.9 (no layout shift, swatches and add-to-cart work). Add the layout handle and declare a block:

```xml
<update handle="hyva_product_slider" />
<referenceContainer name="content">
    <block name="my-slider" template="Magento_Catalog::product/slider/product-slider.phtml">
        <arguments>
            <argument name="title" xsi:type="string" translate="true">My Awesome Slider</argument>
            <argument name="category_ids" xsi:type="string">25</argument>
            <argument name="page_size" xsi:type="number">8</argument>
        </arguments>
    </block>
</referenceContainer>
```

Display arguments: `title` (**required**, accessible label + heading), `heading_tag` (`h3`), `show_heading` (`true`), `heading_css_classes` (`text-2xl font-medium`), `css_classes` (`my-8`), `slider_css_classes`, `column_count` (`4`), `show_pager` (`true`), `slider_name` (block name). Content: `hide_rating_summary`, `hide_details`. Selection: `type` (`related` | `upsell` | `crosssell`), `category_ids` (comma-separated), `include_child_category_products` (1.1.18+, single anchor category only), `product_skus` (1.1.10+), `price_from`/`price_to`, `additional_filters` (SearchCriteria syntax with `field`, `value`, `conditionType` — `eq`, `neq`, `like`, `in`, `nin`, `notnull`, `null`, `from`, `to`, `gt`, `lt`, `gteq`, `lteq`, `moreq`, `finset`, `regexp`), `page_size` (`8`). Sorting: `sort_attribute` (`position`), `sort_direction` (`ASC`).

`page_size` does **not** work for `crosssell` sliders — change `maxCrosssellItemCount` on `\Hyva\Theme\ViewModel\ProductList` via `di.xml` instead.

Removed in 1.4.0: `item_template`, `container_template`; `max_visible` renamed to `column_count`; `maybe_purged_tailwind_slide_item_classes` renamed to `css_classes`.

**Custom sliders** (1.4+) are pure XML — child blocks become slides:

```xml
<block name="my-slider" template="Hyva_Theme::elements/slider.phtml">
    <arguments><argument name="title" xsi:type="string">My Slider</argument></arguments>
    <!-- child blocks = slides -->
</block>
```

Options: `slider_name`, `title` (required for a11y), `heading_tag` (`h3`), `css_classes` (`my-8`), `heading_css_classes` (`text-2xl font-medium`), `column_count` (`1`), `slider_css_classes`, `show_heading` (`true`), `show_pager` (`true`). Or build one directly in a template with `x-snap-slider`. The pre-1.4 `\Hyva\Theme\ViewModel\Slider` + `slider-php.phtml` approach (with `maybe_purged_tailwind_section_classes`, `maybe_purged_tailwind_slide_item_classes`, `max_visible`, `slider.item.template` child alias) is **deprecated**. The old GraphQL client-side `Magento_Theme/templates/elements/slider.phtml` is deprecated but kept for BC.

<https://docs.hyva.io/hyva-themes/view-utilities/product-sliders.html>, <https://docs.hyva.io/hyva-themes/view-utilities/custom-sliders.html>

## Loading indicator

Render `Hyva_Theme::ui/loading.phtml` as a child block **inside** the Alpine component and set an `isLoading` property; the loader shows while it is `true`.

```xml
<block name="my-component" template="My_Module::my-template.phtml">
    <block name="loading" template="Hyva_Theme::ui/loading.phtml"/>
</block>
```

```html
<section x-data="initMyComponent()" @private-content-loaded.window="extractSectionData($event.detail.data)">
    <?= $block->getChildHtml('loading') ?>
    <template x-if="!isLoading"><div>…</div></template>
</section>
```

<https://docs.hyva.io/hyva-themes/view-utilities/loading-indicator.html>

## Customer header menu (since 1.3.2)

Links are child blocks of `header.customer.logged.in.links` / `header.customer.logged.out.links`, sorted ascending by `sort_order`, with block class `Hyva\Theme\Block\SortableItemInterface`:

```xml
<referenceBlock name="header.customer.logged.in.links">
    <block name="customer.header.orders.link" class="Hyva\Theme\Block\SortableItemInterface">
        <arguments>
            <argument name="label" xsi:type="string" translate="true">My Orders</argument>
            <argument name="path" xsi:type="string">sales/order/history</argument>
            <argument name="sort_order" xsi:type="number">30</argument>
        </arguments>
    </block>
</referenceBlock>
```

Default template `Hyva_Theme::sortable-item/link.phtml`; alternatives `Hyva_Theme::sortable-item/delimiter.phtml` and `Hyva_Theme::sortable-item/heading.phtml`. Put the XML in `default.xml` in a theme, or `hyva_default.xml` in a module.

<https://docs.hyva.io/hyva-themes/view-utilities/customer-header-menu-links.html>

## Product detail page structure

**Attributes** appear in two places: below the short description (`Magento_Catalog::product/view/product-info.phtml`, driven by an `attributes` array argument on the `product.info` block) and in "More Information" (`Magento_Catalog::product/view/attributes.phtml`, driven by the EAV "Is Visible On Frontend" flag).

```xml
<argument name="attributes" xsi:type="array">
    <item name="sku" xsi:type="array">
        <item name="call" xsi:type="string">getSku</item>   <!-- or `default` -->
        <item name="code" xsi:type="string">sku</item>
        <item name="label" xsi:type="string">default</item>
        <item name="css_class" xsi:type="string">sku</item> <!-- currently unused -->
    </item>
</argument>
```

Hide the More Information section with `<referenceBlock name="product.attributes" remove="true"/>`.

**Section cards** replace Luma's additional-information tabs — the same layout XML that adds a tab in Luma adds a card in Hyvä. `group="detailed_info"` is required:

```xml
<referenceBlock name="product.info.details">
    <block name="my.section" template="Magento_Catalog::product/view/my-section.phtml" group="detailed_info">
        <arguments>
            <argument name="title" xsi:type="string" translate="true">More Information</argument>
            <argument name="sort_order" xsi:type="number">-10</argument>
            <argument name="title_template" xsi:type="string">Magento_Catalog::product/view/sections/description-section-title.phtml</argument>
        </arguments>
    </block>
</referenceBlock>
```

Default title template: `Magento_Catalog::product/view/sections/default-section-title.phtml`.

**Menus** are limited to two levels by default (parsing cost + UX). Hyvä UI offers Mega and Drilldown menus for deeper structures; otherwise prefer landing pages with link grids over deeper menus.

<https://docs.hyva.io/hyva-themes/view-utilities/product-detail-page-attributes.html>, <https://docs.hyva.io/hyva-themes/view-utilities/product-detail-page-section-cards.html>, <https://docs.hyva.io/hyva-themes/faqs/adding-more-levels-to-the-menus.html>

## PDP pricing logic

Lives in `<Namespace>/<Theme>/Magento_Catalog/templates/product/view/price.phtml`. Three candidate values, checked in this order and computed in the reverse order:

```js
getFormattedFinalPrice() {
    return this.formatPrice(
        this.calculatedFinalPriceWithCustomOptions ||
        this.calculatedFinalPrice ||
        this.initialFinalPrice
    )
}
```

`initialFinalPrice` is server-rendered; `calculatedFinalPrice` recomputes on configurable-option or qty change; `calculatedFinalPriceWithCustomOptions` adds custom-option prices. The price box listens to `update-prices-<id>`, `update-qty-<id>`, `update-custom-option-active`, `update-custom-option-prices`.

Custom-option logic lives in `Magento_Catalog::product/view/options/options.phtml`, listens to `update-product-final-price`, and calls `calculateOptionPrices()` (also on init via `$nextTick`). Child options are tracked as `parent_child` keys (`activeCustomOptions: ['1','3_1','3_2']`). Percent-type options are resolved against `productFinalPrice` using each element's `data-price-amount` / `data-price-type`.

<https://docs.hyva.io/hyva-themes/writing-code/pdp-pricing-logic.html>

## Form validation

Hyvä relies primarily on **HTML5 input types and the browser constraint validation API** (less JS, better a11y). Choosing the right `type` also changes the mobile keyboard. Supported types with useful constraint attributes: `email`/`search`/`tel` (`pattern`), `url`, `number`/`range`/`datetime-local`/`month`/`time`/`week` (`min`, `max`, `step`), `color`; `required` applies to all.

Tailwind exposes state variants (**JIT only**): `invalid:`, `valid:`, `in-range:`, `out-of-range:`, `required:`, `placeholder-shown:`, `indeterminate:`.

To avoid fields showing invalid before interaction, add constraints with JS at the right moment, then call `form.reportValidity()` / `form.checkValidity()` on submit, or use `:required="$refs.amount.value.length > 0"`. Custom messages: `element.setCustomValidity(msg)`; clear with `setCustomValidity('')`.

### The JS form validation library (since 1.1.14)

```xml
<update handle="hyva_form_validation"/>
```

```html
<form x-data="hyva.formValidation($el)" @submit="onSubmit">
    <div class="field field-reserved">
        <input name="example" data-validate='{"required": true}' @change="onChange">
    </div>
</form>
```

`novalidate` is added automatically and the default submit is prevented until all fields pass. Wrap inputs in `field field-reserved` to reserve space for the message and avoid layout shift (generated automatically if missing). `data-validate` is parsed with `JSON.parse()` — strict JSON only. Only use `$el` on the component root (Alpine v2 compatibility).

Built-in validators: `required`, `minlength`, `maxlength`, `pattern` (1.1.21/1.2.1+), `min`, `max`, `step` (all via the browser constraint API), `email` and `password` (Magento regexes), `equalTo` (`data-validate='{"equalTo": "password"}'`). Override a message with `data-msg-<validator>` (`%0` = the rule argument).

Radio/checkbox groups are tracked by identical `name`; rules from different inputs in a group are combined, and conflicting rules resolve to the last one.

Add rules with `hyva.formValidation.addRule(name, fn)`; the callback gets `(value, options, field, context)` and returns `true`, a message string, `{type: 'html', content: '…'}`, or a Promise resolving to one of those (async validation). Auto-apply by input type or attribute:

```js
hyva.formValidation.setInputTypeRuleName('url')
hyva.formValidation.setInputAttributeRuleName('accept', 'validate-file-types')
```

Cross-field rules use `context.validateField(context.fields['country'])` and `context.fields['country'].element.value`. Non-error messages use `context.addMessages(field, cssClass, messages)` / `context.removeMessages(field, cssClass)`. Custom submit: call `this.validate().then(...).catch(invalid => invalid[0].focus())`.

Options (second argument), defaults: `fieldWrapperClassName: "field field-reserved"`, `messagesWrapperClassName: "messages"`, `validClassName: "field-success"`, `invalidClassName: "field-error"`.

In CMS content the layout handle cannot be used — render the library with the block directive instead:

```
{{block class="Magento\Framework\View\Element\Template" template="Hyva_Theme::page/js/advanced-form-validation.phtml"}}
```

<https://docs.hyva.io/hyva-themes/writing-code/form-validation/index.html>, <https://docs.hyva.io/hyva-themes/writing-code/form-validation/javascript-form-validation.html>, <https://docs.hyva.io/hyva-themes/writing-code/form-validation/html5-input-types.html>, <https://docs.hyva.io/hyva-themes/writing-code/form-validation/state-dependent-input-styles.html>, <https://docs.hyva.io/hyva-themes/writing-code/form-validation/triggering-native-validation-messages-with-javascript.html>, <https://docs.hyva.io/hyva-themes/writing-code/form-validation/javascript-form-validation-in-cms-content.html>

## reCAPTCHA in custom forms

Only v3 invisible, v2 invisible and v2 checkbox are supported, and the integration must be fully configured (site + secret key) at `Security > Google reCAPTCHA Storefront`. Legacy captcha must be off.

1. Move the matching validation block into your form block using the alias `recaptcha_validation`:

```xml
<move element="recaptcha_validation" destination="my_form_block" as="recaptcha_validation"/>
<!-- or recaptcha_validation_invisible / recaptcha_validation_recaptcha -->
```

The parent form block **name may only contain `A-Z a-z / _`** — `recaptcha.js` derives the action name from it and otherwise errors with `Invalid action name, may only include "A-Z a-z/_"`.

2. Render the hidden field (`recaptcha_input_field`, `recaptcha_input_field_invisible`, or `recaptcha_input_field_recaptcha`) plus, for v3, `ReCaptcha::RECAPTCHA_LEGAL_NOTICE_BLOCK`.
3. Render the validation child block inside your Alpine submit method. **The form element must be in a variable named `$form`** and errors land on `this.errors`:

```html
<script>
  function initMyForm() {
    return {
      submitForm() {
        const $form = document.getElementById('my-form'); // do not rename $form
        <?= $block->getChildHtml('recaptcha_validation'); ?>
        if (this.errors === 0) { $form.submit(); }
      }
    }
  }
</script>
```

Block declarations to copy from: `Magento_ReCaptchaFrontendUi/layout/default.xml`.

<https://docs.hyva.io/hyva-themes/view-utilities/recaptcha-in-custom-forms.html>

## Checkout button not working

Clicking the cart/mini-cart checkout button dispatches `toggle-authentication`, which is handled by the `authentication-popup` block (`Magento_Customer::account/authentication-popup.phtml`, declared in `Magento_Customer/layout/default.xml` and rendered by `Magento_Theme/templates/html/header.phtml`). If the button does nothing, a theme override of `header.phtml` is usually missing:

```php
<?= $block->getChildHtml('authentication-popup'); ?>
```

<https://docs.hyva.io/hyva-themes/faqs/checkout-button-not-working.html>

## Customizing GraphQL queries

Hyvä uses GraphQL in places (e.g. the GraphQL cart). Queries are wrapped in `GraphqlViewModel::query($queryIdentifier, $query, $eventParams)` (from the open-source `hyva-themes/magento2-graphql-view-model`), which dispatches `hyva_graphql_render_before_<queryIdentifier>`. Edit them in an observer rather than overriding templates or view models:

```php
$gqlEditor = new GraphqlQueryEditor();
$queryString = $event->getData('gql_container')->getData('query');
$queryString = $gqlEditor->addFieldIn($queryString, ['products','items','products','small_image'], 'label url_webp');
$event->getData('gql_container')->setData('query', $queryString);
```

`\Hyva\GraphqlViewModel\Model\GraphqlQueryEditor` has `addFieldIn(string $query, array $path, string $field)` and `addArgumentIn(string $query, array $path, string $key, $value)`; both are **idempotent** and return the modified query string. Inline fragments work as path segments (`'... on ConfigurableCartItem'`).

If GraphQL complains `Field "sku" is not defined by type ProductAttributeFilterInput`, the attribute is not filterable: set **Use in Layered Navigation** to Filterable (with/no results), or set both **Use in Search** and **Visible in Advanced Search** to Yes.

<https://docs.hyva.io/hyva-themes/writing-code/customizing-graphql.html>, <https://docs.hyva.io/hyva-themes/faqs/adding-attributes-to-filter-product-data-in-graqhql.html>

## Rendering cart items

The **PHP cart** (default since 1.1.15) works like Luma — standard PHP item renderers. The **GraphQL cart** renders items client-side with Alpine, so PHP item renderers do not apply. Options there: customize the GraphQL query via observers; add a field to `CartItemInterface` in your `schema.graphqls` with a resolver (plugins on GraphQL resolvers belong in `etc/graphql/di.xml`); or add a child block to the `additional.cart.item.options` container, which is rendered inside the item loop with the GraphQL data available as `item`:

```html
<template x-if="item.my_custom_options && Object.keys(item.my_custom_options).length > 0">
    <template x-for="option in item.my_custom_options">
        <span x-text="option.label"></span>
    </template>
</template>
```

Overriding `Magento_Checkout/templates/cart/items.phtml` works but is a large file and expensive to maintain across upgrades.

<https://docs.hyva.io/hyva-themes/view-utilities/rendering-cart-page-items.html>

## Accessibility

The Hyvä Theme implements WCAG 2.1 level AA features since release 1.3.0: keyboard support, AT support, colour/spacing/font choices, responsiveness, alternative content. Guidance for keeping it that way:

- Use semantic HTML and correctly ordered landmarks/headings; buttons and links instead of clickable `div`/`span`.
- Icon-only buttons/links need `aria-label`, `aria-labelledby`, or visually hidden text via the `sr-only` class — and it must be translated.
- Every focusable element needs a visible focus outline; focus order must be logical. Move focus into a modal on open and back to the trigger on close — the Hyvä modal library does this automatically, other overlays (sliders) do not. `hyva.trapFocus` / `hyva.releaseFocus` exist for that (1.2.6+).
- Use `aria-expanded` on collapsible triggers (see `Magento_Customer/templates/header/customer-menu.phtml`).
- Use `aria-live` on regions updated client-side (see `Magento_Bundle/templates/catalog/product/view/price.phtml`).

Test with the axe DevTools extension, keyboard-only shopping, the DevTools accessibility tree, a screen reader (VoiceOver/NVDA/ChromeVox) and ANDI. A Hyvä-built store is not automatically WCAG AA compliant — content (plain language, alt text, transcripts, captions) and every customization must be checked too.

<https://docs.hyva.io/hyva-themes/building-your-theme/accessibility.html>
