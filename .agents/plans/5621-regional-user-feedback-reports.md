# Implementation: Regional User Support for STT Feedback Reports (#5621)

**Status**: COMPLETE
**Branch**: `5621-add-regional-user-support-for-stt-feedback-reports-page`
**Base**: `develop`
**Last Updated**: 2026-03-10

## Overview

OFA Regional Staff users could not access Feedback Reports because:
1. The `OFA Regional Staff` group lacked the `view_reportfile` permission
2. The backend `ReportFilePermissions` had no handling for regional staff
3. The frontend `STTFeedbackReports` component assumed `user.stt.name` exists, but regional users have `regions` instead of `stt`

Regional staff now see the `STTFeedbackReports` component with an STT selector (ComboBox) filtered to their region's STTs. Reports auto-fetch when both an STT and fiscal year are selected.

---

## Completed Changes

### 1. Backend: Migration — `view_reportfile` permission for OFA Regional Staff ✅

**File**: `tdrs-backend/tdpservice/users/migrations/0056_add_regional_staff_report_permissions.py` (NEW)

- Adds `view_reportfile` permission to `OFA Regional Staff` group
- Follows pattern from `0052_add_report_permissions.py` (Data Analyst)
- Calls `create_perms` first, then adds the permission
- Includes reverse migration to remove the permission
- Depends on `0055_add_ofa_sys_admin_report_permissions`

### 2. Backend: `ReportFilePermissions` — regional staff handling ✅

**File**: `tdrs-backend/tdpservice/users/permissions.py` (lines 186-209)

**`has_permission`** (after the data analyst check):
- Regional staff **cannot** create report files (returns `False` for `create` action)
- Regional staff **can** list and download reports for STTs in their region
- Uses existing `is_own_region()` helper with `get_requested_stt()`

**`has_object_permission`**:
- Regional staff can only interact with report files for STTs in their region
- Checks `obj.stt.region in user.regions.all()`
- Mirrors the pattern from `DataFilePermissions` (lines 274-280)

**Removed**: TODO comments "Will Regional Staff use report files?"

### 3. Backend: `ReportFileViewSet.get_queryset` — regional filtering + `stt` param ✅

**File**: `tdrs-backend/tdpservice/reports/views.py` (lines 30-41)

- Added queryset filter for regional staff: `queryset.filter(stt__region__in=user_regions)`
- Added `stt` query parameter support: `queryset.filter(stt_id=stt)` — used by frontend to filter by specific STT
- The `stt` param works for all user types, placed after region/STT filtering

### 4. Frontend: `STTFeedbackReports` — STT selector for regional staff ✅

**File**: `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.jsx`

**New imports**: `accountIsRegionalStaff`, `availableStts`, `STTComboBox`

**Behavior for Regional Staff**:
- Renders `STTComboBox` above the fiscal year selector
- ComboBox auto-filters to STTs in the user's region (via `availableStts` selector)
- Auto-fetches reports when **both** STT and fiscal year are selected (no search button)
- Both selectors sync to URL query params: `?year=2025&stt=Wisconsin`
- STT query param uses the **STT name** (consistent with TanfSspReports page)
- On page load, initializes selections from URL params if valid
- Changing STT clears the current reports
- H2 heading shows the selected STT name

**Behavior for Data Analysts** (unchanged):
- No STT ComboBox shown
- Auto-fetches on year change
- Only `year` query param in URL

**Content section** (below HR) only shows when:
- Data Analyst: year is selected
- Regional Staff: both STT and year are selected

**API call** includes `stt` param (the STT **id**, not name) for regional staff:
```js
params: { year: 2025, stt: 10 }
```

### 5. Frontend: `STTFeedbackReportsTable` — column rename ✅

**File**: `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReportsTable.jsx`

- Renamed column header "Generated on" → "Uploaded on" (per client request)

### 6. Frontend: `STTFeedbackReports` — Knowledge Center link ✅

