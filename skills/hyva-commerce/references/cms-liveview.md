# Hyvä CMS and the Liveview Editor

Component-based CMS for Magento. Content is stored as **JSON component trees**, rendered through
Magento PHTML templates, and edited in the **Liveview Editor** (a live storefront preview in an
iframe). Package: `hyva-themes/commerce-module-cms`.
<https://docs.hyva.io/hyva-commerce/features/cms/index.html>

## Module split

One composer package, several Magento modules with distinct responsibilities:

| Internal module dir | Responsibility |
|---|---|
| `liveview-editor` | Editor UI, preview, component discovery, version history, translations, Tailwind JIT integration, preview security, editor preferences, CLI tools |
| `hyva-cms-magewire` | Internal Magewire fork used by the admin editor only — not a storefront dependency |
| `magento-cms` (`Hyva_CmsMagento`) | CMS page/block integration: storage tables, rendering plugins, REST, GraphQL, version history, Tailwind CSS storage |
| `magento-attributes` (`Hyva_CmsMagentoAttributes`) | Product/category EAV attribute integration |
| `components-base` (`Hyva_CmsBase`) | Built-in component declarations and templates |
| `scheduling` (`Hyva_CmsScheduling`) | Scheduled publication |
| `template` (`Hyva_CmsTemplate`) | Templates, snippets, thumbnails, default templates |
| `cms-import-export` (`Hyva_CmsImportExport`) | ZIP + JSON import/export, media, translations, history |
| `instance-components` | Admin-created, DB-backed components |

<https://docs.hyva.io/hyva-commerce/features/cms/architecture-overview.html>

## Supported content types

CMS pages, CMS blocks, product attributes, category attributes, templates, snippets. Companion
packages add more through the same provider contracts (Menu Builder adds menus; Form Builder adds
forms; Email Templates adds email/newsletter templates). Custom modules can add their own — see
`cms-component-development.md`.

## Component discovery and caching

Code-defined components are declared in `etc/hyva_cms/components.json` inside any module. A collector
scans installed modules, validates against the JSON schema, resolves `includes` and option sources,
and builds one registry (label, category, template path, fields, child rules, description, context
flags, variants). In production mode the registry is cached in the **`hyva_cms` cache type**;
developer mode skips it for faster iteration.

```bash
bin/magento cache:clean hyva_cms          # clear on deploy
bin/magento hyva:cms:describe-components  # enabled components: name, label, description, category
bin/magento hyva:cms:list-fields          # available field types (core + custom)
bin/magento hyva:cms:list-disabled-components
```

DB-backed **instance components** are collected separately by `InstanceComponentCollector`, stored in
`hyva_cms_instance_component`, merged into the same registry with an `instance/` key prefix, and the
`hyva_cms` cache is cleaned on save.

## Content storage

Each content item has separate **draft** and **published** JSON trees, plus version history and
Tailwind CSS data. CMS pages/blocks use dedicated Hyvä tables referencing native `cms_page` /
`cms_block` rows. Attribute content uses `hyva_commerce_product_attribute_liveview` and
`hyva_commerce_category_attribute_liveview`, holding base content plus `store_content` overrides
keyed by store ID. Version history lives in separate tables so restore/compare never touches the
current draft or published state.

## Rendering

When Hyvä CMS is enabled for an item, the frontend loads the published JSON and walks the tree,
delegating each node to its declared PHTML. Component templates receive
`Hyva\CmsLiveviewEditor\Block\Element`.

In preview mode the editor attributes (`data-liveview-element`, block `id`, root `getEditorAttrs()`)
are injected into each component's **first** element automatically (since Hyvä CMS 1.2.0) and
stripped from public output. Opt out with `$block->setData('auto_attributes', false)` (boolean
`false`).

For product/category attributes, frontend plugins replace the native attribute HTML when content is
enabled and published — but prefer the `AttributeContent` ViewModel (see
`cms-component-development.md`).

## Editor workflow and interface

- **Save Draft** (no storefront change) → **Preview** (draft through the storefront) → **Publish** →
  optional **Schedule Publication**. The header shows up-to-date / unsaved / unpublished / live.
