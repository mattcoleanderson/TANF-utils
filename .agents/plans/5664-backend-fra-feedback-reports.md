# Implementation Plan: Backend FRA Feedback Reports (#5664)

**Status**: COMPLETE
**Branch**: `5664-backend-fra-feedback-reports-implementation`
**Base**: `develop`
**Parent Issue**: #5663 (FRA Feedback Reports)
**Deadline**: April 29, 2026
**Last Updated**: 2026-03-31

## Overview

The existing Feedback Reports backend (`tdpservice/reports/`) was built exclusively for TANF/SSP. The `ReportFile` and `ReportSource` models have no concept of report/program type. This ticket introduces a `report_type` field on both models to distinguish TANF/SSP from FRA feedback reports, updates the API to support filtering by report type, and makes email notifications contextual to the report type.

**Key constraint**: The frontend will send `report_type` via an input selector (separate ticket). The Celery task that parses `ReportSource` → `ReportFile` will also be updated separately. This ticket focuses on the model/migration/API/serializer/email foundation.

---

## Implementation Steps

### 1. Models: Add `ReportType` choices and `report_type` field

**File**: `tdrs-backend/tdpservice/reports/models.py`

**Rationale for a new enum vs. reusing `DataFile.ProgramType`**: The existing `DataFile.ProgramType` has 4 values (`TAN`, `SSP`, `TRIBAL`, `FRA`) which map to individual program types for data file uploads. Feedback Reports group TANF+SSP+Tribal together as "TANF/SSP" vs. FRA separately. A dedicated `ReportType` TextChoices on the `ReportFile`/`ReportSource` models is cleaner and avoids coupling to DataFile semantics. Future types (e.g., PIA) can be added as new choices.

**Changes**:

a) Define `ReportType` as a `TextChoices` enum, either on `ReportFile` or as a standalone class in `models.py`:
```python
class ReportType(models.TextChoices):
    """Report program type for feedback reports."""
    TANF_SSP = "TANF_SSP", "TANF/SSP"
    FRA = "FRA", "FRA"
```

b) Add `report_type` field to **`ReportSource`** (line ~54, after `year`):
```python
report_type = models.CharField(
    max_length=16,
    choices=ReportType.choices,
    default=ReportType.TANF_SSP,
)
```

c) Add `report_type` field to **`ReportFile`** (line ~93, after `year`):
```python
report_type = models.CharField(
    max_length=16,
    choices=ReportType.choices,
    default=ReportType.TANF_SSP,
)
```

d) Update `ReportFile.Meta.constraints` — the unique constraint must include `report_type` so a TANF/SSP report and FRA report for the same STT/year/date can coexist:
```python
constraints = [
    models.UniqueConstraint(
        fields=("version", "date_extracted_on", "year", "stt", "report_type"),
        name="unique_reports_reportfile_fields",
    )
]
```
**Note**: Changing the constraint name or fields requires removing the old constraint and adding the new one in the migration (Django handles this automatically with `makemigrations`).

e) Update `ReportFile.create_new_version()` — the version lookup must also filter by `report_type`:
```python
@classmethod
def create_new_version(self, data):
    version = (
        self.find_latest_version_number(
            year=data["year"],
            date_extracted_on=data["date_extracted_on"],
            stt=data["stt"],
            report_type=data.get("report_type", ReportType.TANF_SSP),
        )
        or 0
    ) + 1
    return ReportFile.objects.create(version=version, **data)
```

f) Update `ReportFile.find_latest_version_number()` and `find_latest_version()` to accept and filter by `report_type`:
```python
@classmethod
def find_latest_version_number(self, year, date_extracted_on, stt, report_type=ReportType.TANF_SSP):
    return self.objects.filter(
        stt=stt, year=year, date_extracted_on=date_extracted_on, report_type=report_type
    ).aggregate(Max("version"))["version__max"]

@classmethod
def find_latest_version(self, year, date_extracted_on, stt, report_type=ReportType.TANF_SSP):
    version = self.find_latest_version_number(year, date_extracted_on, stt, report_type)
    return self.objects.filter(
        version=version, year=year, date_extracted_on=date_extracted_on,
        stt=stt, report_type=report_type,
    ).first()
```

