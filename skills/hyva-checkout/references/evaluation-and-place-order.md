# Evaluation API & Place Order Service

## Evaluation API — backend drives the frontend

Requires Magewire familiarity; it mirrors Magewire's state handling. A Magewire component (or a Place
Order Service) implements `EvaluationInterface` and returns "evaluation results" — serialized
instructions the frontend executes, either immediately (`dispatch()`) or when the customer clicks a
primary navigation button. Because it is backend-driven, plugins can change behaviour.

```php
class ExampleScenario extends \Magewirephp\Magewire\Component
    implements \Hyva\Checkout\Model\Magewire\Component\EvaluationInterface
{
    public int $count = 0;
    public function increment() { $this->count++; }

    // called on page load and after every Magewire update (action or value sync)
    public function evaluateCompletion(EvaluationResultFactory $resultFactory): EvaluationResult
    {
        if ($this->count > 0) {
            return $resultFactory->createSuccess();          // component completed
        }
        return $resultFactory->createErrorMessage()
            ->withMessage('Count value must be greater than zero.')
            ->withVisibilityDuration(5000)
            ->asWarning();
    }
}
```

Flow: interaction → Magewire request → after the update lifecycle the Evaluation API re-evaluates →
state updated on the frontend. By default error messages are bound to the Validation API and only
appear when the customer presses the primary navigation button; chain `dispatch()` to show them as
soon as the Ajax response returns.

Result classes live in `Hyva\Checkout\Model\Magewire\Component\Evaluation`; reusable traits
("capabilities") in `…\Evaluation\Concern` (e.g. `DetailsCapabilities`, `DispatchCapabilities`,
`StackingCapabilities`, `Blocking`, `Messaging`; 1.1.25 added `Tagging`, `Sequence`, `Result`).

The hydrated `result` object your frontend callbacks receive
(`\Hyva\Checkout\Model\Magewire\Component\Hydrator\Evaluation`):

- `arguments` (array) — type-specific arguments
- `dispatch` (bool) — dispatch immediately or bind to a button click
- `result` (bool) — positive/negative outcome
- `type` (string) — result type name
- `id` (string) — Magewire component id
- `hash` (string) — SHA1 of the result array values

Source: <https://docs.hyva.io/hyva-checkout/devdocs/evaluation-api/index.html>

## Result types

`EvaluationResultInterface` was **deprecated in 1.1.13** — custom types extend
`\Hyva\Checkout\Model\Magewire\Component\Evaluation\EvaluationResult`, define a `TYPE` constant (or
override `getType()`) and implement `getArguments(Component $component): array`.