- Live preview with mobile/tablet/desktop modes, split view, shareable draft preview URLs (security
  token signed), "View Published Page".
- Tabs bar with recently edited content and thumbnail hovers; sidebar movable left/right and
  resizable; searchable component tree.
- Component management: categorised picker with search + Favourites, drag and drop, child components
  where the parent allows, copy/paste/duplicate/delete, visibility toggle, context editing.
- **Context editing**: hover a component in the preview for a quick-action dot → open a field's
  panel, highlight in the tree, or delete. On by default.
- **Navigator** slideout: structural tree view plus quick creation flows.
- **Version history**: restore, side-by-side compare, pin, name, author/timestamp, schedule metadata.
- **Undo/redo**: in-memory, session-scoped, separate from version history; can jump to earliest undo
  / latest redo or roll back to the last saved draft.
- First-time setup on new content offers: build from scratch, start from a template, or migrate
  Page Builder content.
- Rich text uses **TipTap**; HTML editing uses **Monaco**.

<https://docs.hyva.io/hyva-commerce/features/cms/editor.html>

## Accessing the editor

- CMS pages/blocks: `Content → Elements → Pages|Blocks` → **Add with Hyvä CMS** for new content, or
  set **Enable Hyvä Editor** = Yes on an existing item, save, then **Edit with Hyvä CMS**.
- Product/category attributes: open the entity, enable the wanted attributes in the **Hyvä CMS**
  panel, save, then open the editor for that attribute.
- The **Hyvä menu** (top-left in the editor) opens templates & snippets, import/export, translations,
  editor preferences, Page Builder migration, and instance components (when permitted).
- Content states: Draft, Published, Scheduled, Enabled/Disabled. Disabling returns output to native
  Magento content for that item; Hyvä draft data is retained.

<https://docs.hyva.io/hyva-commerce/features/cms/accessing-hyva-cms-editor.html>

## Admin configuration paths

All under `Stores → Settings → Configuration → Hyvä Commerce → Hyvä CMS`:

| Group | Notes |
|---|---|
| General | `hyva_cms/general/auto_csp_frame_policies` — "Enable Multi Domain CSP Frame Policies", on by default since 1.0.2 |
| Magento CMS | enable/disable CMS page + block support (enabled by default) |
| Attributes | Enable Product Attributes / Enable Category Attributes (both default on) |
| Templates | Created For options, slideout page size, snippet icon names, **Default Templates** per content type |
| Scheduling | enable, notification recipient, sender identity, email template, publication cron expression, cleanup cron expression, history age |
| Editor Settings | `hyva_cms/editor_settings/default_component_classes` (global), Enable Translations |
| CMS Tailwind Compilation | `hyva_cms_tailwind/hyva_cms_bridge/compilation_strategy` (global only, default `in-browser`) |

Other documented paths: `hyva_commerce_cms/[content_type]/enabled` (per-content-type enable switch
convention for custom integrations), `hyva_cms/preview/devices` (seeds per-user preview widths;
the old `hyva_cms/…/mobile_width`/`tablet_width` fields and their `ConfigInterface` XPATH constants
were removed in CMS 1.2.0 — call the getters instead).

## Multi-store / custom admin domain CSP

The Liveview Editor shows the storefront in a cross-domain iframe, which needs CSP frame policies in
the editor context. Automatic since `1.0.2`. To configure manually, disable
`hyva_cms/general/auto_csp_frame_policies` and add:

```xml
<!-- etc/csp_whitelist.xml -->
<csp_whitelist xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:noNamespaceSchemaLocation="urn:magento:module:Magento_Csp:etc/csp_whitelist.xsd">
    <policies>
        <policy id="frame-ancestors">
            <values><value id="magento-admin-domain" type="host">admin.example.com</value></values>
        </policy>
        <policy id="frame-src">
            <values>
                <value id="store-domain-uk" type="host">example-uk.com</value>
                <value id="store-domain-fr" type="host">example-fr.com</value>
            </values>
        </policy>
    </policies>
</csp_whitelist>
```

CSP must be in strict mode for `frame-ancestors` to override `X-Frame-Options`:

