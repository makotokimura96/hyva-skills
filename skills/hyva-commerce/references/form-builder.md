# Form Builder (beta)

Builds storefront forms in the Hyvä CMS Liveview Editor and delivers each submission by email and,
optionally, to a webhook. Adds a **Forms** option under `Content → Elements`. Forms are a first-class
Hyvä CMS content type alongside Pages, Blocks and Menus.

**Beta.** `0.1.0` requires Hyvä CMS `1.3.0-beta2` as its base, is **not suitable for production**, and
is pending a full security review. Classes, registries, component conventions and contracts may change
in backwards-incompatible ways between betas.
<https://docs.hyva.io/hyva-commerce/features/form-builder/index.html>

## Install

Not bundled with the Hyvä CMS package during beta — a separate package that **depends on**
`hyva-themes/commerce-module-cms`, so install Hyvä CMS first.

```bash
# beta channel: the explicit constraint must land in the root composer.json
composer require hyva-themes/commerce-module-cms:1.3.0-beta2 hyva-themes/commerce-module-form-builder:0.1.0
bin/magento setup:upgrade
# then clear the browser cache
```

With the metapackage installed, alias the CMS beta (`"1.3.0-beta2 as 1.2.2"`). GitLab install:
`composer config repositories.hyva-themes/commerce-module-form-builder git git@gitlab.hyva.io:hyva-commerce/module-form-builder.git`
then `composer require hyva-themes/commerce-module-form-builder:dev-main`.
<https://docs.hyva.io/hyva-commerce/features/form-builder/installation.html>

## Configuration

`Stores → Configuration → Hyvä Commerce → Form Builder`.

**Security** group:

| Setting | Effect |
|---|---|
| Google reCAPTCHA Type | The reCAPTCHA type used by forms whose CAPTCHA Mode is "Google reCAPTCHA". Mirrors "Enable for Hyvä CMS Forms" in Magento's reCAPTCHA storefront panel (same value); site keys come from the type-specific sections there |
| Honeypot Secret | Secret used to derive each form's hidden honeypot field name. Auto-generated on install; override only to rotate. **Clearing it disables the honeypot** |

**Webhook Delivery** group — safeguards for the server, not the submitter (the webhook fires *after*
the response is flushed):

| Setting | Default | Effect |
|---|---|---|
| Max Concurrent Dispatches | `10` | Server-wide concurrent webhook requests. Submissions past the cap skip the webhook; the submission and its email still succeed. `0` disables the cap |
| Connect Timeout (seconds) | `2` | Wait for the endpoint to accept the connection |
| Total Timeout (seconds) | `5` | Whole webhook request |

<https://docs.hyva.io/hyva-commerce/features/form-builder/configuration.html>

## Architecture

A form is Hyvä CMS content: a component tree saved and published like a CMS page. What makes it a
*form* is (a) a **form-root component** holding the fields and the customer-facing settings, (b) a
**form entity** holding the operational submission settings, and (c) one submission controller.

End to end:

1. A form **type** is chosen at creation, seeding the **form root**. Customer-facing settings (submit
   button label, success message, success content, reply-to field, recipient routing) live in the
   root's property panel; operational ones (recipients, subject, webhook, CAPTCHA) on the entity.
2. Publishing writes the tree to `published_content`. Entity settings are **columns**, so they take
   effect on save with no publish and are untouched by a content rollback.
3. On the storefront the published tree renders as a real `<form>` in an Alpine island that POSTs.
4. Every submission hits **one** submission controller, which resolves a `SubmissionContext` and loads
   the form's **stored** tree — never anything the client sent.
5. Security gates run in a fixed order: **form key → honeypot → CAPTCHA**.
6. The payload is validated against a schema compiled from that tree, the notification email is
   rendered and sent, and the submission is optionally mirrored to a webhook.

The server is authoritative: the validation schema is compiled from stored content on every request,
never from the request body, so a tampered POST cannot add fields or relax rules. Whether
`published_content` or `draft_content` is compiled is the context's decision alone, and the draft is
only reachable through a preview link whose signature validates.

### Live sends vs test sends

`SubmissionContext` (built by `SubmissionContextResolver`) is the single seam:

