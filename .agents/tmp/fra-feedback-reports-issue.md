## Background

The existing Feedback Reports feature (#5397, #5390, #5417) enables OFA to distribute quarterly TANF/SSP feedback reports to STTs. Admins upload a master zip file, the backend parses it into per-STT report bundles, and Data Analysts can view and download their reports via the UI. This implementation needs to be extended to also support **FRA (Fiscal Report Appendix) Feedback Reports**.

FRA is a distinct program type in the system (alongside TANF, SSP, and Tribal) with its own set of data sections (Work Outcomes of TANF Exiters, Secondary School Attainment, Supplemental Work Outcomes). FRA feedback reports will follow a similar distribution workflow but must be clearly distinguishable from TANF/SSP feedback reports throughout the system — in the UI, notifications, and emails.

### Why It Matters

- STTs need a way to receive and access FRA-specific feedback, just as they currently do for TANF/SSP
- Notifications and UI must clearly distinguish between TANF/SSP and FRA report types so users understand exactly what feedback is available
- Brings the FRA reporting workflow in line with the existing TANF/SSP feedback report infrastructure

### What's Changing

- FRA Feedback Reports will be uploadable and downloadable through TDP
- Notifications (email and in-app) will distinguish between TANF/SSP and FRA report types
- Knowledge Center guidance for FRA feedback reports

## Development & Testing

### Acceptance Criteria

#### Backend
- [ ] `ReportSource` and `ReportFile` models updated to support a report type indicator (e.g., `report_type` field distinguishing TANF/SSP vs. FRA)
  - Consider whether this should be a `CharField` with choices (e.g., `"TANF_SSP"`, `"FRA"`) or an approach leveraging the existing `DataFile.ProgramType` enum
- [ ] `ReportFile` unique constraint updated to account for report type (a TANF/SSP report and FRA report for the same STT/year/date should be allowed as separate records)
- [ ] Celery task (`process_report_source`) updated to handle FRA zip structure if it differs from TANF/SSP structure, or to pass through the report type when creating `ReportFile` records
- [ ] `ReportFileViewSet` supports filtering by report type via query parameter
- [ ] `ReportSourceViewSet` supports filtering by report type
- [ ] Serializers updated to include and validate the report type field
- [ ] Database migration(s) created for model changes

#### Frontend

> [!IMPORTANT]
> The following Acceptance Criteria is subject to change as the UX Team finalizes the Figma design for this feature

- [ ] Admin upload UI (`AdminFeedbackReports`) updated to allow selection of report type (TANF/SSP or FRA) before uploading
  - The report type selection should be sent to the backend with the upload request
  - Description text updated from TANF/SSP-only language to be contextual based on selected report type
- [ ] STT view (`STTFeedbackReports`) updated to display reports separated by or filterable by report type
  - The "TANF/SSP Data Reporting Reference" table should be contextual — show FRA-relevant reference info when viewing FRA reports
  - Description text about feedback reports should be updated to be contextual based on report type
- [ ] `FeedbackReportAlert` component updated to distinguish between TANF/SSP and FRA feedback availability
  - Consider whether there should be a separate alert component for each
- [ ] `FRAReportsContent` should display the `FeedbackReportAlert` when a `ReportFile` record is availabile for the selected `Fiscal Year`
  - reference the `TanfSspReports` component to see how this is implemented
- [ ] Header navigation / routing may need updates if FRA feedback reports get a distinct URL or tab

#### Email
> [!IMPORTANT]
> The following Acceptance Criteria is subject to change as the UX Team (@reitermb) finalizes the Figma design for this feature

- [ ] Email notification template and helper updated to distinguish TANF/SSP vs FRA in the subject line and body text (e.g., "TANF/SSP Feedback Report Available" vs. "FRA Feedback Report Available")
  - Email subject is contextual to the report type
  - Email body text is contextual to the report type
- [ ] Email links to the knowledge center page for feedback reports
  - There may be an FRA specific knowledge center page for Feedback submission
  - If not, then link should stay the same
- [ ] Email links to Feedback Reports page
  - link should set query params for `fiscal_year` and `report_type`

### Notes

- The current implementation has no `report_type` or `program_type` concept on the `ReportFile`/`ReportSource` models — they are implicitly TANF/SSP-only. This ticket introduces that distinction.
- The existing zip file structure for TANF/SSP is: `{ZipName}/FY{YYYY}/RO{X}/F{X}/files`. Confirm whether FRA zips follow the same structure or if the parsing logic (`find_stt_folders` in `tasks.py`) needs adjustment.
- The `FeedbackReportAlert` component currently shows on the TANF Data Files page. Determine whether it should also show on the FRA Data Files page, and how to handle cases where both TANF/SSP and FRA reports are available simultaneously.
- Reference the existing TANF/SSP implementations for patterns:
  - Backend: #5397 / PR #5438
  - Admin UI: #5390 / PR #5486
  - STT UI: #5417 / PR #5529
- Key files that will need changes:
  - `tdrs-backend/tdpservice/reports/models.py` — add report type field
  - `tdrs-backend/tdpservice/reports/serializers.py` — include report type
  - `tdrs-backend/tdpservice/reports/views.py` — filter by report type
  - `tdrs-backend/tdpservice/reports/tasks.py` — pass report type through processing
  - `tdrs-backend/tdpservice/email/helpers/feedback_report.py` — contextual email content
  - `tdrs-backend/tdpservice/email/templates/feedback/report-available.html` — contextual template
  - `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.jsx` — report type selector
  - `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.jsx` — report type filter/display
  - `tdrs-frontend/src/components/FeedbackReports/FeedbackReportAlert.jsx` — distinguish alert types

### Supporting Documentation

- [Figma Mockup (TANF/SSP Feedback Reports)](https://www.figma.com/design/irgQPLTrajxCXNiYBTEnMV/TDP-Mockups-For-Feedback?node-id=12632-2805&p=f&t=bt6ZtcElx3pAmIcQ-0) — reference for existing design; FRA design updates TBD
- Backend Feedback Reports: #5397 / PR #5438
- Admin Feedback Reports UI: #5390 / PR #5486
- STT Feedback Report UI: #5417 / PR #5529

### Open Questions

- Should FRA feedback reports use a separate upload flow / page section from TANF/SSP, or should the admin select the report type within the existing upload interface?
- Does the FRA zip file follow the same `{ZipName}/FY{YYYY}/RO{X}/F{X}/files` folder structure as TANF/SSP, or does it have a different structure that needs distinct parsing logic?
- Should the STT view show TANF/SSP and FRA reports on the same page (with a filter/toggle) or as separate tabs/pages?
- Is new Figma design work needed for the FRA-specific UI elements, or can we reuse the existing TANF/SSP layout with contextual text changes?
- What FRA-specific guidance content is needed in the Knowledge Center?
