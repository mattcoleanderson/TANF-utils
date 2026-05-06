# Implementation Plan: STT Feedback Reports UI (#5417)

**Status**: IN PROGRESS
**Last Updated**: 2025-12-11

## Overview
Implement a frontend UI for STT (State/Tribe/Territory) users to view and download their feedback reports. This is the companion to the admin upload interface in PR #5486.

---

## ✅ Completed

### Phase 1: Update Selectors and Permissions ✅
**File**: `tdrs-frontend/src/selectors/auth.js`

- ✅ Added `accountCanUploadFeedbackReports` selector
- ✅ Updated `accountCanViewFeedbackReports` to check for `view_reportfile`

### Phase 2: Extract Admin UI ✅
**Files Created**:
- ✅ `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.jsx`
- ✅ `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.test.js`

### Phase 3: Create STT Components ✅
**Files Created**:
- ✅ `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.jsx`
- ✅ `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReportsTable.jsx`

**Implementation Details**:
- Fiscal year dropdown using `getCurrentFiscalYear()` and `constructYearOptions()`
- Reference table showing FY quarters/calendar periods/deadlines
- Description text with contact emails
- Reports table with download functionality (download logic embedded in table component)

### Phase 4: Update Main Component as Wrapper ✅
**File**: `tdrs-frontend/src/components/FeedbackReports/FeedbackReports.jsx`

- ✅ Converted to wrapper component that conditionally renders:
  - `AdminFeedbackReports` for users with upload permissions
  - `STTFeedbackReports` for users with view-only permissions

### Phase 5: Update Routing ✅
**File**: `tdrs-frontend/src/components/Routes/Routes.js`

- ✅ Changed title from "Upload Feedback Reports" to "Feedback Reports"
- ✅ Updated subtitle to "Work Participation Rate and Time Limit Reports"
- ✅ Changed `requiredPermissions` from `['view_reportsource', 'add_reportsource']` to `['view_reportfile']`

### Phase 6: Update Navigation ✅
**File**: `tdrs-frontend/src/components/Header/Header.jsx`

- ✅ Imported `accountCanViewFeedbackReports` selector
- ✅ Added `userCanViewFeedbackReports` selector call
- ✅ Updated Feedback Reports nav item to use `userCanViewFeedbackReports` instead of `userIsAdmin`

---

## 🚧 Remaining Work

### 1. Write Tests for New Components 🔲
**Files Needed**:
- 🔲 `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.test.js`
- 🔲 `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReportsTable.test.js`
- 🔲 `tdrs-frontend/src/components/FeedbackReports/FeedbackReports.test.js` (update for wrapper)
- 🔲 `tdrs-frontend/src/components/Header/Header.test.js` (update for new selector)

**Test Coverage Required**:
- STTFeedbackReports component rendering
- Fiscal year selection and filtering
- Reports fetching and display
- Loading states
- Error states
- Empty states
- Download functionality
- Conditional rendering in wrapper component
- Permission-based navigation visibility

### 2. Run Tests and Fix Issues 🔲
- 🔲 Run `task frontend-test` to execute all tests
- 🔲 Fix any failing tests
- 🔲 Ensure coverage meets 90% target
- 🔲 Run `task frontend-lint` and fix linting issues

### 3. Manual Testing 🔲
- 🔲 Test as admin user (should see upload interface)
- 🔲 Test as Data Analyst (should see STT interface)
- 🔲 Test fiscal year filtering
- 🔲 Test report downloads
- 🔲 Test error handling
- 🔲 Test empty states
- 🔲 Test navigation visibility

### 4. Create Pull Request 🔲
- 🔲 Create commit with all changes
- 🔲 Create PR against `develop` branch
- 🔲 Link to issue #5417
- 🔲 Add description referencing design decisions

---

## Design Decisions

### 1. Routing: Same Route with Conditional Rendering
- Use existing `/feedback-reports` route
- Conditionally render Admin UI vs STT UI based on permissions
- Admin users with `add_reportsource` see upload interface
- STT users with only `view_reportfile` see read-only view

