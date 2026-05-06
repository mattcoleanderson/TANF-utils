# TDP Data File Validation: Understanding the Process & LLM Error Summary Proposal

---

## Part 1: For Non-Engineers — What Happens When a Data File Is Submitted

### The Big Picture

States, tribes, and territories (STTs) that administer TANF (welfare) programs are required to report data about the families they serve to the federal government. They do this by uploading data files through TDP (the TANF Data Portal). These files are essentially big spreadsheets — rows of data about individual cases, families, and people — encoded in a specific fixed-width text format.

When an STT uploads a file, TDP checks it for correctness. Think of it like a very thorough proofreader that checks every number in every row against a rulebook.

### What Gets Validated

The validation happens in four layers, from broadest to most specific:

#### Layer 1: "Is this even a valid file?" (Pre-checks)
Before looking at any individual data, the system checks the basics:
- Does the file have the right header? (Like checking a letter has the right address on the envelope)
- Does the header say it's for the right state, the right quarter, and the right program?
- Is each row the right length? (Every row must be exactly a certain number of characters)

**Example:** A file says it contains Q1 2024 data for California's TANF program. If someone accidentally uploaded Q2 data instead, this layer catches it.

#### Layer 2: "Is each individual value valid?" (Field checks)
Each row has dozens of fields — things like case numbers, dates of birth, income amounts, employment status codes. Each field has allowed values:
- Date of Birth must be a valid date (not February 30th)
- Employment Status must be 1, 2, or 3
- Race indicators must be 0, 1, or 2
- Income amounts must be between 0 and 9,999
- Social Security Numbers must be 9 digits

**Example:** If someone enters "7" for Marital Status but the allowed values are only 0–5, that's a Layer 2 error.

#### Layer 3: "Do the values make sense together?" (Cross-field checks)
This is where it gets complex. Many fields have rules that depend on other fields in the **same row**:
- "If someone is receiving cash assistance, they must also have months of assistance recorded"
- "If a person is listed as a family member (affiliation 1–3), their race fields must be filled in"
- "If a person is listed as the primary recipient (affiliation 1), they must have a valid citizenship status"
- "If someone is marked as work-eligible, their SSN must be valid"
- "If someone is under 19 and marked as a minor parent, they can't also be the head of household"
- "The sum of all benefit amounts (cash, food stamps, child care, transportation) must be greater than zero" — meaning at least *some* benefit was provided

**Example:** A row says a person's Family Affiliation is "1" (primary recipient) but Citizenship Status is blank. The system says: "Since this person is the primary recipient, you must report their citizenship status."

#### Layer 4: "Does this case make sense as a whole?" (Case consistency)
Individual people (T2 records) must link to a family case record (T1). The system checks:
- Every family record must have at least one person record
- At least one person in the family must be listed as a family member (not just an unrelated person)
- A closed case must have at least one person record associated with it

**Example:** A file has a family case (T1) for case number "ABC123" but no individual person records (T2/T3) for that same case number. The system flags this because you can't have a family case with no people in it.

### What Happens After Validation

Based on the errors found, the file gets one of four statuses:
- **Accepted** — No errors at all
- **Accepted with Errors** — Only individual field or cross-field errors (Layer 2/3). The data is usable but has some problems.
- **Partially Accepted** — Some cases were rejected entirely (Layer 4 errors or rows too short). Good cases are kept; bad cases are thrown out.
- **Rejected** — The file header itself was wrong (Layer 1). Nothing could be processed.

The STT receives an Excel error report with two tabs:
1. **Critical** — A prioritized list of the most important errors, row by row
2. **Summary** — Errors grouped by type with counts ("Employment Status invalid: 47 occurrences")

---

## Part 2: For Engineers — The Technical Architecture

### Pipeline Overview

