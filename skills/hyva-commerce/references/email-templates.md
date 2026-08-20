# Email & Newsletter Templates (beta)

Brings the Hyvä CMS Liveview Editor to Magento transactional emails and newsletter campaigns, built
from email-safe components instead of hand-edited email HTML. Package
`hyva-themes/commerce-module-email-templates`, module `Hyva_EmailTemplates`.

**Beta.** `0.1.0` requires Hyvä CMS `1.3.0-beta1` as its base. Classes, plugins, database schema and
component conventions may change in backwards-incompatible ways before GA; not recommended for
production. **Requires Hyvä CMS** installed and enabled.
<https://docs.hyva.io/hyva-commerce/features/email-templates/index.html>

Two content types sharing one editor, one component set and one configuration section:

- **Email Templates** — Magento transactional emails (order confirmation, invoice, shipment, credit
  memo, password reset, customer account emails, any custom template).
- **Newsletter Templates** — Magento newsletter campaigns, sent through the standard newsletter queue.

Key capabilities: visual editing in the Liveview Editor; email-safe components rendering as
table-based HTML with inlined CSS; ready-made presets for the common transactional emails; dynamic
content through Magento directives (`{{var order_data.customer_name}}`) inserted from a variable
picker; live preview with realistic dummy data including a real order; email client simulation and
health checks; test sends; version history.

## Install

```bash
composer require hyva-themes/commerce-module-email-templates
bin/magento setup:upgrade
```

Follow the beta notes for the exact constraint (`hyva-themes/commerce-module-cms:1.3.0-beta1`, aliased
when the metapackage is installed). `setup:upgrade` creates three tables:
`hyva_commerce_email_template` and `hyva_commerce_newsletter_template` (per-template settings: enabled
flag, draft content, preheader) and `hyva_commerce_email_template_version_history` (shared history for
both types).

Then in `Stores → Settings → Configuration → Hyvä Commerce → Email Templates`:

1. Set **Enable for Email Templates** to `Yes` (and **Enable for Newsletter Templates** in its own
   group, if newsletters are used).
2. Press **Create Email Templates** to generate Hyvä versions of the standard transactional emails.
3. Press **Map Templates to Configuration** to point Magento's sales/customer email settings at them.

<https://docs.hyva.io/hyva-commerce/features/email-templates/installation.html>

## Configuration

All under `Stores → Settings → Configuration → Hyvä Commerce → Email Templates`. Everything depends on
Hyvä CMS itself being enabled (`Hyvä CMS → General → Enable Hyvä CMS`).

**Email Templates group**

| Setting | Effect |
|---|---|
| Enable for Email Templates | Master switch for the Hyvä editor on transactional templates |
| Email Templates Enabled by default | New email templates get the Hyvä editor automatically |
| Include Header | Wraps every Hyvä email with a shared header |
| Header Template | Which Liveview-enabled template to use as that header (`0` = built-in default) |
| Include Footer | Wraps every Hyvä email with a shared footer |
| Footer Template | Which Liveview-enabled template to use as that footer (`0` = built-in default) |
| Show Product Images in Order Items | Adds a product thumbnail column to the Order Items component |
| Default Preheader Text | Fallback inbox-preview snippet; supports variables like `{{var store.frontend_name}}`; keep under ~90 characters |

Build the header and footer once as their own email templates, select them here, and every
transactional email picks them up.

**Setup buttons** (bottom of the Email Templates group)

- **Create Email Templates** — creates a Hyvä email template for every default Magento email type
  (order, invoice, shipment, credit memo, customer account, password reset, newsletter subscription
  confirmations, …), pre-filled from the built-in presets. Existing templates are **skipped**, so it is
  safe to press again after new presets ship.
- **Map Templates to Configuration** — points Magento's Sales emails, Customer emails and Newsletter
  confirmation settings at those templates in one go. Without mapping the templates exist but Magento
  keeps sending the old ones.

The mapping writes to core config, so flush it afterwards:

```bash
bin/magento cache:clean config
```

The success message reports created / skipped / failed counts; failures are logged to
`var/log/liveview.log`.

