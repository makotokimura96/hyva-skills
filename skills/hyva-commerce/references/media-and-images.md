# Media Optimization and Image Editor

Two separate Hyvä Commerce features, both GA. **Media Optimization** handles storefront image output
(resize, compress, convert to WebP/AVIF). **Image Editor** is an in-admin editing tool for the media
library. They solve different problems: Image Editor keeps the admin media library at a sensible size;
Media Optimization optimises what customers download.

---

# Media Optimization

Package `hyva-themes/commerce-module-media-optimization`, module `Hyva_MediaOptimization`.

Three capabilities: a developer-friendly API for resizing/converting in your own block and template
output; default implementations that use that API (notably in Hyvä CMS components); and an observer
that scans all block output and automatically replaces images in HTML or CSS with optimised versions.
Plus a `bin/magento` command to flush generated images.
<https://docs.hyva.io/hyva-commerce/features/media-optimization/index.html>

## Install

```bash
# ensure GD or Imagick is present first — like default Magento, at least one is required
composer require hyva-themes/commerce-module-media-optimization
bin/magento setup:upgrade
# clear the browser cache, then open the admin System Check
```

GitLab install: configure the `commerce-module-commerce` and `commerce-module-media-optimization`
repositories, then `composer require --prefer-source 'hyva-themes/commerce-module-media-optimization:dev-main'`.
No further setup steps.
<https://docs.hyva.io/hyva-commerce/features/media-optimization/installation.html>

## Configuration

`Stores → Settings → Configuration → Hyvä Commerce → Media Optimization`.

- **Platform Compatibility Check → System Check** — no settings; reports details and diagnostics on the
  installed resize/conversion libraries, including which features they support. Check it right after
  installing.
- **Image Optimization Settings** — enable the overall functionality, select engines and output
  formats, enable logging. The **Retina** setting controls whether 2x and 3x variants are generated for
  high-density displays (better quality, more storage and processing). Format guidance: WebP has good
  compression with broad browser support; AVIF compresses better but needs newer browsers. Defaults
  work well for most stores.
- **Automatic Image Replacement Settings** — enable/disable replacement, the HTML and CSS replacement
  modes, the input formats to target, and the output formats to generate.
- **Viewport Breakpoints** — rows of *minimum viewport width*, optional *maximum viewport width* and
  the *generated image width* for that range. Images are never generated larger than the original.
  Leave Generated Image Width empty above the largest breakpoint to serve the original size.
  Breakpoints apply when using the Developer API, or automatic replacement in **picture** mode.
- **Engine Settings** — GD and Imagick each expose their own quality, compression and encoding-speed
  settings, separately for resizing and for conversion.

<https://docs.hyva.io/hyva-commerce/features/media-optimization/configuration.html>

## Automatic image replacement

Runs through an observer on the **`view_block_abstract_to_html_after`** event. It regex-scans rendered
block HTML for image references in HTML (`<img>`) and CSS (`background-image`), extracts the media
paths, and swaps in optimised versions per your configuration. No template changes needed.

Replacement modes:

- **HTML → Simple** — keeps the HTML structure, only updates image URLs. Safest option.
- **HTML → Picture** — wraps images in a `<picture>` element for better optimisation, but changes the
  DOM structure, which may affect JavaScript expecting specific elements.
- **CSS → Simple** — replaces URLs with optimised versions.
- **CSS → Image-set** — generates modern `image-set()` declarations.

**Viewport Breakpoints are applied only in picture mode** — that is the main reason to prefer it. They
are not applied in simple mode. When you call the Developer API directly they are always applied.

Known limitations:

- Only blocks with **no child blocks** are processed, so HTML is never scanned or replaced twice.
- Picture-tag mode for HTML **stops configurable swatches from switching images** when clicked.

The product media gallery block (`product.media`) is excluded by default, because replacing its images
breaks the gallery. Exclude any other block by setting `skip_img_optimization`:

```xml
<referenceBlock name="block.name.in.layout.to.exclude">
    <arguments>
        <argument name="skip_img_optimization" xsi:type="boolean">true</argument>
    </arguments>
</referenceBlock>
```

