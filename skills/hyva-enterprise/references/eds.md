# Adobe Edge Delivery Services (EDS) alongside Hyvä Enterprise

## What it is

Hyvä Enterprise can run **side-by-side** with Adobe Edge Delivery Services: content
pages are managed in EDS/AEM, commerce pages are served by Adobe Commerce running
Hyvä Enterprise. Common elements (main navigation, footer) are shared, AEM content
blocks (e.g. rich product descriptions) can be shown on Hyvä pages, and Adobe
Commerce data (e.g. cart contents) is available on EDS pages.

Proof-of-concept tech demo: <https://eds-demo.hyva.io>.

## Implementation reality

**Hyvä EDS is not an installable module.** It must be implemented per project as a
customized implementation matching that project's requirements. Hyvä Enterprise
license holders can request access to the proof-of-concept code to follow the same
approaches.

## Techniques used in the demo

- **Shared Tailwind CSS styles** across EDS pages and Adobe Commerce pages, for a
  consistent experience, less development time and easy developer onboarding.
- **Main menu and footer maintained in AEM** and rendered on both EDS and Adobe
  Commerce pages.
- **Mini cart on EDS pages reads the same browser local-storage data Hyvä uses**, so
  it renders without extra API calls. The same approach extends to other
  customer-session-specific UI components on EDS pages.
- **Embedding AEM/EDS content on Adobe Commerce pages** via a PHP view model or a
  CMS widget. A PageBuilder content-type proof of concept exists but is not used in
  the demo. Typical use case: extra product descriptions authored in Google Docs or
  Microsoft Word through AEM/EDS. In the demo only the main menu and footer are
  embedded content.
- **Rendering products on EDS pages**: Hyvä product carousels can be embedded as EDS
  blocks, but that requires including Alpine.js on the EDS pages so swatches work
  without re-implementing them in vanilla JavaScript.

<https://docs.hyva.io/hyva-enterprise/eds/index.html>