**Email Preview Data group** — fills Magento template variables in the editor preview so it looks like
a real email: Preview First Name / Last Name / Email / Street / City / Country (the dummy customer);
**Preview Order (Increment ID)** — enter a real increment ID (e.g. `000000042`) and the preview uses
that order's actual items, totals, addresses and product images; **Preview Product SKUs** —
comma-separated SKUs shown as ordered items when no order ID is set.

**Newsletter Templates group**

| Setting | Effect |
|---|---|
| Enable for Newsletter Templates | Master switch for the Hyvä editor on newsletter templates |
| Newsletter Templates Enabled by default | New newsletter templates get the Hyvä editor automatically |
| Default Preheader Text | Fallback inbox-preview snippet, same behaviour as the email one |
| Include Default Header | Prepends a store-logo header to every Hyvä newsletter |
| Include Default Footer | Appends store details and the legally required unsubscribe link |

The default footer includes `{{var subscriber_data.unsubscription_link}}`, which most jurisdictions
require in marketing email — if the default footer is disabled, the newsletter content must include an
unsubscribe link some other way (e.g. an HTML component).

**Newsletter Preview Data group** — the dummy subscriber (first name, last name, email) used to
resolve `{{var subscriber.firstname}}` and friends in previews and test sends.
<https://docs.hyva.io/hyva-commerce/features/email-templates/configuration.html>

## Architecture

### Content types and providers

| Content type | Provider | Backing entity |
|---|---|---|
| `email_template` | `Hyva\EmailTemplates\Model\Provider\EmailTemplateProvider` | `Magento\Email\Model\Template` |
| `newsletter_template` | `Hyva\EmailTemplates\Model\Provider\NewsletterTemplateProvider` | `Magento\Newsletter\Model\Template` |

Both registered on the Hyvä CMS `ProviderPool`. Per-template state (Hyvä editor enabled flag, draft
and published component trees, preheader) lives in the module's own tables, each with a cascading
foreign key to its Magento parent. **The Magento template rows stay untouched**, which is why
disabling the Hyvä editor falls back cleanly to classic rendering.

Editor routes are registered in `etc/adminhtml/di.xml` on the `EditorRouteRegistry`:
`hyva_cms_email/liveview/editor` (email) and `hyva_cms_email/liveview/newslettereditor` (newsletter).

### Render pipeline

Both types share `Model\Render\ComponentTreeRenderer`, which renders the saved tree to HTML by
rendering each component's element template (`Hyva\CmsLiveviewEditor\Block\Element` + the component's
`.phtml`). From there they diverge, and **the difference is load-bearing**:

- **Email — `afterGetProcessedTemplate`.** `Plugin\Model\Template` plugs into
  `Magento\Email\Model\Template`. For a Hyvä-enabled template it builds the full email HTML
  (component tree → chrome header/footer → `root.phtml` wrapper), runs it through the Magento email
  template filter (resolving `{{var}}`, `{{trans}}`, `{{layout}}`, `{{depend}}` with the real
  transactional variables), and inlines CSS.
- **Newsletter — `afterGetTemplateText`.** `Plugin\Model\NewsletterTemplate` plugs into
  `getTemplateText()` and deliberately returns HTML **with `{{var}}` directives intact**. Magento's
  newsletter queue snapshots `getTemplateText()` into `newsletter_queue.newsletter_text` when a
  campaign is queued, and the per-subscriber newsletter filter resolves each subscriber's personal
  variables (name, unsubscribe link) at send time. Resolving too early would bake one subscriber's
  data into everyone's newsletter.

If you plug into these models yourself, respect the split — swapping the hooks breaks personalisation.

**CSS inlining and directive safety**: `Model\InlineStyleProcessor` inlines `<style>` rules into
element attributes (Gmail strips `<style>` blocks). Before parsing it placeholder-protects `{}`
directives so DOMDocument cannot corrupt them, so directives survive inlining in both text and
attributes.

### Preview pipeline

The editor preview (`hyva_cms_email/create/emailpreview`, `Block\Preview\EmailWrapper`) renders the
same component tree but resolves directives with **dummy data** instead of the Magento filter:

- `Plugin\Block\EmailOrderContextInjector` injects `order_preview_context` (customer, items, totals,
  addresses) into every element block — from a real order when **Preview Order (Increment ID)** is
  configured, otherwise from fixtures.