```
HTTP POST (multipart) → DataFileViewSet.create()
  → ClamAV virus scan
  → DataFile model created (S3 storage, auto-versioned)
  → Celery task: parser_task.parse.delay(data_file_id)
    → DataFileSummary(status=PENDING)
    → ParserFactory → TanfDataReportParser | FRAParser
    → DecoderFactory → UTF-8 or XLSX decoder
    → Header validation (HeaderSchema)
    → SchemaManager initialized per program type
    → CaseConsistencyValidator initialized
    → Row-by-row loop:
        SchemaManager.parse_and_validate(row)
          → Record type prefix selects schema (T1/T2/T3/T4/T5/T6/T7 or M-equivalents)
          → Category 1: preparsing validators (raw string)
          → Field.parse_value() → fixed-width positional extraction → int/str
          → Category 2: field-level validators (individual values)
          → Category 3: postparsing validators (model instance, cross-field)
        → Records added to CaseConsistencyValidator cache
        → Periodic bulk_create of records + ParserError objects
    → Category 4: case consistency validation (cross-record within case)
    → Duplicate detection & deletion (exact + partial)
    → SSN validation for federally funded recipients
    → DataFileSummary.get_status() → ACCEPTED|ACCEPTED_WITH_ERRORS|PARTIALLY_ACCEPTED|REJECTED
    → XLSX error report generated → attached to DataFileSummary
    → Email notification to data analysts
```

### Key Components

**Schema system** (`row_schema.py`):
- `TanfDataReportSchema` — primary schema class per record type
- Each schema has: `preparsing_validators` (cat1), `fields` (with cat2 validators), `postparsing_validators` (cat3)
- `parse_and_validate(row)` → runs all three in order → returns `SchemaResult(record, is_valid, errors)`

**Field definitions** (`fields.py`):
- `Field` — fixed-width positional extraction. `Position(start, end)` indexes into the raw string.
- `TransformField` — extends Field with `transform_func` (e.g., SSN decryption)
- Types: `NUMERIC` (→ int), `ALPHA_NUMERIC` (→ str)
- Each field carries `validators` (list of cat2 functions), `friendly_name`, `item` number (from the federal reporting spec)

**Validator architecture** (`validators/`):
- `base.py` — pure boolean functions: `isEqual`, `isOneOf`, `isBetween`, `isNumber`, etc.
- `util.py` — `make_validator(bool_func, error_func)` → produces `Result(valid, error_message)`
- `@validator` decorator — composes base validator + error message template
- `category1.py` — preparsing: `recordHasLength`, `caseNumberNotEmpty`, `validateRptMonthYear`
- `category2.py` — field-level: `isOneOf`, `isBetween`, `dateMonthIsValid`, `ssnAllOf`
- `category3.py` — cross-field: `ifThenAlso`, `sumIsEqual`, `sumIsLarger`, `orValidators`, `validate__WORK_ELIGIBLE_INDICATOR__HOH__AGE`
- `case_consistency_validator.py` — cat4: caches records by `(RPT_MONTH_YEAR, CASE_NUMBER)`, validates T1↔T2/T3 linkage, family affiliation presence, max records per case

**Error generation** (`error_generator.py`):
- `ErrorGeneratorFactory` creates closures per category
- Each produces `ParserError` model instances with: `error_message`, `error_type` (cat 1–7), `field_name`, `item_number`, `row_number`, `case_number`, `fields_json`, `values_json`
- `fields_json` carries `{friendly_name: {INTERNAL_NAME: "Human Name"}}` for report formatting

**Error reports** (`data_files/error_reports.py`):
- XLSX via xlsxwriter
- "Critical" sheet: prioritized errors (all cat1/cat4 + specific important cat2/cat3 fields)
- "Summary" sheet: aggregated by error message with occurrence counts
- Prioritization is hardcoded: `PRIORITIZED_CAT2` and `PRIORITIZED_CAT3` tuples define which field combinations get promoted to the Critical sheet

### Schema Scale

| Dimension | Count |
|-----------|-------|
| Schema definition files | 28 (T1–T7, M1–M7, Tribal T1–T7, FRA TE1, header, trailer, program audit) |
| `ifThenAlso` cross-field validators | ~210 across all schemas |
| Other cross-field validators (`sumIsEqual`, `sumIsLarger`, custom) | ~77 |
| Field-level (cat2) validator instances | ~456 |
| Unique fields across all record types | 300+ |

### Error Message Format Examples

Current error messages are generated programmatically:

**Category 2 (field-level):**
> `T2 Item 47 (Employment Status): 7 must be between 1 and 3`

**Category 3 (cross-field, ifThenAlso):**
> `Since Item 30 (Family Affiliation) is 1, then Item 42 (Citizenship/Immigration Status) 0 must be one of (1, 2, 3)`

**Category 3 (sumIsLarger):**
> `No benefit amounts detected for this case. The total sum of AMT_FOOD_STAMP_ASSISTANCE, AMT_SUB_CC, CASH_AMOUNT, CC_AMOUNT, TRANSP_AMOUNT must be greater than 0.`