g) Update `get_s3_upload_path()` to include `report_type` in the S3 path for organizational clarity:
```python
def get_s3_upload_path(instance, filename):
    date_str = instance.date_extracted_on.strftime("%Y-%m-%d") if instance.date_extracted_on else "no-date"
    return os.path.join(
        f"reports/{instance.report_type}/{instance.year}/{date_str}/{instance.stt.id}/",
        filename,
    )
```

---

### 2. Migration: Add `report_type` field with default for existing records

**File**: `tdrs-backend/tdpservice/reports/migrations/0004_add_report_type.py` (NEW, auto-generated)

**Steps**:
1. Run `task backend-exec CMD="makemigrations reports"` — Django will generate a migration that:
   - Adds `report_type` CharField to `ReportSource` (default `"TANF_SSP"`)
   - Adds `report_type` CharField to `ReportFile` (default `"TANF_SSP"`)
   - Removes old unique constraint `unique_reports_reportfile_fields`
   - Adds new unique constraint including `report_type`
2. Because both fields have `default=ReportType.TANF_SSP`, existing records will automatically be populated with `"TANF_SSP"` — no data migration needed.
3. Verify with `task backend-exec CMD="showmigrations reports"`

---

### 3. Serializers: Expose `report_type` field

**File**: `tdrs-backend/tdpservice/reports/serializers.py`

a) **`ReportFileSerializer`**:
- Add `"report_type"` to `fields` list
- It should be writable (not in `read_only_fields`) so the frontend can set it during upload
- Default behavior: if not provided, the model default (`TANF_SSP`) applies

b) **`ReportSourceSerializer`**:
- Add `"report_type"` to `fields` list
- It should be writable (not in `read_only_fields`) so admins can specify when uploading a source zip
- Update `create()` method to pass `report_type` through to `ReportSource.objects.create()`:
```python
report_type = validated_data.get("report_type", ReportType.TANF_SSP)
source = ReportSource.objects.create(
    ...,
    report_type=report_type,
    ...,
)
```

---

### 4. Views: Add `report_type` query parameter filtering

**File**: `tdrs-backend/tdpservice/reports/views.py`

a) **`ReportFileViewSet.get_queryset()`** — add `report_type` filter:
```python
report_type = self.request.query_params.get('report_type')
if report_type:
    queryset = queryset.filter(report_type=report_type)
```

b) **`ReportSourceViewSet.get_queryset()`** — add `report_type` filter:
```python
report_type = self.request.query_params.get('report_type')
if report_type:
    queryset = queryset.filter(report_type=report_type)
```

---

### 5. Admin: Display `report_type` in admin views

**File**: `tdrs-backend/tdpservice/reports/admin.py`

a) **`ReportFileAdmin`**:
- Add `"report_type"` to `list_display`
- Add `"report_type"` to `list_filter`
- Update `VersionFilter.queryset()` subquery to also group by `report_type` (add `report_type=OuterRef("report_type")` to the subquery filter)

b) **`ReportSourceAdmin`**:
- Add `"report_type"` to `list_display`
- Add `"report_type"` to `list_filter`

---

### 6. Email: Make notification contextual to report type

**File**: `tdrs-backend/tdpservice/email/helpers/feedback_report.py`

a) Update `send_feedback_report_available_email()` to use `report_type` in subject and body:

```python
# Determine display label for report type
report_type_label = "FRA" if report_file.report_type == "FRA" else "TANF/SSP"

subject = f"{report_type_label} Feedback Report Available: {report_file.stt.name} - FY {report_file.year}"

text_message = (
    f"A new {report_type_label} feedback report is available for {report_file.stt.name} "
    f"for Fiscal Year {report_file.year} (reflects data submitted through {date_extracted_str})."
)
```

b) Add `report_type` and `report_type_label` to the template context:
```python
context = {
    ...,
    "report_type": report_file.report_type,
    "report_type_label": report_type_label,
}
```

c) Update the email link to include `report_type` query param:
```
/feedback-reports?year={{ fiscal_year }}&report_type={{ report_type }}
```

**File**: `tdrs-backend/tdpservice/email/templates/feedback/report-available.html`

d) Update the template to include report type in the notification text:
```html
<p>
    A new <b>{{ report_type_label }}</b> Feedback Report is available for
    <b>{{ stt_name }}</b> for Fiscal Year <b>{{ fiscal_year }}</b>
    (reflects data submitted through <b>{{ date_extracted_on }}</b>).
</p>
```

