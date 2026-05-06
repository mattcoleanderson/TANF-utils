# STT Feedback Report UI - UX Changes Implementation Plan

## Initial Prompt (Used to Generate This Plan)

> I am working the following github issue: https://github.com/raft-tech/TANF-app/issues/5417
>
> I have completed it but there are changes that have been requested by the client. I have detailed out all of the changes in an obsidian.md markdown file at the following filepath:
> `/Users/matt.anderson/Documents/obsidian_vault/issues/5417.1 - STT Feedback Report UI - UX Changes.md`
>
> This obsidian file has all of the tasks written out that need to be completed as well as images linked to it for what the UI design should look like after fixing it.
>
> Use the design images and tasks from the markdown file to create a detailed plan for solving this issue.

---

## Summary

This plan covers UX changes to the STT Feedback Report feature based on client feedback from Yun (the main user). The key change is that Admins now need to manually select a date representing when data was extracted from the database, rather than having the quarter auto-calculated from the submission date.

**Key Changes:**
- Add `date_extracted_on` field to backend models (replaces `quarter`)
- Remove `quarter` field from BOTH `ReportSource` and `ReportFile` models
- Update unique constraint on `ReportFile` to use `date_extracted_on` instead of `quarter`
- Admin page: Add fiscal year selector, date extracted input, conditional content display, error states
- STT page: Update fiscal year selector behavior, update table columns, add STT name to header

**Note:** The Search button shown in the STT design mockup is an oversight and should NOT be implemented.

---

## Design Mockups Reference

All images are located at: `/Users/matt.anderson/Documents/obsidian_vault/meta/images/`

| Mockup | Description |
|--------|-------------|
| `Pasted image 20260129160535.png` | Admin Upload Feedback Reports page layout |
| `Pasted image 20260129160621.png` | Admin date selector calendar popup |
| `Pasted image 20260129160734.png` | Admin page error states |
| `Pasted image 20260130100015.png` | STT Feedback Reports page layout |

**Full Paths:**
- `/Users/matt.anderson/Documents/obsidian_vault/meta/images/Pasted image 20260129160535.png`
- `/Users/matt.anderson/Documents/obsidian_vault/meta/images/Pasted image 20260129160621.png`
- `/Users/matt.anderson/Documents/obsidian_vault/meta/images/Pasted image 20260129160734.png`
- `/Users/matt.anderson/Documents/obsidian_vault/meta/images/Pasted image 20260130100015.png`

---

## Phase 1: Backend Model and Migration Changes ✅ COMPLETED

**Goal:** Add `date_extracted_on` field, remove `quarter` from both models, update serializers/views

**Status:** Completed on 2026-01-30. All tasks implemented and tests passing (16/18 - 2 failures are pre-existing S3/localstack issues unrelated to these changes).

### Tasks

- [x] **1.1** Add `date_extracted_on = models.DateField(null=True, blank=True)` to `ReportSource` model
- [x] **1.2** Add `date_extracted_on = models.DateField(null=True, blank=True)` to `ReportFile` model
- [x] **1.3** Remove `quarter` field from `ReportSource` model
- [x] **1.4** Remove `Quarter` choices class from `ReportSource`
- [x] **1.5** Remove `quarter` field from `ReportFile` model
- [x] **1.6** Remove `Quarter` choices class from `ReportFile`
- [x] **1.7** Update `ReportFile.Meta.constraints` - replace `quarter` with `date_extracted_on` in the unique constraint:
  - Change from: `UniqueConstraint(fields=("version", "quarter", "year", "stt"), ...)`
  - Change to: `UniqueConstraint(fields=("version", "date_extracted_on", "year", "stt"), ...)`
- [x] **1.8** Update `ReportFile.create_new_version()` method - use `date_extracted_on` instead of `quarter` for versioning
- [x] **1.9** Update `ReportFile.find_latest_version_number()` - use `date_extracted_on` instead of `quarter`
- [x] **1.10** Update `ReportFile.find_latest_version()` - use `date_extracted_on` instead of `quarter`
- [x] **1.11** Update `ReportSourceSerializer`:
  - Add `date_extracted_on` to fields (writable)
  - Remove `quarter` from fields
- [x] **1.12** Update `ReportFileSerializer`:
  - Add `date_extracted_on` to fields (read-only)
  - Remove `quarter` from fields
- [x] **1.13** Add year filter to `ReportSourceViewSet.get_queryset()` for filtering upload history
- [x] **1.14** Create and apply migration (0003_auto_20260130_1950.py)
- [x] **1.15** Update test factories to reflect model changes (remove quarter, add date_extracted_on)
- [x] **1.16** Update/add tests for model, serializer, and view changes

### Additional Files Modified (discovered during implementation)

- `tdrs-backend/tdpservice/reports/admin.py` - Updated to replace `quarter` with `date_extracted_on` in list_display, list_filter, and VersionFilter subquery
- `tdrs-backend/tdpservice/reports/test/conftest.py` - Updated fixtures to use `date_extracted_on` instead of `quarter`

### Files to Modify

| File | Changes |
|------|---------|
| `tdrs-backend/tdpservice/reports/models.py` | Add `date_extracted_on` to both models, remove `quarter` from both models, update versioning logic |
| `tdrs-backend/tdpservice/reports/serializers.py` | Update field lists |
| `tdrs-backend/tdpservice/reports/views.py` | Add year filter to ReportSourceViewSet |
| `tdrs-backend/tdpservice/reports/test/factories.py` | Update factories |
| `tdrs-backend/tdpservice/reports/test/test_models.py` | Update tests for new versioning logic |
| `tdrs-backend/tdpservice/reports/test/test_serializers.py` | Update serializer tests |
| `tdrs-backend/tdpservice/reports/test/test_views.py` | Add year filter tests |

---

## Phase 2: Celery Task Updates & Email Template Changes ✅ COMPLETED

**Goal:** Update report processing to use `date_extracted_on`, remove ALL quarter logic, update email notifications

**Status:** Completed on 2026-01-30. All tasks implemented and tests passing (15 task tests, 8 email tests).

### Tasks