- `Plugin\Block\EmailHtmlVariableSubstitutor` + `Model\DummyData\VariableSubstitutor` resolve
  `{{var}}`, `{{trans}}`, `{{depend}}`, `{{if}}` and `{{layout}}` against a dummy variable map
  covering `order_data.*`, `order.*`, `store.*`, `subscriber.*` and `subscriber_data.*` paths.

Element templates branch on `$block->validPreview()` when preview needs different markup than
production — e.g. Shipment Tracking renders dummy rows in preview and a `{{layout}}` directive in
production.

### Version history

`hyva_commerce_email_template_version_history` stores versions for **both** types, discriminated by an
`entity_type` column (`email_template` / `newsletter_template`). It intentionally has **no foreign
key** (one column cannot reference two parents); cleanup happens at application level via
`Model\VersionHistoryCleaner`, triggered by the delete plugins on both template models.

### Newsletter chrome

`Model\Render\NewsletterChrome` appends the default newsletter footer (store details + unsubscribe
link) and the optional logo header, controlled by `hyva_cms/newsletter_template/use_footer` /
`use_header`. Both the send path and the preview use this one service, so what you preview is what
gets sent. Theme-overridable templates:

- `Hyva_EmailTemplates::newsletter/header/default.phtml`
- `Hyva_EmailTemplates::newsletter/footer/default.phtml`

### Component scoping

All bundled components declare `"context_flags": ["email"]` in `etc/hyva_cms/components.json`, and the
email/newsletter editors declare `allowed_root_component_context_flags: ['email']` plus
`strict_component_context: true`. Net effect: email components never appear in CMS page/block pickers,
and generic CMS components never appear inside emails (they would render non-email-safe markup).
<https://docs.hyva.io/hyva-commerce/features/email-templates/devdocs/index.html>

## Creating custom email components

Regular Hyvä CMS components with extra constraints: email-safe HTML, directives kept intact, and
scoping to the email editors. Component basics are in `cms-component-development.md`.

```json
{
    "vendor_promo_banner": {
        "label": "Promo Banner",
        "category": "Email",
        "context_flags": ["email"],
        "template": "Vendor_Module::elements/email/promo_banner.phtml",
        "content": {
            "text": {
                "type": "richtext",
                "label": "Banner Text",
                "translate": true,
                "default_value": "Free shipping on orders over $50"
            }
        },
        "design": {
            "background_color": { "type": "color", "label": "Background Color", "default_value": "#eff6ff" }
        }
    }
}
```

`"context_flags": ["email"]` puts the component in the picker inside email **and** newsletter
templates and hides it everywhere else (CMS pages, blocks, menus, attributes). Because the email
editors run in strict context mode, the reverse also holds: without the flag the component never
appears in an email editor at all.

To be insertable inside the bundled **Section**, **Two Columns** or **Card** containers, the component
must be listed in their `accepts` array — those declare explicit child lists, so either override the
bundled declaration (a **full** override; see `cms-component-development.md`) or design the component
to sit directly inside the **Email Wrapper**, which accepts any email-flagged component.

### Element template rules

```php
<?php
use Hyva\EmailTemplates\ViewModel\Utilities;
use Hyva\Theme\Model\ViewModelRegistry;
/** @var \Hyva\CmsLiveviewEditor\Block\Element $block */
/** @var \Magento\Framework\Escaper $escaper */
/** @var ViewModelRegistry $viewModels */
$emailUtility = $viewModels->require(Utilities::class);

// Richtext: flatten to inline HTML so markup and {{var}}/{{trans}} directives survive unescaped.
$text = $emailUtility->inlineRichtext((string)($block->getData('text') ?: ''))
    ?: 'Free shipping on orders over $50';

$styles = $block->buildStyles([
    'background-color' => $block->getData('background_color') ?: '#eff6ff',
    'padding'          => '12px 16px',
]);
?>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr>
        <td align="center" style="<?= /** @noEscape */ $styles ?>">
            <?= /** @noEscape */ $text ?>
        </td>
    </tr>
</table>
```

- **Layout with tables, marked presentational.** `<table role="presentation">` for layout — Outlook
  cannot handle flex or grid, and without the role screen readers announce phantom rows and columns.
  Only genuine data tables (Order Items) keep table semantics, with `<th scope="col">` headers.
