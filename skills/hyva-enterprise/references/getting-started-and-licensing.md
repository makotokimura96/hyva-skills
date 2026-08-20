# Hyvä Enterprise - licensing, requirements, installation

## Licensing and access

- Hyvä Enterprise is a **stand-alone commercial product**, sold as one license via
  a **yearly subscription**, currently available to Hyvä Themes licensees only.
- It is split into compatibility offerings for **Hyvä Themes** and for **Hyvä Checkout**,
  each covering three areas: Adobe Commerce base, B2B (B2B Suite), Adobe Sensei
  (Live Search + Product Recommendations).
- A separate Hyvä Enterprise license is required **in addition** to Hyvä Commerce
  and/or Hyvä Checkout licenses. Checkout packages additionally require a Hyvä
  Checkout license.
- Packages are delivered through the Hyvä packagist.com license key; source repos
  live in the GitLab group `gitlab.hyva.io/hyva-enterprise/*` and are only reachable
  with a purchased license.
- Support/feedback: bugs and MRs go on the affected module repo in GitLab (MRs need
  a linked issue); general help in the `#hyva-enterprise` Slack channel.
- Feature status is tracked publicly in the Feature Matrix and the
  `gitlab.hyva.io/hyva-public/enterprise-compatibility-tracker` boards.
- The Enterprise documentation is explicitly flagged as still being completed.

<https://docs.hyva.io/hyva-enterprise/index.html>

## Naming history: "Sensei" -> "Services"

Originally three sub-groups existed (Adobe Commerce, B2B, Sensei), and "Sensei"
bundled Live Search *and* Product Recommendations in one metapackage. Hyvä split
them because (a) Adobe ships independent metapackages and merchants wanted to
install only one, and (b) newer Adobe SaaS services (Catalog Services, Data
Connection) are not Sensei-powered. "Sensei" was renamed to "Services" everywhere
**except GitLab group URLs and composer paths** (so composer names still read
`.../sensei/...` and `magento2-ee-*`), keeping BC. All of them share
`Magento_DataServices` as their base.

<https://docs.hyva.io/hyva-enterprise/index.html>

## System requirements

Install only the prerequisites for features actually used.

Core (all installations):

- **Adobe Commerce** 2.4.4+; implementation targets **2.4.6**. 2.4.4/2.4.5 are not
  fully tested. B2B currently requires 2.4.6+.
- **Hyvä Themes** 1.2.9, 1.3.10 or higher (older Enterprise versions support earlier 1.3.x).
- **Hyvä Checkout** 1.3.0+ - only for checkout features (older versions supported 1.1.x/1.2.x).
- **PHP** 8.0+.

Per feature:

| Feature | Required Adobe package(s) |
|---|---|
| B2B Suite | `magento/extension-b2b` >= 1.4.0 (1.3.x support under review) |
| Live Search | `magento/live-search` >= 3.0.0 |
| Product Recommendations | `magento/product-recommendations` >= 5.0.0, `magento/module-page-builder-product-recommendations` >= 2.0.0, `magento/module-visual-product-recommendations` >= 2.0.0 |
| Data Connection (Adobe Experience Platform) | `magento/module-experience-connector` |

Configure the Adobe service (Adobe's own install guides) **before** installing the
Hyvä compatibility metapackage.

<https://docs.hyva.io/hyva-enterprise/getting-started/index.html>

## Metapackages - Hyvä Themes side

```bash
# Adobe Commerce base features (GTM, customer attributes, gift card, RMA, reward, ...)
composer require hyva-themes/magento2-hyva-enterprise-commerce
bin/magento setup:upgrade

# B2B (company accounts, shared catalogs, quote templates, purchase orders)
# depends on the base commerce metapackage
composer require hyva-themes/magento2-hyva-enterprise-b2b
bin/magento setup:upgrade

# Data Connection (Adobe Experience Platform event tracking)
composer require hyva-themes/magento2-hyva-enterprise-data-connection
bin/magento setup:upgrade

# Live Search
composer require hyva-themes/magento2-hyva-enterprise-live-search
bin/magento setup:upgrade

# Product Recommendations
composer require hyva-themes/magento2-hyva-enterprise-product-recommendations
bin/magento setup:upgrade
```

**DEPRECATED** - the combined Sensei metapackage. Use the three separate
metapackages instead:

```bash
composer require hyva-themes/magento2-hyva-enterprise-sensei   # deprecated
```

B2B and Sensei-family metapackages already require the base Adobe Commerce
metapackage, so do not require it separately.

## Metapackages - Hyvä Checkout side

```bash
# Enterprise checkout features (custom customer attributes, store credit,
# reward points, gift wrapping)
composer require hyva-themes/magento2-hyva-enterprise-commerce-checkout
bin/magento setup:upgrade

# B2B checkout (company checkout, purchase orders, quote templates);
# depends on the commerce-checkout metapackage
composer require hyva-themes/magento2-hyva-enterprise-b2b-checkout
bin/magento setup:upgrade
```

Sensei support *inside* checkout is under review; Sensei/Data Services event
tracking in checkout is handled by the theme-level packages (a single
`checkout_index_index` layout file adding shared Data Services templates).

Underlying module composer names (installable individually) include
`hyva-themes/magento2-ee-magento-data-services`,
`hyva-themes/magento2-ee-magento-live-search`,
`hyva-themes/magento2-ee-magento-product-recommendations`,
`hyva-themes/magento2-ee-magento-page-builder-product-recommendations`,
`hyva-themes/magento2-ee-hyva-enterprise-checkout` and
`hyva-themes/magento2-ee-hyva-enterprise-checkout-b2b`.

<https://docs.hyva.io/hyva-enterprise/getting-started/index.html>

## Rebuild Tailwind after every install/upgrade

Compatibility modules ship their own Tailwind sources; without a rebuild their
classes are missing from `styles.css`.

```bash
npm --prefix vendor/hyva-themes/magento2-default-theme/web/tailwind/ ci --ignore-scripts
npm --prefix vendor/hyva-themes/magento2-default-theme/web/tailwind/ run build
```

Point `--prefix` at the child theme's `web/tailwind` folder when one exists. On
many projects wrap the same npm build plus a `cache:flush` in a `make build` target.

## Customer Custom Attributes at checkout

With Adobe Commerce Customer Custom Attributes, choose which attributes appear on
checkout address forms under
**Stores > Configuration > Hyvä Themes > Checkout > Components**, in the
shipping/billing address groups.

Customer Custom Attributes is **not yet fully supported at checkout** - check the
compatibility tracker board for current status before promising it.

<https://docs.hyva.io/hyva-enterprise/getting-started/index.html>

## Extending and contributing

Extending, customising and contributing follows the same rules as ordinary Hyvä
compatibility modules (see the Hyvä Themes "Compatibility Modules" guide). Hyvä
builds Enterprise in-house and is not actively seeking contributions, but license
holders can discuss feature contributions in `#hyva-enterprise`.