<https://docs.hyva.io/hyva-commerce/features/media-optimization/features/automatic-image-replacement.html>

## Image processing engines

Two engines, GD and Imagick, each configurable separately for **resizing** and for **format
conversion** — e.g. GD for resizing (faster) and Imagick for conversion (better format support).
Imagick is recommended when available. Default configuration works well; only change engine settings
for specific performance or quality issues.

**GD** — PHP's built-in library, always available when PHP was compiled with image support. Faster and
lower memory than Imagick, more limited formats. Supports JPEG, PNG and non-animated GIF by default;
WebP needs PHP 7.0+ with libwebp; AVIF needs PHP 8.1+ compiled with libavif (not always available in
standard distributions). No animated WebP or AVIF.

```bash
php -r "print_r(gd_info());"
```

**Imagick** — PHP bindings for ImageMagick; more configuration options, broader formats, better edge
cases (e.g. PNG colour profiles), more control over conversion. ImageMagick **7.0+** recommended, 6.9+
works for most features. WebP: ImageMagick 6.9.0+ with libwebp; animated WebP needs 7.0.10+ for full
support. AVIF: ImageMagick 7.0.25+ compiled with libheif and libaom; AVIF **with transparency** needs
6.9.12-68 or later — on older versions the module automatically skips AVIF conversion for transparent
images.

If conversion is too slow: use slightly more compression when resizing, disable retina, disable
conversion of animated images, select only one output format (e.g. WebP only), or choose a different
resampling method.
<https://docs.hyva.io/hyva-commerce/features/media-optimization/features/engines.html>

## Developer API

Use the view model for **all** custom implementations, so the code works whether or not Hyvä Commerce
and the Media Optimization module are installed.

```php
/**
 * @param array<string, array{
 *     path: string, type?: string, width?: int, height?: int, media?: string, fallback?: bool,
 * }> $images
 * @param array<string, string> $imgAttributes     alt, loading (lazy|eager), fetchpriority (auto|high|low),
 *                                                 class, id, style, decoding (sync|async|auto), sizes, srcset
 * @param array<string, string> $pictureAttributes class, id, style, data-* attributes
 */
public function getResponsivePictureHtml(
    array $images,
    array $imgAttributes = [],
    array $pictureAttributes = []
): string;
```

`\Hyva\Theme\ViewModel\Media::getResponsivePictureHtml()` (from the `Hyva_Theme` module) delegates to
`getPictureHtml()` declared in `Hyva\Theme\Model\Media\MediaHtmlProviderInterface`.

Basic usage:

```php
<?php
/** @var \Hyva\Theme\ViewModel\Media $mediaViewModel */
$mediaViewModel = $viewModels->require(\Hyva\Theme\ViewModel\Media::class);
$imageConfig = [
    ['path' => 'catalog/product/w/b/wb01-blue-0.jpg', 'width' => 400, 'height' => 500]
];
echo $mediaViewModel->getResponsivePictureHtml($imageConfig);
```

This produces a complete `<picture>` with optimised sources per format, handling retina automatically
when enabled.

Art-directed responsive images:

```php
<?php
/** @var \Hyva\Theme\ViewModel\Media $mediaViewModel */
$mediaViewModel = $viewModels->require(\Hyva\Theme\ViewModel\Media::class);
$desktopImage = [
    'path' => 'wysiwyg/homepage-main-hero.jpg',
    'width' => 1920, 'height' => 600,
    'media' => '(min-width: 768px)',
    'fallback' => true   // used when the browser does not support <picture>
];
$mobileImage = [
    'path' => 'wysiwyg/homepage-mobile-hero.jpg',
    'width' => 768, 'height' => 800,
    'media' => '(max-width: 767px)'
];
$imgAttributes = [
    'alt' => 'Summer Collection',
    'class' => 'w-full h-auto',
    'loading' => 'eager',
    'fetchpriority' => 'high'
];
echo $mediaViewModel->getResponsivePictureHtml([$desktopImage, $mobileImage], $imgAttributes);
```

