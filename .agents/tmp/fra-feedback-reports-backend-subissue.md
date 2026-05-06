## Background ##

This is a sub-issue of #5663 (Implement FRA Feedback Reports) covering the **backend and email notification** implementation.

The existing Feedback Reports backend (`tdpservice/reports/`) was built implicitly for TANF/SSP only — the `ReportFile` and `ReportSource` models have no concept of report/program type. This ticket introduces that distinction so the system can handle FRA Feedback Reports alongside TANF/SSP ones.

### Why It Matters ###

- The backend models, API, Celery task, and email notifications must support a report type field to distinguish TANF/SSP from FRA feedback reports
- The frontend (#TBD) depends on this work for filtering and displaying reports by type

### What's Changing ###

- `ReportFile` and `ReportSource` models gain a `report_type` field
- API endpoints support filtering by report type
- Email notifications are contextual to the report type (subject, body, links)

## Development & Testing ##

### Acceptance Criteria ###

#### Models & Migrations ####

- [ ] `ReportSource` and `ReportFile` models updated to support a report type indicator (e.g., `report_type` field distinguishing TANF/SSP vs. FRA)
  - Consider whether this should be a `CharField` with choices (e.g., `"TANF_SSP"`, `"FRA"`) or an approach leveraging the existing `DataFile.ProgramType` enum
- [ ] `ReportFile` unique constraint updated to account for report type (a TANF/SSP report and FRA report for the same STT/year/date should be allowed as separate records)
- [ ] Database migration(s) created for model changes
- [ ] Existing records default to TANF/SSP report type

#### API & Serializers ####

- [ ] Serializers updated to include and validate the report type field
- [ ] `ReportFileViewSet` supports filtering by report type via query parameter
- [ ] `ReportSourceViewSet` supports filtering by report type

#### Celery Task ####

- [ ] Celery task (`process_report_source`) updated to handle FRA zip structure if it differs from TANF/SSP structure, or to pass through the report type when creating `ReportFile` records

#### Email Notifications ####

> [!IMPORTANT]
> The following Acceptance Criteria is subject to change as the UX Team (@reitermb, @victoriaatraft) finalizes the Figma design for this feature

- [ ] Email notification template and helper updated to distinguish TANF/SSP vs FRA in the subject line and body text (e.g., "TANF/SSP Feedback Report Available" vs. "FRA Feedback Report Available")
  - Email subject is contextual to the report type
  - Email body text is contextual to the report type
- [ ] Email links to the knowledge center page for feedback reports
  - There may be an FRA specific knowledge center page for Feedback submission
  - If not, then link should stay the same
- [ ] Email links to Feedback Reports page
  - link should set query params for `fiscal_year` and `report_type`

#### Testing & Other ####

- [ ] Unit tests for new report type field on models, serializers, views, and Celery task
- [ ] Unit tests for email notifications with FRA report type
- [ ] Testing Checklist has been run and all tests pass
- [ ] README is updated, if necessary
- [ ] [Release digest](https://app.gitbook.com/o/Yd4Wv0Fi89kSKpmakWrn/s/JSIbkxujKUxhKv2cXFEg/) has been updated with testing steps & relevant media

### Usability Testing Criteria ###
_PM/UX/OFA Only: Create a list of expected user behaviors that should be confirmed when UX and/or PM is testing this ticket_

- [ ] Email notification for an FRA feedback report clearly identifies it as FRA (not TANF/SSP) in both subject line and body
- [ ] Email "View Feedback Reports" link navigates to the Feedback Reports page with the correct report type and fiscal year pre-selected

### Notes ###

- Key files that will need changes:
  - `tdrs-backend/tdpservice/reports/models.py` — add report type field
  - `tdrs-backend/tdpservice/reports/serializers.py` — include report type
  - `tdrs-backend/tdpservice/reports/views.py` — filter by report type
  - `tdrs-backend/tdpservice/reports/tasks.py` — pass report type through processing
  - `tdrs-backend/tdpservice/email/helpers/feedback_report.py` — contextual email content
  - `tdrs-backend/tdpservice/email/templates/feedback/report-available.html` — contextual template

### Supporting Documentation ###

- Parent issue: #5663
- References for existing TANF/SSP Feedback Report implementation:
  - Backend: #5397 / PR #5438
  - STT UI: #5417 / PR #5529 (email helpers added here)
- Figma Mockup link
  - @reitermb @victoriaatraft please link the figma design here when complete

### Open Questions ###

- Does the FRA zip file follow the same `{ZipName}/FY{YYYY}/RO{X}/F{X}/files` folder structure as TANF/SSP, or does it have a different structure that needs distinct parsing logic?
- Will there be a separate page in the Knowledge center for FRA Feedback Reports?