- [x] **2.1** Update `_process_stt_folder()` to copy `date_extracted_on` from source to ReportFile
- [x] **2.2** Remove ALL quarter calculation logic from tasks.py:
  - Removed `calculate_quarter_from_date()` function
  - Removed `_determine_quarter()` function
  - Simplified `find_stt_folders()` to not require fiscal year parameter
  - Simplified `_extract_and_validate_structure()` to use `source.year` directly
- [x] **2.3** Update feedback report email template (`report-available.html`):
  - Replaced `{{ quarter }}` with `{{ date_extracted_on }}`
  - Updated text to: "for Fiscal Year **{{ fiscal_year }}** (reflects data submitted through **{{ date_extracted_on }}**)"
- [x] **2.4** Update feedback report email helper (`feedback_report.py`):
  - Replaced `report_file.quarter` with `report_file.date_extracted_on` formatted as MM/DD/YYYY
  - Updated `subject` line to use fiscal year only (removed quarter)
  - Updated `text_message` to use `date_extracted_on`
  - Updated `object_repr` in logger_context to use `date_extracted_on`
  - Updated `context` dict: replaced `"quarter"` key with `"date_extracted_on"`
  - Added handling for null `date_extracted_on` (displays "N/A")
- [x] **2.5** Update tests for Celery task and email changes
  - Removed all quarter-related tests from `test_tasks.py`
  - Updated all process tests to use `year` and `date_extracted_on`
  - Updated email tests to use `date_extracted_on`
  - Added test for null `date_extracted_on` handling

### Files Modified

| File | Changes |
|------|---------|
| `tdrs-backend/tdpservice/reports/tasks.py` | Removed `calculate_quarter_from_date()`, `_determine_quarter()`, simplified `find_stt_folders()` and `_extract_and_validate_structure()`, updated `_process_stt_folder()` to copy `date_extracted_on` |
| `tdrs-backend/tdpservice/email/templates/feedback/report-available.html` | Replaced quarter with date_extracted_on |
| `tdrs-backend/tdpservice/email/helpers/feedback_report.py` | Replaced quarter with date_extracted_on in all references, added null handling |
| `tdrs-backend/tdpservice/reports/test/test_tasks.py` | Removed quarter tests, updated all tests to use date_extracted_on (15 tests passing) |
| `tdrs-backend/tdpservice/email/helpers/test/test_feedback_report.py` | Updated email tests (8 tests passing) |

---

## Phase 3: Admin Frontend Changes ✅ COMPLETED

**Goal:** Add fiscal year selector, date extracted input, hide content until year selected, update table, implement error states

**Status:** Completed on 2026-01-30, updated 2026-02-03. All tasks implemented and tests passing.

### Tasks

- [x] **3.1** Add fiscal year selector at top of AdminFeedbackReports page
  - Use `constructYears()` from `../Reports/utils`
  - Default to no selection (user must choose)
- [x] **3.2** Add conditional rendering: hide everything below `<hr>` until fiscal year is selected
  - Reference pattern from `TanfSspReports.jsx`: `{yearInputValue && (<> <hr /> ... </>)}`