| Source | Test? | Validated against |
|---|---|---|
| `SOURCE_STOREFRONT` | no | `published_content` |
| `SOURCE_FORM_PREVIEW` (the form's own preview) | yes | `draft_content` |
| `SOURCE_EMBEDDED_PREVIEW` (preview of content embedding the form) | yes | `published_content` |

Test status derives only from preview parameters whose hash passes the same preview validation the
preview page runs, so a client-supplied flag can never set or clear it; any resolution failure falls
back to the storefront source. A preview render echoes its preview parameters into the submit URL,
which is what carries them into the POST. Every outbound effect of a test is marked: `[test]` on the
email subject, `X-Hyva-Form-Test: 1` on the webhook.

### Component declaration rules

Forms are ordinary Hyvä CMS components declared in `etc/hyva_cms/components.json` with the same
`label`, `children.accepts`, `context_flags` and property-metadata shape. Two form-specific placement
rules: both shipped roots declare `root_only: true` so no nested picker or drag target admits them,
and the form editor caps the document root at **one** component (refusing an add at the root rather
than only hiding it). Both are enforced **client-side only** — an imported tree, an undo/redo or a
crafted request can still persist an invalid shape.

Everything shipped (roots, field types, containers, the CMS embed widget) lives in
`module-form-builder/src/etc/hyva_cms/components.json` — read that file rather than a list.

### The shared metadata-include contract

The settings that make a root a *form* root live in two shared include files, split by editor tab:

- `Hyva_FormBuilder::etc/hyva_cms/form_root_content_metadata.json` — `submit_button_label`,
  `success_message`, `success_content_type`, `success_redirect_url`, `success_content_block`
- `Hyva_FormBuilder::etc/hyva_cms/form_root_advanced_metadata.json` — `reply_to_field_uid`,
  `recipient_routing`

Everything in them is customer-facing or references a field inside the tree, so it is tree-versioned
with the fields (a version restore keeps references and targets consistent) and translatable ones stay
translatable per store view. These includes are the **published contract**: the submission pipeline
reads each setting **by property name** and never branches on the root's component type. There is no
aliasing layer — the name in the include *is* the name the controller reads.

Extending the settings has two independent halves, both required:

- **Editor half** — the component declaration. `includes` accepts an array, and an inline key beats
  the same key from an include, so a root can add or retune settings without copying an include file.
- **Submission half** — `Hyva\FormBuilder\Model\Submission\RootMetadataPool`, a `di.xml` registry of
  the keys `PublishedForm::getMetadata()` will surface, each entry's value acting as the read-time
  default. The registry keeps structural keys (`children`, `design`, `uid`, `_*`) out of the metadata
  read, so an unregistered key stays invisible to the pipeline however it was declared.

Both halves attach to a root's **own** declaration, so they extend a root you ship. Since Hyvä CMS
replaces components wholesale, adding a setting to `single_step_form` or `multi_step_form` means
overriding the whole declaration — shipping your own root is usually cheaper.

### Entity-level submission settings

Recipients (to/cc/bcc), email subject, webhook URL and body format, and the CAPTCHA toggle are
**columns on the form entity**, not component properties: operational rather than customer-facing, so
they apply on save without a publish, and a content rollback cannot silently redirect or expose
submissions. Read them through one seam, never off the entity getters:

```php
use Hyva\FormBuilder\Model\Submission\FormSubmissionSettingsReader;

/** @var FormSubmissionSettingsReader $reader */
$settings = $reader->fromForm($form);   // stateless; the value object is read-only
$settings->getRecipientTo();            // comma-separated, '' when unset
$settings->getRecipientCc();
$settings->getRecipientBcc();
$settings->getSubjectTemplate();
$settings->getWebhookUrl();
$settings->getWebhookFormat();          // form_encoded | json_flat | json
$settings->isCaptchaEnabled();
```

<https://docs.hyva.io/hyva-commerce/features/form-builder/devdocs/index.html>

## Building forms (merchant workflow)

`Content → Elements → Forms` → **Add New Form** → two-step dialog: (1) pick the form type, every
registered type shown with its description; (2) **Title**, **Identifier**, **Enable Form**, and
optional **Recipient (To)** + **Email Subject**. The Identifier field normalises to lowercase letters,
digits and underscores (spaces and hyphens become underscores): "Contact Inquiry" → `contact_inquiry`.
Failing settings validation on save opens **Form Settings** with the problem highlighted.

The grid shows identifier, status and CAPTCHA; Recipient (To), Email Subject and Webhook URL can be
added from **Columns** but none of the four are inline-editable (change them in
**Form Settings > Submission**). Row **Select** menu: Edit / Duplicate / Delete. Duplicate confirms,
then creates a **disabled** copy titled "… (Copy)" with `_copy` (or `_copy_2`) appended to the
identifier, and opens it.

Shipped form types:

- **Single-Step Form** — one page, one submit button.
- **Multi-Step Form** — wizard with Back/Next and a "Step *N* of *M*" indicator; add two or more
  **Form Step** containers, one per step.

A form document holds exactly one form: adding a second root is refused with "Cannot add: the maximum
number of top-level components has been reached", and a complete form cannot be dropped inside another
form's **Form Content** container. To switch type, delete the root (which takes its fields) and add
the other type.

Field types:

| Field | Use for |
|---|---|
| Text Field | short single-line answer |
| Textarea Field | longer message |
| Email Field | email address, validated automatically |
| Phone Field | telephone number (dial pad on mobile) |
| URL Field | web address |
| Number Field | number, optional min/max |
| Date Field | date, date-and-time, or time |
| Select Field | pick one from a defined list |
| Multi-Choice Field | pick several |
| Checkbox Field | single checkbox, e.g. consent |
| Hidden Field | silently captured value (campaign ID, source page) |

Every field has a **Label** (customer-facing) and a **Field Name** (machine name used in the
notification email; derived from the label when blank). Common properties: Required, Placeholder,
Help text, Default value. Advanced tab: **Validation Pattern (regex)** + **Pattern Error Message** (on
Text, Phone and URL), and **Autocomplete** on Text Field (On, Off, Full name, Given name, Family name,
Email address, Telephone number, Organization, Street address, Postal code, Country name; default
None). Phone, URL and Email set their autocomplete tokens automatically. **Field names must be
unique** — the editor warns and names the offender on publish, drafts tolerate duplicates.

**Form Content** container accepts regular CMS components (text, images, columns, cards, HTML) around
the fields — intros, side-by-side layouts, legal text, visual grouping; fields can sit inside it too.
Its panel has **Width (%)** and **Max Width (px)** (empty = fill the form) plus alignment and spacing.
A Form Content container cannot nest inside another, and a form cannot be dropped inside one.

Form roots carry **no colour settings** — colours belong to the hosting content (see Embedding).
<https://docs.hyva.io/hyva-commerce/features/form-builder/user-guides/building-forms.html>

## Sending and recipients

Submissions are delivered as **email** and optionally to a **webhook**. They are **not stored in the
admin** — there is no submissions grid, the email is the record. Set at least one recipient or a
webhook.

Two homes, deliberately split:

- **Form Settings > Submission** (gear button in the editor header) — recipients, subject, webhook.
  Apply on save, no publish, unaffected by content rollback. Saving these while the canvas has unsaved
  content edits does not re-render the canvas, so a warning only catches up on the next canvas edit or
  page reload.
- **The form root's property panel** — submit button label, success message and content, reply-to
  field, conditional recipient routing. Versioned with the content, live on publish.

**Recipients** — comma-separated addresses in **Recipient (To)** / **(Cc)** / **(Bcc)**. To may be
blank only when delivering to a webhook.

**Conditional Recipients** (root → Advanced) — one dropdown field routes the email. Pick the field and
fill a recipient box per option; a mapped option goes to those addresses and **not** to Recipient (To),
while blank or unmapped answers fall back to Recipient (To). Cc/Bcc are copied either way. One routing
field per form, dropdown fields only. Routing remembers the field itself, so renaming the field or its
Field Name keeps the mapping; deleting the field falls back to Recipient (To) with a note in
`hyva_cms.log`.

**Reply-To Source** (root → Advanced) — pick one of the form's email fields; the submitted value
becomes the Reply-To when the field was filled in with a valid address, otherwise the store sender is
used.

**Email Subject** supports tokens `{{var field.<field_name>}}`:

```text
New inquiry from {{var field.name}}
```

Several tokens can be combined (`{{var field.name}} ({{var field.email}})`); unmatched tokens render
blank. Preview submissions prefix `[test]`.

**After submitting** (root → Content): **Success Message**; **Success Content** = **Redirect URL**
(default) or **CMS Block**; **Success Redirect URL** (blank keeps the customer on the page, and the
success message replaces the form — the out-of-the-box behaviour; filled in, the customer lands on the
target page and the message travels with them as a page message); **Success Content Block** (renders in
place of the form, and the success message is *not* also shown). A carried-over message needs a page
your store renders. A deleted, disabled or out-of-store-view block falls back to the success message,
or to "Thank you. Your message has been sent." Customers without JavaScript get a plain confirmation
page outside the theme. The canvas never renders the success state — check it with a test submission.

**Webhook** (Form Settings > Submission): **Send Submissions To URL** and **Send Format**
(Form-encoded — default; JSON flat fields; JSON with form context). Always a **copy**, never a
replacement for the email; set both and both fire. A form with **no recipient and no webhook** still
submits and shows the success message, but nothing is sent or stored — the editor warns once the form
has been saved.
<https://docs.hyva.io/hyva-commerce/features/form-builder/user-guides/sending-and-recipients.html>

## Spam protection

**Honeypot** — on every form, automatic, nothing to configure. Invisible to real visitors; a bot that
fills it in has its submission silently discarded while still seeing a normal success message. Disable
by clearing `Stores > Configuration > Hyvä Commerce > Form Builder > Security > Honeypot Secret`.

**CAPTCHA** — opt-in per form, two steps: (1) in the editor, **Settings** → **Submission** → **Enable
CAPTCHA** (an entity setting, so saving suffices — no publish, and content rollback leaves it alone);
(2) `Stores > Configuration > Security > Google reCAPTCHA Storefront` with site and secret keys —
Form Builder registers its own reCAPTCHA slot automatically. Enabling CAPTCHA without store-level keys
makes the editor warn once the form is saved, and submissions are rejected with the generic security
message.
<https://docs.hyva.io/hyva-commerce/features/form-builder/user-guides/spam-protection.html>

## Testing a form

| Where | Submit button | What it tests |
|---|---|---|
| Editor canvas | disabled ("Submitting is disabled in the editor. Test submissions from the full-screen preview.") | nothing — the click selects the component |
| The form's own preview | live | the **draft**, as last saved |
| Preview of a page/block embedding the form | live | the **published** form |
| Storefront | live | the published form, as a real customer submission |

Own-form test: save (the preview shows what is saved), **Preview → Open in New Tab**, submit. A form
never published is testable as long as **Enable Form** is on. Embedded test: preview the hosting page —
publish the form first, since the page embeds the published version.

A test really sends: the email goes to the configured recipients with `[test]` prefixed last (never
translated, so nothing in the subject can interpolate it away); the webhook fires with
`X-Hyva-Form-Test: 1`; the customer-side behaviour (success message / redirect / CMS block) is exactly
what goes live; nothing is stored. Spam protection still applies — the honeypot is not rendered in a
preview so there is nothing to trip, but CAPTCHA is **not** skipped.

Cannot send when: **Enable Form** is off ("This form is no longer available." — publishing and
enabling are separate); the form has no destination (own-form preview warns, embedding-page preview
does not); CAPTCHA on but reCAPTCHA unconfigured (same split in warnings); the **preview link was
edited** — test status is derived server-side from the link's signature, so an edited link is treated
as an ordinary storefront submission (validated against published, sent unmarked). A preview opened for
a non-default store view still submits in the default store's scope, so store-specific copy or
recipients are better checked on the storefront after publishing.
<https://docs.hyva.io/hyva-commerce/features/form-builder/user-guides/testing-a-form.html>

## Embedding a form

A form is always addressed by its **identifier**, and only the **published** version of an **active**
form renders. If the form is missing, inactive or never published, the embed renders nothing and the
page is unaffected. A form carries its own compiled Tailwind CSS, so it renders fully styled on any
page — category, product or custom routes, not just Hyvä CMS pages.

**Hyvä CMS editor** — `Add a Component` → **Hyvä CMS Form** → pick the form in the property panel
(listed by identifier) → save/publish. Its **Design** tab has **Background Color** and **Text Color**,
which style the card the form renders in (`hyva_form_widget` includes
`Hyva_FormBuilder::etc/hyva_cms/form_design_colors.json`) — this is why roots carry no colours.

**Magento widget** — `Content → Elements → Widgets` → `Add Widget` → type **Hyvä CMS Form** → storefront
properties + layout update → pick the form.

**Widget shortcode:**

```html
{{widget type="Hyva\FormBuilder\Block\Widget\Form" form_identifier="contact_us"}}
```

**Layout XML:**

```xml
<referenceContainer name="content">
    <block class="Hyva\FormBuilder\Block\Widget\Form">
        <arguments>
            <argument name="form_identifier" xsi:type="string">contact_us</argument>
        </arguments>
    </block>
</referenceContainer>
```

**PHTML** — declare `Hyva\FormBuilder\Block\Widget\Form` in layout and `getChildHtml('hyva_form_block')`,
or build it dynamically:

```php
<?= $block->getLayout()
    ->createBlock(\Hyva\FormBuilder\Block\Widget\Form::class)
    ->setFormIdentifier('contact_us')
    ->toHtml(); ?>
```

<https://docs.hyva.io/hyva-commerce/features/form-builder/user-guides/embedding-a-form.html>

## Creating a custom field

Four artifacts: a component declaration, a `FieldDescriptor` + DI entry, a storefront template at the
convention path, and an entry in the field's **direct parent's** `accepts` list. No PHP changes to the
form-builder package.

**1. Declaration** — `require_parent: true` so it never appears as a top-level pick. Do **not** set
`context_flags` on a field: roots filter children via `accepts`, not context flags. Expose exactly the
config keys the descriptor reads and no more (the shipped fields are held to this by a parity test),
and follow the convention of putting `pattern` / `pattern_message` in `advanced`:

```json
{
  "form_field_phone_e164": {
    "label": "Phone Field (E.164)",
    "description": "Single-line phone input with E.164-style validation.",
    "category": "Form Fields",
    "require_parent": true,
    "content": {
      "label":       { "type": "text", "label": "Label", "default_value": "Phone" },
      "field_name":  { "type": "text", "label": "Field Name", "default_value": "" },
      "placeholder": { "type": "text", "label": "Placeholder", "default_value": "" },
      "required":    { "type": "boolean", "label": "Required", "default_value": false }
    },
    "advanced": {
      "pattern":         { "type": "text", "label": "Validation Pattern", "default_value": "^\\+?[0-9 .-]{6,20}$" },
      "pattern_message": { "type": "text", "label": "Pattern Error Message", "default_value": "" }
    }
  }
}
```

**2. Field descriptor** implementing `Hyva\FormBuilder\Api\FieldDescriptorInterface`:
`getComponentName()` returns the component name, `getType()` the validator type token,
`extractRules()` reads editor-set properties off the saved node into the rule bag (via
`FieldRuleNormaliser`), `ruleKeys()` lists the keys `extractRules()` reads — keeping descriptor and
declaration in lockstep. `module-form-builder/src/Model/Submission/FieldDescriptor/PhoneField.php` is
the copy-and-adjust starting point.

```xml
<type name="Hyva\FormBuilder\Model\Submission\FieldDescriptorPool">
    <arguments>
        <argument name="descriptors" xsi:type="array">
            <item name="form_field_phone_e164" xsi:type="object">
                Acme\FormBuilderPhoneField\Model\Submission\FieldDescriptor\PhoneField
            </item>
        </argument>
    </arguments>
</type>
```

`FieldDescriptorPool` drives both the storefront Alpine pre-flight and the server-side
`SchemaCompiler`. Once registered, the field's payload key joins the validator's known-fields list and
a `Label: Value` row appears in the email body. **Without the descriptor entry, submissions for the
field are rejected as an "unknown field"** — a field that renders but has no descriptor never submits.

**3. Storefront template** at the convention path
(`view/frontend/templates/elements/form_field_phone_e164.phtml`) — no `template:` key needed. Two
non-obvious details: the Hyvä CMS renderer **flat-sets** each JSON node key onto the block, so
`$block->getData()` *is* the property bag and `$block->getData('data')` returns null; pass the bag to
`FormRenderer::extractFieldData()` for the common properties (`uid`, `field_name`, `label`,
`help_text`, `default_value`, `required`, plus derived `input_id` / `help_id` / `error_id`) and read
only per-field extras off `$data`. The extractor's `field_name` is already the wire name the schema
compiler uses — never derive your own.

The CSP-safe binding block every shipped field template repeats on its `<input>` (no `x-model`, no
`syncValue`):

```php
data-field-name="<?= $escaper->escapeHtmlAttr($fieldName) ?>"
data-field-uid="<?= $escaper->escapeHtmlAttr($uid) ?>"
<?php if ($helpId): ?>aria-describedby="<?= $escaper->escapeHtmlAttr($helpId) ?>"<?php endif; ?>
aria-errormessage="<?= $escaper->escapeHtmlAttr($errorId) ?>"
:aria-invalid="fieldHasError"
<?php if (!$isPreview): ?>:value="fieldValue"<?php endif; ?>
@input="onFieldInput"
@blur="onFieldBlur"
```

Keep this shape plus the per-field error block and the JSON submission path, error binding and
ARIA-live announcements work with no JavaScript from your module. Render the default into both the
static `value="…"` and the `:value` mirror, but **omit the mirror when `$block->validPreview()`** so an
edited Default Value repaints live in the canvas instead of being pinned to the seeded Alpine state.
Reference templates: `module-form-builder/src/view/frontend/templates/elements/fields/` (start from
`fields/text.phtml` for a single-line input).

**4. Allow it in a parent.** Single-page forms: the root's `accepts` is the gate. Step-based forms:
`form_step`'s `accepts` is the gate — do **not** add the field to a step-based root's accepts, or the
editor offers it as a sibling of the steps, outside any step. Shipped declarations are closed lists, so
this means a **full override**: copy the whole shipped declaration verbatim, append your component to
`children.config.accepts`, and **pin `"template": "Hyva_FormBuilder::elements/form_step.phtml"`** —
without it Hyvä resolves the declaring module's convention path (yours), which does not exist, and
every form step stops rendering. Sequence your module after `Hyva_FormBuilder` in `module.xml`.
Re-check the override when upgrading. A registry for `accepts` lists may come later.

Bespoke property-panel inputs are ordinary Hyvä CMS custom field types, not anything form-specific —
see `cms-component-development.md`.
<https://docs.hyva.io/hyva-commerce/features/form-builder/devdocs/create-a-custom-field.html>

## Custom validation

The storefront pre-flight mirrors the compiled rules (required, lengths, pattern) as a convenience
only; the server recompiles the schema from the **published** tree on every POST and enforces it there.

Reuse the built-in rule keys wherever possible so client and server stay aligned: `required`,
`min_length`, `max_length`, `pattern`, `pattern_message`, `allowed_values`. Only add bespoke keys for
things the built-ins cannot express (a date range, an uploaded file's MIME type, a checksum) — emit
them from `extractRules()` and read them back off the `FieldRule`.

Implement `Hyva\FormBuilder\Api\FieldValidatorInterface`; its single method returns the error message
or `null`:

```php
<?php
declare(strict_types=1);

namespace Acme\FormBuilderPhoneField\Model\Submission\FieldValidator;

use Hyva\FormBuilder\Api\FieldValidatorInterface;
use Hyva\FormBuilder\Model\Submission\FieldRule;

class PhoneValidator implements FieldValidatorInterface
{
    public function validate(FieldRule $rule, mixed $rawValue): ?string
    {
        $value = is_string($rawValue) ? trim($rawValue) : '';
        if ($value === '') {
            return $rule->required ? (string)__('This field is required.') : null;
        }
        // E.164: optional leading +, 8 to 15 digits, nothing else.
        if (!preg_match('/^\+?[0-9]{8,15}$/', preg_replace('/[ .\-]/', '', $value))) {
            return $rule->patternMessage ?: (string)__('Enter a valid phone number.');
        }
        return null;
    }
}
```

The pool dispatches **every** field to its validator, including empty optional ones — handle the empty
case yourself (return `null` for a blank optional field, the required message for a blank required
one) before applying type-specific logic, and prefer the editor-set `patternMessage` so error copy
stays editable.

Register it keyed by the token the descriptor's `getType()` returns:

```xml
<type name="Hyva\FormBuilder\Model\Submission\FieldValidatorPool">
    <arguments>
        <argument name="validators" xsi:type="array">
            <item name="phone" xsi:type="object">
                Acme\FormBuilderPhoneField\Model\Submission\FieldValidator\PhoneValidator
            </item>
        </argument>
    </arguments>
</type>
```

`PayloadValidator` dispatches `pool->get($rule->type)->validate(...)` and **falls back to the text
validator for unknown tokens** — so if `getType()` and the pool key disagree, your check silently
never runs.

The pool is per-field. Genuinely cross-field rules (confirm-email equals email, a total summing its
parts) need a plugin on `Hyva\FormBuilder\Model\Submission\PayloadValidator::validate()`, which sees
the whole submitted set.

Reference: `src/Api/FieldValidatorInterface.php`, `src/Model/Submission/FieldValidatorPool.php`,
`PayloadValidator.php`, `SchemaCompiler.php` + `FieldRule`, `src/etc/di.xml`.
<https://docs.hyva.io/hyva-commerce/features/form-builder/devdocs/add-custom-validation.html>

## Security gates

Gates are composed in `di.xml` through `Hyva\FormBuilder\Model\Security\SecurityGuard`'s **ordered**
`gates` argument; `SecurityGuard` walks it in order and the first rejection stops the submission.
Shipped order: form key → honeypot → CAPTCHA.

Two interfaces: `Hyva\FormBuilder\Model\Security\GateInterface` (general) and `CaptchaGateInterface`
(specialisation for CAPTCHA providers, bound as a preference — which is what makes a provider swap a
one-liner). A gate's single method is
`check(RequestInterface $request, FormInterface $form): Verdict`.

```php
class HCaptchaGate implements CaptchaGateInterface
{
    public function __construct(private readonly FormSubmissionSettingsReader $settingsReader) {}

    public function check(RequestInterface $request, FormInterface $form): Verdict
    {
        if (!$this->settingsReader->fromForm($form)->isCaptchaEnabled()) {
            return Verdict::pass();
        }
        $token = (string)$request->getParam('h-captcha-response', '');
        if ($token === '' || !$this->verifyWithHCaptcha($token)) {
            return Verdict::rejectCaptcha();
        }
        return Verdict::pass();
    }
}
```

Read the CAPTCHA toggle through `FormSubmissionSettingsReader`, not the published component metadata.

A gate never writes an HTTP response — it returns a `Verdict` and the controller maps it:

- `Verdict::pass()` — continue to the next gate
- `Verdict::silentSuccess()` — the honeypot's quiet trap: a fake success to the caller, no email sent
- `Verdict::rejectFormKey()` — CSRF form key missing or wrong
- `Verdict::rejectCaptcha()`, narrowed by `rejectCaptchaMissing()`, `rejectCaptchaInvalid()`,
  `rejectCaptchaError()` so the controller can say "please complete the CAPTCHA" instead of generic
  security copy

Registration — swap the CAPTCHA provider:

```xml
<preference for="Hyva\FormBuilder\Model\Security\CaptchaGateInterface"
            type="Acme\HCaptchaGate\Model\Security\Gate\HCaptchaGate"/>
```

Append an extra gate (`sortOrder` controls when it runs relative to the shipped three):

```xml
<type name="Hyva\FormBuilder\Model\Security\SecurityGuard">
    <arguments>
        <argument name="gates" xsi:type="array">
            <item name="acme_allowlist" xsi:type="object" sortOrder="40">
                Acme\AllowlistGate\Model\Security\Gate\AllowlistGate
            </item>
        </argument>
    </arguments>
</type>
```

Reference: `src/Model/Security/Gate/` (`MagentoReCaptchaGate.php` is the full-file example for a
provider swap; the honeypot gate is the one returning `silentSuccess()`), `Verdict.php`,
`SecurityGuard.php`, `src/etc/di.xml`.
<https://docs.hyva.io/hyva-commerce/features/form-builder/devdocs/add-a-security-gate.html>

## Webhook deliveries

Fire-and-forget: `WebhookDispatcher` runs **after** the response is flushed, nothing is retried, and a
non-2xx response, refused URL or transport failure is logged as a warning to `var/log/hyva_cms.log`
without changing what the submitter sees. Only `http` and `https` URLs are dispatched; localhost,
loopback and reserved IP literals are refused.

One POST per submission carrying the validator-clean payload — envelope keys, the form key and the
honeypot field are already stripped, so the body is exactly the fields declared in the published tree,
keyed by **Field Name**.

**Form-encoded** (`application/x-www-form-urlencoded`):

```text
name=Jane+Smith&email=jane%40example.com
```

**JSON (flat fields)** (`application/json`):

```json
{"name": "Jane Smith", "email": "jane@example.com"}
```

**JSON (with form context)** (`application/json`):

```json
{
  "form_identifier": "contact_us",
  "store_id": 1,
  "submitted_at": "2026-08-06T10:15:00+00:00",
  "test": true,
  "fields": { "name": "Jane Smith", "email": "jane@example.com" }
}
```

A Multi-Choice Field arrives as a JSON array in either JSON format and as repeated `field[]=…` pairs
in the form-encoded one.

Test marking: **every** test delivery carries `X-Hyva-Form-Test: 1`. Only the form-context format also
carries `"test": true` (between `submitted_at` and `fields`); the key is **absent** on a live
submission rather than `false`, so a storefront envelope stays byte-identical for existing receivers.
The two flat formats have no body flag (adding one would collide with a merchant field named `test`) —
**check the header**, which is the only marker present in all three formats. Receivers that act on
submissions (CRM, automation, mailing list) should drop or quarantine header-carrying deliveries
before merchants start testing.

Extension seams — both must preserve the marking:

```php
public function dispatch(
    FormSubmissionSettings $settings,
    string $formIdentifier,
    array $submittedFields,
    SubmissionContext $context
): void

protected function buildBody(
    string $format,
    string $formIdentifier,
    array $submittedFields,
    bool $isTest = false
): array   // returns [$body, $contentType]
```

`buildBody()` is `protected` for a subclass adding or reshaping a format; a bespoke format with no
test field still gets the header, because the header is added by `dispatch()`.
`SubmissionMailer::dispatch()` has the same shape and uses the context to prefix `[test]` onto the
subject. The context is a **required** argument on both on purpose — a caller that forgets gets a
`TypeError` rather than a quietly unmarked email.

Reference: `src/Model/Submission/WebhookDispatcher.php`, `SubmissionContext.php` +
`SubmissionContextResolver.php`, `FormSubmissionSettings.php` + `FormSubmissionSettingsReader.php`,
`src/Controller/Submit/Index.php`.
<https://docs.hyva.io/hyva-commerce/features/form-builder/devdocs/webhook-deliveries.html>

## Creating a custom form root

A root owns the storefront `<form>` envelope, carries the component-side metadata the pipeline reads,
and gates its children. Shipped: `single_step_form`, `multi_step_form`.

**1. Declaration** — `context_flags: ["hyva_form_root"]` is what makes the editor offer it in form
mode and lists it in the new-form dialog (your `label` and `description` are the type card, so write
the description for whoever is choosing). `root_only: true` is **required** — a form is a complete
`<form>`, so nesting one inside another produces invalid markup; without it your root appears in
nested pickers (including the **Form Content** container) and merchants can build a form inside a form.
`children.config.accepts` is the authoritative gate.

```json
{
  "survey_form": {
    "label": "Survey Form",
    "description": "Root for a multi-step survey with a progress bar. Accepts Form Step containers.",
    "category": "Form",
    "context_flags": ["hyva_form_root"],
    "root_only": true,
    "children": { "config": { "accepts": ["form_step"] } },
    "content": {
      "progress_bar_style": {
        "type": "select", "label": "Progress Bar Style", "default_value": "bar",
        "options": [ {"value": "bar", "label": "Bar"}, {"value": "dots", "label": "Dots"} ]
      }
    },
    "advanced": {
      "survey_campaign_id": { "type": "text", "label": "Campaign ID", "default_value": "" }
    }
  }
}
```

Reuse `form_step` when the structure is multi-step, reuse the shipped field components directly when
single-page, or ship your own container when a bespoke child shape is needed.

**2. Include the shared metadata** alongside your own keys in each tab block:

```json
"content": {
  "includes": "Hyva_FormBuilder::etc/hyva_cms/form_root_content_metadata.json",
  "progress_bar_style": { "...": "as above" }
},
"advanced": {
  "includes": "Hyva_FormBuilder::etc/hyva_cms/form_root_advanced_metadata.json",
  "survey_campaign_id": { "...": "as above" }
}
```

`includes` accepts an array, later files winning on a repeated key. Your inline keys beat the includes
(so you can retune a shipped field's label, comment or default without copying the file — the property
name stays the same, so the pipeline still reads it), and included fields lay out first, meaning an
overridden key moves to the end of the tab.

**The include is the published contract**: the pipeline looks each key up by name with no aliasing
layer. Renaming `success_message` to something themed simply is not picked up — the controller reads
blank and the customer sees no confirmation. A root skipping the includes still loads, but every
component-side property reads blank: default submit label, no success message, no reply-to. A blank or
unrecognised `success_content_type` resolves to `redirect_url`.

Do **not** declare recipients/subject/webhook/CAPTCHA on a root — they are entity columns and would
render inputs nothing reads; there is no dual-read fallback. Neither shipped root declares a `design`
block and neither template renders design values, so a root's Design tab reaches nothing: colours come
from the embed component (a deliberate reversal, because root-level background styling was lost on the
widget path, which is the most common placement).

**3. Root template** at `<Module>::elements/<component-name>.phtml` (convention path, no `template:`
key). Context comes from two view models: `Hyva\FormBuilder\ViewModel\Storefront\FormRenderer`
(submit URL, form key, honeypot name, entity settings, Alpine state seed) and `ChildElementRenderer`
(child components). On the storefront the block is a `Hyva\FormBuilder\Block\Form` carrying the
resolved `PublishedForm`; in the editor canvas it is the generic Hyvä CMS `Element` block with no
`getPublishedForm()`, which is why the branch below uses `instanceof`.

Three render paths — collapsing them either breaks testing or lets the canvas post for real:

| Path | How to spot it | Submit button |
|---|---|---|
| Storefront, or any preview embedding this form | `$block->getPublishedForm()` is a `PublishedForm` | live |
| The form's own full-screen preview | preview and **not** `isEditorCanvas()` | live, wired from the preview URL |
| The editor canvas | preview and `isEditorCanvas()` | inert, with a message |

```php
$isEditorCanvas = $isPreview && $formRenderer->isEditorCanvas();
$publishedForm = $block instanceof FormBlock ? $block->getPublishedForm() : null;

if ($publishedForm instanceof PublishedForm) {
    $submitUrl         = $formRenderer->getSubmitUrl();
    $formKey           = $formRenderer->getFormKey();
    $honeypotFieldName = $formRenderer->getHoneypotFieldName($formIdentifier);
    $alpineInitialState = $formRenderer->getAlpineInitialStateJson($formIdentifier, $publishedForm);
} elseif ($isPreview && !$isEditorCanvas) {
    $formIdentifier = $formRenderer->getPreviewFormIdentifier();
    if ($formIdentifier !== '') {
        $submitUrl = $formRenderer->getSubmitUrl();
        $formKey   = $formRenderer->getFormKey();
    }
    $alpineInitialState = $formRenderer->getPreviewInitialStateJson($children, $formIdentifier);
} else {
    $alpineInitialState = $formRenderer->getCanvasInitialStateJson($children);
}
```

Pieces every root template builds on:

- `$block->validPreview()` — true in any preview including the canvas; combine with
  `FormRenderer::isEditorCanvas()` rather than treating every preview as the canvas.
- `$block->getData('children')` — child nodes, rendered via
  `ChildElementRenderer::renderChildHtml($child)`. Properties are flat-set, so `form_identifier`,
  `submit_button_label` and your own keys all come from `$block->getData('…')`.
- `FormRenderer::getSubmissionSettings($formIdentifier)` — the entity settings value object.
- `FormRenderer::isSavedForm($formIdentifier)` — false until a saved entity backs the render; keeps
  advisory callouts off a brand-new form's canvas.
- `FormRenderer::getFormTitle($formIdentifier)` — the form's accessible name; returns `''` when
  nothing resolves, so keep a fallback.
- `FormRenderer::getSubmitUrl()` / `getFormKey()` — controller URL and CSRF token for hidden inputs.
  On a preview render the submit URL echoes the preview parameters, which is what lets the server
  classify the submission as a test.
- `FormRenderer::getHoneypotFieldName($formIdentifier)` — per-(store, form) HMAC-derived input name;
  render the honeypot **only on the storefront**.
- `getAlpineInitialStateJson(...)` / `getPreviewInitialStateJson($children, $formIdentifier)` /
  `getCanvasInitialStateJson($children)` — the `hyvaFormBuilder` state seed. The factory reads it from
  a `<script type="application/json" data-initial-state>` element inside the root, not an `x-data`
  literal (the CSP-safe Alpine build cannot eval one) and not an attribute.
- `FormRenderer::isReCaptchaConfigured()`, `getReCaptchaInputHtml()`,
  `getReCaptchaLegalNoticeHtml()` — server-rendered reCAPTCHA fragments, gated on the entity toggle.
- `FormRenderer::renderFormScriptHtml()` — the shared `hyvaFormBuilder` script; echo once from the
  root (shipped roots render it right after the closing `</form>`). A named layout block dedupes it, so
  several forms on one page emit it once, and it only ships on pages that render a form.

The `data-hyva-form-result="success"` div bound to `x-html="resultMessage"` is the **only** place a
confirmation renders — the includes supply the settings, not the surface, so dropping the div leaves a
successful submitter looking at nothing.

**4. Register extra root settings** that the submission side must read.
`progress_bar_style` is presentational and the template reads it straight off the block — nothing
further needed. A submission-side value must be registered in `RootMetadataPool`, a registry rather
than a passthrough (which is what keeps `children`, `design`, `uid`, `_*` out of the metadata read):

```xml
<type name="Hyva\FormBuilder\Model\Submission\RootMetadataPool">
    <arguments>
        <argument name="keys" xsi:type="array">
            <item name="survey_campaign_id" xsi:type="string"/>
        </argument>
    </arguments>
</type>
```

The item value is the read-time default when the field was left blank. A custom key cannot clobber a
standard one (the standard key's coercion and default win), and non-scalar values fall back to the
registered default. **A setting needs both halves**: declared but unregistered saves into the tree and
never reaches `getMetadata()`; registered but undeclared reads the default forever.

Read it back with `$publishedForm->getMetadataValue('survey_campaign_id')`, typically from a plugin on
`WebhookDispatcher::dispatch()` or `SubmissionMailer::dispatch()`.

Reference: `src/etc/hyva_cms/components.json`, the two metadata include files,
`src/view/frontend/templates/elements/single_step_form.phtml` and `multi_step_form.phtml`,
`src/Model/Submission/RootMetadataPool.php`, `FormSubmissionSettingsReader.php`.
<https://docs.hyva.io/hyva-commerce/features/form-builder/devdocs/create-a-custom-form-root.html>