```xml
<!-- etc/config.xml -->
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:module:Magento_Store:etc/config.xsd">
    <default><csp><mode><storefront><report_only>0</report_only></storefront></mode></csp></default>
</config>
```

or the equivalent `system/default/csp/mode/storefront/report_only => '0'` in `app/etc/env.php`.
<https://docs.hyva.io/hyva-commerce/features/cms/installation.html>

## Adding head assets to the editor

The editor uses a different frontend stack than standard adminhtml, so third-party admin CSS/JS added
via `default.xml` is filtered out. Allow it explicitly:

```xml
<type name="Hyva\CmsLiveviewEditor\Plugin\PageConfigStructurePlugin">
    <arguments>
        <argument name="allowedAssets" xsi:type="array">
            <item name="Vendor_Module::css/my-module-admin.css" xsi:type="string">Vendor_Module::css/my-module-admin.css</item>
            <item name="Vendor_Module::js/my-module-admin.js" xsi:type="string">Vendor_Module::js/my-module-admin.js</item>
        </argument>
    </arguments>
</type>
```

<https://docs.hyva.io/hyva-commerce/features/cms/adding-assets-to-liveview-editor.html>

## Tailwind CSS compilation and scoping

Hyvä CMS generates Tailwind CSS for classes used in content, so components produce styles without a
full theme rebuild. Output is:

- **Scoped per entity** with a wrapper selector `.hcms-{type}-{id}` (e.g. `.hcms-page-42`), stored
  per entity, theme and edition (draft / published / scheduled).
- Emitted in an `@layer hyva-cms-tailwind` cascade layer declared at lowest priority, so the theme's
  `styles.css` always wins. Override deliberately with Tailwind's `!` modifier (`!w-96`,
  `md:!p-3`, or Tailwind v4's trailing `md:p-3!`) — but prefer adding a dedicated component field.

Two strategies (both support Tailwind v3 and v4, both produce the same scoped output):

- **in-browser** JIT (default) — compiles in the editor.
- **server-side** — Node-based compiler daemon; smaller inline CSS payload, uses each theme's real
  Tailwind config. **Recommended for new projects.**

Set at `Stores → Configuration → Hyvä Commerce → Hyvä CMS → CMS Tailwind Compilation → Hyvä CMS
Compilation Strategy` (`hyva_cms_tailwind/hyva_cms_bridge/compilation_strategy`, global scope).
Backends are pulled in as CMS dependencies (`hyva-themes/magento2-cms-tailwind-compiler`,
`hyva-themes/commerce-module-cms-tailwind-jit-bridge`); no separate install. The in-browser compiler
version (v3/v4) is shared with the native Magento CMS/PageBuilder compiler.

Compilation runs on save; enable **Update Hyvä Styles on Edit** in editor preferences to compile
live while editing (heavier). Compilation can be switched off globally or per entity.

Bulk recompile after the 1.2.0 scoping change:

```bash
composer require hyva-themes/magento2-cms-tailwind-recompile
bin/magento hyva:cms-tailwind:recompile [--background] [--theme=Hyva/default] [--status]
```

Per-entity, re-saving the page or block recompiles its scoped CSS.
<https://docs.hyva.io/hyva-commerce/features/cms/tailwind-compilation.html>

## Content scheduling

Hyvä CMS has its own scheduler, independent of Adobe Commerce Content Staging (Adobe scheduling
**cannot** publish Hyvä CMS draft content; the two can coexist for other data).

- Merchant flow: save draft → **Schedule Publication** → new or existing **release** → date/time →
  release name + item description → review content-type advanced settings → save the scheduled item.
  The editor then opens the scheduled version; edits there update the scheduled item, not published
  content.
- A **release** is the launch event; a **scheduled item** is one piece of content inside it. One
  release can publish several items together.
- Supported by core: CMS pages, CMS blocks, product attribute content, category attribute content.
  Pages/blocks expose advanced scheduled settings (page title, content heading, meta title, meta
  description, enabled state, URL key; block title, identifier, preview URL key, enabled state).
  Attributes expose no extra scheduled entity settings.
- Statuses: Pending Publication, Publication in Progress, Successfully Published, Failed to Publish,
  Partially Published, Cancelled.