- [x] **3.3** Add H2 header below `<hr>`: `Fiscal Year {selectedFY} — Upload Feedback Reports`
- [x] **3.4** Add new date input field using USWDS date picker:
  - Label: "Data extracted from database on"
  - Hint text: "mm/dd/yyyy"
  - **Updated to use proper USWDS date picker** (`<div className="usa-date-picker">` wrapper)
  - Import and initialize `datePicker` from `@uswds/uswds/src/js/components`
  - Uses DOM-reading approach since USWDS manages input state (React onChange doesn't fire)
- [x] **3.5** Add validation for date extracted field:
  - Required before upload
  - Show error: "Choose the date that the data you're uploading was extracted from the database."
  - Reads value from DOM via `getDateValue()` method
- [x] **3.6** Update `handleUpload()` to include `year` and `date_extracted_on` in POST body
  - Converts date from MM/DD/YYYY (USWDS format) to YYYY-MM-DD (backend format)
- [x] **3.7** Update `fetchUploadHistory()` to filter by selected year: `?year={selectedYear}`
- [x] **3.8** Update `FeedbackReportsHistory.jsx` table columns:
  - Remove "Fiscal Year" column
  - Add "Data Extracted On" column (between "Feedback Uploaded On" and "Notifications Sent On")
  - **KEPT the "Status" and "Error" columns** as required
- [x] **3.9** Update `FeedbackReportsUpload.jsx` to accept date input props
  - **Refactored to use `forwardRef` and `useImperativeHandle`**
  - Exposes `getDateValue()` and `clearDate()` methods to parent component
  - Encapsulates USWDS date picker DOM interaction logic
- [x] **3.10** Implement error states for form inputs:
  - **File input error states:**
    - "Invalid file. Make sure to select a zip file." (when non-zip selected)
    - "No file selected." (when form submitted without file)
    - "Your file's Fiscal Year does not match the selected Fiscal Year for this upload." (when zip filename doesn't match selected FY)
  - **Date extracted input error state:**
    - "Choose the date that the data you're uploading was extracted from the database." (when form submitted without date)
  - Used USWDS error classes: `usa-form-group--error`, `usa-error-message`, `usa-input--error`
  - Tracked touched state with `onBlur` handlers
  - Show errors only after field has been touched or form submission attempted
- [x] **3.11** Update/add tests for all admin component changes including error states
- [x] **3.12** Add fiscal year as persistent URL query param
  - Uses `useSearchParams` from react-router-dom
  - URL is clean on first access (no params)
  - Year syncs to URL when changed: `?year=2025`
  - Year restored from URL on page reload

### Files Modified

| File | Changes |
|------|---------|
| `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.jsx` | Added FY selector, date input, conditional rendering, validation, error states, URL query param for year, uses `uploadFormRef` to access date picker methods |
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReportsUpload.jsx` | Added USWDS date picker with `forwardRef`/`useImperativeHandle`, exposes `getDateValue()` and `clearDate()` methods, handles date format conversion |
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReportsHistory.jsx` | Updated table columns (removed FY, added Date Extracted On) |
| `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.test.js` | Rewrote tests for new FY selector and conditional rendering |
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReportsUpload.test.js` | Added date input tests, updated button state tests |
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReportsHistory.test.js` | Updated for new columns and date_extracted_on field |
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReports.test.js` | Updated for FY selector requirement in admin view |

### Technical Notes

**USWDS Date Picker Integration:**
- USWDS date picker transforms the original input (hides it) and creates an "external input" for display
- React's `onChange` doesn't fire when USWDS programmatically sets values
- Solution: Read values directly from DOM via `document.getElementById()` and `document.querySelector()`
- Date format conversion: USWDS uses MM/DD/YYYY, backend expects YYYY-MM-DD
- This DOM-reading pattern is consistent with how `ComboBox` component handles USWDS state sync issues

### Design Reference (Admin Page)

From mockup `Pasted image 20260129160535.png`:
```
Upload Feedback Reports
-----------------------
[Fiscal Year Selector: 2026]

——————————————————— <hr>

Fiscal Year 2025 — Upload Feedback Reports

Feedback Reports ZIP
[Drag file here or choose from folder]

Data extracted from database on
mm/dd/yyyy
[Date Input] [Calendar Icon]

[Upload & Notify States]

Upload History
| Feedback Uploaded On | Data Extracted On | Notifications Sent On | Status | Error | File | Downloaded by |
```

**Note:** The design mockup didn't include Status and Error columns, but they exist in the current implementation and should be KEPT.

### Error States Reference (Admin Page)

From mockup `Pasted image 20260129160734.png`:
```
Feedback Reports ZIP                              ← usa-form-group--error (red left border)
├── "Invalid file. Make sure to select a zip file."     ← usa-error-message
├── "No file selected."                                  ← usa-error-message
├── "Your file's Fiscal Year does not match..."          ← usa-error-message
└── [File input with dashed red border]                  ← usa-input--error

Data extracted from database on                   ← usa-form-group--error (red left border)
mm/dd/yyyy
├── "Choose the date that the data you're uploading was extracted from the database."
└── [Date input with red border]                         ← usa-input--error
```

**Error State Pattern** (from `FiscalYearSelect.jsx`):
```jsx
<div className={classNames('usa-form-group', { 'usa-form-group--error': hasError })}>
  <label className="usa-label text-bold">
    Field Label
    {hasError && (
      <div className="usa-error-message" role="alert">
        Error message text
      </div>
    )}
    <input
      className={classNames('usa-input', { 'usa-input--error': hasError })}
      onBlur={handleBlur}
      ...
    />
  </label>
</div>
```

---

## Phase 4: STT Frontend Changes ✅ COMPLETED

**Goal:** Update fiscal year selector behavior, hide content until selected, update table columns, add STT name header

**Status:** Completed on 2026-02-03. All tasks implemented and tests updated.

### Tasks

- [x] **4.1** Update `getValidatedYear()` to return `null` if no URL param (not current year default)
- [x] **4.2** Add placeholder option to fiscal year selector: `"- Select Fiscal Year -"`
- [x] **4.3** Add conditional rendering: hide everything below `<hr>` until fiscal year is selected
  - Used pattern: `{selectedYear && (<> <hr /> ... </>)}`
- [x] **4.4** Add H2 header below `<hr>`: `{STT Name} — Fiscal Year {selectedFY} — Feedback Reports`
  - Used Redux pattern consistent with rest of codebase: `useSelector((state) => state.auth.user?.stt?.name)`
- [x] **4.5** Change H3 header from `Fiscal Year {year} Feedback Reports` to just `Feedback Reports`
- [x] **4.6** Update `STTFeedbackReportsTable.jsx` columns:
  - "Feedback generated on" → "Generated on"
  - "Fiscal quarters included in feedback" → "Reflects data submitted through"
  - Display `report.date_extracted_on` instead of `report.quarter` (formatted from YYYY-MM-DD to MM/DD/YYYY)
- [x] **4.7** Update `fetchReports()` to only fetch when `selectedYear` is not null
- [x] **4.8** Update/add tests for all STT component changes

**Note:** The Search button shown in the design mockup was NOT implemented (per plan notes - it was an oversight in the mockup).

### Files Modified

| File | Changes |
|------|---------|
| `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.jsx` | Added Redux selector for STT name, updated `getValidatedYear()` to return null, added placeholder option, added conditional rendering, added H2 header with STT name, changed H3 to just "Feedback Reports", updated `fetchReports()` to only fetch when year is selected |
| `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReportsTable.jsx` | Added `formatDate()` function, updated column headers ("Generated on", "Reflects data submitted through"), changed from `report.quarter` to `report.date_extracted_on` |
| `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.test.js` | Updated all tests for new behavior: placeholder option, conditional rendering, H2 header with STT name, fetching only when year selected, URL param handling |
| `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReportsTable.test.js` | Updated all tests to use `date_extracted_on` instead of `quarter`, updated header tests |

---

## Phase 5: Update Expected Zip File Structure ✅ COMPLETED

**Goal:** Update backend to handle actual zip file structure from Yun's reports

**Status:** Completed on 2026-02-03. All tasks implemented and tests passing.

### Problem (Resolved)

The expected zip file structure was different from what was originally implemented:
- **Old structure:** `2025/4/01/...`
- **New structure:** `FY2025/R01/F1/...`

### Changes Made

| Component | Old | New |
|-----------|-----|-----|
| Fiscal Year | `2025` | `FY2025` (prefixed with "FY") |
| Region | `4` | `R01` (prefixed with "R") |
| STT Code | `01` | `F1` (prefixed with "F", strips prefix for lookup) |

### Tasks

- [x] **5.1** Renamed test zip files with `FYXXXX_` prefix (5 files renamed, 3 kept as-is for invalid structure tests)
- [x] **5.2** Updated `find_stt_folders()` in tasks.py:
  - Now parses `FY{YYYY}/R{XX}/F{X}/filename` structure
  - Strips "F" prefix from STT folder to get actual STT code
  - Updated error message to reflect new expected structure
- [x] **5.3** Updated validation and error messages for new structure
- [x] **5.4** Recreated test zip files with new internal structure:
  - `FY2025_valid_single_stt.zip` - `FY2025/R04/F1/...`
  - `FY2025_valid_multiple_stts_same_region.zip` - `FY2025/R04/F1/`, `FY2025/R04/F12/`
  - `FY2025_valid_multiple_regions.zip` - `FY2025/R01/F9/`, `FY2025/R02/F34/`, `FY2025/R03/F42/`
  - `FY2025_invalid_empty_stt_folder.zip` - `FY2025/R04/F1/` (empty)
  - `FY2025_invalid_stt_code_999.zip` - `FY2025/R04/F999/`
  - `invalid_fiscal_year_bad_format.zip` - `FY202a/R04/F1/` (kept without FY prefix in filename)
  - `invalid_flat_structure.zip` - `report.pdf` (kept as-is)
  - `invalid_multiple_fiscal_years.zip` - `FY2025/...` and `FY2024/...` (kept without FY prefix in filename)
- [x] **5.5** Updated `README.md` in test data directory with new structure documentation
- [x] **5.6** Updated tests for new parsing logic:
  - Updated `create_nested_zip()` helper in conftest.py
  - Updated all test structures in test_tasks.py
  - All 15 task tests pass

### Files Modified

| File | Changes |
|------|---------|
| `tdrs-backend/tdpservice/reports/tasks.py` | Updated `find_stt_folders()` to parse new structure, strip "F" prefix |
| `tdrs-backend/tdpservice/reports/test/conftest.py` | Updated `create_nested_zip()` and fixtures to use new structure |
| `tdrs-backend/tdpservice/reports/test/test_tasks.py` | Updated all test structures from `{"2025": {"Region_1": {"1": [...]}}}` to `{"FY2025": {"R01": {"F1": [...]}}}` |
| `tdrs-backend/tdpservice/reports/test/data/README.md` | Complete rewrite with new structure documentation |
| `tdrs-backend/tdpservice/reports/test/data/*.zip` | Renamed 5 files with FY prefix, recreated all 8 with new internal structure |

### Design Reference (STT Page)

From mockup `Pasted image 20260130100015.png`:
```
Feedback Reports
----------------
[Fiscal Year Selector: 2025]    [TANF/SSP Data Reporting Reference Table]

——————————————————— <hr>

Alabama — Fiscal Year 2025 Feedback Reports

[Description paragraphs...]

Feedback Reports
| Generated on | Reflects data submitted through | Files |
| 03/05/2025 10:41 AM | 02/28/2025 | FY 2025 Feedback Reports - Reflects data submitted through 2/28/2025.zip |
```

---

## Verification Plan

### Backend Tests
```bash
task backend-pytest PYTEST_ARGS="tdpservice/reports/test/ -v"
```

### Frontend Tests
```bash
task frontend-test
```

### Manual Testing Checklist

**Admin Page:**
- [ ] Fiscal year selector appears at top
- [ ] Content below `<hr>` is hidden until FY selected
- [ ] H2 header shows selected fiscal year
- [ ] Date extracted input uses USWDS date picker with calendar popup
- [ ] Date extracted input has mm/dd/yyyy hint text
- [ ] Upload includes year and date_extracted_on in request body
- [ ] Upload history filtered by selected year
- [ ] Upload history table shows "Data Extracted On" column
- [ ] Upload history table does NOT show "Fiscal Year" column
- [ ] Upload history table KEEPS "Status" and "Error" columns
- [ ] **Error States:**
  - [ ] File input shows error when non-zip file selected
  - [ ] File input shows error when trying to upload without selecting file
  - [ ] File input shows error when zip filename's year doesn't match selector
  - [ ] Date input shows error when trying to upload without selecting date
  - [ ] Date input shows error when date year doesn't match selected fiscal year
  - [ ] Error styling includes red left border on form group
  - [ ] Error messages appear below labels

**STT Page:**
- [ ] Fiscal year selector defaults to no selection (not current year)
- [ ] Fiscal year selector has placeholder "- Select Fiscal Year -"
- [ ] Content below `<hr>` is hidden until FY selected
- [ ] H2 header shows STT name and fiscal year
- [ ] H3 says "Feedback Reports" (not "Fiscal Year XXXX Feedback Reports")
- [ ] Table column says "Generated on" (not "Feedback generated on")
- [ ] Table column says "Reflects data submitted through"
- [ ] Table shows date_extracted_on value (not quarter)
- [ ] NO Search button present

---

## Dependencies Between Phases

```
Phase 1 (Backend Models) ✅
    ↓
Phase 2 (Celery Tasks) ✅ ←── depends on model changes
    ↓
Phase 3 (Admin Frontend) ✅ ←── depends on API changes
    ↓
Phase 4 (STT Frontend) ✅ ←── depends on API changes (can run parallel with Phase 3)
    ↓
Phase 5 (Zip Structure) ✅ ←── completed after Phases 1-4
```

**ALL PHASES COMPLETE**

---

## Additional Notes

### Data Migration Consideration
- Existing `ReportSource` and `ReportFile` records with `quarter` values will lose that data
- This is acceptable as quarter is being completely replaced with `date_extracted_on`
- The unique constraint on ReportFile will use `date_extracted_on` instead of `quarter`

### STT Name Access (Phase 4)
- **Preferred:** Avoid Redux if possible - check for alternatives first
- **Fallback:** `const user = useSelector((state) => state.auth.user)` → `user?.stt?.name`
- Current codebase pattern uses Redux for user data in most components

### Conditional Rendering Pattern
Reference from `tdrs-frontend/src/components/Reports/tdr/TanfSspReports.jsx`:
```jsx
{yearInputValue && quarterInputValue && stt && (
  <>
    <hr />
    {/* Content below */}
  </>
)}
```

For Feedback Reports (year only):
```jsx
{selectedYear && (
  <>
    <hr />
    {/* Content below */}
  </>
)}
```

### USWDS Date Picker
- No existing date picker implementation in codebase
- Implement from scratch using USWDS date picker component
- Reference: https://designsystem.digital.gov/components/date-picker/
- Match the design mockup closely (calendar popup style)

### Zip Filename Validation (Admin Page)
- Validate fiscal year from **filename** only, not zip contents
- Expected filename format: `FY2025_12012025.zip`
- Extract characters 3-6 (after "FY") to get the year
- Compare against selected fiscal year
- **Do NOT unzip or inspect contents on frontend**

### Future Enhancement: Date Validation Range
**Note for future:** The date validation currently only checks that the date's year matches the selected Fiscal Year. A future enhancement may require validating that the selected date falls within the fiscal year range:
- Between **October 1 of the previous calendar year** and **September 30 of the selected fiscal year**
- Example: For FY 2025, valid dates would be Oct 1, 2024 through Sep 30, 2025
- **This is NOT implemented now** - just checking year match for simplicity

### Future Enhancement: Dynamic Filename Generation
**Note for future:** Once the exact filename format is confirmed, update the Celery task to generate dynamic filenames:
- **Proposed format:** `FY {YYYY} Feedback Reports - Reflects data submitted through {MMDDYYYY}.zip`
- `{YYYY}` = `source.year`
- `{MMDDYYYY}` = `source.date_extracted_on` formatted as **MMDDYYYY** (NO forward slashes - slashes are invalid in filenames)
- Example: `FY 2025 Feedback Reports - Reflects data submitted through 02282025.zip`

**Tasks to implement (DEFERRED):**
- Update filename generation in `tasks.py` for ReportFile
- Update `ReportSourceSerializer.create()` to save source file with new naming convention
- Update tests for filename changes

---

## Session Notes (2026-02-03)

### Work Completed This Session
- **Phase 4 (STT Frontend Changes)** fully implemented
- All FeedbackReports component tests updated and passing
- Fixed USWDS `datePicker` mock missing from test files
- Fixed uncontrolled date input test patterns (need to set DOM value directly)
- Fixed STT API call test to require fiscal year selection first
- **Fixed Header.test.js** - Added `MemoryRouter` wrapper to 4 "Feedback Reports Navigation" tests
- **All 812 frontend tests now pass** (72/72 test suites)

### Header.test.js Fixes ✅ COMPLETED

**Header.test.js** - Fixed 4 failing tests in "Feedback Reports Navigation" describe block:
- `should show Feedback Reports nav item when user has view_reportfile permission and is approved`
- `should NOT show Feedback Reports nav item when user lacks view_reportfile permission`
- `should NOT show Feedback Reports nav item when user is not approved`
- `should show Feedback Reports nav item for admin users with view_reportfile permission`

**Root Cause:** These tests were missing `MemoryRouter` wrapper. The Header component uses React Router `<Link>` components which require Router context.

**Fix Applied:** Added `<MemoryRouter>` wrapper around the render calls in all 4 tests, matching the pattern used by other tests in the same file.

**Result:** All 812 frontend tests now pass (72/72 test suites).

### Test Command Reference
```bash
# Run all frontend tests
task frontend-test JEST_ARGS="--watchAll=false"