**Category 4 (case consistency):**
> `Every T1 record must have at least one corresponding T2 or T3 record with the same RPT_MONTH_YEAR and CASE_NUMBER.`

---

## Part 3: The Case for LLM-Generated Error Summaries

### Is the Combinatorial Complexity Claim Valid?

**Yes, absolutely.** Here's the quantitative argument:

#### Source 1: Cross-field validator explosion

The `ifThenAlso` pattern creates conditional dependencies. Consider just the T2 record (one person in an active TANF case):

- `FAMILY_AFFILIATION` has 4 allowed values (1, 2, 3, 5)
- Depending on which value it has, **different fields** become required and have **different allowed ranges**:
  - If 1: CITIZENSHIP_STATUS must be 1/2/3, EDUCATION_LEVEL must not be 0 or 99, WORK_ELIGIBLE_INDICATOR must be valid, SSN must be valid...
  - If 1–2: PARENT_MINOR_CHILD must be 1–3
  - If 1–3: all 6 race fields must be 1–2, MARITAL_STATUS must be 1–5, EMPLOYMENT_STATUS must be 1–3, COOPERATION_CHILD_SUPPORT must be 1/2/9
  - If 2–3: EDUCATION_LEVEL must be 0–16 or 98–99
  - If 5: most of the above are NOT required

This is **one field** controlling the validity of **15+ other fields**. And those controlled fields have their own dependencies:

- `WORK_ELIGIBLE_INDICATOR` has 12+ allowed values (1–9, 11, 12), and **it** controls:
  - If 1–5: WORK_PART_STATUS must not be "99"
  - If 1–5: SSN must pass full validation
  - If 11: cross-check with AGE and RELATIONSHIP_HOH (three-way dependency)

#### Source 2: Multi-record interactions (Category 4)

A single case can have a T1 (family), plus multiple T2s and T3s (people). Errors at the case level depend on the **combination of values across records**:
- "No T2 with FAMILY_AFFILIATION=1" means no primary recipient was reported. But **why** might depend on whether there are T2 records at all, or whether they all have affiliation=5 (irrelevant person), or whether the case number was mistyped.

#### Source 3: Combinatorial math

For just the T2 record type with ~40 fields, each field has 2–12 possible values, and ~15 cross-field validators create conditional chains. A conservative estimate:

- 4 (FAMILY_AFFILIATION) × 12 (WORK_ELIGIBLE_INDICATOR) × 10 (WORK_PART_STATUS) × 4 (CITIZENSHIP_STATUS) × 3 (EMPLOYMENT_STATUS) = **5,760 condition paths** for just these 5 fields
- Each path enables/disables different validators on 15+ downstream fields
- Each downstream field has its own range of invalid values that produce distinct error messages
- A single row can trigger **multiple errors simultaneously** — the combination of 3 concurrent errors has meaning that differs from each error individually

Across all record types (T1–T7, M1–M7, Tribal variants), the total state space is enormous. A file submission can have **thousands of rows**, each with a different combination of values, producing a unique constellation of errors.

#### Source 4: Context matters

The same error means different things in different contexts:
- "CITIZENSHIP_STATUS must be one of (1, 2, 3)" when FAMILY_AFFILIATION=1 means "you forgot to report the primary recipient's citizenship"
- The same field being blank when FAMILY_AFFILIATION=5 is **not an error at all**
- A cluster of "family affiliation" errors across many T2 records in the same case might mean the STT systematically miscoded who the primary recipient is
- A single case with 20+ errors might have **one root cause** (e.g., wrong record type used) that cascades into many downstream failures

**An engineer cannot hand-write summaries for all combinations.** With ~210 cross-field validators, ~456 field validators, 4 error categories, 28 record types, and multi-record case-level interactions, the number of meaningful error combinations is in the millions. Writing static summaries for even the top 1,000 patterns would be a massive effort that still misses the long tail.

An LLM is well-suited because it can:
1. Read the specific combination of errors for a case or file
2. Understand the conditional dependency chains from context
3. Identify likely root causes (one bad field causing cascading failures)
4. Explain the fix in terms a data analyst understands
5. Handle novel combinations it has never seen before

---

