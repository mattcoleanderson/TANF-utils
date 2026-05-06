# Frontend FRA Feedback Reports Implementation Plan

**Issue:** [#5665](https://github.com/raft-tech/TANF-app/issues/5665)
**Branch:** `5665-frontend-fra-feedback-reports-implementation`
**Deadline:** April 29, 2026

## Context

The existing Feedback Reports UI was built exclusively for TANF/SSP reports. The backend already supports a `report_type` field (`TANF_SSP` | `FRA`) with query param filtering (via PR #5765), but the frontend never exposes it. This plan extends the frontend to support FRA feedback reports across three areas: Admin upload UI, STT/Regional view, and in-app alerts.

## FRA Access Model (Research Summary)

**Permission:** `has_fra_access` (Django permission on User model)

**Who has it automatically (via group):**
- OFA System Admin, OFA Admin, OFA Regional Staff, Developer

**Who must request it individually:**
- Data Analyst — granted via `UserChangeRequest` or `request_access` endpoint

**Who cannot have it:**
- Tribes (FRA not applicable)

**Frontend check:** `selectUserPermissions(state).includes('has_fra_access')`

**Implication for radio selector visibility:**
- **Admin view:** Radio always visible — anyone with upload access can submit for all program types
- **STT view:** If user has `has_fra_access` → show radio (TANF/SSP + FRA); if not → no radio, auto-default to TANF_SSP
- Since all users who can view feedback reports have TANF/SSP access, having FRA access always means both are available

---

## Phase 1: New Auth Selector + Shared Constants ✅ COMPLETE

### Files to create/modify:
- `tdrs-frontend/src/selectors/auth.js`

### Changes:

1. **Add `accountHasFraAccess` selector** in `auth.js`:
   ```js
   export const accountHasFraAccess = (state) =>
     accountStatusIsApproved(state) &&
     selectUserPermissions(state).includes('has_fra_access')
   ```

2. **Define report type constants** — add at top of `FeedbackReports.jsx` or a shared utils file if needed:
   ```js
   const REPORT_TYPES = {
     TANF_SSP: 'TANF_SSP',
     FRA: 'FRA',
   }
   const REPORT_TYPE_LABELS = {
     TANF_SSP: 'TANF/SSP',
     FRA: 'FRA',
   }
   ```

---

## Phase 2: Admin UI (`AdminFeedbackReports`) ✅ COMPLETE

### Files to modify:
- `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.jsx`
- `tdrs-frontend/src/components/FeedbackReports/FeedbackReportsHistory.jsx`
- `tdrs-frontend/src/components/Routes/Routes.js` (subtitle update)

### Changes:

#### 2a. Report Type Radio Selector
- Add `selectedReportType` state, initialized from URL query param `type` (default `TANF_SSP`)
- Add radio button group with options: TANF/SSP, FRA
- Radio only shown if user has `has_fra_access` (use `accountHasFraAccess` selector)
- If user doesn't have FRA access, auto-default to `TANF_SSP` and enforce it even if URL has `type=FRA`
- Sync `type` param to URL alongside existing `year` param
- Reset form state when report type changes (same pattern as year change)

#### 2b. Include `report_type` in API Calls
- **Upload POST** (`/reports/report-sources/`): append `report_type` to FormData
- **History GET** (`/reports/report-sources/?year={year}`): add `&report_type={type}` param
- Both already supported by backend views

#### 2c. Contextual Description Text
- Current: "Once submitted, TDP will distribute feedback reports to TANF/SSP submission history pages..."
- When TANF/SSP selected: keep current text
- When FRA selected: Update language to match the suggested language from the issue (generic, not TANF/SSP-specific)

#### 2d. Upload History Table
- Add `Report Type` column to `FeedbackReportsHistory` showing "TANF/SSP" or "FRA"
- OR: contextually filter by selected report type (preferred — matches the pattern of selecting a type then seeing its history)

#### 2e. Section Header Update
- Current: `Fiscal Year {selectedYear} — Upload Feedback Reports`
- Updated: `Fiscal Year {selectedYear} — Upload {reportTypeLabel} Feedback Reports`

#### 2f. Route Subtitle (Routes.js)
- Current admin subtitle: `'TANF WPR, SSP WPR, TANF & SSP Combined, and Time Limit Reports'`
- This is static and doesn't know the selected type. Keep as-is or generalize to cover both. Consider: `'TANF/SSP and FRA Feedback Reports'` if user has FRA access, otherwise keep current.

---

## Phase 3: STT View (`STTFeedbackReports`) ✅ COMPLETE

### Files to modify:
- `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.jsx`

### Changes:

#### 3a. Report Type Radio Selector
- Add `selectedReportType` state, initialized from URL query param `type` (default `TANF_SSP`)
- Use `accountHasFraAccess` selector to determine visibility
- If user has FRA access: show radio with TANF/SSP and FRA options
- If user does NOT have FRA access: no radio, force `TANF_SSP`, guard against URL manipulation
- Position: above Fiscal Year selector (matching design screenshots)
- Sync `type` to URL query params

#### 3b. Include `report_type` in Fetch
- Update `fetchReports` to add `report_type` param:
  ```js
  params.report_type = selectedReportType
  ```
- Re-fetch when report type changes (add to useCallback deps and useEffect)

#### 3c. Contextual Reference Table
- Current: hardcoded "TANF/SSP Data Reporting Reference" with TANF/SSP quarters
- When FRA selected: show "FRA Data Reporting Reference" with FRA-specific deadlines
  - FRA quarters have different due dates (reference `FiscalQuarterExplainer` in `FRAReports.jsx`):
    - FY Q1: Oct 1 - Dec 31, Due May 15
    - FY Q2: Jan 1 - Mar 31, Due August 14
    - FY Q3: Apr 1 - Jun 30, Due November 14
    - FY Q4: Jul 1 - Sep 30, Due February 14

#### 3d. Contextual Description Text
- Current: TANF/SSP-specific language about work participation rate and time limit
- When FRA selected: Use the suggested language from the issue (generic, program-agnostic)
- Contact info: Keep `TANFData@acf.hhs.gov` for both (or adjust per requirements)

#### 3e. Header Update
- Current: `{sttName} — Fiscal Year {selectedYear} Feedback Reports`
- Updated: `{sttName} — {reportTypeLabel} Fiscal Year {selectedYear} Feedback Reports`
  (matches design screenshots: "Alabama — TANF/SSP Fiscal Year 2025 Feedback Reports")

#### 3f. Regional Staff STT Filtering
- When FRA is selected, filter tribes from STT list (reuse `availableStts` selector pattern — pass path that includes 'fra')
- Actually: `availableStts('/fra')` already filters tribes. Use this when FRA is selected.
- When TANF/SSP selected: use `availableStts('/feedback-reports')` (includes all STTs)
- Dynamic: `useSelector(availableStts(selectedReportType === 'FRA' ? '/fra' : '/feedback-reports'))`

---

## Phase 4: In-App Alerts (`FeedbackReportAlert`) ✅ COMPLETE

### Files to modify:
- `tdrs-frontend/src/components/FeedbackReports/FeedbackReportAlert.jsx`
- `tdrs-frontend/src/components/Reports/FRAReports.jsx` (add alert)
- `tdrs-frontend/src/components/Reports/tdr/TanfSspReports.jsx` (pass report_type)

### Changes:

#### 4a. Add `reportType` Prop to FeedbackReportAlert
- New prop: `reportType` (default `'TANF_SSP'`)
- Include in fetch: `params.report_type = reportType`
- Include in localStorage key: `feedbackAlertDismissed_{reportType}_{year}` (separate dismiss state per type)
- Include in link URL: `href={/feedback-reports?year=${year}&type=${reportType}...}`
- Update alert text to indicate report type: "TANF/SSP Feedback Reports Available..." or "FRA Feedback Reports Available..."

#### 4b. Update TanfSspReports Usage
- Pass `reportType="TANF_SSP"` to existing `<FeedbackReportAlert>`:
  ```jsx
  <FeedbackReportAlert stt={isRegionalStaff ? stt : null} reportType="TANF_SSP" />
  ```

#### 4c. Add FeedbackReportAlert to FRAReportsContent
- Import `FeedbackReportAlert` in `FRAReports.jsx`
- Add it after the header (same pattern as TanfSspReports):
  ```jsx
  {(isDataAnalyst || isRegionalStaff) && (
    <FeedbackReportAlert stt={isRegionalStaff ? stt : null} reportType="FRA" />
  )}
  ```
- Need to determine `isDataAnalyst` — check if there's an existing selector or derive from role name
- Note: `FRAReportsContent` already has `isRegionalStaff` selector. Need to add Data Analyst check.

#### 4d. Data Analyst Detection in FRAReports
- Check existing patterns. In `TanfSspReports`, `isDataAnalyst` is passed as a prop. Trace where it comes from.
- Add same prop or selector to FRAReportsContent.

---

## Phase 5: Tests

### Files to modify:
- `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.test.js`
- `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.test.js`
- `tdrs-frontend/src/components/FeedbackReports/FeedbackReportAlert.test.js`
- `tdrs-frontend/src/components/FeedbackReports/FeedbackReportsHistory.test.js`
- `tdrs-frontend/src/selectors/auth.test.js` (if exists)

### Test Cases:

#### Admin UI Tests
- Radio selector visible when user has `has_fra_access`
- Radio selector hidden when user lacks `has_fra_access`
- Selecting FRA updates URL param
- Upload includes `report_type` in form data
- History fetched with `report_type` filter
- Description text changes based on selected type

#### STT View Tests
- Radio selector visible when Data Analyst has `has_fra_access`
- Radio selector hidden when Data Analyst lacks `has_fra_access`
- Regional Staff always sees radio (has `has_fra_access` via group)
- FRA type enforced — URL manipulation rejected without permission
- Reference table changes based on selected type
- Fetch includes `report_type` param
- Tribes filtered from STT list when FRA selected

#### FeedbackReportAlert Tests
- Fetches with `report_type` param
- localStorage key includes report type
- Alert text includes report type label
- Link URL includes `type` param
- Works correctly on FRA Data Files page

---

## Verification

### Manual Testing
1. **Admin Upload (OFA System Admin):**
   - Navigate to `/feedback-reports`
   - Verify radio selector shows TANF/SSP and FRA
   - Select FRA, select year, upload a zip — verify `report_type=FRA` sent in POST
   - Verify upload history filters by selected type
   - Verify URL has `?type=FRA&year=2025`

2. **STT View (Data Analyst with FRA access):**
   - Navigate to `/feedback-reports`
   - Verify radio selector shows both options
   - Select FRA — verify reference table shows FRA deadlines
   - Verify reports fetched with `report_type=FRA`
   - Verify description text is contextual

3. **STT View (Data Analyst WITHOUT FRA access):**
   - Navigate to `/feedback-reports`
   - Verify no radio selector
   - Manually set `?type=FRA` in URL — verify it's rejected/ignored
   - Verify only TANF_SSP reports shown

4. **In-App Alerts:**
   - On TANF Data Files page: verify alert fetches TANF_SSP reports only
   - On FRA Data Files page: verify alert fetches FRA reports only
   - Verify dismiss state is independent per report type
   - Verify alert link includes `type` param

### Automated Tests
```bash
/test frontend FeedbackReport
/test frontend AdminFeedbackReports
/test frontend STTFeedbackReports
/test frontend FeedbackReportAlert
```

---

## File Change Summary

| File | Change Type |
|------|------------|
| `tdrs-frontend/src/selectors/auth.js` | Add `accountHasFraAccess` selector |
| `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.jsx` | Add report type radio, update API calls, contextual text |
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReportsHistory.jsx` | Minimal — history is contextually filtered by type |
| `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.jsx` | Add report type radio, contextual reference table, update fetch |
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReportAlert.jsx` | Add `reportType` prop, update fetch/link/localStorage |
| `tdrs-frontend/src/components/Reports/FRAReports.jsx` | Add FeedbackReportAlert, add isDataAnalyst detection |
| `tdrs-frontend/src/components/Reports/tdr/TanfSspReports.jsx` | Pass `reportType="TANF_SSP"` to FeedbackReportAlert |
| `tdrs-frontend/src/components/Routes/Routes.js` | Update subtitle to be FRA-aware (if needed) |
| Test files (4-5 files) | Update/add test cases for all above |

## Existing Utilities to Reuse

- `selectUserPermissions(state)` — `tdrs-frontend/src/selectors/auth.js:19`
- `availableStts(path)` — `tdrs-frontend/src/selectors/stts.js:3` (filters tribes when path includes 'fra')
- `constructYears()` — `tdrs-frontend/src/components/Reports/utils.js`
- `useSearchParams` from react-router-dom (already used in both components)
- FRA deadline data from `FiscalQuarterExplainer` in `FRAReports.jsx:75-108`
- `RadioSelect` component — `tdrs-frontend/src/components/Form` (used in FRAReports for file type selection)

---

## Pending Decisions (Awaiting UX Response)

- [ ] **Feedback Reports page subtitle (Routes.js):** The current admin subtitle `'TANF WPR, SSP WPR, TANF & SSP Combined, and Time Limit Reports'` doesn't encompass FRA. Waiting on UX (@reitermb, @victoriaatraft) for the updated copy. File: `tdrs-frontend/src/components/Routes/Routes.js:60-61`
- [ ] **E2E upload test — Cypress corrupts binary zip files:** The "DIGIT Team member can upload a valid feedback report" e2e test fails because Cypress `selectFile` with `action: 'drag-drop'` UTF-8 encodes binary zip data, corrupting it (462 bytes → 530 bytes with `\xef\xbf\xbd` replacement chars). **Confirmed: also fails on `develop` branch** — pre-existing issue unrelated to FRA changes. Test is currently commented out. Fix: use `cy.readFile(path, null)` to read as binary buffer before passing to `selectFile`. File: `tdrs-frontend/cypress/e2e/feedback-reports/feedback-reports-helpers.js:42-57`
