# Hyvä Knowledge Skills

Reference [Agent Skills](https://code.claude.com/docs/en/skills) for **Magento 2
Hyvä** development. Seven skills, 51 files, 16,228 lines — distilled from the
official Hyvä documentation and verified against a real Hyvä 1.5 / Magento 2.4.7
install.

Works in **Claude Code**, **Antigravity**, **Codex** and any other agent that
reads the open Agent Skills format (a `SKILL.md` with YAML frontmatter).

> **Unofficial.** Not affiliated with, endorsed by, or supported by Hyvä Themes.
> Derived from the public documentation at [docs.hyva.io](https://docs.hyva.io).
> Hyvä Theme, Hyvä Checkout, Hyvä Commerce, Hyvä Enterprise and the Hyvä UI
> Library are **commercial products requiring a licence** — these skills describe
> them, they do not give you access to them. See [ATTRIBUTION.md](ATTRIBUTION.md).
>
> **Looking for official tooling?** Hyvä maintains
> [hyva-themes/hyva-ai-tools](https://github.com/hyva-themes/hyva-ai-tools)
> (OSL-3.0). Those are *task* skills — "create a child theme", "compile
> Tailwind", "create an Alpine component". These are *reference* skills that
> explain how the platform behaves. They complement each other; install both.

## The skills

| Skill | Lines | Covers |
| --- | --- | --- |
| `hyva-theme` | 4,097 | Install & versions, child themes, Tailwind workflow, view models, templates & layout handles, Alpine + `window.hyva`, strict CSP, CMS content & Tailwind JIT, compat modules, deployment & performance |
| `hyva-commerce` | 4,507 | Hyvä CMS & Liveview Editor, dashboard widgets, admin theme, Menu Builder, Form Builder, Email & Newsletter Templates, Media Optimization, Image Editor, Category Merchandiser, Linked Products |
| `hyva-checkout` | 2,718 | Magewire components & lifecycle, `hyva_checkout.xml` & steps, Form API, form customization, `window.hyvaCheckout` frontend API & events, Evaluation API, Place Order Services, payment & shipping integration, CSP |
| `alpinejs-csp` | 1,634 | Alpine v3 under Hyvä's CSP build: the `Alpine.data()` pattern, every directive & magic with its CSP verdict, official plugins, state/event/lifecycle patterns |
| `hyva-admin` | 1,453 | Declarative adminhtml grids via `hyva_admin` grid XML — full node reference, data sources, filters, row/mass actions, exports, PHP contracts, events |
| `hyva-enterprise` | 1,002 | B2B suite, Adobe Commerce-only features, GTM, Live Search / Product Recs / Data Connection, Edge Delivery Services, upgrade patterns |
| `hyva-ui-library` | 817 | Hyvä UI components & licensing, product gallery `view.xml`, CSS sliders, i18n, plus the free Hyvä Widgets module |

Each skill is a `SKILL.md` index plus `references/*.md` carrying the detail, so
your agent loads the entry point and pulls in only the reference file it needs.

## Install

### Claude Code — plugin marketplace

```bash
/plugin marketplace add makotokimura96/hyva-skills
/plugin install hyva-skills
```

### Any agent — install script

Clone once, then run it from the project you want the skills in:

```bash
git clone https://github.com/makotokimura96/hyva-skills.git

# all skills, auto-detected agent
./hyva-skills/install.sh

# a specific agent
./hyva-skills/install.sh claude
./hyva-skills/install.sh antigravity
./hyva-skills/install.sh codex

# only what you need
./hyva-skills/install.sh claude hyva-checkout alpinejs-csp

# globally, not per-project
./hyva-skills/install.sh antigravity --global

# list what is available
./hyva-skills/install.sh --list
```

Skills are **symlinked** by default, so `git pull` in the clone updates every
project at once. Use `--copy` when symlinks won't work (containers, some mounts);
re-run the script after pulling to update copies.

Supported: `claude`, `antigravity`, `codex`, `cursor`, `copilot`, `gemini`,
`opencode`.

### Manual

Every skill is a plain directory with a `SKILL.md`. Copy the ones you want into
whichever directory your agent reads:

| Agent | Project | Global |
| --- | --- | --- |
| Claude Code | `.claude/skills/` | `~/.claude/skills/` |
| Antigravity | `.agents/skills/` (legacy `.agent/skills/`) | `~/.gemini/config/skills/` |
| Codex | `.codex/skills/` | `~/.codex/skills/` |

## Usage

Agents load a skill when the request looks relevant, so mostly you just work:

- "Why is my Alpine dropdown rendering but not responding to clicks?"
- "Add a shipping-method field to Hyvä Checkout's address form"
- "Build an admin grid listing our custom entity with a CSV export"
- "Our Tailwind classes in CMS content aren't compiling"
- "Convert this Luma phtml to Hyvä"

Or invoke one directly: `/hyva-checkout`, `/alpinejs-csp`.

## Notable content

Some things in here you won't get from a quick docs skim:

- **Alpine CSP is stricter than the upstream docs say.** The bundle Hyvä ships
  (`alpine3-csp.js`, 3.14.3) uses a bare dot-path evaluator. It supports none of
  the `count++`, `count > 5`, `'Hello ' + name` or ternary forms that the current
  [alpinejs.dev/advanced/csp](https://alpinejs.dev/advanced/csp) page advertises —
  that page documents a newer, more permissive build. Violations log a
  `console.warn` and the component silently does nothing, so they ship to
  production looking fine.
- **The stale `global::DiConfig` trap.** `setup:di:compile` reads a cached
  pre-merged DI config that is *not* invalidated when the module list changes,
  bakes `null` into required `array` arguments, and 500s every page. The failure
  then disables its own fix — `bin/magento cache:flush` reports *"There are no
  commands defined in the cache namespace"*. Flush **between** `setup:upgrade`
  and `setup:di:compile`, not at the end of your deploy.
- **Node daemons on Adobe Commerce Cloud** persist only on Pro Staging/Production
  in Cron mode, decided by `KillMode=process` vs `control-group` — not by
  configuration. `on_demand` is never safe there.
- **Beta surfaces flagged as beta.** Hyvä Commerce Form Builder and Email
  Templates have explicitly unstable PHP APIs; Form Builder is documented as
  pending security review and not production-suitable. Category Merchandiser
  doesn't support Adobe Commerce at all.

## Repo layout

```
skills/<skill-name>/
├── SKILL.md            frontmatter + index + pitfalls; loaded first
└── references/*.md      the detail, pulled in on demand
```

Keeping `SKILL.md` short and the bulk in `references/` is deliberate: the agent
reads the index, then loads only the reference file the task needs, instead of
pulling 4,000 lines into context to answer one question.

## Accuracy and scope

Written from the documentation as it stood in **August 2026**, against Hyvä
Theme 1.5.x / Magento 2.4.7. Hyvä moves fast — treat version-specific claims as
a starting point and check [docs.hyva.io](https://docs.hyva.io) for anything
critical. Every non-obvious claim in the references carries a source link.

## Contributing

Corrections very welcome, especially version drift. If something here
contradicts the official docs, **the official docs win** — open an issue or a PR.

Useful things to report:

- a claim that is wrong, or was right and has since changed
- a version constraint that has moved
- a missing source link, or one that 404s
- a code sample that does not run

Please keep the existing shape: facts with a source link, runnable specifics over
prose, and no invented class or config names. If you are unsure whether something
is true, leave it out rather than guessing.

## Licence

Documentation content: [CC BY 4.0](LICENSE). The `install.sh` script: MIT.
See [ATTRIBUTION.md](ATTRIBUTION.md) for the derivation and trademark notes.