## Part 4: High-Level Design for an LLM Error Summary Service

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Existing Parse Pipeline                    │
│                                                              │
│  DataFile → Parser → Validators → ParserErrors → ErrorReport │
│                                         │                    │
│                                         ▼                    │
│                              DataFileSummary                 │
└──────────────────────────────────┬───────────────────────────┘
                                   │
                                   │ (after status computed,
                                   │  before/after XLSX generation)
                                   ▼
                     ┌─────────────────────────┐
                     │  Error Summary Service   │
                     │                         │
                     │  1. Collect errors       │
                     │  2. Group & structure    │
                     │  3. Build LLM prompt     │
                     │  4. Call LLM API         │
                     │  5. Store summary        │
                     └────────────┬────────────┘
                                  │
                                  ▼
                     ┌─────────────────────────┐
                     │  ErrorSummary model      │
                     │  (linked to              │
                     │   DataFileSummary)       │
                     └─────────────────────────┘
                                  │
                        ┌─────────┴──────────┐
                        ▼                    ▼
                  XLSX report           Frontend UI
                  (new "Summary         (summary panel
                   Guidance" tab)        on file status)
```

### Component Design

#### 1. Error Collector & Grouper

A new module (e.g., `tdpservice/parsers/error_summarizer.py`) that:

- Queries all `ParserError` objects for a given `DataFile`
- Groups them by:
  - **Case** (`case_number` + `rpt_month_year`) — for per-case summaries
  - **Error pattern** (error_type + involved fields) — for file-level pattern summaries
  - **Record type** (T1, T2, etc.) — for record-type breakdowns
- Identifies "error clusters": cases where the same root field appears in multiple errors (likely cascading)
- Produces a structured JSON representation:

```python
{
    "file_summary": {
        "program": "TANF",
        "section": "Active Case Data",
        "quarter": "Q1 2024",
        "stt": "California",
        "status": "Accepted with Errors",
        "total_records": 1500,
        "total_errors": 342,
        "total_cases_with_errors": 89
    },
    "error_patterns": [
        {
            "pattern_id": 1,
            "description": "FAMILY_AFFILIATION triggers missing downstream fields",
            "involved_fields": ["FAMILY_AFFILIATION", "CITIZENSHIP_STATUS", "RACE_*", "EMPLOYMENT_STATUS"],
            "error_types": ["Value Consistency"],
            "occurrence_count": 156,
            "affected_cases": 42,
            "sample_errors": [
                {
                    "case_number": "ABC123",
                    "row": 45,
                    "errors": [
                        "Since Item 30 (Family Affiliation) is 1, then Item 42 (Citizenship/Immigration Status) 0 must be one of (1, 2, 3)",
                        "Since Item 30 (Family Affiliation) is 1, then Item 34A (Hispanic or Latino) 0 must be between 1 and 2"
                    ]
                }
            ]
        }
    ],
    "case_details": [
        {
            "case_number": "ABC123",
            "record_types": ["T1", "T2", "T2"],
            "error_count": 8,
            "errors": [...]
        }
    ]
}
```

#### 2. Prompt Builder

Constructs an LLM prompt with:

**System prompt** (static, provides domain context):
- What TANF data reporting is
- What the record types mean (T1=family, T2=adult, T3=child, T4/T5=closed case)
- What the error categories mean
- What the key fields are and their business meaning
- The conditional dependency chains (extracted from schema definitions)
- Instructions for tone: clear, non-technical, actionable

**User prompt** (dynamic, per file):
- The structured error data from step 1
- The file-level statistics
- Request for:
  1. **File-level summary** (2–3 paragraphs): What are the main issues? What patterns exist?
  2. **Top error patterns** (ranked list): What are the most impactful problems and how to fix them?
  3. **Root cause analysis**: Where cascading errors exist, identify the likely root cause
  4. **Action items**: Concrete steps the STT should take to correct the data

**Key prompt engineering considerations:**
- Keep prompts focused — don't dump all 342 errors, use the grouped/sampled representation
- Include the validation rules as context so the LLM understands *why* the errors exist
- Ask for structured output (JSON or markdown) for consistent rendering
- Temperature=0 for deterministic, factual output

#### 3. LLM Integration

**Recommended approach: Anthropic Claude API** (since this is an Anthropic-adjacent project)

```python
# Simplified example
class ErrorSummaryService:
    def __init__(self):
        self.client = anthropic.Anthropic()

    def generate_summary(self, data_file_summary):
        """Generate LLM error summary for a DataFileSummary."""
        errors = self.collect_and_group_errors(data_file_summary.datafile)
        prompt = self.build_prompt(errors, data_file_summary)

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2000,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": prompt}]
        )

        return self.parse_and_store(response, data_file_summary)