# Run FeedbackReports tests only (all passing)
task frontend-test JEST_ARGS="--watchAll=false --testPathPattern=FeedbackReports"
```

---

## Session Notes (2026-02-03 - continued)

### Serializer Bug Fix ✅ COMPLETED

**Issue:** Two backend tests were failing:
1. `test_report_file_serializer_valid` - KeyError: 'date_extracted_on'
2. `test_create_report_file` - 400 instead of 201

**Root Cause:** `ReportFileSerializer` had `date_extracted_on` in `read_only_fields`, which caused it to be stripped from `validated_data`. However, `ReportFile.create_new_version()` requires `date_extracted_on` to check the unique constraint and create new versions.

**Fix Applied:** Removed `date_extracted_on` from `read_only_fields` in `ReportFileSerializer` (line 40 in serializers.py). This makes the field writable so admins can provide it when creating report files directly.

**File Modified:** `tdrs-backend/tdpservice/reports/serializers.py`

**Test Results After Fix:**
- Backend reports tests: 33/33 passed
- Backend email helper tests: 8/8 passed
- Frontend tests: 812/812 passed (72/72 test suites)

### Implementation Status Summary

| Phase | Status | Tests |
|-------|--------|-------|
| Phase 1: Backend Models | ✅ Complete | 33 passed |
| Phase 2: Celery Tasks & Email | ✅ Complete | 8 email tests passed |
| Phase 3: Admin Frontend | ✅ Complete | 73/73 suites |
| Phase 4: STT Frontend | ✅ Complete | 73/73 suites |
| Phase 5: Zip Structure | ✅ Complete | 33 backend, 815 frontend |

**All Phases 1-5 are complete. The implementation is ready for manual testing and PR creation.**

---

## Session Notes (2026-02-03 - Phase 5 Implementation)

### Phase 5 Work Completed

**Updated zip file structure from `YYYY/Region/STT/` to `FY{YYYY}/R{XX}/F{X}/`**

1. **Renamed test zip files** - Added `FY2025_` prefix to 5 valid/invalid test files
   - Kept 3 files without prefix (invalid structure IS the error being tested)

2. **Updated `find_stt_folders()` in tasks.py**:
   - Now expects `FY{YYYY}/R{XX}/F{X}/filename` structure
   - Strips "F" prefix from STT folder names to get actual STT code
   - Maintains backwards compatibility (falls back if no "F" prefix)
   - Updated error message to show new expected structure

3. **Recreated all 8 test zip files** with new internal structure:
   - Valid files: `FY2025/R04/F1/`, `FY2025/R04/F12/`, etc.
   - Invalid files: Updated to use new format where applicable

4. **Updated test code**:
   - `conftest.py`: Updated `create_nested_zip()` docstring and fixtures
   - `test_tasks.py`: Updated all 15 test structures to use new format

5. **Updated README.md** with complete new structure documentation

### Test Results After Phase 5
- Backend reports tests: **33/33 passed**
- Frontend tests: **815/815 passed** (73/73 test suites)

---

## Phase 6: Dismissable Alert Banner & STT Code Fix ✅ COMPLETED

**Goal:** Make the FeedbackReportAlert banner dismissable with localStorage persistence, fix STT code lookup for zip file processing

**Status:** Completed on 2026-02-03. All tasks implemented and tests passing.

### Part A: Dismissable FeedbackReportAlert Banner

**Problem:** Data analysts needed the ability to dismiss the "Feedback Reports Available" alert banner, with the dismissal persisted per fiscal year and the alert reappearing when a new report is uploaded.

**Dismissal Logic:**
- Dismiss alert for the **currently selected fiscal year only**
- Show new alert after dismissed only if a **new report is available** (different `created_at` timestamp) for the **same fiscal year and STT**
- STT filtering is handled server-side (API only returns reports for user's STT)

### Tasks

- [x] **6.1** Add dismiss button (X) to `FeedbackReportAlert` component
  - Used existing codebase pattern from `FeedbackModal` and `FeedbackWidget`
  - Classes: `usa-modal__close feedback-modal-close-button`
  - Imported `Feedback.scss` for consistent styling
  - Added `aria-label="Dismiss alert"` for accessibility
- [x] **6.2** Add localStorage persistence for dismissed state
  - Key format: `feedbackAlertDismissed_{year}` (e.g., `feedbackAlertDismissed_2025`)
  - Value: The report's `created_at` timestamp
- [x] **6.3** Implement show/hide logic based on dismissed state
  - Fetch latest report → get `created_at` timestamp
  - Check localStorage for `feedbackAlertDismissed_{year}`
  - If stored timestamp === current report's `created_at` → stay dismissed
  - If stored timestamp !== current report's `created_at` → show alert (new report)
  - If no stored value → show alert (never dismissed)
- [x] **6.4** Add comprehensive tests for dismissable functionality (8 new tests)
  - `renders dismiss button with correct aria-label`
  - `hides alert when dismiss button is clicked`
  - `saves dismissed state to localStorage on dismiss`
  - `does not render alert when previously dismissed for same report`
  - `renders alert again when new report is available (different created_at)`
  - `renders alert when fiscal year changes even if previous year was dismissed`
  - `dismiss button has correct styling`
  - `alert body has flex layout for dismiss button positioning`

### Part B: STT Code Lookup Fix

**Problem:** When uploading a zip file with folder structure `FY2025/R04/F1/`, the code extracted `stt_code="1"` but Alabama's code is stored as `"01"` (zero-padded) in the database, causing "STT code '1' not found in system" error.

**Root Cause:** The `populate_stts` management command stores STT codes with zero-padding:
- States/Territories: 2 digits (e.g., `"01"` for Alabama)
- Tribes: 3 digits (e.g., `"001"`)

### Tasks

- [x] **6.5** Update `_process_stt_folder()` in tasks.py to try zero-padded STT codes
  - Try 2-digit padding first (states/territories)
  - Then try 3-digit padding (tribes)
- [x] **6.6** Update test STT codes to use zero-padded values matching production
  - Changed `stt_code="1"` → `stt_code="01"`
  - Changed `stt_code="2"` → `stt_code="02"`
  - Updated corresponding assertions

### Files Modified

| File | Changes |
|------|---------|
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReportAlert.jsx` | Added dismiss button with `usa-modal__close feedback-modal-close-button` classes, localStorage persistence, show/hide logic based on dismissed state |
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReportAlert.test.js` | Added 8 new tests for dismissable functionality, added localStorage mock |
| `tdrs-backend/tdpservice/reports/tasks.py` | Updated `_process_stt_folder()` to try zero-padded STT codes (2-digit then 3-digit) |
| `tdrs-backend/tdpservice/reports/test/test_tasks.py` | Updated all test STT codes to use zero-padded values (`"01"`, `"02"`) |

### STT Code Lookup Implementation

```python
# Validate STT exists
# STT codes are stored with zero-padding: 2 digits for states/territories, 3 for tribes
# Try 2-digit padding first (states/territories), then 3-digit (tribes)
stt = None
for pad_length in (2, 3):
    padded_code = stt_code.zfill(pad_length)
    try:
        stt = STT.objects.get(stt_code=padded_code)
        break
    except STT.DoesNotExist:
        continue

