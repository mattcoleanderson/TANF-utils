## Background ##

This is a sub-issue of #5663 (Implement FRA Feedback Reports) covering the **frontend and in-app notification** implementation.

The existing Feedback Reports UI (`FeedbackReports` components) was built for TANF/SSP only — there is no report type selector for admins, no filtering by type for STTs, and the in-app alert banner does not distinguish between report types. This ticket extends the UI to support FRA Feedback Reports alongside TANF/SSP.

### Why It Matters ###

- Admins need to specify whether they're uploading TANF/SSP or FRA feedback reports
- STT Data Analysts need to clearly distinguish between the two report types when viewing and downloading
- In-app alerts must indicate which type of feedback is available

### What's Changing ###

- Admin upload interface gains a report type selector
- STT view supports filtering/displaying reports by type with contextual reference information
- In-app alert banners distinguish between TANF/SSP and FRA feedback availability
- FRA Data Files page displays feedback alert when FRA reports are available

## Development & Testing ##

### Acceptance Criteria ###

> [!IMPORTANT]
> The following Acceptance Criteria is subject to change as the UX Team (@reitermb, @victoriaatraft) finalizes the Figma design for this feature

#### Admin UI ####

- [ ] Admin upload UI (`AdminFeedbackReports`) updated to allow selection of report type (TANF/SSP or FRA) before uploading
  - The report type selection should be sent to the backend with the upload request
  - Description text updated from TANF/SSP-only language to be contextual based on selected report type
- [ ] Upload history table clearly indicates which uploads are TANF/SSP vs FRA

#### STT View ####

- [ ] STT view (`STTFeedbackReports`) updated to display reports separated by or filterable by report type
  - The "TANF/SSP Data Reporting Reference" table should be contextual — show FRA-relevant reference info when viewing FRA reports
  - Description text about feedback reports should be updated to be contextual based on report type

#### In-App Alerts ####

- [ ] `FeedbackReportAlert` component updated to distinguish between TANF/SSP and FRA feedback availability
  - Consider whether there should be a separate alert component for each
- [ ] `FRAReportsContent` should display the `FeedbackReportAlert` when a `ReportFile` record is available for the selected `Fiscal Year`
  - Reference the `TanfSspReports` component to see how this is implemented

#### Navigation / Routing ####

- [ ] Header navigation / routing may need updates if FRA feedback reports get a distinct URL or tab

#### Testing & Other ####

- [ ] Frontend unit tests for report type selection in admin UI
- [ ] Frontend unit tests for report type filtering/display in STT UI
- [ ] Frontend unit tests for updated alert banner
- [ ] Testing Checklist has been run and all tests pass
- [ ] README is updated, if necessary
- [ ] [Release digest](https://app.gitbook.com/o/Yd4Wv0Fi89kSKpmakWrn/s/JSIbkxujKUxhKv2cXFEg/) has been updated with testing steps & relevant media

### Usability Testing Criteria ###
_PM/UX/OFA Only: Create a list of expected user behaviors that should be confirmed when UX and/or PM is testing this ticket_

#### Admin Perspective ####
- [ ] Admin can select report type (TANF/SSP or FRA) before uploading a feedback report zip, and the selection is clearly distinguishable
- [ ] After uploading an FRA feedback report, the success message and upload history correctly reflect that it is an FRA report (not TANF/SSP)

#### STT Data Analyst Perspective ####
- [ ] Data Analyst can distinguish between TANF/SSP and FRA feedback reports when viewing available reports
- [ ] The reference table and descriptive text update contextually when viewing FRA reports vs TANF/SSP reports
- [ ] Data Analyst can successfully download an FRA feedback report zip

#### Notifications ####
- [ ] In-app alert banner on the FRA Data Files page correctly indicates FRA feedback availability and links to the appropriate feedback reports view

### Notes ###

- **Depends on**: Backend FRA Feedback Reports sub-issue (the backend must expose the `report_type` field and filtering before the frontend can use it)
- Key files that will need changes:
  - `tdrs-frontend/src/components/FeedbackReports/AdminFeedbackReports.jsx` — report type selector
  - `tdrs-frontend/src/components/FeedbackReports/STTFeedbackReports.jsx` — report type filter/display
  - `tdrs-frontend/src/components/FeedbackReports/FeedbackReportAlert.jsx` — distinguish alert types
  - `tdrs-frontend/src/components/FeedbackReports/FeedbackReports.jsx` — may need report type routing
  - `tdrs-frontend/src/components/Reports/FRAReports.jsx` — add FeedbackReportAlert

### Supporting Documentation ###

- Parent issue: #5663
- References for existing TANF/SSP Feedback Report implementation:
  - Admin UI: #5390 / PR #5486
  - STT UI: #5417 / PR #5529
- Figma Mockup link
  - @reitermb @victoriaatraft please link the figma design here when complete
