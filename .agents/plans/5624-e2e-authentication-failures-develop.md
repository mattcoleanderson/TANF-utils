# Fix E2E Authentication Failures in Develop (#5624)

## Context
Cypress E2E tests run post-merge on CircleCI against `https://tdp-frontend-develop.acf.hhs.gov`. CircleCI runners use AWS (us-east-1, us-east-2) and GCP (us-east1, us-central1) IPs that aren't in the nginx IP allow-list, causing intermittent 403 errors across the entire test suite. The fix: give develop a separate allow-list that includes these cloud provider IP ranges.

## Implementation

### 1. Create IP range generation script
**New file:** `scripts/generate-circleci-ip-ranges.sh`

Script that:
- Downloads AWS IP ranges from `https://ip-ranges.amazonaws.com/ip-ranges.json`
- Filters for EC2 service in `us-east-1` and `us-east-2`
- Downloads GCP IP ranges from `https://www.gstatic.com/ipranges/cloud.json`
- Filters for `us-east1` and `us-central1` scopes
- Outputs nginx `allow` directives to `tdrs-frontend/nginx/cloud.gov/ip_circleci_runners.conf`
- Includes a generation timestamp comment header
- Requires `curl` and `jq`

### 2. Generate and commit the CircleCI runner IP ranges
**New file:** `tdrs-frontend/nginx/cloud.gov/ip_circleci_runners.conf`

Run the script from step 1 to produce this file. It will contain lines like:
```
allow 3.80.0.0/12;
allow 34.192.0.0/10;
...
```

### 3. Create develop-specific ip_whitelist.conf
**New file:** `tdrs-frontend/nginx/cloud.gov/ip_whitelist_develop.conf`

```nginx
location / {
    include ip_whitelist_ipv4.conf;
    include ip_whitelist_ipv6.conf;
    include ip_circleci_runners.conf;
    deny all;
}
```

Identical to existing `ip_whitelist.conf` but adds the CircleCI ranges include.

### 4. Modify deploy script to use develop-specific config
**Modify:** `scripts/deploy-frontend.sh` (lines 63-65)

Replace the single `cp` for `ip_whitelist.conf` with a conditional based on `$CGHOSTNAME_FRONTEND`:

```sh
cp nginx/cloud.gov/ip_whitelist_ipv4.conf deployment/ip_whitelist_ipv4.conf
cp nginx/cloud.gov/ip_whitelist_ipv6.conf deployment/ip_whitelist_ipv6.conf

if [ "$CGHOSTNAME_FRONTEND" = "tdp-frontend-develop" ]; then
    cp nginx/cloud.gov/ip_whitelist_develop.conf deployment/ip_whitelist.conf
    cp nginx/cloud.gov/ip_circleci_runners.conf deployment/ip_circleci_runners.conf
else
    cp nginx/cloud.gov/ip_whitelist.conf deployment/ip_whitelist.conf
fi
```

**Why key off `$CGHOSTNAME_FRONTEND`?** Both develop and staging use `cf-space: tanf-staging`, so `$CF_SPACE` can't distinguish them.

## Files Summary

| File | Action |
|------|--------|
| `scripts/generate-circleci-ip-ranges.sh` | Create |
| `tdrs-frontend/nginx/cloud.gov/ip_circleci_runners.conf` | Create (generated) |
| `tdrs-frontend/nginx/cloud.gov/ip_whitelist_develop.conf` | Create |
| `scripts/deploy-frontend.sh` | Modify (lines 63-65) |

## Verification
1. Run `scripts/generate-circleci-ip-ranges.sh` and verify it produces valid nginx allow directives
2. Verify `ip_whitelist_develop.conf` includes all three allow files + `deny all`
3. Review `deploy-frontend.sh` logic: develop gets the expanded list, staging/prod get the original
4. After merge to develop, monitor the `test-deployment-e2e` CircleCI job — it should no longer 403

## Future Maintenance
If E2E tests start failing with 403s again, re-run `scripts/generate-circleci-ip-ranges.sh` to refresh the IP ranges and commit the updated `ip_circleci_runners.conf`.
