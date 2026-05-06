# Issue 5584: Parsing Complete Banner Interrupts Screenreader

## Problem
When a file is submitted, two banners appear in sequence:
1. "Successfully submitted" banner (localAlert)
2. "Your file is being processed" / "Processing complete" banner (processingAlert)

The second banner interrupts the screenreader before it finishes reading the first banner.

## Solution Implemented

### Pattern: Separate SR-only live regions from visible alerts

```jsx
{/* Screen-reader announcer (visually hidden) */}
<div className="usa-sr-only">
  <div role="status" aria-live="polite" aria-atomic="true">
    {localAlert.active ? localAlert.message : ''}
  </div>
  <div role="status" aria-live="polite" aria-atomic="true">
    {processingAlert.active ? processingAlert.message : ''}
  </div>
</div>

{/* Visible alerts (hidden from accessibility tree) */}
{localAlert.active && (
  <div className="usa-alert..." aria-hidden="true">
    <div className="usa-alert__body">
      <p className="usa-alert__text">{localAlert.message}</p>
    </div>
  </div>
)}
{processingAlert.active && (
  <div className="usa-alert..." aria-hidden="true">
    ...
  </div>
)}
```

**Why this works:**
- `usa-sr-only`: Visually hidden but available to screenreaders
- `role="status"`: Indicates a live region for status messages
- `aria-live="polite"`: Announces changes without interrupting current speech
- `aria-atomic="true"`: Announces the entire content when it changes
- `aria-hidden="true"` on visible alerts: Prevents duplicate announcements

## Completed Work
- [x] Separated the single alert into two distinct alerts (localAlert and processingAlert)
- [x] Added separate refs for each alert (alertRef and processingAlertRef)
- [x] Updated useFileUploadForm hook to manage both alert states
- [x] Updated SectionFileUploadForm.jsx with dual banners + sr-only pattern
- [x] Updated QuarterFileUploadForm.jsx with dual banners + sr-only pattern
- [x] Updated FRAReports.jsx with dual banners + sr-only pattern
- [x] Added setProcessingAlertState to clear processing alert on file change
- [x] Updated FileUpload.jsx to accept and call setProcessingAlertState
- [x] Updated useFileUploadForm.js to expose setProcessingAlertState
- [x] Fixed FRAReports UploadForm to clear processingAlert on file change

## Files Modified
1. `tdrs-frontend/src/components/FileUploadForms/SectionFileUploadForm.jsx`
2. `tdrs-frontend/src/components/FileUploadForms/QuarterFileUploadForm.jsx`
3. `tdrs-frontend/src/components/Reports/FRAReports.jsx`
4. `tdrs-frontend/src/components/FileUpload/FileUpload.jsx`
5. `tdrs-frontend/src/hooks/useFileUploadForm.js`
6. `tdrs-frontend/src/components/Reports/ReportsContext.jsx` (earlier work)

## Test Fixes Applied
Fixed 10 failing tests across 4 test suites. Two categories of failures:

1. **`getByRole('alert')` → `getAllByRole('status')`** (4 tests): Visible alerts now have `aria-hidden="true"`, so `getByRole('alert')` can't find them. Tests now query the sr-only `role="status"` elements instead.
2. **`getByText(msg)` → `getAllByText(msg)`** (6 tests): Message text appears in both the sr-only live region and the visible `<p>` element, causing `getByText` to throw on duplicate matches. Tests now use `getAllByText` and check length.

**Files fixed:**
- `QuarterFileUploadForm.test.js` - 1 test
- `SectionFileUploadForm.test.js` - 1 test
- `FRAReports.test.js` - 5 tests
- `Reports.test.js` - 3 tests

**Result:** 838 passed, 0 failed across 73 suites.

## Approaches Tried (Not Working)

### 1. `role="alert"` on inner div (Original approach)
**Result:** Second banner interrupts first banner - screenreader stops reading first message mid-sentence.

### 2. `role="status"` on `<p>` element
**Result:** Did not solve the interruption problem.

### 3. `aria-live="polite"` on outer container of each banner
**Result:** Did not solve the interruption problem.

### 4. Single wrapper `<div aria-live="polite">` around both banners
**Result:** Second banner still interrupts the first banner.

### 5. Separate sr-only live regions (WORKING)
**Result:** Successfully allows both messages to be read without interruption.