- Cron defaults: publication check every 5 minutes; history cleanup Sundays 04:00; 90-day retention.
  Config at `Stores > Configuration > Hyvä Commerce > Hyvä CMS > Scheduling`.
- A release holds up to 100 scheduled items by default (DI-configurable).
- Architecture: releases and scheduled items are stored separately from drafts/published content;
  cron asks each content type's registered schedule provider to apply content, Tailwind CSS, version
  history and type-specific settings.

<https://docs.hyva.io/hyva-commerce/features/cms/features/content-scheduling.html>

## Translations

Per-store-view translation of *translatable* fields without duplicating the component tree. Fields
opt in with `"translate": true` in the declaration.

- Panel supports manual entry per store view, CSV export/import (including drag-and-drop) and
  translation status tracking. Reachable from the Hyvä menu or the translation icon next to a field.
- Enabled by default: `Stores > Configuration > Hyvä Commerce > Hyvä CMS > Editor Settings > Enable
  Translations`.
- Translations vs store-view content overrides: translations keep one structure with localised
  values; overrides change the structure per store view. Attribute content follows Magento scope
  ("All Store Views" default, per-store "Use default value" toggle).
- Optional `Hyva_CmsAiTranslations` package adds AI assistance (OpenAI, Google Gemini, DeepL) with
  modes for empty-fields-only or replace-existing.
- Templates, snippets, import/export and scheduled publication preserve translation data when the
  relevant options are enabled.

<https://docs.hyva.io/hyva-commerce/features/cms/features/translations.html>

## Import / export

Handler-driven; two mechanisms.

**ZIP transfer packages** — for moving content between environments. Can include CMS pages, CMS
blocks, product/category attribute content, instance components, templates, snippets, referenced
media, store-view translations, and version history. Export options: Images, Translations, History,
Components. The ZIP holds `manifest.json`, per-entity settings + content JSON, optional translation
CSVs, and media under an images directory.

Import behaviours: **Replace** (overwrite by identifier) or **Import as new** (copy identifiers).
CMS pages, blocks and instance components support import-as-new; product/category attribute content
does not, because the target catalog entity must already exist.

Portability rules: product content matched by **SKU**, category content by **URL path**, attribute
IDs normalised to attribute **codes**, and product/category/CMS-page/CMS-block links normalised to
portable identifiers. Unresolvable references keep their original value and raise a warning. Existing
media files are never overwritten. Supported media extensions include `jpg`, `jpeg`, `png`, `gif`,
`webp`, `svg`, `avif`, `ico`, `mp4`, `webm`, `mov`, `pdf`, `woff`, `woff2`, `ttf`, `otf`.

CMS pages/blocks only appear in the export picker when they actually carry Hyvä CMS content;
direct export attempts for others are rejected server-side.

**JSON tab** — current item only. Export JSON copies the draft component structure; Import JSON
**overwrites** the current draft structure.

Import/Export is driven by adminhtml controllers, not a public REST endpoint. Registering a custom
content type handler is covered in `cms-component-development.md`.
<https://docs.hyva.io/hyva-commerce/features/cms/features/import-export.html>

## Instance components (DB-backed)

Admin-created components stored in `hyva_cms_instance_component`, keyed in the editor as
`instance/<identifier>`. Created from the editor menu → **Instance Components**.

An instance component has: name, identifier, category, optional description, optional availability
restrictions by content type, icon (emoji with optional background/border colours, or a module image
path), active flag, editable fields, HTML template. Editing one changes every existing use.

Field types available in the visual builder: text, textarea, rich text, HTML, URL, image, link,
boolean, color, date, date-and-time, number, range, select, multiselect, searchable select. Text-like
fields can be marked translatable; select fields can define options; supported types can define
defaults. A JSON editor is available for the raw field declaration.

Template syntax (escaped by default; image/link/richtext have field-specific renderers):

```html
<section class="promo-strip">
    <h2>{title}</h2>
    {#if image}<img src="{image.src}" alt="{image.alt}">{/if}
    {#if link}{link}{/if}
</section>
```

