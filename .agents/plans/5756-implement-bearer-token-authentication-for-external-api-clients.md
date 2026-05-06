# Plan: Bearer Token Authentication for External API Clients

**Issue:** [#5756](https://github.com/raft-tech/TANF-app/issues/5756) (parent epic [#5703](https://github.com/raft-tech/TANF-app/issues/5703))
**Branch:** `5756-implement-bearer-token-authentication-for-external-api-clients`
**Depends on:** #5757 (Keycloak canary at 100%)

## Context

Today, external tools (Postman, CLI, CI/CD) cannot authenticate against the TDP Django API without reverse-engineering session cookies — the legacy Login.gov/AMS flows are tightly coupled to the browser. With Keycloak now in place as a standards-compliant OIDC broker (PR [#5782](https://github.com/raft-tech/TANF-app/pull/5782)), we can let those tools authenticate via standard OAuth2 grants (Authorization Code + PKCE for Postman, Device Authorization Grant for CLIs). Users still authenticate through Login.gov / AMS — only the token-delivery mechanism changes.

This unlocks: CLI-based STT data submission, scripted report generation, easier security audits / penetration testing, and Postman-based API exploration. It is the last *capability* ticket in the Keycloak epic — only #5758 (legacy auth removal) remains afterward.

The architecture is already specified in `docs/Technical-Documentation/tech-memos/keycloak/keycloak-architecture-plan.md` §7.

## Approach

Three pieces of work, kept small:

1. **Django** — add a DRF `BaseAuthentication` class that validates Keycloak JWT bearer tokens against the JWKS endpoint and reuses the existing `KeycloakOIDCBackend` user-resolution logic. Configure DRF throttling per Keycloak `azp` (authorized party / client ID). Emit an audit log line per authenticated request.
2. **Keycloak** — add a `tdp-cli` public client (no secret) to `realm-export.json` with Authorization Code + PKCE (S256) and Device Authorization Grant enabled. Default scopes include `tdp-user-attributes` so token claims match browser sessions.
3. **Docs** — short Postman + Device Authorization Grant setup section in `tdrs-backend/keycloak/README.md`.

### Why subclass `mozilla_django_oidc.contrib.drf.OIDCAuthentication`

The pinned version (`mozilla-django-oidc==4.0.1`, `tdrs-backend/Pipfile`) ships `mozilla_django_oidc.contrib.drf.OIDCAuthentication`, which already validates `Authorization: Bearer …` against `OIDC_OP_JWKS_ENDPOINT` using the JWT signing algo from `OIDC_RP_SIGN_ALGO`. Subclassing it lets us reuse that machinery and only override user resolution + claim verification — no hand-rolled JWT parsing.

## Files to modify

### 1. `tdrs-backend/tdpservice/users/oidc.py` — extract reusable helpers

Currently `KeycloakOIDCBackend.filter_users_by_claims` (lines 30–64), `verify_claims` (117–145), `update_user` (79–100), and `create_user` (66–77) live as instance methods. Refactor: extract them into module-level functions that both the OIDC backend and the bearer authenticator can call. `KeycloakOIDCBackend` methods become thin wrappers.

```python
# New module-level helpers (called from both backends):
def filter_users_by_claims(claims: dict) -> list[User]: ...
def verify_claims(claims: dict) -> bool: ...
def apply_user_updates(user: User, claims: dict) -> User: ...
def create_user_from_claims(claims: dict) -> Optional[User]: ...
```

This is the minimum refactor needed — no behavior change, existing tests in `tdrs-backend/tdpservice/users/test/test_oidc.py` should pass unchanged.

### 2. `tdrs-backend/tdpservice/users/authentication.py` — new bearer-token auth class

Add `KeycloakBearerTokenAuthentication` next to the existing `CustomAuthentication`:

```python
from mozilla_django_oidc.contrib.drf import OIDCAuthentication
from tdpservice.users.oidc import (
    filter_users_by_claims, verify_claims,
    apply_user_updates, create_user_from_claims,
)

class KeycloakBearerTokenAuthentication(OIDCAuthentication):
    """Validate Keycloak-issued JWT bearer tokens for DRF requests."""

    def get_or_create_user(self, access_token, id_token, payload):
        # `payload` already contains decoded + signature-verified claims
        # (mozilla-django-oidc fetched JWKS, verified RS256, checked exp/aud).
        if not verify_claims(payload):
            return None
        users = filter_users_by_claims(payload)
        if users:
            return apply_user_updates(users[0], payload)
        return create_user_from_claims(payload)

    def authenticate(self, request):
        result = super().authenticate(request)
        if result is not None:
            user, token = result
            client_id = self._claims_from_token(token).get("azp", "unknown")
            logger.info(
                "Bearer token auth",
                extra={
                    "client_id": client_id,
                    "user_id": user.id,
                    "username": user.username,
                    "path": request.path,
                },
            )
            request._keycloak_client_id = client_id  # for ScopedRateThrottle
        return result
```

The `azp` (authorized party) claim is the Keycloak client that requested the token — exactly what we want for audit + per-client rate limiting.

### 3. `tdrs-backend/tdpservice/users/throttling.py` — new file

```python
from rest_framework.throttling import SimpleRateThrottle

class KeycloakClientRateThrottle(SimpleRateThrottle):
    """Throttle DRF requests by Keycloak client_id (azp claim).

    Falls through (no throttling) for non-bearer-authed requests so that
    browser sessions and the existing CustomAuthentication path are unaffected.
    """
    scope = "keycloak_client"

    def get_cache_key(self, request, view):
        client_id = getattr(request, "_keycloak_client_id", None)
        if not client_id:
            return None
        return self.cache_format % {"scope": self.scope, "ident": client_id}
```

### 4. `tdrs-backend/tdpservice/settings/common.py` — wire up DRF

Update `REST_FRAMEWORK` (lines 397–413):

- Add `tdpservice.users.authentication.KeycloakBearerTokenAuthentication` to `DEFAULT_AUTHENTICATION_CLASSES` (place before `SessionAuthentication`).
- Add throttle config:
  ```python
  "DEFAULT_THROTTLE_CLASSES": ("tdpservice.users.throttling.KeycloakClientRateThrottle",),
  "DEFAULT_THROTTLE_RATES": {"keycloak_client": os.getenv("KEYCLOAK_CLIENT_RATE", "300/min")},
  ```

Add a new throttle-dedicated cache to `CACHES` (lines 708–721) backed by Redis (DB 3, since 0/1/2 are taken by Celery / `stts` / `feature-flags`):

```python
"throttle": {
    "BACKEND": "django.core.cache.backends.redis.RedisCache",
    "LOCATION": f"{REDIS_URI}/3",
},
```

DRF's `SimpleRateThrottle` uses `default` cache; either point `default` at Redis in production, or override `cache` on the throttle class to use `caches["throttle"]`. Use the override approach to avoid changing the default cache for everything else.

### 5. `tdrs-backend/keycloak/realm-export.json` — add `tdp-cli` public client

Append to the `clients` array (after `tdp-grafana` at line 313). Mirror the structure of `tdp-django` (lines 243–280) but flip to public with PKCE + Device Authorization Grant:

```json
{
  "clientId": "tdp-cli",
  "name": "TDP CLI / Postman",
  "enabled": true,
  "publicClient": true,
  "clientAuthenticatorType": "none",
  "redirectUris": [
    "http://localhost/*",
    "http://127.0.0.1/*",
    "https://oauth.pstmn.io/v1/callback",
    "${KC_CLI_REDIRECT_URI:http://localhost/*}"
  ],
  "webOrigins": ["+"],
  "protocol": "openid-connect",
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": false,
  "fullScopeAllowed": true,
  "attributes": {
    "pkce.code.challenge.method": "S256",
    "oauth2.device.authorization.grant.enabled": "true"
  },
  "defaultClientScopes": ["openid", "email", "profile", "tdp-user-attributes"],
  "optionalClientScopes": []
}
```

Notes:
- `clientAuthenticatorType: "none"` + `publicClient: true` means no secret.
- `pkce.code.challenge.method: "S256"` enforces PKCE (no fallback to plain).
- `oauth2.device.authorization.grant.enabled: "true"` is the Keycloak attribute that enables the device flow (not a top-level field).
- `https://oauth.pstmn.io/v1/callback` is Postman's callback URL.
- `directAccessGrantsEnabled: false` blocks Resource Owner Password (per arch plan §7).

### 6. `tdrs-backend/tdpservice/users/test/test_bearer_token_auth.py` — new tests

Mirror the patterns in `test_oidc.py` (217 lines). Cover:

- Valid bearer token → user resolved by `hhs_id` / `login_gov_uuid` / email.
- Missing email → 401.
- ACF user with `identity_provider: login-gov` → 401.
- Deactivated user → 401.
- Unknown user with valid claims → user is created.
- Audit log line includes `client_id` (`azp`).
- Throttle key is keyed off `azp`.
- Mock JWKS response (use `responses` or `requests-mock`; check existing fixtures in `conftest.py`).

### 7. `tdrs-backend/keycloak/README.md` — short usage section

Add an "External API Clients" section with:

- Postman OAuth2 setup: discovery URL `${KEYCLOAK_BROWSER_URL}/realms/tdp/.well-known/openid-configuration`, client ID `tdp-cli`, no secret, PKCE S256, callback `https://oauth.pstmn.io/v1/callback`.
- Device Authorization Grant: `curl` example hitting `/realms/tdp/protocol/openid-connect/auth/device`, then poll `/token`.
- How to call Django: `Authorization: Bearer <access_token>` to any `/v1/...` endpoint.

## Verification

End-to-end manual + unit testing:

1. **Unit tests:** `task backend-pytest PYTEST_ARGS="tdpservice/users/test/test_bearer_token_auth.py tdpservice/users/test/test_oidc.py -v"` — both files pass.
2. **Lint:** `task backend-lint` is clean.
3. **Local Keycloak smoke test:**
   - `task backend-up` (brings up Keycloak + Django).
   - Confirm `tdp-cli` appears in Keycloak admin (http://localhost:8443, admin/admin → Clients).
4. **Postman flow** (per AC):
   - New request → Authorization tab → OAuth2 → Configure: Auth URL, Token URL from `.well-known`, client ID `tdp-cli`, PKCE S256.
   - "Get New Access Token" → popup → log in via Login.gov sandbox or AMS → token returned.
   - `GET http://localhost:8080/v1/users/me/` with the bearer token → 200 + user payload.
   - Same call without token → 401.
5. **Device Authorization Grant** (per AC):
   - `curl -X POST "${KC}/realms/tdp/protocol/openid-connect/auth/device" -d "client_id=tdp-cli&scope=openid"` → device_code + verification_uri.
   - Open the URL, authenticate, then poll `/token` with `grant_type=urn:ietf:params:oauth:grant-type:device_code` → access token.
   - Use it against `/v1/users/me/`.
6. **Throttling:** burst > `KEYCLOAK_CLIENT_RATE` calls with the same token → 429 once exceeded; verify with a second client (different `azp`) it's unaffected.
7. **Audit logging:** `task backend-logs` shows `Bearer token auth` log lines with `client_id=tdp-cli` and `user_id=…`.
8. **Authorization parity:** call an STT-scoped endpoint (e.g. `/v1/data_files/`) with a bearer token from a non-admin user → same 403 / filtered queryset as a session-authed request.

## Out of scope

- Building the actual Go CLI tool (separate ticket / future work).
- Removing legacy auth code (#5758).
- Confidential `tdp-ci` Client Credentials client — arch plan §7 mentions it for internal CI/CD, but it's not in this ticket's ACs. Defer.
- Frontend changes — none needed; this is a backend + Keycloak realm change only.
