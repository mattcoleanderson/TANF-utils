# E2E Tests for Admin Feedback Reports

## Original Prompt

> Implement the following github issue: https://github.com/raft-tech/TANF-app/issues/5421
>
> The following are reference issues / PRs that will help in understanding the core feature the E2E tests are for:
> - STT Feedback Report UI:
>   - Issue: https://github.com/raft-tech/TANF-app/issues/5417
>   - PR: https://github.com/raft-tech/TANF-app/pull/5529
> - Admin Feedback Report UI:
>   - Issue: https://github.com/raft-tech/TANF-app/issues/5390
>   - PR: https://github.com/raft-tech/TANF-app/pull/5486
> - Backend Feedback Report:
>   - Issue: https://github.com/raft-tech/TANF-app/issues/5397
>   - PR: https://github.com/raft-tech/TANF-app/pull/5438
>
> The most recent PR is the STT Feedback Report UI, and actually had significant changes to the design and implementation of the Admin UI and Backend.
>
> You will be implementing E2E tests for just the Admin Feedback Report.
>
> Explore the projects components to understand how the components work.
>
> use context7 to lookup cypress documentation. Then explore the reports cypress tests to get an understanding of our patterns.
>
> Then create a detailed plan to create the cypress tests. The plan should be broken into phases that can be done in one session. Each task should have a checkbox so the plan can be updated with what has been completed in each session

---

## Context

Issue #5421 requires implementing Cypress E2E tests for the **Admin Feedback Report** workflow. This is the final "confidence layer" for the feedback reports epic. The backend (#5397/#5438), admin UI (#5390/#5486), and STT UI (#5417/#5529) are all merged. The E2E tests ensure the admin upload workflow functions correctly end-to-end.

**The Admin Feedback Report flow:**
1. Admin (OFA System Admin or DIGIT Team) navigates to `/feedback-reports`
2. Selects a fiscal year from dropdown (`#fiscal-year-select`)
3. Sees upload form with file input (`#feedback_reports`) and date picker (`#date-extracted-on`)
4. Uploads a ZIP file → backend creates `ReportSource` (PENDING)
5. Celery task processes ZIP → creates `ReportFile` per STT → sends email notifications
6. Upload history table shows status progression (Pending → Processing → Parsed & Notified)
7. Validation catches: no file, non-zip, FY mismatch, missing date

---

## Critical Files

### Frontend Components (to test against)
- `tdrs-frontend/src/components/FeedbackReports/FeedbackReports.jsx` — Wrapper (Admin vs STT routing)
- `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.jsx` — Main admin UI
- `tdrs-frontend/src/components/FeedbackReports/FeedbackReportsUpload.jsx` — File input + date picker
- `tdrs-frontend/src/components/FeedbackReports/FeedbackReportsHistory.jsx` — Upload history table
- `tdrs-frontend/src/selectors/auth.js` — `accountCanUploadFeedbackReports` selector

### Backend API Endpoints (exercised by tests)
- `POST /v1/reports/report-sources/` — Upload feedback report ZIP
- `GET /v1/reports/report-sources/?year={year}` — List upload history
- `GET /v1/reports/report-sources/{id}/` — Get individual report source status

### Test Data (existing fixtures)
- `tdrs-backend/tdpservice/reports/test/data/FY2025_valid_single_stt.zip` — 1 STT (Alabama)
- `tdrs-backend/tdpservice/reports/test/data/FY2025_valid_multiple_stts_same_region.zip` — 2 STTs
- `tdrs-backend/tdpservice/reports/test/data/FY2025_invalid_empty_stt_folder.zip` — Empty STT folder
- `tdrs-backend/tdpservice/reports/test/data/invalid_flat_structure.zip` — Invalid structure

### Existing Patterns to Reuse
- `cypress/support/commands.js` — `cy.login()`, `cy.adminApiRequest()`, `cy.waitForDataFileSummary()`
- `cypress/e2e/common-steps/common-steps.js` — `ACTORS` dict, `loginAsActor()`
- `cypress/e2e/common-steps/data_files.js` — `uploadFile()` pattern, download helpers
- `cypress/e2e/common-steps/a11y.js` — `checkA11y()` for accessibility testing