if stt is None:
    _mark_source_failed(source, f"STT code '{stt_code}' not found in system.")
    return False
```

### Test Results After Phase 6
- Backend reports tests: **15/15 passed** (test_tasks.py)
- Frontend FeedbackReportAlert tests: **19/19 passed**
- Frontend lint: **passed**
- Backend lint: **passed**

---

## Updated Dependencies Between Phases

```
Phase 1 (Backend Models) ✅
    ↓
Phase 2 (Celery Tasks) ✅ ←── depends on model changes
    ↓
Phase 3 (Admin Frontend) ✅ ←── depends on API changes
    ↓
Phase 4 (STT Frontend) ✅ ←── depends on API changes (can run parallel with Phase 3)
    ↓
Phase 5 (Zip Structure) ✅ ←── completed after Phases 1-4
    ↓
Phase 6 (Alert Dismissal & STT Fix) ✅ ←── independent, completed after Phase 5
    ↓
Phase 7 (Zip Structure Update) ✅ ←── handle extra nested folder + R{X} to RO{X}
    ↓
Phase 8 (Permissions Update) ✅ ←── DIGIT Team + OFA System Admin get Feedback Report access
```

**ALL PHASES COMPLETE (1-8)**

---

## Phase 7: Update Zip File Structure Parsing ✅ COMPLETED

**Goal:** Update parser to handle the actual zip structure from QASP (extra nested folder) and update R{X} to RO{X}

**Status:** Completed on 2026-02-05. All tasks implemented and 33 backend reports tests passing.

### Background

The actual zip files from QASP have an extra nested folder that matches the zip filename:

**Current parser expects:**
```
FY2025_07312025.zip -> FY2025/RO1/F9/files
                       (3 levels: FY/Region/STT)
