---
name: hyva-checkout
description: Covers Hyvä Checkout development on Magento 2 — Magewire components and lifecycle hooks, hyva_checkout.xml step configuration and layout handles, the Form API and address form modifiers, the window.hyvaCheckout frontend API and its JS events, the Evaluation API and Place Order Services, payment and shipping integrations, and mandatory strict CSP / Alpine CSP rules. Use this skill when adding or reordering checkout steps, building or debugging a Magewire checkout component, adding/removing/relabelling shipping or billing address fields, adding a custom address EAV attribute, writing an EntityFormModifier, registering a payment or shipping method renderer, adapting a Luma/Knockout payment module to Hyvä Checkout, writing a Place Order Service or a 3DS/redirect flow, registering a frontend validator or executable, hooking checkout JS events, fixing CSP violations or inline scripts in checkout templates, or troubleshooting Magewire 404s, missing totals, or "Main wire element could not be found" — keywords: hyva_checkout.xml, hyvaCheckout, Magewire, wire:model, wire:auto-save, EntityFormModifierInterface, EvaluationInterface, EvaluationResultFactory, PlaceOrderServiceProvider, registerMethod, registerValidator, hyva_checkout_components.xml, registerInlineScript, Alpine CSP.
---

# Hyvä Checkout

Hyvä Checkout is a commercial, licensed replacement for the Luma checkout, built on **Magewire**
(a Livewire port for Magento) with **Alpine.js**. It is server-rendered and component-based: the
checkout is an empty shell, components are registered in layout XML and moved into steps, and steps
come from `etc/hyva_checkout.xml`.

Written for a developer who knows Luma checkout / Knockout but not Magewire. The biggest mental
shifts: **the payment method no longer places the order** (a Place Order Service does), the
**payment step can be anywhere**, backend PHP drives frontend behaviour through the **Evaluation
API**, and from 1.3.x **strict CSP is mandatory and cannot be disabled**.

Always note the version a feature landed in — this codebase's constraints matter more here than in
most Magento work. Key gates: 1.1.0 Form API, 1.1.13 Evaluation batch/navigation/redirect + storage
API, 1.1.21 `modifyField*`, 1.1.27 `wire:auto-save`, 1.3.0 strict CSP, 1.3.3/1.3.4
`hyvaCheckout.api`, 1.3.6 rewritten JS payment API (needs >= 1.3.5), 1.3.12 payment-availability
security fix, 1.3.1000-beta1 address EAV attributes (beta), 1.4.0-beta1 Magewire v3.

**Common project shape.** Many Hyvä projects keep all client code in `vendor/<vendor>/*`
composer packages rather than `app/code`, often including `module-<feature>-hyva-checkout` /
`-hyva-compat` adapters for third-party payment modules. Where each package is its own git
repository, changes made in `vendor/` must be committed there too or the next
`composer install` wipes them. Flush the cache after PHP/XML changes
(`bin/magento cache:flush`); `.phtml`, layout and DI changes all need one. Route every
customer-facing string through `__()` for each store locale.

## References

- `references/architecture-and-magewire.md` — how Hyvä Checkout differs from Luma, install/upgrade/
  admin config, Tailwind styling, and the full Magewire primer: component declaration, lifecycle
  hooks, `wire:` bindings, emit messages, form components, Alpine `$wire`, vanilla `Magewire.find()`,
  and the common failure modes (Magewire 404, fallback theme, wrong totals).
- `references/checkout-xml-and-steps.md` — `etc/hyva_checkout.xml` element/attribute reference,
  config merging, step conditions, the layout handle processing order for base and child checkouts,
  `hyva_checkout_components` + `<move>`, two-column and accordion layout recipes, server-side
  `hyva_checkout_*` Magento events, totals sort order, customer comment in emails.
- `references/form-api.md` — the four pieces of a Magewire-driven form (layout, `AbstractForm`,
  `AbstractEntityForm`, save service), elements vs fields, element/field factories and their
  fallback tables, renderers and accessories in `hyva_checkout_form_elements`, targeted/wrapping/
  conditional rendering, the nine modification hooks with signatures, client-side validation rules,
  and `wire:auto-save`.