e) Update the button link to include `report_type`:
```html
href="{{ url }}/feedback-reports?year={{ fiscal_year }}&report_type={{ report_type }}"
```

---

### 7. Tests: Update existing and add new tests

**Files**:
- `tdrs-backend/tdpservice/reports/test/factories.py`
- `tdrs-backend/tdpservice/reports/test/test_models.py`
- `tdrs-backend/tdpservice/reports/test/test_serializers.py`
- `tdrs-backend/tdpservice/reports/test/test_views.py`
- `tdrs-backend/tdpservice/reports/test/test_tasks.py`

a) **Factories** (`factories.py`):
- Add `report_type = ReportType.TANF_SSP` to both `ReportFileFactory` and `ReportSourceFactory`
- Add a `FRAReportFileFactory` subclass (or parametrize) that uses `ReportType.FRA`

b) **Model tests** (`test_models.py`):
- Test `create_new_version` creates correct version for same STT/year/date but different `report_type`
- Test unique constraint allows same (version, date_extracted_on, year, stt) with different `report_type`
- Test unique constraint still prevents duplicates within same `report_type`
- Test `find_latest_version_number` and `find_latest_version` filter by `report_type`

c) **Serializer tests** (`test_serializers.py`):
- Test `report_type` is included in serialized output
- Test creating a ReportFile with explicit `report_type=FRA`
- Test creating a ReportSource with explicit `report_type=FRA`
- Test default `report_type` when not provided is `TANF_SSP`

d) **View tests** (`test_views.py`):
- Test `?report_type=FRA` query parameter filters correctly
- Test `?report_type=TANF_SSP` query parameter filters correctly
- Test without `report_type` param returns all reports

e) **Task tests** (`test_tasks.py`):
- Existing tests should still pass (they use default TANF_SSP)
- Note: The Celery task itself is not being modified in this ticket (that's a separate ticket), but tests should verify that `report_type` propagation from `ReportSource` to `ReportFile` works when explicitly set

f) **Email tests**:
- Test that TANF_SSP report generates subject with "TANF/SSP Feedback Report Available"
- Test that FRA report generates subject with "FRA Feedback Report Available"
- Test that email link includes `report_type` query param
- Test that template renders `report_type_label` correctly

---

### 8. NOT in scope (deferred to other tickets)

- **Frontend report_type selector UI** — separate ticket will add radio button to upload screen
- **Celery task `process_report_source` modifications** — a separate ticket will update the task to read `report_type` from the `ReportSource` and propagate it to created `ReportFile` records. The current task will continue to work with the default `TANF_SSP` value.
- **FRA-specific zip folder structure parsing** — if FRA zips have a different folder structure, that's a separate parsing concern

---

## File Change Summary

| File | Action | Description |
|------|--------|-------------|
| `tdpservice/reports/models.py` | MODIFY | Add `ReportType` choices, `report_type` field on both models, update constraint and classmethods |
| `tdpservice/reports/migrations/0004_*.py` | NEW | Add `report_type` field, update unique constraint |
| `tdpservice/reports/serializers.py` | MODIFY | Add `report_type` to fields on both serializers |
| `tdpservice/reports/views.py` | MODIFY | Add `report_type` query param filtering |
| `tdpservice/reports/admin.py` | MODIFY | Add `report_type` to list_display, list_filter, update VersionFilter |
| `tdpservice/email/helpers/feedback_report.py` | MODIFY | Make subject/body/link contextual to report_type |
| `tdpservice/email/templates/feedback/report-available.html` | MODIFY | Add report_type_label to template, update link |
| `tdpservice/reports/test/factories.py` | MODIFY | Add `report_type` to factories |
| `tdpservice/reports/test/test_models.py` | MODIFY | Add report_type tests for models |
| `tdpservice/reports/test/test_serializers.py` | MODIFY | Add report_type tests for serializers |
| `tdpservice/reports/test/test_views.py` | MODIFY | Add report_type filtering tests |
| `tdpservice/reports/test/test_tasks.py` | MODIFY | Add report_type email notification tests |

## Execution Order

1. Models (ReportType enum + fields + constraint + classmethods + S3 path)
2. Migration (makemigrations)
3. Serializers
4. Views
5. Admin
6. Email helper + template
7. Tests (run after each step with `/test backend tdpservice/reports/`)