### 2. State Management: Local State (useState)
- Follow the same pattern as the existing admin `FeedbackReports.jsx`
- No Redux needed - page-specific, isolated state
- Fresh fetch on page load is acceptable for small data volume

### 3. Year Filtering: Client-Side
- Backend doesn't currently support `?year=` parameter
- Fetch all reports from `/reports/` and filter client-side
- Data volume is small (typically 4 reports/year per STT)

### 4. Downloads: Embedded in Table Component
- Download logic embedded directly in `STTFeedbackReportsTable.jsx`
- No separate utility file created
- Uses axios with blob response type

### 5. Reuse Existing Utilities
- `getCurrentFiscalYear()` from `Reports/utils.js`
- `constructYearOptions()` for year dropdown
- `PaginatedComponent` from `Paginator/Paginator.jsx`

---

## File Changes Summary

### New Files Created (5)
1. ✅ `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.jsx`
2. ✅ `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.test.js`
3. ✅ `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.jsx`
4. ✅ `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReportsTable.jsx`
5. 🔲 `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.test.js` (TODO)
6. 🔲 `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReportsTable.test.js` (TODO)

### Modified Files (4)
1. ✅ `tdrs-frontend/src/selectors/auth.js`
2. ✅ `tdrs-frontend/src/components/FeedbackReports/FeedbackReports.jsx`
3. ✅ `tdrs-frontend/src/components/Routes/Routes.js`
4. ✅ `tdrs-frontend/src/components/Header/Header.jsx`
5. 🔲 `tdrs-frontend/src/components/FeedbackReports/FeedbackReports.test.js` (TODO)
6. 🔲 `tdrs-frontend/src/components/Header/Header.test.js` (TODO)

---

## UI Design (from Figma)

### Reference Table
| Fiscal Year (FY) & Quarter (Q) | Calendar Period | Reporting Deadline |
|-------------------------------|-----------------|-------------------|
| FY Q1 | Oct 1 - Dec 31 | February 14 |
| FY Q2 | Jan 1 - Mar 31 | May 15 |
| FY Q3 | Apr 1 - Jun 30 | August 14 |
| FY Q4 | Jul 1 - Sep 30 | November 14 |

### Description Text
> Feedback reports are produced cumulatively throughout each fiscal year. Each ZIP files contains multiple feedback reports for the work participation rate and time limit. Please refer to the most recently produced report for the most up-to-date feedback about your data.
>
> Please review this feedback and, if needed, resubmit complete and accurate data via TDP.
>
> If you have questions or require assistance, feel free to contact Yun.Song@acf.hhs.gov and copy TANFData@acf.hhs.gov.
>
> For more detail about each report, refer to the Feedback Report Reference in the TDP Knowledge Center.

### Reports Table
| Feedback generated on | Fiscal quarters included in feedback | Files |
|----------------------|-------------------------------------|-------|
| 03/05/2025 10:41 AM | Q2 | F33.zip |
| 01/08/2025 9:48 AM | Q1 | F33.zip |

**Note:** Quarter column displays single quarter value from `ReportFile.quarter` field (not cumulative).

---

## Next Steps

1. **Write tests** for `STTFeedbackReports`, `STTFeedbackReportsTable`, and update wrapper tests
2. **Update existing tests** for `FeedbackReports.jsx` (wrapper) and `Header.jsx` (nav visibility)
3. **Run full test suite** and ensure all tests pass
4. **Manual testing** in local environment
5. **Create PR** with all changes

---

## Notes

- Download functionality is embedded in `STTFeedbackReportsTable` instead of a separate utility
- No Redux actions/reducers created - using local state pattern from admin UI
- Backend endpoint `/reports/` already filters by STT automatically for Data Analysts
- SiteMap.jsx already uses `accountCanViewFeedbackReports` selector, so it will work automatically once selector is updated
