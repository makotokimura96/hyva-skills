---
name: hyva-enterprise
description: Covers Hyvä Enterprise, the separately licensed set of Hyvä compatibility modules for Adobe Commerce - the B2B suite (company accounts, negotiable quotes, requisition lists, purchase orders, quick order, company credit), Adobe Commerce-only features (gift card, gift wrapping, reward points, RMA, multiple wishlist, customer balance, customer custom attributes, versions CMS), Adobe Commerce Google Tag Manager, the Adobe SaaS services (Live Search incl. the React PLP Widget, Product Recommendations, Data Services / Data Connection to Adobe Experience Platform) and the Adobe Edge Delivery Services side-by-side architecture. Use this skill when installing or upgrading a hyva-themes/magento2-hyva-enterprise-* metapackage, wiring B2B or purchase-order flows into Hyvä Checkout, debugging the GTM dataLayer or Sensei/Data Services event tracking, styling or disabling the Live Search PLP Widget, customising a Hyva_Magento* Enterprise module or its view models, or answering "does Hyvä support this Adobe Commerce feature / what license do I need"; keywords Hyvä Enterprise, Hyva_Enterprise, Hyva_EnterpriseCheckoutB2b, magento/extension-b2b, live-search, product-recommendations, data-connection, experience-connector, EDS.
---

# Hyvä Enterprise

Hyvä Enterprise is **not** part of the Hyvä theme. It is a stand-alone commercial
product (yearly subscription, own license, own GitLab group `gitlab.hyva.io/hyva-enterprise/*`)
that makes **Adobe Commerce** enterprise functionality work on a Hyvä storefront
and in Hyvä Checkout. Access to the repos comes only with a purchased license.
<https://docs.hyva.io/hyva-enterprise/index.html>

**Edition gate - check this before advising anything.** Every Hyvä Enterprise
feature depends on an Adobe Commerce module (`magento/extension-b2b`,
`magento/live-search`, `magento/product-recommendations`,
`magento/module-experience-connector`, GiftCard/RMA/Reward, …). On **Magento Open
Source none of those Adobe packages exist**, so Hyvä Enterprise is neither
installable nor relevant there. Establish which edition the project runs first:
on Open Source, treat an Enterprise request as a scoping question and answer it
with the licensing facts below.

Run Magento CLI through your local stack's wrapper if containerised, e.g.
`bin/magento setup:upgrade`, and Tailwind lives at
`vendor/hyva-themes/magento2-default-theme/web/tailwind/` (`make build` / `make watch`).
Store locales are `fr_FR` and `en_US`, so every Enterprise `i18n/en_US.csv`
phrase added by an upgrade needs a `fr_FR` counterpart.

## References

- `references/getting-started-and-licensing.md` - licensing, system requirements per feature, all metapackages and their `composer require` lines, deprecated Sensei metapackage, Tailwind rebuild, checkout customer-custom-attribute config.
- `references/b2b.md` - B2B module list, Luma-vs-Hyvä architectural differences, company permissions API, `is_company` condition, company checkout layouts, purchase-order checkout flow.
- `references/adobe-commerce-integration.md` - Commerce-only feature modules, the switcher component, the full GTM dataLayer integration (blocks, templates, layout arguments, view-model plugins), Live Search + PLP Widget, Product Recommendations, Data Services / Data Connection events.
- `references/eds.md` - Adobe Edge Delivery Services side-by-side architecture and what is shared between AEM/EDS and Adobe Commerce pages.
- `references/upgrading-patterns.md` - upgrade procedure, per-product changelog map, and the recurring migration themes (CSP, Tailwind 4, helpers to view models, consolidation into base modules, SDK bumps).

## Pitfalls

- Never claim Hyvä Enterprise works on Magento Open Source; each feature requires the matching Adobe Commerce module and its own Adobe entitlement.
- Install the Adobe module (B2B, Live Search, Product Recs, Experience Connector) and configure the service *before* the Hyvä compatibility metapackage.
- Do not install the base `magento2-hyva-enterprise-commerce` package alongside B2B or Sensei metapackages - they already depend on it.
- Stop using `hyva-themes/magento2-hyva-enterprise-sensei`; it is deprecated in favour of separate `live-search`, `product-recommendations` and `data-connection` metapackages.
- Rebuild Tailwind (`npm ... ci --ignore-scripts` then `run build`) after every Enterprise install/upgrade or compatibility-module CSS is missing.
- Enterprise metapackages pin the **theme module** version but not the default theme, so read the `Enterprise`-labelled issues in the default-theme repo and port those template changes into the child theme by hand.
- Purchase-order integration only alters **online** payment methods (`MethodInterface::isOffline()`); do not expect changes for offline methods.
- The `ee_default_purchase_order` checkout is deliberately hidden from the Hyvä Checkout admin list - never expose or reuse it for normal orders.
- Customise GTM data through plugins on `Hyva\MagentoGoogleTagManager\ViewModel\GoogleTagManager::get*ItemData()` and layout `<argument>` overrides, not by copying templates.
- An empty or missing `banner_selector`, `button_selector` or `impression_list` layout argument silently stops the GTM script from rendering at all.
- Every page must emit a `page-view` Data Services event or Adobe's ML jobs and Live Search / Product Recs dashboards report nothing.
- Enabling the Live Search PLP Widget hands the whole product list to Adobe's React app: styling moves to CSS selectors, performance and CLS degrade, and functional changes require forking Adobe's app.
- Check company permissions with `Hyva\MagentoCompany\ViewModel\CompanyPermissions::isAllowed()` on non-cached pages and the `company-permissions-loaded` JS event on FPC pages - never render B2B UI unguarded.
- Read the version-specific "Upgrading to x.y.z" page before bumping; several releases moved templates, layout handles and validation rules into the base `Hyva_Theme` / `Hyva_Checkout` modules.