```

**Model selection tradeoffs:**
- Claude Sonnet: good balance of cost/quality for structured summarization
- Claude Haiku: cheaper, viable if summaries are simpler pattern-matching
- Could use Haiku for files with <50 errors, Sonnet for complex cases

#### 4. Storage Model

```python
class ErrorSummary(models.Model):
    data_file_summary = models.OneToOneField(DataFileSummary, on_delete=models.CASCADE)

    file_level_summary = models.TextField()        # Markdown narrative
    error_patterns_json = models.JSONField()        # Structured pattern analysis
    action_items_json = models.JSONField()          # Prioritized fix suggestions
    root_causes_json = models.JSONField()           # Identified cascading root causes

    model_used = models.CharField(max_length=50)    # For audit: which LLM model
    prompt_tokens = models.IntegerField()           # Cost tracking
    completion_tokens = models.IntegerField()       # Cost tracking

    created_at = models.DateTimeField(auto_now_add=True)
```

#### 5. Integration Points

**Option A: Inline with parse pipeline (Celery task)**
- After `update_dfs()` computes the status, call `generate_error_summary()` in the same Celery task
- Pros: summary available when the analyst first views the file
- Cons: adds latency to the parse pipeline (LLM call is 2-10 seconds); parse pipeline failure modes expand

**Option B: Separate Celery task (recommended)**
- After parse completes, dispatch a separate `generate_error_summary.delay(data_file_summary_id)` task
- Pros: parse pipeline is unaffected; retries are independent; can be rate-limited
- Cons: brief window where file is processed but summary isn't ready yet (show "generating summary..." in UI)

**Option C: On-demand (lazy generation)**
- Generate summary only when an analyst views the error report
- Pros: no cost for files nobody looks at
- Cons: analyst waits 2-10 seconds on first view; need caching

**Recommendation: Option B** — it decouples concerns, keeps the critical parse pipeline reliable, and the summary is usually ready by the time an analyst looks at it.

#### 6. Surfacing to Users

**In the XLSX error report:**
- Add a new "Guidance" tab (first tab) with the narrative summary, pattern analysis, and action items
- Keep existing "Critical" and "Summary" tabs unchanged

**In the frontend UI:**
- New collapsible panel on the DataFile detail page showing the LLM summary
- Markdown-rendered for readability
- "This summary was generated by AI to help you understand the errors in your file. Always refer to the coding instructions for authoritative guidance."

### Cost Estimation

- Average file might produce 100–500 errors → grouped into 5–15 patterns
- Prompt: ~2,000–4,000 tokens (system + structured error data)
- Completion: ~500–1,500 tokens
- At Claude Sonnet pricing (~$3/M input, ~$15/M output tokens):
  - Per file: ~$0.01–$0.03
  - 1,000 files/month: ~$10–$30/month
- Very cost-effective for the value provided

### Security & Compliance Considerations

- **PII**: Error data may contain case numbers and SSNs. The error grouper should **strip SSNs** before sending to the LLM. Case numbers may be needed for context but could be anonymized (Case A, Case B, etc.).
- **Data residency**: If using Claude API, data is processed by Anthropic. Review data processing agreement for compliance with ACF requirements. Consider whether anonymized/aggregated data is sufficient.
- **Determinism**: For audit purposes, store the exact prompt and response. Use `temperature=0`.
- **Disclaimer**: Always present summaries as AI-generated guidance, not authoritative interpretation of the coding instructions.

### Phased Rollout

**Phase 1: File-level summaries only**
- Generate a 2–3 paragraph narrative summary per file
- Surface in XLSX and frontend
- Validate with data analysts: are the summaries helpful? accurate?

**Phase 2: Pattern analysis**
- Add root cause detection (cascading error identification)
- Add prioritized action items
- A/B test: do analysts fix errors faster with summaries?

**Phase 3: Case-level drill-down**
- Per-case summaries for the most error-heavy cases
- Interactive: analyst can ask follow-up questions about a specific case (chat interface)

**Phase 4: Proactive guidance**
- Use historical error patterns per STT to predict common mistakes
- Pre-submission validation hints: "Last quarter, your files had frequent FAMILY_AFFILIATION/CITIZENSHIP_STATUS mismatches — double-check these before uploading"