| Type | Class (`…\Evaluation\`) | Frontend processor | Since | Capabilities |
|---|---|---|---|---|
| Batch | `Batch` | `batch` | 1.1.13 | – |
| Blocking | `Blocking` | `blocking` | 1.0 | Details, Blocking, Dispatch |
| Custom | `Custom` | *yours* | 1.1.13 | Details, Blocking, Dispatch |
| ErrorMessage | `ErrorMessage` | `message` | 1.0 | Blocking, Messaging, Dispatch |
| Event | `Event` (extended by `ErrorMessageEvent`, `ErrorEvent`, `Success`) | `event` | 1.0 | Details, Dispatch |
| Executable | `Executable` | `executable` | 1.1.13 | Dispatch |
| NavigationTask | `NavigationTask` | `navigation_task` | 1.1.13 | Dispatch, Stacking |
| Redirect | `Redirect` | `redirect` | 1.1.13 | Dispatch, Stacking |
| Success | `Success` | `event` | 1.0 | Details, Dispatch |
| Validation | `Validation` | `validation` | 1.1.13 | Stacking, Details |

**Batch** bundles results and is good practice — plugins can inject into it. `getFactory()` gives
access to the factory from inside a batch; `owns()`, `misses()`, `push()`, `clear()`,
`filter()`, `containsFailureResults()`, `containsSuccessResults()` (the last four since 1.1.25).

```php
$batch = $resultFactory->createBatch([
    $resultFactory->createErrorMessage()->withMessage('Something went wrong.')->asWarning(),
    $resultFactory->createEvent()->withCustomEvent('my-batch-event')->dispatch(),
]);
if (false === $component->getEvaluationResultBatch()->owns(fn ($v) => $v instanceof Redirect)) {
    $batch->clear()->push(
        $resultFactory->createRedirect('https://hyva.io/hyva-checkout.html')
            ->withNotificationDialog()
            ->withNotificationMessage("You're being redirected…")
            ->withTimeout(2500)
    );
}
return $batch;
```

**Blocking** disables *all* primary navigation buttons and stops navigation tasks and validations
from firing. There is **no automatic unblock** — only a later `Success` from the same component's
`evaluateCompletion()`, or a manual frontend API call, clears it. A payment method that blocks and
then cannot authorize traps the customer even if they switch methods. **Prefer `ErrorMessage`.**

**ErrorMessage** despite its name renders any style:
`asWarning()`, `asInformally()`, `asCustomType('success')`, `withVisibilityDuration($ms)`,
`dispatch()`.

**Event** family: `createEvent()->withCustomEvent('my-custom-event')->dispatch()`;
`createErrorMessageEvent()->withCustomEvent(...)->withMessage(...)->dispatch()`;
`createErrorEvent()->withCustomEvent(...)` (false result, bound to the Validation API by default).

**Custom** — a result handled entirely by your own processor:

```php
return $resultFactory->createCustom('foo')->withDetails(['alert' => 'Something went wrong.']);
```

```js
window.addEventListener('checkout:init:evaluation', () => {
    hyvaCheckout.evaluation.registerProcessor('foo', (component, el, result) => {
        alert(result.arguments.details.alert);
        return result.result;
    });
});
```

**Executable** — a named JS function whose arguments come from PHP; standalone (dispatched) or
wrapped in a NavigationTask:

```php
$executable = $resultFactory->createExecutable('custom-modal')->withParams(['buttons' => ['confirm','cancel']]);
return $resultFactory->createNavigationTask('foo', $executable);
```

```js
hyvaCheckout.evaluation.registerExecutable('custom-modal', async (result, el, component) => {
    // result.arguments.params carries withParam()/withParams() data
});
```

**NavigationTask** — defers work until the navigation / place-order button is clicked; tasks run in
`stackPosition` order (default 500). `executeAfter()` runs the task *after* the next step loads or
the order completes. It can wrap any result type and handles dispatchable ones itself. It does **not**
run at checkout init, but it *does* run every time the customer navigates to or from the step holding
the component — guard against duplicate API calls.

**Redirect** — for gateway redirects before/after order placement; ships a modal that can be a
notification dialog or a confirm/cancel dialog, and admins can force confirmation dialogs for all
redirects via the redirect system settings. It sits late in the task stack so other tasks run first.
Since **1.3.4** a Place Order Service may use `PlaceOrderRedirect` (extends `Redirect`) with a custom
template:

```php
return $resultFactory->create(PlaceOrderRedirect::class, ['url' => 'https://…'])
    ->withRedirectTemplate('Hyva_Checkout::redirect-to-hyva.phtml');
```

**Validation** — injects a frontend validator that runs on primary-button click, *after* all
NavigationTasks. Attach failure handling with `withFailureResult()`:

```php
return $resultFactory->createValidation('validateMyCustomCcComponent')
    ->withFailureResult(
        $resultFactory->createErrorMessageEvent()
            ->withCustomEvent('payment:method:error')
            ->withMessage('Invalid credit card details provided. Please try again.')
            ->withVisibilityDuration(5000)
    );
```

Serialized to the frontend it looks like:

```json
{"example-component-name":{"arguments":{"name":"validateExampleComponent",
 "detail":{"component":{"id":"example-component-name"}},"stack":{"position":500},
 "results":{"failure":{"arguments":{"event":"payment:method:error","detail":{"message":{"text":"…","type":"error","duration":5000}}},
 "dispatch":true,"result":false,"type":"event"}}},"type":"validation"}}
```

Register validators/executables/processors from a `.phtml` injected via
`hyva_checkout_index_index` into `hyva.checkout.init-evaluation.after` (each API has its own `after`
container, so custom code always lands after its parent API is ready).

Other options in 1.1.25: Message Dialog result type, and **Cascading Step Validation** (verifies all
required steps completed before proceeding).

Source: <https://docs.hyva.io/hyva-checkout/devdocs/evaluation-api/evaluation-result-types.html>,
<https://docs.hyva.io/hyva-checkout/devdocs/evaluation-api/evaluation-examples.html>,
<https://docs.hyva.io/hyva-checkout/upgrading/feature-history.html>

## Worked example: optional marketing opt-in

Component keeps `public bool $shouldRegister`, `evaluateCompletion()` returns
`createNavigationTask('marketingRegistrationTask', createExecutable('marketingRegistrationExecutable')
->withParam('shouldRegister', $this->shouldRegister))->executeAfter()`. The checkbox block is
registered inside `hyva_checkout_components.xml` (in `checkout.quote-summary.section`) with
`wire:model="shouldRegister"`; the executable's JS lives in a separate block added to
`hyva.checkout.api-v1.after` through `hyva_checkout_index_index.xml`, reading
`result.arguments.params.shouldRegister`. NavigationTask (not Validation) is the right type because
the registration is optional and must never block navigation.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/evaluation-api/evaluation-examples.html>

---

# Place Order Service (POS)

In Luma each payment method places the order. Hyvä Checkout centralizes this so the payment step can
sit anywhere. A Place Order Service is a PHP class bound to a payment method code; without one the
default `\Hyva\Checkout\Model\Magewire\Payment\DefaultPlaceOrderService` runs.

Flow:

1. `\Hyva\Checkout\Magewire\Main::placeOrder()` receives the request — since 1.1.13 it also accepts
   the checkout session data, converted to
   `\Hyva\Checkout\Model\Magewire\Payment\AbstractOrderData`.
2. The POS processor asks `PlaceOrderServiceProvider` for a service matching the quote's payment
   method (marked `@internal` since 1.1.13 — only `Main` should use it).
3. Falls back to `DefaultPlaceOrderService`.
4. `canPlaceOrder()` is checked, session data converted, `placeOrder()` runs, exceptions caught.
5. On success the processor pushes an `order:place:success` window event into the evaluation batch,
   dispatched immediately on the frontend.
6. If `canRedirect()` is true and no Redirect is in the batch, it appends one with
   `getRedirectUrl()`.
7. Any post-order evaluation results execute on the frontend.

**Never convert a quote to an order inside a payment component or a PSP callback.** The payment step
may not be last, and once the quote becomes an order the following steps lose the data they need.

Source: <https://docs.hyva.io/hyva-checkout/devdocs/place-order-service-api/index.html>,
<https://docs.hyva.io/hyva-checkout/devdocs/place-order-service-api/service-processor.html>

## The abstraction layer

Extend `\Hyva\Checkout\Model\Magewire\Payment\AbstractPlaceOrderService` and override only what you
need.

| Method | Returns | Default behaviour |
|---|---|---|
| `placeOrder(\Magento\Quote\Model\Quote $quote)` | `int` (reserved order id) | `(int) $this->cartManagement->placeOrder($quote->getId(), $quote->getPayment())` |
| `canPlaceOrder()` | `bool` | true; return **false** when an external gateway will create the order through the Magento API after payment |
| `handleException(\Exception $e, \Magewirephp\Magewire\Component $component, Quote $quote)` | `void` | rethrows as `LocalizedException(__($e->getMessage()))` so the processor logs it and shows an error-message evaluation result |
| `canRedirect()` | `bool` | true; target from `getRedirectUrl()` |
| `getRedirectUrl()` | `string` | Magento route path or absolute URL; the frontend performs the redirect |
| `evaluateCompletion(EvaluationResultFactory $f, ?int $orderId = null)` | `EvaluationResult` | `Success`; the processor appends a `Redirect` when `canRedirect()` is true (since 1.1.13) |
| `getData()` | `AbstractOrderData` | the browser session-storage data set with `hyvaCheckout.storage.setValue()` (since 1.1.13) |

Register per payment method code — the `<item name>` **must equal the payment method code**:

```xml
<!-- etc/frontend/di.xml -->
<type name="Hyva\Checkout\Model\Magewire\Payment\PlaceOrderServiceProvider">
    <arguments>
        <argument name="placeOrderServiceList" xsi:type="array">
            <item name="foo" xsi:type="object">My\Example\Model\Payment\PlaceOrderService\FooPlaceOrderService</item>
        </argument>
    </arguments>
</type>
```

Source: <https://docs.hyva.io/hyva-checkout/devdocs/place-order-service-api/abstraction-layer.html>

## Worked example: 3DS modal after order placement

```php
class FooPlaceOrderService extends AbstractPlaceOrderService
{
    public function canRedirect(): bool { return false; }   // modal must show before redirecting

    public function evaluateCompletion(EvaluationResultFactory $resultFactory, ?int $orderId = null): EvaluationResultInterface
    {
        $redirect = $resultFactory->createRedirect('checkout/onepage/success');
        if ($orderId === null) {
            return $redirect;
        }
        $validate = $resultFactory->createValidation('foo-authentication');
        $validate->withFailureResult($redirect);            // order exists, go to success anyway

        $navigationTask = $resultFactory->createNavigationTask('foo-redirect', $redirect);
        $navigationTask->executeAfter(true);                 // required before 1.1.18

        return $resultFactory->createBatch()->push($validate)->push($navigationTask);
    }
}
```

The modal markup must live **outside the Main component** — the payment method may be on a different
step than the Place Order button. Put it in `hyva.checkout.init-validation.after` via
`hyva_checkout_index_index.xml`:

```xml
<referenceContainer name="hyva.checkout.init-validation.after">
    <block name="modals.three-ds.authentication" template="My_Example::modals/three-ds/authentication.phtml"/>
</referenceContainer>
```

The Alpine component composes `hyva.modal()`, uses `x-bind:value` + `x-on:input` instead of
`x-model`, and the validator bridges modal ↔ evaluation:

```js
function initFooAuthentication() {
    return Object.assign({ code: null }, hyva.modal(), {
        updateCode(event) { this.code = event.target.value; },
        init() {
            window.addEventListener('foo:authenticate:show', () => {
                this.show().then(result =>
                    this.$dispatch('foo:authenticate:confirm', { result: result && this.code === '1234' }));
            });
        }
    });
}
window.addEventListener('alpine:init', () => Alpine.data('initFooAuthentication', initFooAuthentication), {once: true});

window.addEventListener('checkout:init:evaluation', () => {
    hyvaCheckout.evaluation.registerValidator('foo-authentication', element => new Promise((resolve, reject) => {
        window.dispatchEvent(new Event('foo:authenticate:show'));
        window.addEventListener('foo:authenticate:confirm', e => e.detail.result ? resolve() : reject());
    }));
});
```

Source: <https://docs.hyva.io/hyva-checkout/devdocs/place-order-service-api/index.html>

## Error handling on place order

If `handleException()` rethrows, the processor logs the message and shows the generic
*"Something went wrong while processing your order. Please try again."*. Throw a
`\Magento\Framework\Exception\LocalizedException` to control the wording (localization is handled
automatically). It also dispatches `order:place:error` and
`order:place:{payment_method_code}:error` window events — **no core component listens to them**.

```php
public function handleException(\Exception $exception, Component $component, Quote $quote): void
{
    if ($exception instanceof \My\Example\Exceptions\AuthenticationFailureException) {
        $component->getEvaluationResultBatch()->push(
            $component->getEvaluationResultBatch()->getFactory()
                ->createEvent('my:custom:event')
                ->withDetails(['code' => $exception->getCode(), 'gateway' => $exception->getGateway()])
        );
        throw new \Magento\Framework\Exception\LocalizedException(
            __('Unable to authenticate to the payment gateway. Please try again.')
        );
    }
    parent::handleException($exception, $component, $quote);
}
```

Inside a POS you push results onto the pre-created batch on `$component`
(`$component->getEvaluationResultBatch()`), and `getFactory()` on the batch creates them —
`createExecutable('foo_exception')`, etc.

### Messenger component

`Hyva_Checkout::page/messenger.phtml` renders errors/warnings in a consistent style. It is **not
placed automatically** — inject it where you want the messages, with an `event_prefix` argument; it
then listens for `{event_prefix}:error` events:

```xml
<block name="checkout.shipping.method.foo" as="foo_foo">
    <block name="component-messenger-guest-details" template="Hyva_Checkout::page/messenger.phtml">
        <arguments><argument name="event_prefix" xsi:type="string">order:place</argument></arguments>
    </block>
</block>
```

Or listen yourself: `window.addEventListener('my:custom:event', event => { /* event.detail */ })`
(plus `registerInlineScript()`).

Source: <https://docs.hyva.io/hyva-checkout/devdocs/place-order-service-api/service-processor.html>
