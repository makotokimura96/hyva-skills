# Upgrading Hyvä Enterprise - process and recurring patterns

## Procedure

1. Read the version-specific upgrade notes for each Enterprise package being
   updated (Adobe Commerce / B2B / Live Search / Product Recs / Data Connection,
   for Hyvä Theme *and* Hyvä Checkout separately). Backward-incompatible changes
   are listed there.
2. Read the changelog for the new version.
3. Update the packages.
4. Apply the required changes to files customised in the project.

```bash
# Hyvä Theme side
composer update --with-dependencies hyva-themes/magento2-hyva-enterprise-commerce   # only when used standalone
composer update --with-dependencies hyva-themes/magento2-hyva-enterprise-b2b        # also updates the base commerce packages
composer update --with-dependencies hyva-themes/magento2-hyva-enterprise-sensei     # deprecated metapackage

# Hyvä Checkout side
composer update --with-dependencies hyva-themes/magento2-hyva-enterprise-commerce-checkout
composer update --with-dependencies hyva-themes/magento2-hyva-enterprise-b2b-checkout

# pin an exact version
composer update --with-dependencies <package-name>:x.y.z
```

Then `bin/magento setup:upgrade` and rebuild Tailwind (`npm run build` in the
theme's `web/tailwind` directory, or whatever target the project wraps it in).

## The default-theme trap

Enterprise packages carry version constraints on the **theme module** but *not* on
the **default theme**, even though some Enterprise features need default-theme
template changes to work or display correctly. After upgrading, find those changes
by filtering issues labelled `Enterprise` in the **Default Theme** repository (the
issues link to their merge requests and usually name the milestone matching a
default-theme release), then port them into the child theme. The same filter works
on the **Theme Module** repository.

<https://docs.hyva.io/hyva-enterprise/upgrading/index.html>

## Changelog map

| Product | Changelog |
|---|---|
| Adobe Commerce - Hyvä Theme | `upgrading/commerce/changelog-theme.html` |
| Adobe Commerce - Hyvä Checkout | `upgrading/commerce/changelog-checkout.html` |
| B2B - Hyvä Theme | `upgrading/b2b/changelog-theme.html` |
| B2B - Hyvä Checkout | `upgrading/b2b/changelog-checkout.html` |
| Live Search | `upgrading/live-search/changelog.html` |
| Product Recommendations | `upgrading/product-recommendations/changelog.html` |
| Data Connection | `upgrading/data-connection/changelog.html` |
| Adobe Sensei (deprecated combined) | `upgrading/sensei/changelog.html` |
| Security fixes across all products | `upgrading/security-changelog.html` |

Changelogs list the metapackage version and, under it, each `Hyva_Magento*` module
version - module versions and metapackage versions do **not** match. Do not assume
`Hyva_MagentoCompany` 1.1.1 means B2B metapackage 1.1.1 even when they coincide.

## Recurring migration themes

These are the patterns that repeat across releases; expect them on any upgrade.

**Platform capability waves.** Whole metapackages get one capability at a time,
module by module: CSP compatibility (Commerce theme 0.6.0, Commerce/B2B checkout
0.2.0, B2B theme 1.0.4, Live Search / Product Recs / Data Connection 1.0.0),
non-CSP theme compatibility (Commerce 0.6.1), **Tailwind 4 support** (Commerce
0.7.0, B2B theme 1.0.6, Live Search 1.0.2, Product Recs 1.0.1, Data Connection
1.0.4), AlpineCSP support for Sensei templates, PHP 8.4 (B2B 1.0.5) and PHP 8.5
(`Hyva_MagentoVersionsCms` 1.0.1) compatibility. When a project is mid-migration,
check that the Enterprise version actually carries the wave you need.

**Adobe SDK version bumps.** Data Services tracks Adobe's Storefront Events and
Storefront Event Collector SDKs (1.8.1 -> 1.14.0 -> 1.15.0 -> 1.16.0 -> 1.17.0);
Product Recommendations tracks the recommendations SDK (2.0.7 -> 2.0.9). These are
the usual cause of event-payload differences after an upgrade.

**Consolidation into base modules.** Duplicated logic keeps moving out of Enterprise
into `Hyva_Theme` / `Hyva_Checkout`, which breaks references:

- Form validation layouts/templates moved from `Hyva_Enterprise` to `Hyva_Theme`
  (Commerce theme 1.0.0). Removed: `Hyva_Enterprise::hyva_form_validation_date.xml`,
  `..._files.xml`, `..._input_additional.xml`, `..._min_max.xml` and
  `Hyva_Enterprise::form/date-validation.phtml`, `form/file-validation.phtml`,
  `form/input-additional-validation.phtml`, `form/min-max-validation.phtml`. Layout
  blocks `date.validation`, `file.upload.validation`,
  `additional.input.validation`, `min.max.validation` must be repointed to the
  `Hyva_Theme` equivalents. The JS rules themselves (`dateFromTo`, `minMax`,
  `file-type`, `file-max-size`, `image-max-dimensions`, `url`) are unchanged.
- Checkout address-attribute admin handling moved to `Hyva_Checkout`
  (`\Hyva\Checkout\Model\Config\DispensableAttributesProvider` +
  `\Hyva\Checkout\Block\Adminhtml\System\Config\HyvaThemesCheckout`);
  `\Hyva\EnterpriseCheckout\ViewModel\Adminhtml\System\Config\AddressAttributes` is
  kept but `@deprecated`. The EE dispensable attributes
  (`reward_warning_notification`, `reward_update_notification`) are now registered
  through the base module's `di.xml`.
- The `hyva-themes/magento2-ee-magento-google-tag-manager` dependency was dropped
  from the Commerce checkout module's `composer.json`.

**Magento helpers -> Hyvä view models.** Templates calling `$this->helper(...)` are
migrated to dedicated view models, and **child themes overriding those templates
break**. Examples from Commerce theme 1.0.0: `\Hyva\MagentoReward\ViewModel\Reward`
(replaces `\Magento\Reward\Helper\Data` in `customer/reward/info.phtml` and
`tooltip.phtml`); `\Hyva\MagentoRma\ViewModel\RmaTracking` plus a new
`\Hyva\MagentoRma\ViewModel\CreateRma::getReturnCreateUrl(Order $order)` (replacing
`\Magento\Rma\Helper\Data` in `order/button.phtml` and `return/tracking.phtml`) -
`CreateRma` now requires `\Magento\Framework\UrlInterface` and
`\Magento\Customer\Model\Session` constructor arguments, so `di.xml` overrides and
subclasses must supply them; `Hyva_MagentoAdvancedCheckout::cart/item/failed.phtml`
now uses `\Hyva\Theme\ViewModel\ProductPrice`. Same pattern in Live Search, where
`Hyva\MagentoLiveSearch\ViewModel\ProductData` was deprecated for
`Hyva\Theme\ViewModel\Image` (needs theme module 1.3.10).

**Per-product inline Alpine components -> one shared component.** Gift Card replaced
its per-product `initPrice<productId>()` inline component with a single shared
`initGiftCardPrice` component in `Hyva_MagentoGiftCard::js/gift-card-price.phtml`,
registered as block `giftcard.price.js` in `before.body.end` via
`hyva_catalog_product_view_type_giftcard.xml`. State moves to `data-*` attributes
(`data-product-id`, `data-display-tax`, `data-initial-final-price`,
`data-initial-tier-prices`, `data-regular-price`, `data-is-saleable`); the window
event contract is preserved (`update-prices-<productId>`, `update-qty-<productId>`,
`update-custom-option-active`, `update-custom-option-prices` in;
`update-product-final-price` out). Code referencing the old component breaks.

**CSP registration correctness.** `\Hyva\Theme\ViewModel\HyvaCsp::registerInlineScript()`
returns `void` and echoes internally, so it must be called as a statement, not a
short echo:

```php
<?php $hyvaCsp->registerInlineScript(); ?>   // correct
<?= $hyvaCsp->registerInlineScript(); ?>     // was wrong in several EE templates
```

Affected templates were in `Hyva_MagentoCustomerBalance`, `Hyva_MagentoGiftWrapping`,
`Hyva_MagentoGiftCard` and `Hyva_MagentoReward`.

**Block renames to avoid collisions.** `Hyva_MagentoMultipleWishlist` renamed its
price-render block in `hyva_wishlist_index_index.xml` to
`multiple.product.price.render.wishlist` with `as="product.price.render.wishlist"`
(fixing missing wishlist item prices when `multiple_enabled=0`). Layout
customisations targeting `product.price.render.wishlist` by name in the
multiple-wishlist context must use the new name; the `as` alias keeps
template-level lookups working.

**Escaping and translation hygiene.** Releases routinely fix escaper choice
(`escapeJs()` in JS context, `escapeHtml()` for label text, `escapeHtmlAttr()` for
attributes), add missing `translate="true"` on XML arguments, and add phrases to
`src/i18n/en_US.csv`. With more than one store locale, every such batch means new
untranslated strings until every non-`en_US` dictionary is updated.

**Config gating.** Features get gated by system config, e.g. the RMA Return button
is now `ifconfig="sales/magento_rma/enabled"` across all sales/RMA order layouts.

**Pre-release cleanups.** The 1.0.0 releases (B2B theme, B2B checkout, Commerce
theme, Commerce checkout) removed all code deprecated during Early Access. If
upgrading from anything below the documented starting point (`0.5.0` for B2B theme,
`0.7.0` for Commerce theme, `0.2.0` for the checkout packages), diff the module
across major pre-release versions yourself - some code was removed without ever
being deprecated.

<https://docs.hyva.io/hyva-enterprise/upgrading/commerce/theme-upgrading-to-1.0.0.html>
<https://docs.hyva.io/hyva-enterprise/upgrading/commerce/checkout-upgrading-to-1.0.0.html>
<https://docs.hyva.io/hyva-enterprise/upgrading/b2b/theme-upgrading-to-1.0.0.html>

## Security changelog

One page lists security-relevant fixes for all Enterprise products. As of the docs
read, the only entry is **B2B Theme 1.0.3 (2025-02-07)**: the company structure tree
let users without permission *initiate* a drag/reorder in the frontend UI.
Server-side authorization was working and rejected the action - impact was
frontend-only UX, severity low, affected `>= 1.0.0, < 1.0.3`, no data at risk.

<https://docs.hyva.io/hyva-enterprise/upgrading/security-changelog.html>