- **Inline-friendly CSS only.** Emit per-instance styles via `$block->buildStyles([...])` into
  `style=""`, or use a `<style>` block with simple selectors that `InlineStyleProcessor` can inline.
  Avoid media queries, web fonts and background images unless degraded rendering is acceptable.
- **Keep directives raw.** Text and richtext values may contain `{{var ...}}` / `{{trans ...}}`. Run
  richtext through `Utilities::inlineRichtext()` (strips `<p>`/`<div>` wrappers, converts paragraph
  breaks to `<br />`) and output with `/** @noEscape */` — escaping would send literal `{{var ...}}`
  text to customers.
- **Meet WCAG AA contrast** — 4.5:1 for text, 3:1 for large text. The bundled palette uses `#374151`
  (body), `#111827` (emphasis) and `#4b5563` (muted), all passing on white and `#f9fafb`. The editor's
  health check flags violations, including ones caused by merchant colour choices.
- **Branch on preview** when production output is a directive that only works in a real send:

```php
<?php if ($block->validPreview()): ?>
    <!-- dummy rows so the merchant sees something -->
<?php else: ?>
    {{layout handle="sales_email_order_shipment_track" shipment_id=$shipment_id order_id=$order_id}}
<?php endif; ?>
```

- **Outlook buttons need VML.** Copy the pattern from `elements/email/button.phtml` — an anchor for
  modern clients wrapped in a VML roundrect fallback. The VML branch uses `strip_tags()` on the label
  because VML cannot render HTML markup.

### Variable picker and preview variables

The **Insert Variable** picker is part of the richtext toolbar, so only `richtext` fields get it. Plain
`text` fields have no picker (typed directives still work at render time — the picker is convenience
only). This is why the bundled directive-bearing fields (button labels, the Order Intro greeting) are
richtext.

If a component emits a directive the preview does not know, the preview shows `…` in its place. Dummy
values live in `Model\DummyData\VariableSubstitutor`; for custom variables add a plugin on the
substitutor or handle the preview case with `validPreview()`.

### Overriding bundled templates

Any element template can be overridden in a theme the standard Magento way, e.g.
`app/design/frontend/Vendor/theme/Hyva_EmailTemplates/templates/elements/email/footer.phtml`. The same
applies to the email chrome (`root.phtml`, `header/default.phtml`, `footer/default.phtml`) and the
newsletter chrome. Shared static CSS lives in `web/css/hyva-email.css`.
<https://docs.hyva.io/hyva-commerce/features/email-templates/devdocs/creating-email-components.html>

## Building email templates (merchant workflow)

1. Ensure **Enable for Email Templates** is on.
2. `Marketing → Communications → Email Templates`, open or create a template.
3. Tick **Enable Hyvä Editor** on the template form and save.
4. Open it in the Hyvä editor.

The setup buttons do all of this for the standard transactional emails, pre-filled — you then edit only
what you want to change.

**Structure components**: Email Wrapper (outer container; max width 400–600px, background, padding —
start every email with one), Section (full-width band with its own background and padding), Two Columns
(configurable split: 50/50, 60/40, …), Card (boxed area with background, border, rounded corners).

**Content components**: Heading (H1–H4, colour, alignment), Text (rich text), Button (bulletproof CTA
that renders correctly in Outlook), Image (width, alignment, optional link), Divider / Spacer, HTML Code.

**Email-specific components**: Email Header (store logo, optional store name, linked to the store),
Email Footer (store name, copyright, links), Order Intro (greeting + intro paragraph, both editable and
variable-capable), Order Summary / Document Summary (order/invoice/shipment/credit-memo reference box),
Order Items (with optional product image column), Order Totals, Order Addresses, Order Customer Note
(rendered only when present), Shipment Tracking, Admin Comment (only when a comment exists), Dynamic
Button (link resolves per email: order page, account page, password reset, newsletter unsubscribe, or a
custom URL).

Order Intro ships with `{{trans "Dear %name," name=$order_data.customer_name}}` as the greeting plus a
rewritable thank-you sentence; both are editable and translatable per store view. Directives are
resolved at send time by Magento, not stored as static text.

**Preheader**: per-template in the editor's settings panel, or the store-wide default from
configuration; without either, the subject line is used.