`{field}`, `{field.property}`, `{raw:field}`, `{#if field}…{#else}…{/if}`,
`{#foreach items as item}…{/foreach}`, `\{` / `\}` for literal braces.

Deliberate limits: no field value can drive a CSS class, style attribute or other dynamic behaviour
(injection surface + maintainability), and no child components. ACL:
`Content > Elements > Hyvä CMS Instance Components` with View / Save / Delete. Reserve HTML/template
access for trusted users, and move long-lived design-system components into code.
<https://docs.hyva.io/hyva-commerce/features/cms/features/instance-components.html>

## Templates and snippets (`Hyva_CmsTemplate`)

**Templates** store a complete content structure plus metadata and a preview thumbnail; loading one
inserts its components into whatever you are editing. On save you set: name, optional "Created For"
tag (Any, Page, Product, Category, Block, Menu), preview thumbnail (captured or uploaded).
Administrators can set default templates per content type at
`Stores > Configuration > Hyvä Commerce > Hyvä CMS > Templates > Default Templates`.

**Snippets** store selected components from the current content (**Save as Snippet**), with name,
private/shared visibility, and an icon/uploaded/captured preview. Private snippets are visible only
to their creator; shared snippets show the owner.

Both are registered as Hyvä CMS content providers *and* Import/Export handlers, and are exposed over
REST. Introduced in Hyvä CMS 1.2.0.
<https://docs.hyva.io/hyva-commerce/features/cms/features/templates-and-snippets.html>

## Rich text editor and variables

TipTap (ProseMirror) based, used by every `richtext` field; replaced the Quill editor in Hyvä CMS
1.2.0 (existing stored HTML is reparsed on load).

Toolbar: bold, italic, underline, strikethrough, H1–H3, bullet/ordered lists, blockquote, code block,
per-field undo/redo, **Expand** for a full-screen modal. Link / Image / Widget buttons reuse the
editor's own pickers and render as editable "chips".

**Insert Variable** has two tabs:

- *Store & Custom Variables* — curated set from Magento's variable system: store contact info emits
  `{{config path="..."}}`, admin custom variables emit `{{customVar code="..."}}` (managed at
  `Content > Custom Variables`). Free-form config paths are deliberately not offered.
- *Custom Directive* — guided builders with live preview for `{{var ...}}`, `{{trans "..."}}` and
  `{{store url="..."}}` / `{{store direct_url="..."}}`.

Hyvä-specific directives, insertable via the same pickers:

```html
{{hyva_image src="path/to/image.jpg" alt="Alt text" width="640" height="480" /}}
{{hyva_link type="cms_page" value="about-us" label="About Us" target="_blank" /}}
```

`{{hyva_link}}` is store-aware and resolves category, product, CMS page and custom URL types;
`{{hyva_image}}` resolves a media path to a full URL.

There is no "prose" toggle: add `prose` through **Advanced > CSS Classes**, or pre-populate it with
default component classes. No dedicated system config or ACL — access follows Liveview Editor admin
access.
<https://docs.hyva.io/hyva-commerce/features/cms/features/rich-text-editor.html>

## Editor preferences, favourites, keybindings

Three distinct systems: **editor preferences + keybindings** (per admin user), **favourite
components** (per admin user), **default component classes** (shared, in system config).
Open with **Editor Preferences** from the Hyvä menu or `Mod` + `,`.

General tab (defaults in brackets): Update Hyvä Styles on Edit [Off], Sidebar on Left [Off], Enable
Context Editing [On], Open Component Editor on Add [Off], Show Content Preview in Tree [On], Confirm
Before Publishing [Off]. "Update Hyvä Styles on Edit" only applies when Tailwind JIT is enabled for
the current content.

Favourites: star a component in the picker; the Favourites tab appears once at least one is starred.

Default component classes pre-populate the **CSS Classes** field when a matching component is added.
Managed in the **Shared** tab or at `Stores > Configuration > Hyvä Commerce > Hyvä CMS > Editor
Settings > Default Component Classes`. Ships with `text` → `prose`.

Favourites and customisable keybindings arrived in 1.2.0, which also moved preferences from browser
local storage to per-user DB storage (migrated automatically on first open).