Implementations: the default `\Hyva\Theme\ViewModel\Media::getPictureHtml()` in `Hyva_Theme` outputs a
`<picture>` from the given data but does **not** resize or convert. When Media Optimization is
installed the base provider is replaced by
`\Hyva\MediaOptimization\Model\Media\MediaHtmlProvider::getPictureHtml()`, which adds resizing,
conversion and per-viewport sizes, respects the module configuration, and falls back gracefully to
standard image tags when optimisation is disabled.
<https://docs.hyva.io/hyva-commerce/features/media-optimization/features/developer-api.html>

## Flushing generated images

```bash
bin/magento hyva:media-optimization:clear [options] [--] [<path>]
```

- `<path>` — the media item to clear. **Running without a path removes all optimised media.**
- `--converted-only` — clears only converted media.
- `--resized-only` — clears only resized media.

```bash
bin/magento hyva:media-optimization:clear
bin/magento hyva:media-optimization:clear catalog/product/m/b/mb01-blue-0.jpg
bin/magento hyva:media-optimization:clear --converted-only
```

Clear everything after changing global settings such as output formats or quality (images regenerate
with the new settings). Clear a specific image when you replace an original but keep the same filename
— the cache does not detect that the source changed.
<https://docs.hyva.io/hyva-commerce/features/media-optimization/features/flushing-generated-images.html>

## Hyvä CMS integration

With both Hyvä CMS and Media Optimization installed, imagery in **every built-in Hyvä CMS component**
is resized and converted automatically, with no extra configuration. Optimisation is not wired into
each component: the built-in components render images through the shared
`Hyva\Theme\ViewModel\Media` view model, which resizes and converts when the module is present and
outputs a plain `<picture>` when it is not.

Optimise a custom component the same way — `Element::getResponsiveImageData()` turns an image field
value into what `getResponsivePictureHtml()` expects:

```php
<?php
use Hyva\CmsLiveviewEditor\Block\Element;
use Hyva\Theme\Model\ViewModelRegistry;
use Hyva\Theme\ViewModel\Media;
/** @var Element $block */
/** @var ViewModelRegistry $viewModels */
$media = $viewModels->require(Media::class);
$image = $block->getData('image') ?: [];
?>
<?php if (!empty($image['src'])): ?>
    <?php
    $imageData = array_filter([
        $block->getResponsiveImageData($image, 'acme_my-component_image'),
    ]);
    $imgAttributes = ['alt' => $image['alt'] ?? '', 'loading' => 'lazy'];
    ?>
    <?= /** @noEscape */ $media->getResponsivePictureHtml($imageData, $imgAttributes, ['data-liveview-element' => 'image']) ?>
<?php endif; ?>
```

The second argument to `getResponsiveImageData()` is a **unique id** Media Optimization uses to track
and separate generated images. Use your own scheme, e.g. `vendor_component-name_type` — and **never
reuse the built-in `hyva_cms_*` ids**.

Art-directed variants need one entry and one **distinct id** per source:

```php
$imageData = array_filter([
    $block->getResponsiveImageData($image, 'acme_my-component_image'),
    $block->getResponsiveImageData($desktopImage, 'acme_my-component_image_desktop', ['media' => '(min-width: 1024px)']),
]);
```

Because rendering goes through `getResponsivePictureHtml()`, a custom component gets the same resizing,
format conversion and Viewport Breakpoint behaviour as the built-in ones.
<https://docs.hyva.io/hyva-commerce/features/media-optimization/features/hyva-cms-integration.html>

---

# Image Editor

Package `hyva-themes/commerce-module-image-editor`, module `Hyva_ImageEditor`. An in-admin image tool
for basic transformations — resize, crop, flip, fine-tune, filters — supporting **JPEG (JPG)** and
**PNG**, usable anywhere the Media Gallery is available, including inside Hyvä CMS. Built on a forked
version of <a href="https://github.com/scaleflex/filerobot-image-editor">Filerobot Image Editor</a>.
<https://docs.hyva.io/hyva-commerce/features/image-editor/index.html>

## Install

```bash
composer require hyva-themes/commerce-module-image-editor
bin/magento setup:upgrade
# clear the browser cache
```

**Additional setup: the 'New' Media Gallery must be enabled** — the Image Editor only supports editing
images through it (also a Hyvä CMS requirement). Large edited images can exceed default upload limits;
see Server Upload Limits below.
<https://docs.hyva.io/hyva-commerce/features/image-editor/installation.html>