### Key UI Selectors
| Element | Selector |
|---------|----------|
| Fiscal Year dropdown | `#fiscal-year-select` |
| File input | `#feedback_reports` or `.usa-file-input` |
| Date picker input | `#date-extracted-on` or `.usa-date-picker__external-input` |
| Upload button | `button` containing "Upload & Notify States" |
| Upload history table | `caption` containing "Upload History" |
| Alert messages | `.usa-alert__text` |
| Error messages | `.usa-error-message` |
| Header nav (primary) | `.usa-nav__primary` |

### Error Messages (from AdminFeedbackReports.jsx)
- `"No file selected."`
- `"Invalid file. Make sure to select a zip file."`
- `"Your file's Fiscal Year does not match the selected Fiscal Year for this upload."`
- `"Choose the date that the data you're uploading was extracted from the database."`
- Success: `"Feedback report uploaded successfully! Processing has begun..."`

---

## Session Setup

**At the beginning of each implementation session**, use context7 to fetch up-to-date Cypress documentation:

```
# Resolve Cypress library ID
mcp__context7__resolve-library-id(libraryName: "cypress", query: "e2e testing best practices")

# Then query for relevant docs based on the phase you're working on:
# Phase 1-2: cy.intercept, cy.selectFile, custom commands, file uploads
mcp__context7__query-docs(libraryId: "/cypress-io/cypress-documentation", query: "cy.intercept file upload selectFile custom commands best practices")

# Phase 3-4: assertions, error handling, form validation
mcp__context7__query-docs(libraryId: "/cypress-io/cypress-documentation", query: "assertions should contain error validation form testing")

# Phase 5: accessibility testing
mcp__context7__query-docs(libraryId: "/cypress-io/cypress-documentation", query: "accessibility testing cypress-axe a11y")
```

This ensures you have the latest Cypress API references and patterns available during implementation.

---

## Important Discoveries

### User Permissions
- **"Admin Alex"** is in group **"OFA System Admin"** — has feedback reports access
- **"DIGIT Diana"** is in group **"DIGIT Team"** — has feedback reports access
- **"Data Analyst Tim"** — does NOT have `view_reportfile` permission, cannot see nav item
- **"Regional Staff Cypress"** — does NOT have `view_reportfile` permission, cannot see nav item
- The Background step uses `'DIGIT Diana' logs in` (not Admin Alex) since DIGIT Team is the primary group with upload permissions
- The nav item visibility is gated by `accountCanViewFeedbackReports` which requires `view_reportfile` permission
- Step `'{string} logs in'` is defined globally in `common-steps.js` — do NOT redefine it in the feature step definitions file

### Nginx Configuration
- Added `location ^~ /feedback-reports` to both `nginx/local/locations.conf` and `nginx/cloud.gov/locations.conf`
- Without this, `cy.visit('/feedback-reports')` returns 404 from nginx
- Must rebuild frontend container (`task frontend-up` or `task up`) after changing nginx config
- The `navigateToFeedbackReports()` helper uses `cy.visit('/feedback-reports')` directly (not nav click)

### Nav Selector
- When checking that "Feedback Reports" is NOT in the nav, use `.usa-nav__primary` selector (header nav)
- Do NOT use `cy.get('nav')` — this matches the footer nav (`nav.usa-footer__nav`) which may contain "Feedback Reports" text

---

## Implementation Plan

### Files Created
```
tdrs-frontend/cypress/e2e/feedback-reports/
  ├── admin-feedback-reports.feature    # Gherkin scenarios (12 scenarios)
  ├── admin-feedback-reports.js         # Step definitions
  └── feedback-reports-helpers.js       # Shared helper functions
```

### Files Modified
```
tdrs-frontend/cypress/support/commands.js          # Added waitForReportSourceProcessing
tdrs-frontend/nginx/local/locations.conf            # Added /feedback-reports location
tdrs-frontend/nginx/cloud.gov/locations.conf        # Added /feedback-reports location
```

---

## Phase 1: Foundation & Infrastructure ✅

- [x] **1.1 Create `feedback-reports-helpers.js`** — shared utilities for feedback report tests
  - `navigateToFeedbackReports()` — visit `/feedback-reports`, wait for page load
  - `selectFiscalYear(year)` — select from `#fiscal-year-select`, wait for content
  - `uploadFeedbackZip(filePath)` — handle USWDS file input with drag-drop
  - `enterExtractionDate(dateStr)` — type into USWDS date picker external input
  - `clickUploadAndNotify()` — click the submit button
  - `verifyUploadHistoryVisible()`, `verifyNoUploadHistory()`, `getLatestUploadHistoryRow()`
  - Constants: `TEST_ZIP_DIR`, `ERROR_MESSAGES`, `SUCCESS_MESSAGE`