Default keyboard shortcuts (`Mod` = `Cmd` on macOS, `Ctrl` elsewhere):

| Action | Shortcut | Works while typing |
|---|---|---|
| Save draft | `Mod`+`S` | yes |
| Publish | `Mod`+`Shift`+`S` | yes |
| Undo | `Mod`+`Z` | no |
| Redo | `Ctrl`+`Y` (Win/Linux), `Cmd`+`Shift`+`Z` (macOS) | no |
| Open search | `Mod`+`K` | no |
| Open component library | `Shift`+`A` | no |
| Open navigator | `Shift`+`N` | no |
| Open version history | `Shift`+`H` | no |
| Open preferences | `Mod`+`,` | no |

Remap per user in the **Keybindings** tab (click, press, save; Reset / Reset All). Duplicate
bindings are rejected. Shortcuts also fire from inside the preview iframe, forwarded by the Liveview
Bridge.
<https://docs.hyva.io/hyva-commerce/features/cms/features/keyboard-shortcuts.html>

## User Settings API (developer)

Storage: `hyva_commerce_user_settings` table, owned by `Hyva_Commerce`. Hyvä CMS adds a `cms` column
holding JSON with `editor_preferences` (General toggles + a `keybindings` map) and
`favourite_components`. Default component classes are **not** per user — they live in system config
at `hyva_cms/editor_settings/default_component_classes` and are applied server-side on component
creation.

```js
await liveview.userSettings.load()                                          // memoized
await liveview.userSettings.save({ editor_preferences: { sidebarOnLeft: true } })  // shallow-merged
await liveview.favourites.toggle('banner')
liveview.favourites.is('banner')
```

Alpine stores: `Alpine.store('userSettings')` → `{ favouriteComponents: [], settings: {}, loaded: false }`;
`Alpine.store('preferences')` keyed by preference id (e.g. `.sidebarOnLeft`);
`Alpine.store('keybindings')` → `{ definitions, bindings }`.

Third-party modules mirror their own key onto a store property:

```js
document.addEventListener('liveview:user-settings:init', (event) => {
    event.detail.userSettings.registerStoreBinding('my_module_settings', {
        storeKey: 'myModuleSettings',
        defaultValue: {}
    })
})
```

Controllers (ACL `Magento_Backend::content`): `GET liveview/user/getsettings`,
`POST liveview/user/savesettings`. Default component classes use `liveview/config/get` and
`liveview/config/save`, restricted to a whitelist of allowed config fields.
<https://docs.hyva.io/hyva-commerce/features/cms/user-settings-api.html>

## Liveview Bridge (editor ↔ preview `postMessage`)

`window.liveviewBridge` exists on both sides:
editor side `src/liveview-editor/view/adminhtml/templates/page/js/utils/liveview-bridge.phtml`
(provides `toPreview()`), preview side `src/liveview-editor/view/frontend/templates/bridge.phtml`
(provides `toEditor()`, only emitted in a valid preview context). Both share `liveviewBridge.MSG`.

```js
window.liveviewBridge.toEditor(window.liveviewBridge.MSG.ACTIVATE_FORM, { component: uid, field: 'title' })
window.liveviewBridge.toPreview(window.liveviewBridge.MSG.UPDATE_CONTENT, responseData, iframe) // omit iframe to broadcast
```

Inbound editor messages are handled by an `@message.window` handler in `liveview-composer.phtml`.