## Configuration

One setting: **Image Quality**, the compression applied when saving edited images in the admin. Higher
quality means larger files — uncompressed, an edited image can be up to **five times** the original
size. Applies only to images saved through the Image Editor in the admin.

`Stores → Settings → Configuration → Hyvä Commerce → Image Editor → General → Image Quality`, a
percentage between **10 and 100**.

Affects `jpg` / `jpeg` only — lossless formats such as `png` are saved without this compression. This
setting exists to keep the admin media library at a sensible size; storefront optimisation is Media
Optimization's job.
<https://docs.hyva.io/hyva-commerce/features/image-editor/configuration.html>

## Saving and restoring

- **Save** — stores the image under the same filename. On the **first** save, Image Editor backs up the
  original.
- **Save As** — stores it as a new file with the name you provide; if that name exists, a numeric
  suffix such as `_1` is appended. Useful for variants (narrow, wide, mobile).
- **Restore from backup** — appears in the save menu after the first Save, and reverts all changes to
  the original file.

**Save As does not create a backup** — those are new files with nothing to restore from.
<https://docs.hyva.io/hyva-commerce/features/image-editor/features.html>

## Custom crop presets

Defaults live in
`Hyva/ImageEditor/src/view/adminhtml/web/js/image/image-editor-config.js`, with `presetsItems`
(aspect ratios: Square 1:1, classicTv 4:3, cinemascope 21:9) and `presetsFolders` → groups → items
(Hyva Theme → Product: Product page 700×700, Small image 135×135, Thumbnail 78×78 — all
`disableManualResize: true`; Category: Category page grid 240×300).

Override them with a Magento JavaScript mixin.

```js
// app/code/Hyva/CustomModule/view/adminhtml/requirejs-config.js
var config = {
    config: {
        mixins: {
            'Hyva_ImageEditor/js/image/image-editor-config': {
                'Hyva_CustomModule/js/image/custom-editor-config-mixin': true
            }
        }
    }
}
```

```js
// app/code/Hyva/CustomModule/view/adminhtml/web/js/image/custom-editor-config-mixin.js
define(['mage/translate'], function ($t) {
    return function (target) {
        var newCrop = {
            autoResize: true,
            presetsItems: [
                { titleKey: 'Custom one', descriptionKey: '1:4', ratio: 1/4 }
            ],
            presetsFolders: [
                {
                    titleKey: 'Hyva Theme',
                    groups: [
                        {
                            titleKey: 'Product',
                            items: [
                                { titleKey: 'Product page', width: 70, height: 70, disableManualResize: true, descriptionKey: 'pdpSize' }
                            ]
                        },
                        {
                            titleKey: 'Category',
                            items: [
                                { titleKey: 'Category page grid', width: 240, height: 300, descriptionKey: 'categoryGrid' }
                            ]
                        }
                    ]
                }
            ]
        }
        target.Crop = newCrop
        return target;
    };
});
```

The mixin receives the current config as `target`, replaces `target.Crop`, and returns it.
<https://docs.hyva.io/hyva-commerce/features/image-editor/custom-presets.html>

## Server upload limits

High-quality images — especially lossless `png` — can exceed default web server and PHP upload limits,
and file size can *increase* after editing.

**Nginx** defaults to 1 MB:

```nginx
client_max_body_size 128M;
```

The Apache equivalent is `LimitRequestBody`, which defaults to `0` (unlimited) upstream; some
distributions (RHEL 8.7+/9.1+) ship a packaged default of 1 GiB instead — check your distribution.

Scope it to the Image Editor save routes rather than globally:

- `/hyva_image_editor/image/save`
- `/hyva_image_editor/image/duplicate`

**PHP**:

```ini
post_max_size=128M
upload_max_filesize=100M
```

Keep `post_max_size` above `upload_max_filesize` to leave room for request overhead. Where possible
(e.g. a separate admin `php.ini`), limit these changes to the admin area, not the storefront.
<https://docs.hyva.io/hyva-commerce/features/image-editor/server-upload-limits.html>
