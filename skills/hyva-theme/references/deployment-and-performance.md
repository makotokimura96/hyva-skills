# Deployment and performance

## The one rule that governs Hyvä deploys

A Hyvä storefront's CSS is a **build artifact**. Nothing about Magento's own
deploy pipeline produces it. `setup:static-content:deploy` only *copies*
`web/css/styles.css` into `pub/static/…`; if the Tailwind build never ran, SCD
happily deploys nothing and the storefront renders unstyled.

So every deployment method below is the same three steps in a different wrapper:

1. Build the minified Tailwind stylesheet → `web/css/styles.css`
2. `bin/magento setup:static-content:deploy` (copies it to `pub/static`)
3. Ship `pub/static/` to the server

Build the stylesheet on a dev, staging or CI box — **not** on production.
Installing Node and a toolchain on a production server is unnecessary attack
surface.
<https://docs.hyva.io/hyva-themes/building-your-theme/deploying-hyva-to-production.html>

## Building the production stylesheet

```bash
cd app/design/frontend/My/theme/web/tailwind
npm run build
```

or from the Magento root, which is what CI usually wants:

```bash
npm --prefix app/design/frontend/My/theme/web/tailwind run build
```

In CI use `npm ci`, never `npm install` — `ci` installs the exact versions from
`package-lock.json` while `install` may drift to newer compatible ones. Add
`--ignore-scripts` to stop packages running lifecycle scripts, which is a
supply-chain guard:

```bash
npm ci --ignore-scripts
```

Hyvä 1.1.x used `npm run build-prod`. Current versions use `npm run build`. If
you inherit an old pipeline, that stale script name is a likely break.

The Default Theme's `.npmrc` sets npm's `min-release-age`: `7 days` was
introduced in Hyvä 1.5.1 and lowered to `1 day` in 1.5.2, matching pnpm's
default, because a week made freshly released packages uninstallable. If a build
refuses to pick up a new package version, check that value first.
<https://docs.hyva.io/hyva-themes/upgrading/upgrading-to-1-5-2.html>

### Audit your own deploy order

Most Magento deploy pipelines — Deployer (`.deployer/deploy.php`), Capistrano,
a CI script, ECE-Tools — run some variant of:

```text
composer install --no-dev
  → build Tailwind
  → setup:upgrade
  → setup:di:compile
  → setup:static-content:deploy <locales> -f
  → cache:flush
```

Tailwind before SCD is correct, for the reason above. But that trailing
`cache:flush` is a **trap worth checking in your own pipeline**: the documented
prevention for the stale-DI-config failure below is a flush **between
`setup:upgrade` and `setup:di:compile`**. A flush at the *end* cannot prevent a
poisoned compile — by the time it runs, the `null` is already baked into the
generated metadata, and (see below) `bin/magento cache:flush` may itself have
stopped working by then.

