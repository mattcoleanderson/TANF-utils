## Background ##

The existing Feedback Reports feature enables OFA to distribute quarterly TANF/SSP feedback reports to STTs. Admins upload a master zip file, the backend parses it into per-STT report bundles, and Data Analysts can view and download their reports via the UI. This implementation needs to be extended to also support **FRA (Fiscal Report Appendix) Feedback Reports**.

### Why It Matters ###

- STTs need a way to receive and access FRA-specific feedback, just as they currently do for TANF/SSP
- Notifications and UI must clearly distinguish between TANF/SSP and FRA report types so users understand exactly what feedback is available
- Brings the FRA reporting workflow in line with the existing TANF/SSP feedback report infrastructure

### What's Changing ###


- FRA Feedback Reports will be uploadable and downloadable through TDP
- Notifications (email and in-app) will distinguish between TANF/SSP and FRA report types

## Sub-Issues ##

| Sub-Issue | Scope |
|-----------|-------|
| #TBD_BACKEND | Backend models, API, Celery task, email notifications |
| #TBD_FRONTEND | Admin upload UI, STT view, in-app alerts, routing |

> The frontend sub-issue depends on the backend sub-issue (the API must expose `report_type` before the frontend can use it).

## Supporting Documentation ##

- References for existing TANF/SSP Feedback Report implementation:
  - Backend: #5397 / PR #5438
  - Admin UI: #5390 / PR #5486
  - STT UI: #5417 / PR #5529
- Figma Mockup link
  - @reitermb @victoriaatraft please link the figma design here when complete

## Open Questions ##

- Does the FRA zip file follow the same `{ZipName}/FY{YYYY}/RO{X}/F{X}/files` folder structure as TANF/SSP, or does it have a different structure that needs distinct parsing logic?
- Will there be a separate page in the Knowledge center for FRA Feedback Reports?