| Constant | Value | Direction | Purpose |
|---|---|---|---|
| `FOCUS_COMPONENT` | `liveview-focus-component` | editor→preview | scroll to + pulse a component |
| `UPDATE_CONTENT` | `liveview-update-content` | editor→preview | push re-rendered HTML/styles |
| `ADMIN_PREVIEW` | `liveview-admin-preview` | editor→preview | preview is inside the editor |
| `ACTIVATE_FORM` | `liveview-activate-form` | preview→editor | open a component/field panel |
| `TOGGLE_COMPONENT_LIST` | `liveview-toggle-component-list` | preview→editor | open the add-component picker |
| `MISSING_CONTENT_NODE` | `liveview-missing-preview-content-node` | preview→editor | preview content node not found |
| `STOREFRONT_INFO` | `liveview-storefront-info` | preview→editor | storefront context |
| `CONTEXT_FIELD_TYPES` | `liveview-context-field-types` | editor→preview | per-component handler-field map |
| `CONTEXT_OPEN_HANDLER` | `liveview-context-open-handler` | preview→editor | open a field handler |
| `CONTEXT_HIGHLIGHT_SIDEBAR` | `liveview-context-highlight-sidebar` | preview→editor | highlight in the tree |
| `CONTEXT_DELETE` | `liveview-context-delete` | preview→editor | delete a component |
| `KEYDOWN` | `liveview-keydown` | preview→editor | forward a keystroke |
| `IFRAME_POINTER_DOWN` | `liveview-iframe-pointer-down` | preview→editor | click inside the preview |

`FIELD_TYPES` / `OPEN_FIELD_HANDLER` were renamed to `CONTEXT_FIELD_TYPES` /
`CONTEXT_OPEN_HANDLER`. `IFRAME_POINTER_DOWN` becomes a `liveview:iframe-pointer-down` window event
the editor's dropdowns listen for (`@liveview:iframe-pointer-down.window="showDropdown = false"`).
<https://docs.hyva.io/hyva-commerce/features/cms/liveview-bridge.html>

## Page Builder migration

Introduced 1.0.1 (experimental), enabled by default for new installs since 1.0.2, no longer
experimental since 1.1.0. Two modes:

- **Partial** — imports existing content into HTML components (safest when nothing maps cleanly).
- **Full** — attempts to convert known Page Builder structures (images, columns) into Hyvä CMS
  components.

Run it from the editor menu on a page, block, product attribute or category attribute. Always
review: save the draft, check every breakpoint, replace generic HTML components with project
components, verify images/links/widgets/responsive layout, then publish. Custom Page Builder content
types or heavily customised markup may need project-specific handling.
<https://docs.hyva.io/hyva-commerce/features/cms/features/pagebuilder-migration.html>

## REST and GraphQL

**REST** — admin-token authorised, generated from installed service contracts. Browse the accurate
per-environment reference at `https://<store>/swagger` (developer mode only). Covers CMS pages and
blocks, product/category attribute content, scheduling, templates and snippets, with standard
service-contract operations (`GET /:id`, `GET /search`, `POST`, `PUT /:id`, `DELETE /:id`).
Attribute endpoints (all requiring `Magento_Backend::content`):

| Entity | Base URL |
|---|---|
| Product attribute content | `/V1/hyvaProductAttribute` |
| Product attribute versions | `/V1/hyvaProductAttributeVersionHistory` |
| Category attribute content | `/V1/hyvaCategoryAttribute` |
| Category attribute versions | `/V1/hyvaCategoryAttributeVersionHistory` |

**GraphQL** — public, no admin auth; exposes only published content, never drafts or admin-only data.

```graphql
{ hyvaCmsPage(identifier: "home") { ... } }
{ hyvaCmsBlock(identifier: "footer_links") { ... } }
{ hyvaCmsBlocks(identifiers: ["a", "b"]) { ... } }
{ hyvaProductAttribute(sku: "24-MB01") { ... } }
{ hyvaCategoryAttribute(categoryId: 3) { ... } }
```

Responses can include published content, rendered HTML and Tailwind CSS. Published content and
rendered HTML come back **empty** when liveview is disabled for the entity, even though the query
succeeds. Check the instance schema for the authoritative field list.

Import/Export is a separate admin workflow, not the REST API.
<https://docs.hyva.io/hyva-commerce/features/cms/apis.html>

## FAQ facts worth remembering

- Hyvä CMS is optional and applied per content entity.
- It replaces the *frontend output* of Page Builder/WYSIWYG only where enabled; the original Magento
  content is never deleted, so disabling reverts output.
- Hyvä CMS has no hard dependency on Page Builder, but Hyvä does not provide guidance for removing
  Page Builder.
- Adobe Content Staging cannot publish Hyvä CMS drafts.

<https://docs.hyva.io/hyva-commerce/features/cms/faqs.html>
