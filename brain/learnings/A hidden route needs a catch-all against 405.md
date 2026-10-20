---
type: learning
date: 2026-10-20
tags: [learning, laravel, security, routing]
---

# A hidden route needs a catch-all against 405

What happened: the admin portal turned every refusal into a 404, yet `PUT /<secret>` answered **405 Method Not Allowed**, which proves the path exists. Laravel's router throws `MethodNotAllowedHttpException` while *matching*, before any route middleware runs, so middleware can't hide it. Also, a refused request that went through `StartSession` carries a session cookie, which an unknown URL never has.

**So:** end the hidden route group with `Route::any('{any?}', fn () => abort(404))->where('any', '.*')` (optional segment, so the bare prefix is covered too), and have the first middleware replace every refusal with a freshly rendered 404 (`ExceptionHandler::render(new NotFoundHttpException(...))`) so no cookie leaks. A test compares the body and cookies with a real unknown URL.

Related: [[D-012 Hidden admin portal]]