- [x] **1.2 Add `waitForReportSourceProcessing` custom command** to `cypress/support/commands.js`
  - Follows the pattern of existing `waitForDataFileSummary`
  - Polls `GET /v1/reports/report-sources/{id}/` until status !== 'PENDING' && status !== 'PROCESSING'
  - Max 60 attempts, 2000ms interval (matches existing pattern)

- [x] **1.3 Create `admin-feedback-reports.feature`** — Gherkin feature file with all scenarios

- [x] **1.4 Create `admin-feedback-reports.js`** — Step definitions implementing all scenarios

- [x] **1.5 Add nginx location for `/feedback-reports`** in both local and cloud.gov configs

## Phase 2: Happy Path Tests ✅

- [x] **2.1 Scenario: DIGIT Team navigates to Feedback Reports page**
- [x] **2.2 Scenario: DIGIT Team sees upload form after selecting fiscal year**
- [x] **2.3 Scenario: DIGIT Team uploads a valid feedback report ZIP**

## Phase 3: Validation Error Tests ✅

- [x] **3.1 Scenario: Error when no file selected**
- [x] **3.2 Scenario: Error when non-ZIP file selected**
- [x] **3.3 Scenario: Error when ZIP file fiscal year mismatches**
- [x] **3.4 Scenario: Error when no date selected**

## Phase 4: Upload History, State Management & Permissions ✅

- [x] **4.1 Scenario: Upload history filters by fiscal year**
- [x] **4.2 Scenario: Form resets when fiscal year changes**
  - Fixed: Changed assertion from `.usa-file-input__preview` (USWDS artifact persists) to `#feedback_reports` input value check
- [x] **4.3 Scenario: OFA System Admin can access admin feedback reports**
- [x] **4.4 Scenario: OFA Regional Staff cannot see Feedback Reports nav item**
  - Fixed: Changed `cy.get('nav')` to `cy.get('.usa-nav__primary')` to avoid matching footer nav
- **4.5 REMOVED: Data Analyst scenario** — Data Analyst has their own version of the Feedback Reports page; separate issue will cover those e2e tests

**All 11 scenarios passing as of 2026-02-18.**

## Phase 5: Accessibility & Final Review ✅

- [x] **5.1 Add accessibility tests** for the Feedback Reports page
  - Created `cypress/e2e/feedback-reports/a11y.js`
  - Tests admin view before and after selecting fiscal year
  - Uses `beforeEach` login (not `before`) to ensure session is fresh for each test
- [x] **5.2 Review and finalize all tests**
  - Full suite run: 52 passing, 16 failing (all failures pre-existing, unrelated to feedback-reports)
  - feedback-reports spec: 13/13 passing (11 feature + 2 a11y), no regressions
  - Pre-existing failures: submission_history (1), profile-editing (15 — missing fixture users)

---

## Verification

1. **Start services**: `task up` (both frontend and backend)
2. **Load cypress fixtures**: `task e2e-env-var-setup`
3. **Run just the new tests**: `npx cypress run --spec "cypress/e2e/feedback-reports/**"`
4. **Run with UI**: `npx cypress open` and select the feature file
5. **Run full suite**:  to ensure no regressions
6. **Check accessibility**: Verify the a11y test passes

---

## Notes

- The USWDS date picker creates a secondary external input that must be targeted for typing dates — use `.usa-date-picker__external-input` selector
- The USWDS file input uses a custom wrapper; `cy.selectFile()` with `{ action: 'drag-drop', force: true }` is the established pattern
- Report processing is asynchronous (Celery); the polling pattern from `waitForDataFileSummary` should be adapted
- Test users: "DIGIT Diana" (DIGIT Team) is the primary test user, "Admin Alex" (OFA System Admin) is used for permission verification
- Test ZIPs exist at `tdrs-backend/tdpservice/reports/test/data/` — no new fixtures needed
- The `'{string} logs in'` step is defined globally in `common-steps/common-steps.js` — never redefine it in feature-specific step files or you get "Multiple matching step definitions" error
- `docker-compose.local.yml` for the frontend uses `npm run start` on an isolated `local` network with no API proxy — use `task frontend-up` (normal docker-compose.yml with nginx) instead for E2E testing