**File**: `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.jsx` (line 273)

- Knowledge Center link now points to `${REACT_APP_KNOWLEDGE_CENTER_LINK}/feedback-reports.html` instead of just `/`

### 7. Frontend: `FeedbackReportAlert` — regional staff support ✅

**File**: `tdrs-frontend/src/components/FeedbackReports/FeedbackReportAlert.jsx`

- Accepts optional `stt` prop (STT object with `id` and `name`)
- When `stt` is provided, includes `stt: stt.id` in the API call to fetch latest report
- Link to feedback reports page includes `&stt=<stt.name>` when `stt` prop is provided
- Added `stt` to the `useEffect` dependency array

### 8. Frontend: `TanfSspReports` — show alert for regional staff ✅

**File**: `tdrs-frontend/src/components/Reports/tdr/TanfSspReports.jsx` (line 49)

- Changed `{isDataAnalyst && <FeedbackReportAlert />}` to:
  ```jsx
  {(isDataAnalyst || isRegionalStaff) && (
    <FeedbackReportAlert stt={isRegionalStaff ? stt : null} />
  )}
  ```
- Regional staff now see the feedback report alert banner on the data files page
- The `stt` prop is passed only for regional staff (Data Analysts don't need it — backend filters by their assigned STT)

### 9. Frontend: `FeedbackReports` wrapper — no changes needed ✅

**File**: `tdrs-frontend/src/components/FeedbackReports/FeedbackReports.jsx`

- No code changes required — regional staff don't have `add_reportsource` or `view_reportsource`, so `accountCanUploadFeedbackReports` is false and they correctly see `STTFeedbackReports`

---

## Test Changes

### Backend Tests ✅

**File**: `tdrs-backend/tdpservice/reports/test/test_views.py`

Added `TestReportFileViewAsRegionalStaff` class (6 tests):
- `test_can_list_reports` — 200 OK
- `test_only_sees_reports_in_own_region` — sees own region reports, not others
- `test_cannot_create_report_files` — 403 Forbidden
- `test_can_download_report_in_own_region` — 200 OK
- `test_cannot_download_report_outside_region` — 404 Not Found (queryset filters it out before object permission check)
- `test_stt_query_param_filters_results` — filters by STT id

**File**: `tdrs-backend/tdpservice/reports/test/conftest.py`

Added fixtures:
- `regional_report_file_instance` — ReportFile tied to an STT in the regional user's region (uses `stt` fixture = Wisconsin, region 5)
- `other_region_report_file_instance` — ReportFile tied to an STT in region 99 (outside the regional user's region)

### Frontend Tests ✅

**File**: `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.test.js`

- Mocks `STTComboBox` to avoid `fetchSttList` side effects (renders a simple `<select>` with Wisconsin/Illinois options)
- All existing Data Analyst tests preserved
- Added Data Analyst-specific assertions: no STT ComboBox shown
- Added `Regional Staff` describe block (7 tests):
  - Renders STT ComboBox
  - Does not show content until both STT and year selected
  - Does not fetch when only year selected
  - Auto-fetches with `stt` param when both selected
  - Shows H2 heading with selected STT name
  - Clears reports when STT changes
  - Initializes STT from URL `stt` query param (by name)
- Store mocks include `stts: { sttList: [], loading: false }` (required by `availableStts` selector)

**File**: `tdrs-frontend/src/components/FeedbackReports/FeedbackReports.test.js`

- Added `STTComboBox` mock and `comboBox.init` to USWDS mock
- Added `stts` to all mock stores
- Added test: "renders STTFeedbackReports for OFA Regional Staff (not Admin view)"

**File**: `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReportsTable.test.js`

- Updated assertion: "Generated on" → "Uploaded on"

**File**: `tdrs-frontend/src/components/FeedbackReports/FeedbackReportAlert.test.js`

- Updated `renderComponent` to accept props
- Added `Regional Staff stt prop` describe block (3 tests):
  - Includes `stt` param in API call when `stt` prop provided
  - Includes `stt` name in feedback reports link when `stt` prop provided
  - Does not include `stt` in link when `stt` prop is null

### Test Results

- **Frontend**: 7 suites, 171 tests — all passing
- **Backend**: 23 tests in `test_views.py` — all passing

---

## Key Design Decisions

### 1. No Search Button
Auto-fetches when both STT and fiscal year are selected, consistent with the existing Data Analyst behavior (auto-fetch on year change). This was changed from the original plan which called for a Search button.

### 2. STT Query Param Uses Name (not ID)
The `stt` URL query param uses the STT name (e.g., `?stt=Wisconsin`) to be consistent with the `TanfSspReports` page which also uses STT name in its `stt` query param. The backend API call still sends the STT **id** since that's what the backend filter expects.

### 3. Download Outside Region Returns 404 (not 403)
When a regional staff user tries to download a report for an STT outside their region, the response is 404 (not 403) because `get_queryset` filters out reports outside the region before `has_object_permission` is reached. The report simply doesn't exist in the user's visible queryset.

### 4. FeedbackReportAlert Gets `stt` Prop (not Redux)
Rather than making `FeedbackReportAlert` aware of regional staff via Redux selectors, it receives an optional `stt` prop from `TanfSspReports`. This keeps the component simple and reusable — the parent decides whether to pass STT context.

---

## Key Reusable Components Referenced

| Component/Utility | File | Purpose |
|---|---|---|
| `STTComboBox` | `tdrs-frontend/src/components/STTComboBox/STTComboBox.jsx` | Renders filtered STT dropdown; auto-filters for regional users via `availableStts` selector |
| `availableStts` | `tdrs-frontend/src/selectors/stts.js` | Returns region-filtered STTs for regional staff, full list for others |
| `accountIsRegionalStaff` | `tdrs-frontend/src/selectors/auth.js:88-90` | Checks if user is OFA Regional Staff |
| `is_own_region` | `tdrs-backend/tdpservice/users/permissions.py:105-111` | Checks if STT is in user's regions |
| `get_requested_stt` | `tdrs-backend/tdpservice/users/permissions.py:99-102` | Extracts STT from request params |
| `regional_user` fixture | `tdrs-backend/tdpservice/conftest.py:68-76` | Creates a regional staff user with region 5 |
| `DataFilePermissions` | `tdrs-backend/tdpservice/users/permissions.py:225-282` | Reference pattern for regional filtering in permissions and object permissions |

---

## Files Changed (12 total)

### New Files (1)
| File | Purpose |
|---|---|
| `tdrs-backend/tdpservice/users/migrations/0056_add_regional_staff_report_permissions.py` | Add `view_reportfile` to OFA Regional Staff |

### Modified Files (11)
| File | Purpose |
|---|---|
| `tdrs-backend/tdpservice/users/permissions.py` | Regional staff handling in `ReportFilePermissions` |
| `tdrs-backend/tdpservice/reports/views.py` | Regional filtering + `stt` query param in `get_queryset` |
| `tdrs-backend/tdpservice/reports/test/test_views.py` | Regional staff test class (6 tests) |
| `tdrs-backend/tdpservice/reports/test/conftest.py` | Regional-specific fixtures |
| `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.jsx` | STT selector + auto-fetch for regional staff |
| `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReportsTable.jsx` | "Generated on" → "Uploaded on" |
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReportAlert.jsx` | Accept `stt` prop, include in API call and link |
| `tdrs-frontend/src/components/Reports/tdr/TanfSspReports.jsx` | Show alert for regional staff |
| `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.test.js` | Regional staff tests |
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReports.test.js` | Regional staff routing test + store fixes |
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReportAlert.test.js` | Regional staff stt prop tests |
| `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReportsTable.test.js` | "Uploaded on" assertion |