If your pipeline has a flush only at the end, move or duplicate it to sit
immediately before the compile. See
[the stale DI config trap](#the-stale-di-config-trap).

## Optimising static content deploy

Hyvä needs no LESS compilation, no JS bundling and no HTML minification, so
turning those off cuts SCD time substantially:

```bash
# Admin theme, en_US only
bin/magento setup:static-content:deploy -j 2 -f --no-parent --theme=Magento/backend en_US

# Frontend theme, skipping work Hyvä does not need
bin/magento setup:static-content:deploy -j 2 -f --area=frontend --no-parent \
  --no-less --no-js-bundle --no-html-minify --theme=Vendor/theme nl_NL de_DE
```

<https://docs.hyva.io/hyva-themes/building-your-theme/deploying-hyva-to-production.html>

### Two SCD failures specific to Hyvä

**`Compilation from source: LESS file is empty: frontend/Hyva/reset/xx_XX/css/email-fonts.less`**
— a warning, not a failure; compilation does not abort. Fix it properly by
upgrading `hyva-themes/magento2-email-module` to **>= 1.0.4**.

**SCD dies inside `tubalmartin/cssmin`.** Depending on the Tailwind version and
the classes a theme uses, Magento's CSS minifier can crash during
`setup:static-content:deploy`. Hyvä already emits minified CSS from `npm run
build`, so the built-in minification buys nothing — but CSS minification
**cannot be scoped per store view** (Magento always reads the global setting), so
on a mixed Hyvä/Luma instance you cannot simply switch it off. Enable it globally
and apply the community patch to `vendor/tubalmartin/cssmin/src/Minifier.php`
(it null-guards every `preg_replace*` result and casts to `(string)`):

```bash
bin/magento config:set dev/css/minify_files 1
```

<https://docs.hyva.io/hyva-themes/faqs/static-content-deploy-fails-with-css-error.html>
<https://docs.hyva.io/hyva-themes/faqs/troubleshooting.html>

## `app/etc/hyva-themes.json` and CI

`app/etc/hyva-themes.json` records which modules contribute Tailwind sources
when a theme's `styles.css` is generated. Without it the build finds no source
files and produces a useless stylesheet.

- **Hyvä ≥ 1.1.14** — regenerated automatically after `setup:install`,
  `setup:upgrade`, `module:enable` and `module:disable`. Normally CI needs to do
  nothing.
- **Hyvä ≤ 1.1.13** — `setup:upgrade`, `module:enable` and `module:disable`
  regenerate it, but `setup:install` does **not**. If a build runs
  `setup:install` with Hyvä packages already present, run
  `bin/magento hyva:config:generate` before building the stylesheet.

<https://docs.hyva.io/hyva-themes/building-your-theme/ci-cd-hyva-installation.html>

## The stale DI config trap

The highest-value thing to know about deploying Hyvä, because a green build is
not proof the environment is healthy.

`setup:di:compile` does **not** read your `etc/di.xml` files. It reads a cached,
pre-merged copy of the global DI configuration (cache id `global::DiConfig`),
and **that entry is not invalidated when the set of installed modules changes.**
If the cache was warmed before a Hyvä module was registered, the compiler bakes a
configuration that is missing that module's arguments and records an explicit
`null` for required `array` constructor arguments. At runtime PHP then throws:

```text
Hyva\Theme\Service\HyvaThemes::__construct():
  Argument #1 ($hyvaBaseThemes) must be of type array, null given

Hyva\BaseLayoutReset\Model\Layout\SpecialCaseLayoutFileReset\SpecialCaseLayoutResetPool::__construct():
  Argument #1 ($specialCases) must be of type array, null given
```

The tell is a required `array` argument receiving `null`, thrown through
`ObjectManager/Factory/AbstractFactory.php`. Every storefront page returns
HTTP 500.

**Why it happens is an ordering problem.** `composer install` only puts files on
disk; the module is not registered in `app/etc/config.php` until `setup:upgrade`
runs — but the very first `bin/magento` bootstrap *inside* that `setup:upgrade`
merges and caches the DI config using the **old** module list.

Two things make it nasty:

- In production mode, JS/CSS minification is active, so Hyvä's minifier-skip
  plugin resolves `HyvaThemes` for **every** asset.
  `setup:static-content:deploy` then fails with the same `TypeError` once per
  minifiable file — thousands of identical errors — and never completes.
- **The failure disables its own fix.** Once the compiled metadata is poisoned,
  `bin/magento` hits the same `TypeError` while building its command list and
  silently falls back to a minimal command set. The cache commands disappear:

```console
$ bin/magento cache:flush
There are no commands defined in the "cache" namespace.
```

  So a remediation script (or a pipeline) that ends in `bin/magento cache:flush`
  silently no-ops.

### The fix: flush immediately before compiling

```bash
composer install --no-dev            # or composer update
bin/magento setup:upgrade
bin/magento deploy:mode:set production --skip-compilation
bin/magento cache:flush              # drop the stale global::DiConfig FIRST
bin/magento setup:di:compile         # now compiles from the current di.xml
bin/magento setup:static-content:deploy -j 4
```

That single relocated `cache:flush` is the whole fix. If the CLI is already
degraded, clear the config cache backend directly instead:

```bash
redis-cli -n <config-cache-db> flushdb
bin/magento setup:di:compile
```

`--skip-compilation` is used because a plain `deploy:mode:set production` runs
both `setup:di:compile` **and** `setup:static-content:deploy`, and builds want to
run SCD themselves with specific themes, locales and a `-j` count.

Two properties worth internalising:

- **It is intermittent and not tied to a Magento version.** Whether the stale
  merge survives to `setup:di:compile` depends on build ordering and timing, so
  the same code can build cleanly on one run and fatal on the next — especially
  when builds share a host. Front-loading the flush removes the entry regardless
  of timing.
- **Only `array` and scalar arguments are affected.** Object arguments are
  auto-wired by the compiler even when the configuration is missing, so they
  never receive a bare `null`.

In build scripts, treat `There are no commands defined` in any `bin/magento`
output as a **hard failure** — it means the compile is already poisoned and every
later `cache:flush` in the script is doing nothing.

<https://docs.hyva.io/hyva-themes/faqs/stale-di-config-cache.html>
<https://docs.hyva.io/hyva-themes/faqs/troubleshooting.html>

## Capistrano

`capistrano-magento2` needs a custom Rake task, because it knows nothing about
Tailwind. Create `lib/capistrano/tasks/tailwind.rake`:

```ruby
namespace :deploy do
  desc 'Build tailwindCSS'
  task :hyva_tailwind_build do
    on roles(:all) do
      fetch(:hyva_tailwind_paths, []).each do |tailwind_path|
        within release_path + tailwind_path do
          execute :npm, :ci, "--ignore-scripts"
          execute :npm, :run, "build"
        end
      end
    end
  end
end
```

Declare the theme paths and hook the task ahead of SCD in `config/deploy.rb`:

```ruby
set :hyva_tailwind_paths, [
  'app/design/frontend/Vendor/ThemeOne/web/tailwind',
  'app/design/frontend/Vendor/ThemeTwo/web/tailwind'
]

before 'magento:setup:static-content:deploy', 'deploy:hyva_tailwind_build'
```

A successful production build lands between roughly 30KB and 150KB depending on
customisation — a wildly larger file usually means a dev/watch build got shipped.
<https://docs.hyva.io/hyva-themes/building-your-theme/capistrano-deployment.html>

## Adobe Commerce Cloud

Cloud is the awkward one: the build container has no Node, the build phase runs
before Magento is fully initialised, and generated files must appear in specific
phases.

### Provide Node as a platform dependency

Prefer this over fetching Node in the hook, because a `dependencies.nodejs` Node
is on `PATH` **at build time and at runtime** — and runtime is what Hyvä's Node
daemons need.

```yaml
dependencies:
    php:
        composer/composer: '2.x'
    nodejs:
        npm: "*"
```

Verify after deploy:

```bash
magento-cloud ssh -e <environment> -- 'node -v; command -v node'
```

If you run no Hyvä daemon and want Node off production entirely, install it with
NVM inside the build hook instead (build-only, removed afterwards).

### The build hook

```yaml
hooks:
    build: |
        echo "Building Hyvä Tailwind CSS with node $(node -v) / npm $(npm -v)"
        mkdir -p app/design/frontend/{VENDOR}/{THEME}/web/css/
        npm --prefix app/design/frontend/{VENDOR}/{THEME}/web/tailwind/ install --no-audit --no-fund --ignore-scripts
        npm --prefix app/design/frontend/{VENDOR}/{THEME}/web/tailwind/ run build
        # Drop this line if you run the CMS Tailwind Compiler daemon
        rm -rf app/design/frontend/{VENDOR}/{THEME}/web/tailwind/node_modules/
```

`mkdir -p …/web/css/` is not optional — Cloud build containers do not include
theme directories by default. If `npm --prefix` trips over a host-set
`NPM_CONFIG_PREFIX`, `unset NPM_CONFIG_PREFIX` before the npm calls.

With ECE-Tools, the Tailwind build must run **before**
`ece-tools run scenario/build/generate.xml`. Generate the CSS after that and SCD
never sees it:

```yaml
build: |
    set -e
    composer --no-ansi --no-interaction install --no-progress --prefer-dist --optimize-autoloader --no-dev
    ... Tailwind steps from above ...
    php ./vendor/bin/ece-tools run scenario/build/generate.xml
    php ./vendor/bin/ece-tools run scenario/build/transfer.xml
```

### Composer auth for the private Hyvä repo

Either commit `auth.json` alongside a scoped repository entry:

```json
"repositories": {
    "hyva-private-packagist": {
        "type": "composer",
        "url": "https://hyva-themes.repo.packagist.com/{{MERCHANT-ID}}/",
        "only": ["hyva-themes/*"]
    }
}
```

…or set `COMPOSER_AUTH` at **project** level (not environment level) in the Cloud
console, to keep credentials out of the repo.

### Two files you must commit

- `app/etc/hyva-themes.json` — the Cloud build phase runs before Magento is
  installed, so `hyva:config:generate` cannot run there. Generate it locally and
  commit it.
- `app/etc/config.php` — `ece-tools run scenario/build/generate.xml` only does
  build-time SCD if it can read the store/theme/locale matrix from this file. If
  it contains only the `modules` list, build-time SCD is skipped silently and no
  `pub/static/deployed_version.txt` is produced. Fix with
  `bin/magento app:config:dump` and commit the result (env-specific values stay
  in the uncommitted `env.php`).

### `.gitignore` breaks Tailwind v4 on Cloud

Tailwind v4's `@source` directive respects `.gitignore` when deciding what to
scan. Cloud's default `.gitignore` is an **allow-list**: a leading `*` ignores
everything, then `!` negations re-add specific paths. That leaves `vendor/`
ignored, so a child theme's `tailwind-source.css` cannot `@source` the parent
theme in `vendor/hyva-themes/magento2-default-theme`, and the build fails.

Replace it with a **deny-list** `.gitignore` — the standard Magento 2 one — which
lists what to exclude instead of excluding everything by default.
<https://docs.hyva.io/hyva-themes/building-your-theme/adobe-commerce-cloud-deployment.html>

## Node daemons on Adobe Commerce Cloud

Two Hyvä modules ship a long-running Node daemon: the CMS Tailwind compiler
(`hyva-themes/magento2-cms-tailwind-compiler`) and the response minifier
(`hyva-themes/magento2-minification`). Storefront theme CSS is **not** a daemon
concern — that is built in the build hook.

Both daemons need Node ≥ 20 at runtime, a home **in the web container** (php-fpm
reaches them on `127.0.0.1` or a `/tmp` socket, so a Cloud *worker* cannot be
used — different container, no shared loopback or `/tmp`), and a launch context
the platform does not reap.

**Whether the daemon survives is decided by infrastructure, not configuration:**

| Plan | Environment | Infrastructure | Daemon persists? |
| --- | --- | --- | --- |
| Pro | Production (3 nodes) | Dedicated IaaS | Yes |
| Pro | Staging / Staging2 | Dedicated IaaS | Yes |
| Pro | Integration | PaaS grid container | No |
| Starter | Production (`master`) | PaaS grid container | No |
| Starter | Staging / Integration | PaaS grid container | No |

So: **Pro Staging/Production in Cron mode only.** On Starter there is no
environment where it persists, production included.

The mechanism is one systemd setting. On a Pro node cron runs with
`KillMode=process`, so when `cron:run` exits systemd kills only the unit's main
process and leaves the `setsid`'d daemon running in the `cron.service` cgroup. On
a grid container cron runs `KillMode=control-group`, so the whole cgroup — the
daemon included — is torn down seconds after spawn. `setsid` does not help; the
kill is at cgroup level and `setsid` changes the session, not cgroup membership.

The definitive check, over SSH:

```bash
systemctl show cron.service -p KillMode 2>/dev/null || echo "systemctl unavailable"
```

Identifying the environment: `type: production` proves nothing (Starter `master`
reports it and is still a grid container). Combine plan and environment.

```bash
magento-cloud subscription:info plan          # e.g. magento/pro_core24
magento-cloud environment:info -e <env> type  # development | staging | production
magento-cloud environment:list
```

Only `magento/pro_*` plans get dedicated IaaS. `magento/starter*` and the
partner/developer/demo sandboxes (`magento/development`,
`magento/extension_developer`, `magento/sales_demo`) are all grid containers. A
quick outside tell: three selectable SSH nodes with numbered hosts
(`1.ent-<project>-…`) means dedicated VM; a single instance whose prompt ends in
`.0` means grid container.
<https://docs.hyva.io/hyva-themes/building-your-theme/adobe-cloud-node-daemons.html>

### Cron mode is the only safe mode on Cloud

`daemon_management` takes `off`, `cron` or `on_demand`. **Never use `on_demand`
on Adobe Commerce Cloud.** In that mode the daemon is spawned by a *web request*,
so php-fpm is its parent scope — and php-fpm on Pro Staging/Production is
supervised under runit with `KillMode=control-group`. Any php-fpm reload or
restart kills the whole cgroup, daemon included. It appears to work, then
vanishes on the next deploy. Always configure `cron`, where the Hyvä watchdog
(`DaemonWatchdog`, scheduled `* * * * *`) runs inside `bin/magento cron:run`.

### Installing daemon dependencies in the build hook

The runtime filesystem is read-only, so Node dependencies must be baked into the
image. The CMS Tailwind compiler pre-bundles its production dependencies and
needs no install step; the response minifier depends on `@swc/html` and does:

```yaml
hooks:
    build: |
        set -e
        composer install --no-dev
        # … storefront Tailwind build …
        npm --prefix vendor/hyva-themes/magento2-minification/node install --ignore-scripts
        php ./vendor/bin/ece-tools run scenario/build/generate.xml
        php ./vendor/bin/ece-tools run scenario/build/transfer.xml
```

**Never commit a locally built `node_modules`.** `@swc/html` ships its native
binary as platform-specific optional dependencies (`@swc/html-linux-x64-gnu` and
friends) and npm resolves only the one matching the machine it runs on. A
`node_modules` installed on macOS or arm64 fails to load on Cloud's linux-x64
container and the daemon crashes at startup. Run the install in the Cloud build
hook so the correct binary is fetched, and keep `node_modules` git-ignored — the
module's `node/.gitignore` already does.

### Configure via environment variables, not `env.php`

`app/etc` is a shared mount on Cloud, so avoid deploy-time writes to
`app/etc/env.php`. Use Magento's configuration environment variables in
`.magento.app.yaml`:

```yaml
variables:
    env:
        # Deployment config (the env.php equivalent, resolved at runtime)
        MAGENTO_DC_HYVA_MINIFICATION__NODE_BINARY: '/app/bin/node'
        MAGENTO_DC_HYVA_MINIFICATION__TRANSPORT: 'unix_socket'
        MAGENTO_DC_HYVA_MINIFICATION__SOCKET_PATH: '/tmp/hyva-minifier.sock'
        # Scope config (core_config_data) — survives app:config:import
        CONFIG__DEFAULT__HYVA_MINIFICATION__GENERAL__ENABLED: '1'
        CONFIG__DEFAULT__HYVA_MINIFICATION__GENERAL__DAEMON_MANAGEMENT: 'cron'
```

Enabling through `CONFIG__DEFAULT__` rather than the admin toggle means the
setting cannot be lost to an `app:config:import`. Prefer a **Unix socket in
`/tmp`**, which is writable and node-local: php-fpm and the daemon share the
container, so there is no reason to occupy a TCP port. On Pro, cron runs on every
web node, so you get one daemon and one socket **per node** — three per
environment.

| Setting | Config type | Config path | Environment variable |
| --- | --- | --- | --- |
| `enabled` | scope | `hyva_minification/general/enabled` | `CONFIG__DEFAULT__HYVA_MINIFICATION__GENERAL__ENABLED` |
| `daemon_management` | scope | `hyva_minification/general/daemon_management` | `CONFIG__DEFAULT__HYVA_MINIFICATION__GENERAL__DAEMON_MANAGEMENT` |
| `node_binary` | deployment | `hyva_minification/node_binary` | `MAGENTO_DC_HYVA_MINIFICATION__NODE_BINARY` |
| `transport` | deployment | `hyva_minification/transport` | `MAGENTO_DC_HYVA_MINIFICATION__TRANSPORT` |
| `tcp_host` / `tcp_port` | deployment | `hyva_minification/tcp_host`, `…/tcp_port` | `MAGENTO_DC_HYVA_MINIFICATION__TCP_HOST`, `…_TCP_PORT` |
| `socket_path` | deployment | `hyva_minification/socket_path` | `MAGENTO_DC_HYVA_MINIFICATION__SOCKET_PATH` |

The CMS Tailwind compiler uses the same shape under `hyva_cms_tailwind/…`.

An alternative to `dependencies.nodejs`, verified end to end on a live Pro
production environment, is to copy a Node binary into the build artifact — the
`/app` prefix is rewritten to the real application root at runtime, so
`node_binary: /app/bin/node` resolves with no project ID hardcoded:

```bash
unset NPM_CONFIG_PREFIX
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"
nvm install 20
cp "$(which node)" /app/bin/node && chmod +x /app/bin/node
rm -rf ~/.nvm
```

### The graceful fallback

On every environment where the daemon cannot persist — all Starter environments,
Pro Integration, partner sandboxes — **both modules degrade gracefully**, and
that is the recommended path rather than chasing a daemon the platform will not
let live. It also covers the window after a deploy, before the watchdog restarts.

- **Response minifier** — logs a warning and serves the response **unminified**.
  No error, no broken page.
- **CMS Tailwind compiler** — set the compilation strategy to `in-browser` and
  Tailwind compiles client-side.

### What to expect on Pro

Figures from a customer running both daemons on live Pro production nodes:
**~350 MB RSS per daemon** under production traffic (76–90 MB on low-traffic
staging), held flat by `MALLOC_ARENA_MAX=2`, with **47 days of continuous
running and no leak**. The daemon only dies on a deploy (container restart) or a
manual `cron.service` restart — no daily platform event takes it down — and the
watchdog restarts it within **2 to 4 minutes**. Post-deploy watchdog latency is
realistically the only thing worth tuning.

### Troubleshooting a daemon that will not stay up

Step one is not optional: **identify the architecture first**, or you will debug
a problem that has no solution. On a grid container this is expected behaviour —
stop and switch to the fallback. On a dedicated VM, work through:

```bash
php bin/magento config:show hyva_minification/general/daemon_management  # must be 'cron'
php bin/magento config:show hyva_minification/general/enabled            # 1
ls -l /app/bin/node && /app/bin/node -v                                  # present and runnable
ls vendor/hyva-themes/magento2-minification/node/node_modules >/dev/null && echo deps-ok
pgrep -af daemon.mjs                                                     # is it running?
ls -l /tmp/hyva-minifier.sock                                            # is the socket there?
tail -n 40 var/log/hyva_minifier_daemon.log                              # startup errors / "listening"
grep -E 'cron:run|Killed' /var/log/cron.log | tail                       # watchdog firing, OOM kills
systemctl show cron.service -p KillMode                                  # expect KillMode=process
```

Interpreting it:

- Absent, and `daemon_management = on_demand` → wrong mode, switch to `cron`.
- Dies only on deploys and reloads → normal; check watchdog latency, nothing more.
- `node: not found` or missing `node_modules` → the build hook did not install them.
- Socket missing or connection refused → `transport`/`socket_path` mismatch, or a
  startup crash. Read the daemon log; this is often a native-binary architecture
  error caused by a committed `node_modules`.
- `Killed` in `cron.log` alongside memory pressure → an **OOM kill**, not scope
  reaping. The two look alike, so go by the fingerprint: an OOM coincides with
  memory pressure, while scope reaping kills the daemon precisely when `cron:run`
  exits, with the box otherwise idle.

### The pinned `caching_application` OOM trap

A frequent aggravator of OOM pressure on Cloud, and worth checking before
blaming the daemon. Running `bin/magento app:config:dump` on a local environment
that uses Varnish captures `system/full_page_cache/caching_application => 2`
(Varnish/Fastly) into the **shared** `app/etc/config.php`, where it is then
applied on **every** environment — including those with no Fastly in front, since
Fastly is a Pro Staging/Production facility. There it disables Magento's built-in
Redis full-page cache and hands caching to a Varnish that does not exist, so
nothing caches at all: every response becomes a full PHP render, php-fpm workers
get OOM-killed under any concurrency, and you get intermittent `502`s.

The tell is internal headers leaking to the client (`X-Magento-Tags`,
`Set-Cookie: PHPSESSID`, `Pragma: cache`) on a repeated guest request — the
built-in cache strips those before responding, so if they reach the client it
never ran. Remove the key from the shared `config.php` and let each environment
resolve it:

```bash
grep -n caching_application app/etc/config.php                           # should NOT be pinned
php bin/magento config:show system/full_page_cache/caching_application    # empty or 1 without Fastly
```

<https://docs.hyva.io/hyva-themes/building-your-theme/adobe-cloud-node-daemons.html>

## Response minification

`hyva-themes/magento2-minification` minifies full-page HTML plus inline CSS/JS in
PHP before Varnish caches it, using `@swc/html` with Alpine-safe settings.
Requires Magento 2.4.x with Hyvä Theme `^1.3.11`, Node ≥ 20, PHP 8.1+.

**Read the trade-off before enabling it.** Every *uncached* response is round
tripped through the daemon, adding roughly **70–120 ms per cache miss**. Cache
hits (Varnish and `block_html`) are unaffected — they serve the already-minified
response. JS merging alone does not carry this cost. Expect a small APDEX drop
and raise your APDEX target time by about 100 ms so the score reflects the new
baseline instead of flagging every uncached page.

It is compatible with strict CSP (`magento2-default-theme-csp`): SHA-256 hashes
for inline scripts are computed from the minified output, including ESI blocks
and `block_html`-cached blocks.

```bash
composer require hyva-themes/magento2-minification
bin/magento module:enable Hyva_Minification
bin/magento setup:upgrade

cd vendor/hyva-themes/magento2-minification/node
npm install --ignore-scripts
npm run minifier-daemon
```

The daemon listens on `127.0.0.1:3100` and **has no authentication** — keep it on
loopback, never set `MINIFIER_HOST` to `0.0.0.0`, and do not expose the port from
a container.

| Variable | Default | Purpose |
| --- | --- | --- |
| `MINIFIER_PORT` | `3100` | TCP port |
| `MINIFIER_HOST` | `127.0.0.1` | Bind address |
| `MINIFIER_SOCKET` | *(empty)* | Unix socket path, overrides TCP |
| `MALLOC_ARENA_MAX` | `2` when Magento-managed | Caps glibc malloc arenas |

`MALLOC_ARENA_MAX=2` matters: the minifier makes many small short-lived
allocations and glibc keeps freed memory in per-arena free-lists, so on a
many-core host RSS balloons. Add it to your systemd unit if you supervise the
daemon yourself. It is harmlessly ignored on musl/macOS/BSD.

```ini
[Service]
Type=simple
Environment=MALLOC_ARENA_MAX=2
WorkingDirectory=/var/www/html/vendor/hyva-themes/magento2-minification/node
ExecStart=/usr/bin/node daemon.mjs
Restart=always
User=www-data
```

Daemon management modes live at `Stores > Configuration > Hyvä Themes > System >
Response Minification > Daemon Management`: **Off** (you supervise it), **Cron**
(a per-minute watchdog restarts it if unresponsive), **Start on-demand** (spawned
on first request needing it; file lock prevents stampede, gives up after 30
consecutive failures, auto-resets after an hour).

```bash
bin/magento config:set hyva_minification/general/daemon_management cron
```

To restart without shell access — e.g. after a deploy — use the admin button or
drop the signal file; the daemon checks for it every 5 seconds:

```bash
touch var/hyva_minifier_shutdown.flag
```

In Cron mode the web-server user and the cron user must both read/write the same
`var/` files (PID, log, flag). Fine on Cloud out of the box, a common on-prem
misconfiguration.
<https://docs.hyva.io/hyva-themes/performance/hyva-minification-readme.html>

## Baseline performance configuration

Highest impact per unit of effort, no code changes:

- **Varnish as the FPC** — `Stores → Configuration → Advanced → System → Full
  Page Cache → Caching Application`. Sub-200ms warm responses are normal because
  PHP is never reached. Follow Magento's Varnish guide so tag invalidation and
  ESI work.
- **Redis for cache and sessions** — file cache is fine for dev, materially
  slower under production load.

<https://docs.hyva.io/hyva-themes/performance/index.html>

## Core Web Vitals

Targets: **LCP** < 2.5s, **CLS** < 0.1, **INP** < 200ms.

### LCP

Mark the hero/main product image explicitly and never lazy-load it:

```html
<img src="hero.jpg" fetchpriority="high" loading="eager" width="1200" height="600" alt="Hero image">
```

Everything else gets `loading="lazy"`. Defer non-critical JS with `defer`/`async`.
Use `font-display: swap` with a fallback whose `line-height` and size match, so
the swap does not shift layout.

### CLS

Always set `width` and `height` on images and videos — without them the browser
cannot reserve space. Pre-allocate space (`min-height` or a placeholder) for
anything injected later: cookie banners, chat widgets, promo bars. Do not inject
content above existing content after first render.

### INP

Third-party scripts are the usual culprit — chat, analytics, consent, search
autocomplete all compete with user input on the main thread. Loading them
synchronously in `<head>` is described as the single biggest INP killer on
Magento storefronts. Use facades: load chat on scroll or mouse move, autocomplete
on search focus, a video player on thumbnail click. For GTM specifically,
consider Partytown to move analytics into a web worker.

<https://docs.hyva.io/hyva-themes/performance/core-web-vitals.html>

## Hyvä-specific performance tips

- **Restrict allowed countries** — `Stores → Configuration → General → General →
  Country Options → Allow Countries`. Magento ships every country in a directory
  JSON payload loaded on every page with an address form.
- **Images** — `loading="lazy"` on everything but the LCP image; always set
  `width`/`height`; serve WebP/AVIF via `<picture>` with a JPEG fallback. Never
  use an animated GIF: replace it with `<video autoplay loop muted playsinline>`,
  which is typically 80–95% smaller for an identical result.
- **`x-defer="intersect"`** delays Alpine init for below-fold components. Be
  selective — applying it to every component on a page can *increase* total
  main-thread blocking. Measure per page.
- **Defer third-party JS to first interaction** — Hyvä dispatches
  `init-external-scripts` the first time the visitor interacts with the page.
- **Don't overuse arbitrary Tailwind values** — each `w-[123px]` /
  `text-[#ff3a00]` generates a unique unshareable rule and grows the stylesheet.
  Use config tokens; reserve arbitrary values for genuine one-offs.
- **DOM size** — prefer `x-if` over `x-show` for rarely-visible content so nodes
  are never added, but remember `x-if` content is invisible to search engines and
  must sit on a `<template>`. Avoid nesting `<template x-if>` inside another —
  Alpine evaluates each layer in sequence. Use `x-show` when content must be
  indexed or toggles frequently. For heavy below-fold blocks (mega menu panels,
  cart drawer) consider fetching via AJAX on first need.

<https://docs.hyva.io/hyva-themes/performance/hyva-performance-tips.html>

## Speculation Rules

Stable and **enabled by default** from Hyvä Default Theme 1.4, configured at
`Stores → Configuration → Hyvä Themes → General → Speculation Rules`. Default is
`prefetch` on hover with `moderate` eagerness; method can be `prefetch`,
`prerender` or disabled, eagerness `immediate` / `eager` / `moderate` /
`conservative`.

`prerender` gives genuinely instant navigation but fully renders pages the user
may never visit — more client CPU/memory and more server load — and it **breaks
analytics**, because tracking scripts fire a page view on prerender. Guard with:

```js
const initAnalytics = () => { /* page_view here */ };
if (document.prerendering) {
    document.addEventListener('prerenderingchange', initAnalytics);
} else {
    initAnalytics();
}
```

Exclude destructive or stateful paths. Via layout XML:

```xml
<referenceBlock name="speculationrules">
    <arguments>
        <argument name="exclude_list" xsi:type="array">
            <item name="logout_path" xsi:type="string">customer/account/logout</item>
            <item name="add_to_cart_path" xsi:type="string">checkout/cart/add</item>
        </argument>
    </arguments>
</referenceBlock>
```

Or via `frontend/di.xml`, where the path is the item *name* and the value is
`true`:

```xml
<type name="Hyva\Theme\ViewModel\SpeculationRules">
    <arguments>
        <argument name="excludeFromPreloading" xsi:type="array">
            <item name="my/dynamic/url" xsi:type="boolean">true</item>
        </argument>
    </arguments>
</type>
```

<https://docs.hyva.io/hyva-themes/performance/speculation-rules.html>

## Back-forward cache (bfcache)

Available from Hyvä Default Theme 1.4 but **off by default**, because Magento
core has two blockers.

1. **`Cache-Control: no-store`** on all frontend responses — browsers treat it as
   an explicit bfcache opt-out. Set both in PHP
   (`Framework\App\Response\Http::setNoCacheHeaders()`) and in the Varnish VCL.
2. **Stale JS state on restore** — Hyvä's own components already handle this;
   custom and third-party scripts do not.

Enable at `Stores → Configuration → Hyvä Themes → System → Cache Options → Enable
Bfcache`, which strips `no-store` at the PHP level. That is sufficient unless you
run Varnish, in which case also patch the VCL — `vcl_deliver`, identical for
Varnish 4/5/6:

```diff
-        set resp.http.Cache-Control = "no-store, no-cache, must-revalidate, max-age=0";
+        set resp.http.Cache-Control = "no-cache, must-revalidate, max-age=0";
```

Elgentos `magento2-varnish-extended` generates a VCL with this applied;
`magento/magento2#40750` fixes PHP and all VCL versions at core level and is
available as ready-made patches via `magento-patch-bfcache` until merged.

Reset state on restore:

```js
window.addEventListener('pageshow', (event) => {
    if (event.persisted) { /* restored from bfcache */ }
});
```

In an Alpine component, bind `x-bind="eventListeners"` on the root and declare:

```js
eventListeners: {
    ['@pageshow.window'](event) {
        if (event.persisted) {
            this.closeMenu();
        }
    }
}
```

<https://docs.hyva.io/hyva-themes/performance/bfcache.html>

## Caching layers and the view model cache tag problem

Magento has four caching layers: **low-level** (config, layout, EAV; Redis or
files; cleared with `cache:clean`/`cache:flush`), **FPC** (whole pages; Varnish
or Fastly in production), **ESI** (page fragments assembled at the edge, Varnish
only), and **browser** (static assets, customer section data in localStorage,
cookies).

Invalidation runs on cache tags — `cat_p_123` for product 123. Built-in FPC and
low-level cache clean in-process; Varnish receives an HTTP PURGE with an
`X-Magento-Tags-Pattern` header. Browser-side content uses other mechanisms:
customer section data refreshes when `private_content_version` increments, static
assets when the `/static/version…/` hash changes.

**The architectural problem Hyvä has to solve:** cache tags come from *blocks*.
Block HTML cache tags come from `AbstractBlock::getCacheTags()`; FPC and ESI tags
come from blocks implementing `Magento\Framework\DataObject\IdentityInterface`
and returning `getIdentities()`. But Hyvä's whole pattern is generic `Template`
blocks plus view models — and a generic block cannot implement a custom
interface, so **view models have no standard way to contribute cache tags**.
Pages built from view models can therefore serve stale data from Varnish after
the underlying entity changes.

### Hyvä's fix

A view model may implement `IdentityInterface` directly, and
`ViewModelRegistry` collects the tags:

```php
class CurrentProduct implements ArgumentInterface, \Magento\Framework\DataObject\IdentityInterface
{
    private $registry;

    public function __construct(\Magento\Framework\Registry $registry)
    {
        $this->registry = $registry;
    }

    public function getIdentities(): array
    {
        $currentProduct = $this->registry->registry('current_product');

        return $currentProduct instanceof IdentityInterface
            ? $currentProduct->getIdentities()
            : [];
    }
}
```

Mechanics worth knowing when debugging:

- `ViewModelRegistry::require()` calls
  `Hyva\Theme\Model\ViewModelCacheTags::collectFrom($viewModel)`, so every view
  model instantiated anywhere in the render is tracked.
- `getIdentities()` is evaluated **lazily**, at response finalisation. That is
  deliberate: the Navigation view model accumulates tags while walking the
  category tree, so calling it early would miss categories.
- Tags reach the response via `Hyva\Theme\Block\ViewModelCacheTagsBlock`,
  injected into `before.body.end` in the `hyva_default` handle. It renders nothing
  visible — except in **developer mode**, where it emits an HTML comment listing
  all collected tags near `</body>`. That comment is the fastest way to verify tag
  propagation.
- Double-cached ESI blocks (cached in both ESI and `block_html`, like the nav
  menu) would otherwise contribute no tags, since `block_html` serves them
  without instantiating view models. A plugin on `Layout::getOutput()` stores
  their tags in a `block_html` record, and
  `Hyva\Theme\Plugin\PageCache\AddViewModelCacheTagsToEsiResponse` on
  `Magento\PageCache\Controller\Block\Esi` puts them back on the ESI response.

Works with FPC only, `block_html` only, or both together.

<https://docs.hyva.io/hyva-themes/performance/block-html-full-page-caching.html>
<https://docs.hyva.io/hyva-themes/performance/view-model-cache-tags.html>

## Measuring

Lab tools (Lighthouse in DevTools, PageSpeed Insights) are directional and depend
on your machine; field data (CrUX, RUM) is what Google actually ranks on. CrUX is
a 28-day rolling window, so changes take weeks to show, and low-traffic pages may
not appear at all.

| Goal | Tool |
| --- | --- |
| Fast feedback while developing | Lighthouse (DevTools) |
| Lab vs. real users | PageSpeed Insights |
| Root-causing an issue | Chrome Performance panel |
| Monitoring over time | CrUX or a RUM tool |
| Tracking one element | `elementtiming` + `PerformanceObserver` |

**Ignore the render-blocking-CSS warning.** Lighthouse flags Hyvä's stylesheet as
render-blocking, but that is correct browser behaviour — CSS must be parsed
before render or you ship unstyled content and wreck CLS. If the warning bothers
you, the real question is whether the file is too large or full of unused rules;
Tailwind already only emits used classes, so a big file usually means a
development/watch build got deployed instead of a production one. Do not chase it
with async CSS or critical-CSS inlining.

Instrument a specific element:

```html
<img src="hero.jpg" elementtiming="hero-image" alt="Hero image">
```

```js
const observer = new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    console.log('LCP candidate:', entry.startTime, entry.element);
  }
});
observer.observe({ type: 'largest-contentful-paint', buffered: true });
```

<https://docs.hyva.io/hyva-themes/performance/measuring-performance.html>

## Varnish gotchas

Four failure modes that look like Hyvä bugs and are not.

**`Uncaught ReferenceError: initHeaderNavigation is not defined`** with a raw
`<esi:include src="…/page_cache/block/esi/blocks/…">` visible in the page source
means Varnish is enabled but not configured correctly — check the VCL is correct
*and actually loaded*.

**An ESI block that never renders.** Any block with a `ttl` in layout XML becomes
a Varnish ESI include, and its **block class** must implement
`Magento\Framework\DataObject\IdentityInterface` with a public
`getIdentities()`. The default `Magento\Framework\View\Element\Template` does
not, so this silently renders nothing:

```xml
<block name="topmenu" as="topmenu" template="Magento_Theme::html/header/topmenu.phtml" ttl="3600"/>
```

while this works, because `Topmenu` meets the requirement:

```xml
<block class="Magento\Theme\Block\Html\Topmenu" name="topmenu" as="topmenu"
       template="Magento_Theme::html/header/topmenu.phtml" ttl="3600"/>
```

(Since Hyvä 1.1.9 view models can supply ESI cache tags too — see the view model
cache tag section above. Before that release only block classes could.)

**Top menu intermittently missing styles**, with an `<esi:include>` in the
source, has been reported with Varnish **plus Brotli compression**. Disable
Brotli — on Hypernode, in `varnish.webroot.conf`.

**Visitors stuck on the wrong store view, unable to switch.** A core Magento
issue rather than a Hyvä one, but it shows up on Hyvä stores. Varnish hashes on
the `X-Magento-Vary` cookie while Magento picks the store view from the `store`
cookie, and for the default store view with customer group `guest` neither cookie
is set. So a request carrying a `store` cookie but **no** `X-Magento-Vary` gets
cached as the *default* store view page — which happens when a session times out
after the visitor selected a non-default store view. Extend `vcl_hash` to also
hash the `store` cookie when `X-Magento-Vary` is absent:

```vcl
sub vcl_hash {
    if (req.http.cookie ~ "X-Magento-Vary=") {
            hash_data(regsub(req.http.cookie, "^.*?X-Magento-Vary=([^;]+);*.*$", "\1"));
        } else {
            # No 'X-Magento-Vary' means there should be no 'store' cookie either.
            # This stops requests with an illegal cookie state from polluting
            # the cache for the default store view:
            if (req.http.cookie ~ "store=") {
                hash_data(regsub(req.http.cookie, "^.*?store=([^;]+);*.*$", "\1"));
            }
        }
```

Also note that **strict CSP requires Varnish or Fastly**: they cache the CSP
header with the page and return it, while Magento's built-in PHP full-page cache
does not store the header, so inline scripts on cached pages end up
unauthorised. Uncached pages such as the checkout are unaffected.

<https://docs.hyva.io/hyva-themes/faqs/resolving-top-menu-varnish-issues.html>
<https://docs.hyva.io/hyva-themes/faqs/troubleshooting.html>
<https://docs.hyva.io/hyva-themes/writing-code/csp/csp-magento-configuration.html>

## Deploy troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Styles completely missing | `styles.css` never generated | `npm run build` in the theme's `web/tailwind` |
| 404 on `styles.css` | Static content not deployed | `bin/magento setup:static-content:deploy` |
| Old styles served | Browser or CDN/Varnish cache | Clear browser cache, purge CDN/Varnish |
| Some Tailwind classes missing | Classes absent from sources at build time | Save all templates, rebuild |
| Stylesheet suspiciously large | A watch/dev build was deployed | Rebuild with `npm run build` |
| Cloud: Tailwind build fails resolving parent theme | Allow-list `.gitignore` hides `vendor/` from `@source` | Switch to a deny-list `.gitignore` |
| Cloud: no `deployed_version.txt`, SCD skipped | `app/etc/config.php` lacks the theme/locale matrix | `bin/magento app:config:dump`, commit it |
| Daemon restarts every minute on Cloud | Grid-container environment reaping it | Expected — Pro Staging/Production only |
| HTTP 500 everywhere after `setup:di:compile` | Stale `global::DiConfig`; `null` for an `array` argument | `cache:flush` **before** `setup:di:compile`, then recompile |
| `There are no commands defined in the "cache" namespace` | The compile is already poisoned; CLI degraded | Flush the config cache backend directly, then recompile |
| SCD fails in `tubalmartin/cssmin` | Magento CSS minifier crashing on Tailwind output | Enable `dev/css/minify_files`, apply the `Minifier.php` patch |
| `LESS file is empty: …/email-fonts.less` | Known warning, not a failure | Upgrade `hyva-themes/magento2-email-module` to >= 1.0.4 |
| Daemon vanishes after a deploy or php-fpm reload | `daemon_management = on_demand` on Cloud | Switch to `cron` |
| Intermittent 502s and OOM-killed workers on Cloud | `caching_application` pinned to Varnish in shared `config.php` | Unpin it; let each environment resolve its own FPC |
| ESI block renders nothing | Block class does not implement `IdentityInterface` | Use a block class with `getIdentities()` |

Post-deploy verification: `bin/magento cache:flush`, confirm `css/styles.css`
loads in the Network tab, check the console for 404s, and resize the viewport to
confirm responsive classes work.