**Headers and footers**: with **Include Header** / **Include Footer** enabled, every Hyvä email is
wrapped automatically — no need to add them per template.
<https://docs.hyva.io/hyva-commerce/features/email-templates/user-guides/building-email-templates.html>

## Building newsletter templates

Same editor, same components. What differs:

1. **Enable for Newsletter Templates** must be on.
2. `Marketing → Communications → Newsletter Template`, open or create, tick **Enable Hyvä Editor**, save.
3. Build the campaign in the Hyvä editor.

**Include Default Header** prepends the store logo; **Include Default Footer** (on by default) appends
store details and the unsubscribe link, so the template can focus on campaign content. Marketing email
may legally require an unsubscribe option — keep the default footer, or include
`{{var subscriber_data.unsubscription_link}}` elsewhere (e.g. an HTML component).

Subscriber variables from the Insert Variable picker:

| Variable | Resolves to |
|---|---|
| `{{var subscriber_data.unsubscription_link}}` | personal unsubscribe URL |
| `{{var subscriber_data.confirmation_link}}` | subscription confirmation URL |
| `{{var subscriber.firstname}}` / `{{var subscriber.lastname}}` | subscriber's name |
| `{{var subscriber.email}}` | subscriber's email address |

The Dynamic Button component also offers **Newsletter Unsubscribe** and **Subscription Confirmation**
link types. In the preview these resolve using the dummy subscriber from Newsletter Preview Data.

**Queue behaviour** (`Marketing → Communications → Newsletter Queue`): queueing snapshots the rendered
Hyvä content (with subscriber variables still unresolved) into the queue; each subscriber's send
resolves their personal variables at delivery time. **Edits after queueing do not reach the queue** —
delete the queue entry and queue the template again.
<https://docs.hyva.io/hyva-commerce/features/email-templates/user-guides/building-newsletter-templates.html>

## Previewing and testing

**Live preview with realistic data** — directives are replaced as you type: customer details from
Email Preview Data (or the dummy subscriber for newsletters); a real order when **Preview Order
(Increment ID)** is set, otherwise dummy products or the configured SKUs.

**Email client simulation** from the preview toolbar:

- **Gmail** (desktop and mobile) — inlines styles and disables `<style>` blocks exactly as Gmail does,
  and shows a clipping banner past Gmail's **102 KB** limit.
- **Outlook** — flags layout its Word-based engine cannot render.
- **Apple Mail** (desktop and mobile).
- **Dark mode** — simulates dark-mode colour transformations.

**Health check panel**, three areas, each with an explanation and a suggested fix:

- **Deliverability** — spam trigger phrases, subject length (desktop and mobile limits), missing or
  oversized preheader, total email weight, Gmail clipping, `http://` links, missing physical address,
  missing unsubscribe link (newsletters).
- **Accessibility** — colour contrast below WCAG AA, images without alt text, image-only emails,
  heading order, generic link text ("click here"), missing document language, small font sizes,
  all-caps text.
- **Client compatibility** — flex or grid layout, CSS classes without inline styles, background
  images, web fonts, forms and scripts, SVG and data-URI images, deeply nested tables, layout tables
  not marked presentational.

Bundled components are built to pass these checks, so warnings usually point at custom HTML components
or colour choices; each warning names the triggering element.

**Send Test Email** in the editor header sends to any address, rendered with the same preview data.
Newsletter templates have the same button, using dummy subscriber data (so the unsubscribe link
resolves to a placeholder, not a live unsubscribe).

Every save creates a version; both types keep their own history for compare and rollback.
<https://docs.hyva.io/hyva-commerce/features/email-templates/user-guides/previewing-and-testing.html>

## FAQ facts

- Hyvä CMS is required.
- The module renders complete standalone email HTML, so no storefront theme changes are needed and
  emails work with any theme, including non-Hyvä themes.
- The Hyvä editor is **opt-in per template** — templates without it render exactly as before.
- Emails and newsletters are identical in the editor; they differ only in setup and delivery (separate
  config groups, separate enable switches, and the newsletter queue with its own default chrome).
- Custom email components follow the standard Hyvä CMS component patterns with the `email` context flag.

<https://docs.hyva.io/hyva-commerce/features/email-templates/faqs.html>