- `references/form-customization.md` — customizing the shipping/billing address forms:
  `EntityForm*` interfaces, writing and registering an `EntityFormModifierInterface` with the right
  `sortOrder`, `modifyField()` helpers, HTML field attributes, why `setValue()` only works in
  `form:*:updated`, interdependent fields, ancestor/relative elements, and adding custom address EAV
  attributes (beta).
- `references/frontend-api-events-and-csp.md` — `window.hyvaCheckout` sub-namespaces, init sequence,
  extending the API safely, the container → template-directory map for JS blocks,
  `hyvaCheckout.api.after()`, `storage`, `evaluation` registration functions, the full window event
  table, the Frontend API backport package, and everything strict CSP: `registerInlineScript()`,
  moving scripts to page load, Alpine CSP rules, shared theme components.
- `references/evaluation-and-place-order.md` — `EvaluationInterface::evaluateCompletion()`, all ten
  result types with capabilities and version gates, custom result types and processors, then the
  Place Order Service: flow, `AbstractPlaceOrderService` method table, DI registration per payment
  code, the 3DS modal example, exception handling and the Messenger component.
- `references/payment-integration.md` — what a payment integration owns, a Luma→Hyvä mapping table,
  renderer registration under `checkout.payment.methods`, icon/subtitle metadata, gating the button
  with `Blocking`/`Success`, the PSP iframe + `wire:ignore` pattern, the full
  `hyvaCheckout.payment.registerMethod` contract with its deprecations, availability filtering and
  the 1.3.12 security fix, zero-subtotal and auto-select, shipping methods, and the autocomplete /
  guest-to-customer abstraction layers.

## Pitfalls

- Never assume the payment step is last, and never convert a quote to an order in a payment component or PSP callback — use a Place Order Service.
- Give a Magewire component template exactly one root DOM element; leading text counts as a second root and breaks DOM patching.
- Never declare `$id`, `$name`, `$rules`, `$messages`, `$loader` or any other reserved Magewire property on your component.
- Put no inline `<script>` inside a Magewire component template — extract it to a block in `magewire.plugin.scripts` via the `hyva_checkout` handle, or it silently never runs under CSP.
- Add `<?php $hyvaCsp->registerInlineScript() ?>` immediately after every closing `</script>` on a checkout page.
- Use `x-data="initFoo"` (registered name, no parentheses) and method references in `x-on:`/`x-init`; replace `x-model` with `x-bind:value` + `x-on:input`.
- Set `setValue()` / `empty()` only inside `form:billing:updated` / `form:shipping:updated`; in `form:build` they are silently discarded.
- Do not add or remove fields in `form:build`, and never change element relationships in `form:build:magewire` — fields render twice.
- Always give every `entityFormModifiers` item an explicit `sortOrder`; core uses 0–999, so start at 1000.
- Read HTML field attributes with `$field->getAttributes()[$code]`, never `getAttribute($code)` — that returns the EAV attribute model.
- Match the block `as` alias exactly to the payment method code, or `carrierCode_methodCode` for shipping, or the template never renders.
- Prefer an `ErrorMessage` evaluation result over `Blocking` — nothing unblocks the checkout automatically.
- Wrap SDK-rendered DOM (iframes especially) in `wire:ignore` or the next Magewire roundtrip wipes it.
- Wrap any `hyvaCheckout.*` use on page load in `hyvaCheckout.api.after()`; never target elements by id/class in an API extension.
- `wire:auto-save` requires a matching `wire:model.defer`, and `wire:submit.prevent` conflicts with `hyva.formValidation` — validate first, then call `$wire`.
- Persist a selected payment method through `PaymentMethodManagement::set()` and read the quote via `CartRepositoryInterface`, not the session cache (1.3.12 security fix).
- Add `Hyva_Checkout` to your module's `<sequence>` when shipping checkout layout XML from a module.
- Custom address EAV attributes need `customer_register_address` in `used_in_forms`, and on Magento Open Source their values are **not** persisted for you.
