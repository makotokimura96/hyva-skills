---
name: alpinejs-csp
description: Alpine.js v3 as it actually behaves inside a Hyvä theme under strict CSP - the CSP-friendly build Hyvä ships, the Alpine.data() component pattern, every x-* directive and $ magic with its CSP verdict, the official plugins, and the state/event/lifecycle patterns Hyvä uses. Use this skill when writing or debugging any Alpine component in a .phtml template, choosing between x-data inline state and a registered Alpine.data() factory, wiring x-on/x-model/x-for/x-bind, using $store $watch $dispatch $refs $nextTick, adding an Alpine plugin, registering an inline script with a CSP nonce, converting a Luma/Knockout or Alpine V2 snippet, or investigating a component that renders but silently does nothing - keywords Alpine, alpine3-csp.js, x-data, Alpine.data, alpine:init, registerInlineScript, hyvaCsp, unsafe-eval, CSP violation, "unable to interpret the following expression".
---

# Alpine.js under Hyvä CSP

Alpine v3 is the only JS framework in a Hyvä storefront, and Hyvä ships the
**CSP-friendly build**, which is a far more restrictive language than the Alpine
you find in blog posts and in most of the upstream documentation examples. Almost
every Alpine snippet on the internet is a CSP violation here.

The failure mode is the dangerous one: a violating expression logs a
`console.warn` and the component **silently does nothing**. It does not throw, so
it reaches production looking fine.

## References

- `references/csp-mode.md` — **read this first.** Why the CSP build exists, what
  Hyvä actually ships (verified against the vendor bundle), the forbidden-vs-compliant
  table, the canonical component pattern, nonce registration, and a debug checklist.
- `references/directives.md` — every `x-*` directive: syntax, modifiers, an example,
  and whether it works in CSP mode.
- `references/magics-and-globals.md` — `$el $refs $store $watch $dispatch $nextTick
  $root $data $id $event` and `Alpine.data/store/bind`, with what is actually present
  in the shipped bundle.
- `references/plugins.md` — the official plugins (persist, intersect, collapse, focus,
  mask, morph, anchor, resize, sort), how to load one, and when it earns its weight.
- `references/patterns.md` — state, events, lifecycle, reactivity, async, extending
  Alpine, and the Alpine V2 leftovers to reject in code review.

## CSP rules

Non-negotiable under Hyvä's CSP build. Details and the full table are in `references/csp-mode.md`.

1. **A directive value may only be a property name or a dot path of property names.**
   Nothing else. No operators, parentheses, literals, or spaces.
2. Every operator, comparison, concatenation, ternary, and negation moves into a
   **getter** on the component; the directive references the getter by name.
3. Call a method as `@click="toggle"`, never `@click="toggle()"` — the resolved
   function is auto-invoked with the directive's params.
4. Assignment is forbidden anywhere. `open = ! open` becomes a `toggle()` method.
5. Never reference a global (`Math`, `document`, `console`, `window`) from an
   attribute. Do it in JS inside the component.
6. Components are registered factories: an inline `<script>` defines the factory and
   registers it on `alpine:init`; `x-data` names it. Arguments cannot be passed from
   `x-data="dropdown(true)"` — bake them into the factory.
7. Every inline `<script>` must go through `$hyvaCsp->registerInlineScript()` to get
   the page nonce, or CSP blocks it.
8. Modifiers are part of the attribute *name*, so they all work — `@click.outside`,
   `@keydown.window.escape`, `x-model.debounce.500ms`, `x-transition.duration.500ms`.
9. `x-for="item in items"` and `(item, index) in items` are fine — the directive
   parses the `… in …` form itself. A range like `x-for="i in 10"` is not; put the
   array in state.
10. `$event` dot paths resolve inside `x-on`, so `$event.detail` works and
    `$event.target.remove` works (function auto-invoked), but `$event.target.remove()`
    does not.
11. **Never add `x-data` to make a directive resolve — look up the tree first.** Scope is
    inherited, and this holds for *every* directive, not just event handlers: `@click`,
    `x-show`, `x-text`, `x-bind`/`:class`, `:value` + `@input`, `@change`, `@submit`, `x-if`
    and `x-for` all resolve through the whole ancestor chain. A property, getter or method on
    a grandparent already works where it stands, with no new wrapper. Adding `x-data` to a
    closer parent starts a **second, independent instance**. It is worst when the wrapper
    repeats a component an ancestor already has: `init()` runs twice, handlers mutate the inner
    copy while markup bound to the outer one never updates, and same-named properties shadow the
    ancestor's, so reads return the wrong instance. `$root` also re-points to the inner element.
    There is **no console warning** — the expression resolved fine. Put the member on the
    existing component; add `x-data` only when the block genuinely needs state of its own.

## Verify, don't trust the upstream page

The current <https://alpinejs.dev/advanced/csp> page documents a **newer and much more
permissive** CSP evaluator than the one Hyvä ships. The rules above were read out of
the shipped bundle,
`vendor/hyva-themes/magento2-theme-module/src/view/base/web/js/alpine3-csp.js`, at
Alpine **3.14.3**, as shipped by `hyva-themes/magento2-theme-module` **1.5.2**.
That evaluator is a bare dot-path lookup: it supports none of the `count++`,
`count > 5`, `'Hello ' + name` or ternary forms that page advertises. Treat the
upstream "not supported" list as the **floor, not the ceiling**.

Do not take 3.14.3 on trust — check the install in front of you. Read the version
string at the top of that file, and confirm the evaluator is still the dot-path
`reduce` quoted in `references/csp-mode.md`. Re-check after any Alpine or Hyvä
upgrade: a more permissive evaluator would relax every rule above.

## Debugging

Watch the browser console for:

```text
Alpine Error: Alpine is unable to interpret the following expression using the CSP-friendly build: "<expr>"
```

That is a `console.warn`, not an exception. A component that renders its markup but
responds to nothing is almost always this. `references/csp-mode.md` has the full
checklist.