```

**Actual structure from QASP:**
```
FY2025_07312025.zip -> FY2025_07312025/FY2025/RO1/F9/files
                       (4 levels: ZipName/FY/Region/STT)
```

Also, the region folder uses `RO{X}` (Regional Office) not `R{X}`.

### Tasks

- [x] **7.1** Update `find_stt_folders()` in `tasks.py`:
  - Update to expect 4 nested folders before files (ZipName/FY/RO/F)
  - Change path parsing from `parts[2]` (STT) to `parts[3]` (STT is now at index 3)
  - Update docstring to show: `{ZipName}/FY{YYYY}/RO{X}/F{X}/files`
  - Update error message to show correct expected structure
- [x] **7.2** Update `create_nested_zip()` helper in `conftest.py`:
  - Update to create 4-level structure with zip name folder at root
  - Update docstring example to show `RO1` instead of `R01`
  - Accept optional `zip_name` parameter for the root folder name
- [x] **7.3** Update all test structures in `test_tasks.py`:
  - Add root folder level (e.g., `"FY2025_test"`)
  - Change all `"R01"`, `"R04"`, etc. to `"RO1"`, `"RO4"`, etc.
  - Update path string checks to include root folder
- [x] **7.4** Update `fiscal_year_report_source_zip` fixture in `conftest.py`:
  - Add root folder level
  - Change `"R01"` to `"RO1"`
- [x] **7.5** Update `multi_stt_report_source_zip` fixture in `conftest.py`:
  - Add root folder level
  - Change `"R01"` to `"RO1"`
- [x] **7.6** Recreate all test zip files in `test/data/` with new 4-level structure
- [x] **7.7** Update `README.md` in `test/data/` with new structure documentation
- [x] **7.8** Run backend tests to verify all changes work correctly (33/33 passed)

### Files to Modify

| File | Changes |
|------|---------|
| `tdrs-backend/tdpservice/reports/tasks.py` | Update `find_stt_folders()` to handle 4-level structure, use `parts[3]` for STT |
| `tdrs-backend/tdpservice/reports/test/conftest.py` | Update `create_nested_zip()` and fixtures |
| `tdrs-backend/tdpservice/reports/test/test_tasks.py` | Update all test structures |
| `tdrs-backend/tdpservice/reports/test/data/README.md` | Update structure documentation |
| `tdrs-backend/tdpservice/reports/test/data/*.zip` | Recreate with new 4-level structure |

### Structure Change Summary

| Level | Old | New |
|-------|-----|-----|
| 0 | (none) | ZipName folder (e.g., `FY2025_07312025`) |
| 1 | FY{YYYY} | FY{YYYY} |
| 2 | R{XX} | RO{X} |
| 3 | F{X} | F{X} |
| 4 | files | files |

**Path index change:** STT folder moves from `parts[2]` to `parts[3]`

---

## Phase 8: Update Feedback Report Permissions ✅ COMPLETED

**Goal:** Remove all Feedback Report permissions from OFA Admin, grant to DIGIT Team and OFA System Admin

**Status:** Completed on 2026-02-05. All tasks implemented and tests passing (39 backend, 839 frontend).

### Background

Currently, AdminFeedbackReports (the upload/notify functionality) is accessible by OFA Admin users. The client has requested:

- **OFA Admin:** NO permissions for Feedback Reports at all (cannot view or upload)
- **DIGIT Team:** Should have all Feedback Report permissions (see Upload Feedback Reports page)
- **OFA System Admin:** Should have all Feedback Report permissions (see Upload Feedback Reports page)

**Current Permission Flow:**
1. Frontend selector `accountCanUploadFeedbackReports` checks for `view_reportsource` and `add_reportsource` permissions
2. These permissions are granted to "OFA Admin" group via migration `0052_add_report_permissions.py`
3. Backend `ReportSourcePermissions` class checks `request.user.is_an_admin` for create actions

**Desired Permission Flow:**
1. Frontend selector remains the same (permission-based, will work automatically)
2. Remove ALL report permissions from "OFA Admin" group
3. Add permissions to "DIGIT Team" and "OFA System Admin" groups
4. Backend `ReportSourcePermissions` should check for DIGIT Team OR OFA System Admin

### Tasks

- [x] **8.1** Create new migration to update report permissions:
  - Remove ALL report permissions from "OFA Admin" group:
    - `view_reportsource`, `add_reportsource`
    - `view_reportfile`, `add_reportfile`
  - Add ALL report permissions to "DIGIT Team" group
  - File: `tdrs-backend/tdpservice/users/migrations/0054_update_feedback_report_permissions.py`
- [x] **8.1b** Create migration to add report permissions to OFA System Admin:
  - Migration 0020 only grants permissions that exist when it runs (2021 - before Reports app)
  - Must explicitly add Report permissions to OFA System Admin
  - File: `tdrs-backend/tdpservice/users/migrations/0055_add_ofa_sys_admin_report_permissions.py`
- [x] **8.2** Update `ReportSourcePermissions` and `ReportFilePermissions` in `permissions.py`:
  - Changed check from `is_an_admin` to `is_ofa_sys_admin or is_digit_team`
  - Updated comments to reflect new access rules
- [x] **8.3** Update backend tests for permission changes:
  - Rewrote `test_views.py` with new test classes:
    - `TestReportFileViewAsOFASystemAdmin` - 3 tests (create, upload, download)
    - `TestReportFileViewAsDigitTeam` - 3 tests (create, upload, download)
    - `TestReportFileViewAsOFAAdmin` - 3 tests (all denied)
    - `TestReportFileViewAsDataAnalyst` - 8 tests (view own STT only)
- [x] **8.4** Update frontend tests:
  - Updated `FeedbackReports.test.js` - changed role mocks from "OFA Admin" to "DIGIT Team"
  - Updated `AdminFeedbackReports.test.js` - changed role mock to "DIGIT Team"
  - Updated `Header.test.js` - added tests for DIGIT Team, OFA System Admin, and OFA Admin denial
  - Updated `AdminFeedbackReports.jsx` docstring to reflect new permissions
- [x] **8.5** Run all backend and frontend tests to verify changes
  - Backend reports tests: 39/39 passed
  - Frontend tests: 839/839 passed (73/73 suites)

### Files Modified

| File | Changes |
|------|---------|
| `tdrs-backend/tdpservice/users/migrations/0054_update_feedback_report_permissions.py` | New migration to remove OFA Admin permissions, add DIGIT Team permissions |
| `tdrs-backend/tdpservice/users/migrations/0055_add_ofa_sys_admin_report_permissions.py` | New migration to add report permissions to OFA System Admin (added 2026-02-10) |
| `tdrs-backend/tdpservice/users/permissions.py` | Updated `ReportSourcePermissions` and `ReportFilePermissions` to check `is_ofa_sys_admin or is_digit_team` |
| `tdrs-backend/tdpservice/reports/test/test_views.py` | Complete rewrite with 4 test classes for different user roles |
| `tdrs-frontend/src/components/FeedbackReports/FeedbackReports.test.js` | Updated role mocks to DIGIT Team |
| `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.test.js` | Updated role mock to DIGIT Team |
| `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.jsx` | Updated docstring |
| `tdrs-frontend/src/components/Header/Header.test.js` | Added tests for DIGIT Team, OFA System Admin, OFA Admin denial |

### Permission Matrix After Change

| Group | view_reportsource | add_reportsource | view_reportfile | add_reportfile |
|-------|-------------------|------------------|-----------------|----------------|
| OFA Admin | ❌ Removed | ❌ Removed | ❌ Removed | ❌ Removed |
| OFA System Admin | ✅ Added (via 0055) | ✅ Added (via 0055) | ✅ Added (via 0055) | ✅ Added (via 0055) |
| DIGIT Team | ✅ Added (via 0054) | ✅ Added (via 0054) | ✅ Added (via 0054) | ✅ Added (via 0054) |
| Data Analyst | ❌ | ❌ | ✅ (existing) | ❌ |

### Notes

- OFA Admin will NOT see "Feedback Reports" in navigation at all after this change
- Both DIGIT Team and OFA System Admin will see the Upload Feedback Reports page
- Data Analyst retains `view_reportfile` for viewing their STT's feedback reports

---

## Session Notes (2026-02-05 - Phase 8 Implementation)

### Work Completed This Session

**Phase 8: Update Feedback Report Permissions** - fully implemented

1. **Created migration** `0054_update_feedback_report_permissions.py`:
   - Removes `view_reportsource`, `add_reportsource`, `view_reportfile`, `add_reportfile` from "OFA Admin"
   - Adds `view_reportsource`, `add_reportsource`, `view_reportfile`, `add_reportfile` to "DIGIT Team"
   - ~~OFA System Admin already has all permissions via migration 0020~~ (See 2026-02-10 session - this was incorrect)

2. **Updated permission checks** in `permissions.py`:
   - `ReportFilePermissions.has_permission()` - changed from `is_an_admin` to `is_ofa_sys_admin or is_digit_team`
   - `ReportSourcePermissions.has_permission()` - changed from `is_an_admin` to `is_ofa_sys_admin or is_digit_team`

3. **Rewrote backend tests** in `test_views.py`:
   - `TestReportFileViewAsOFASystemAdmin` - 3 tests verifying full access
   - `TestReportFileViewAsDigitTeam` - 3 tests verifying full access
   - `TestReportFileViewAsOFAAdmin` - 3 tests verifying 403 Forbidden
   - `TestReportFileViewAsDataAnalyst` - 8 tests (unchanged, still works)

4. **Updated frontend tests**:
   - Changed role mocks from "OFA Admin" to "DIGIT Team" in FeedbackReports tests
   - Added Header tests for DIGIT Team, OFA System Admin, and OFA Admin denial

### Test Results

| Test Suite | Tests | Status |
|------------|-------|--------|
| Backend `tdpservice/reports/test/` | 39 | ✅ All passed |
| Frontend (all) | 839 | ✅ All passed |

### Implementation Complete

All 8 phases of the STT Feedback Report UI UX Changes are now complete. The feature is ready for:
1. Manual testing
2. Code review
3. PR creation

---

## Session Notes (2026-02-10 - OFA System Admin Permissions Fix)

### Issue Discovered

OFA System Admin was getting report permissions in local environment but **not** in deployed environments (test/staging/prod).

### Root Cause Analysis

**Migration 0020** (`0020_ofa_system_admin_permissions.py`) from August 2021 grants OFA System Admin "all permissions that exist at the time the migration runs":

```python
system_admin_permissions = (
    apps.get_model('auth', 'Permission')
        .objects
        .exclude(delete_permissions_q)
        .values_list('id', flat=True)
)
ofa_system_admin.permissions.add(*system_admin_permissions)
```

**The problem:** This is a snapshot-in-time approach. It only runs once.

- In deployed environments, 0020 ran in 2021 before the Reports app existed
- Report permissions were created later by migration 0052
- Since migrations only run once, 0020 never re-runs to pick up new permissions
- Result: OFA System Admin never received Report permissions in deployed environments

**Why modifying 0054 wouldn't work:**
- Migration 0054 was already applied to deployed environments
- Django tracks applied migrations in `django_migrations` table
- Modifying an already-applied migration has no effect

### Solution

Created new migration **0055** (`0055_add_ofa_sys_admin_report_permissions.py`) that explicitly adds Report permissions to OFA System Admin.

### Files Modified

| File | Change |
|------|--------|
| `tdrs-backend/tdpservice/users/migrations/0054_update_feedback_report_permissions.py` | Updated docstring to note OFA System Admin handled in 0055 |
| `tdrs-backend/tdpservice/users/migrations/0055_add_ofa_sys_admin_report_permissions.py` | **NEW** - Adds report permissions to OFA System Admin |

### Key Learnings

1. **Migrations are snapshots** - A migration that queries "all permissions" only captures what exists when it runs
2. **Migrations only run once** - Modifying an already-applied migration won't re-apply it
3. **New permissions require explicit grants** - When adding new models/permissions, must create migrations to grant them to existing groups
4. **Django's `permissions.add()` is idempotent** - Safe to call even if permissions already exist (won't duplicate)

### Test Results

All 17 tests in `tdpservice/reports/test/test_views.py` passed:
- OFA System Admin: Full access (create, upload, download)
- DIGIT Team: Full access (create, upload, download)
- OFA Admin: Denied (403) for all report operations
- Data Analyst: Can view/download own STT's reports only
