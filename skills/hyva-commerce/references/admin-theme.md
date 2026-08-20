# Admin Theme

A modern, refreshed look and feel for the Magento admin panel, based on the
<a href="https://github.com/mage-os-lab/theme-adminhtml-m137">Mage-OS M137 Admin Theme</a>. Package
`hyva-themes/commerce-theme-adminhtml`, with the supporting module
`hyva-themes/commerce-module-admin-theme`.
<https://docs.hyva.io/hyva-commerce/features/admin-theme/index.html>

## Install

```bash
composer require hyva-themes/commerce-theme-adminhtml
bin/magento setup:upgrade
# then clear the browser cache
```

GitLab (dev environments only) needs the `commerce-module-commerce` and `commerce-theme-adminhtml`
repositories configured, then
`composer require --prefer-source 'hyva-themes/commerce-theme-adminhtml:dev-main'`.

After installation the theme is **enabled by default**, unless the Mage-OS M137 Admin Theme was
previously installed and its active-theme configuration had been saved manually. No further setup
steps.
<https://docs.hyva.io/hyva-commerce/features/admin-theme/installation.html>

## Choosing the active admin theme

`Stores → Settings → Configuration → Advanced → Admin → Admin Design → Active Admin Theme`, then save.
No code change or deployment needed to switch.

**In production mode, make sure static content is generated for all admin themes** as part of the
deployment process. To generate static files for only one admin theme, it is recommended to
<a href="https://experienceleague.adobe.com/en/docs/commerce-operations/configuration-guide/cli/configuration-management/set-configuration-values">lock the configuration value</a>
so admin users cannot change it.

## Admin branding (logos)

`Stores → Settings → Configuration → Advanced → Admin → Admin Branding → Active Admin Branding`.

Available **without installing the admin theme** — custom logos work with any Hyvä Commerce
functionality, even when the Hyvä admin theme is not enabled or installed. Three options:

1. **Current Admin Theme** — use the active admin theme's own logos (the Hyvä Commerce logo when the
   Hyvä theme is active).
2. **Default Magento / Adobe Commerce** — the stock logos regardless of the active theme.
3. **Custom** — separate uploads for the login screen logo, the above-menu logo and the admin favicon.
   Any field left empty falls back to the active admin theme's logo.

Three logo slots are covered: the admin login screen, above the menu on all admin pages, and the admin
favicon. Save the configuration when done.
<https://docs.hyva.io/hyva-commerce/features/admin-theme/configuration.html>

## Compatibility and customisation

- **The admin theme is optional.** Skip installing it, or switch to another admin theme in
  configuration.
- **Tech stack is unchanged** from the default Magento and Mage-OS admin themes: LESS, RequireJS,
  Knockout and all the other default libraries and approaches. This was maintained deliberately to keep
  existing third-party admin extensions and customisations working. Worst case is minimal styling bugs.
- **Custom or third-party modules keep working** for the same reason.
- **To customise**: logos via configuration; for styling, layout and other code changes, treat it like
  any other default Magento theme. Recommended approach is a **new child admin theme with the Hyvä
  theme as parent**, then set the child as the active theme in configuration.

<https://docs.hyva.io/hyva-commerce/features/admin-theme/faqs.html>

## Related base-module behaviour

The `Hyva_Commerce` base module (`hyva-themes/commerce-module-commerce`) owns admin branding, and its
changelog documents a few facts worth knowing when touching admin header templates:

- An `is_admin_login_page` **layout XML argument** manages selection of the default vs login logo on an
  admin page, and the login logo is used on all pages including the `admin_login` handle.
- `\Hyva\Commerce\ViewModel\AdminBranding::isAdminLoginPage` is **deprecated** in favour of that
  argument (it was extended to cover 2FA pages for backwards compatibility). The
  `Hyva_Commerce::page/header.phtml` template uses the layout argument.
- Alpine.js in the admin panel follows the same loading logic as the frontend and is loaded via the
  `hyva_adminhtml_alpine` layout handle; `hyva_adminhtml_alpine_csp` remains for backwards
  compatibility.
- The module also ships the Hyvä Commerce system-config tab, the user-settings interface used by other
  Hyvä Commerce features, and Hyvä Enterprise branding support for the admin theme.

<https://docs.hyva.io/hyva-commerce/upgrading/changelog-commerce-module.html>
