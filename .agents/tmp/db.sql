
-- System Wide Summary

WITH submissions AS (
      SELECT
          df.id,
          df.year AS data_fy,
          df.stt_id,
          CASE
              WHEN EXTRACT(MONTH FROM df.created_at) > 11
                   OR (EXTRACT(MONTH FROM df.created_at) = 11
                       AND EXTRACT(DAY FROM df.created_at) >= 15)
              THEN EXTRACT(YEAR FROM df.created_at)::int + 1
              ELSE EXTRACT(YEAR FROM df.created_at)::int
          END AS submission_fy
      FROM data_files_datafile df
  )
  SELECT
      COUNT(*) AS total_submissions,
      COUNT(*) FILTER (WHERE submission_fy - data_fy >= 2) AS historical_submissions,
      COUNT(DISTINCT stt_id) FILTER (WHERE submission_fy - data_fy >= 2) AS stts_submitting_historical,
      ROUND(
          100.0 * COUNT(*) FILTER (WHERE submission_fy - data_fy >= 2) / NULLIF(COUNT(*), 0),
          1
      ) AS pct_historical
  FROM submissions;

  -- Which STTs Submit Historical Data, Ranked

  WITH submissions AS (
      SELECT
          df.id,
          df.created_at,
          df.year AS data_fy,
          df.stt_id,
          s.name AS stt_name,
          s.type AS stt_type,
          CASE
              WHEN EXTRACT(MONTH FROM df.created_at) > 11
                   OR (EXTRACT(MONTH FROM df.created_at) = 11
                       AND EXTRACT(DAY FROM df.created_at) >= 15)
              THEN EXTRACT(YEAR FROM df.created_at)::int + 1
              ELSE EXTRACT(YEAR FROM df.created_at)::int
          END AS submission_fy
      FROM data_files_datafile df
      JOIN stts_stt s ON df.stt_id = s.id
  )
  SELECT
      stt_name,
      stt_type,
      COUNT(*) AS historical_submissions,
      COUNT(DISTINCT data_fy) AS distinct_data_fys_submitted,
      MIN(data_fy) AS oldest_data_fy,
      MAX(data_fy) AS newest_data_fy,
      MIN(created_at)::date AS earliest_submission_date,
      MAX(created_at)::date AS latest_submission_date
  FROM submissions
  WHERE submission_fy - data_fy >= 2
  GROUP BY stt_name, stt_type
  ORDER BY historical_submissions DESC;

  --  Historical vs Current Ratio Per STT

  WITH submissions AS (
      SELECT
          df.id,
          df.year AS data_fy,
          s.name AS stt_name,
          s.type as stt_type,
          CASE
              WHEN EXTRACT(MONTH FROM df.created_at) > 11
                   OR (EXTRACT(MONTH FROM df.created_at) = 11
                       AND EXTRACT(DAY FROM df.created_at) >= 15)
              THEN EXTRACT(YEAR FROM df.created_at)::int + 1
              ELSE EXTRACT(YEAR FROM df.created_at)::int
          END AS submission_fy
      FROM data_files_datafile df
      JOIN stts_stt s ON df.stt_id = s.id
  )
  SELECT
      stt_name,
      stt_type,
      COUNT(*) AS total_submissions,
      COUNT(*) FILTER (WHERE submission_fy - data_fy >= 2) AS historical_submissions,
      ROUND(
          100.0 * COUNT(*) FILTER (WHERE submission_fy - data_fy >= 2) / COUNT(*),
          1
      ) AS pct_historical
  FROM submissions
  GROUP BY stt_name, stt_type
  HAVING COUNT(*) FILTER (WHERE submission_fy - data_fy >= 2) > 0
  ORDER BY pct_historical DESC;

  -- Detailed Breakdown by STT, Data Year, and Submission Year

  WITH submissions AS (
      SELECT
          df.id,
          df.created_at,
          df.year AS data_fy,
          df.quarter,
          df.program_type,
          df.version,
          s.name AS stt_name,
          s.type AS stt_type,
          CASE
              WHEN EXTRACT(MONTH FROM df.created_at) > 11
                   OR (EXTRACT(MONTH FROM df.created_at) = 11
                       AND EXTRACT(DAY FROM df.created_at) >= 15)
              THEN EXTRACT(YEAR FROM df.created_at)::int + 1
              ELSE EXTRACT(YEAR FROM df.created_at)::int
          END AS submission_fy
      FROM data_files_datafile df
      JOIN stts_stt s ON df.stt_id = s.id
  )
  SELECT
      stt_name,
      stt_type,
      data_fy,
      submission_fy,
      (submission_fy - data_fy) AS fys_late,
      COUNT(*) AS file_count,
      COUNT(DISTINCT quarter) AS quarters_submitted,
      COUNT(DISTINCT program_type) AS program_types,
      MAX(version) AS max_version
  FROM submissions
  WHERE submission_fy - data_fy >= 2
  GROUP BY stt_name, stt_type, data_fy, submission_fy
  ORDER BY stt_name, data_fy, submission_fy;

-- Trend Over Time

WITH submissions AS (
      SELECT
          df.id,
          df.year AS data_fy,
          df.stt_id,
          CASE
              WHEN EXTRACT(MONTH FROM df.created_at) > 11
                   OR (EXTRACT(MONTH FROM df.created_at) = 11
                       AND EXTRACT(DAY FROM df.created_at) >= 15)
              THEN EXTRACT(YEAR FROM df.created_at)::int + 1
              ELSE EXTRACT(YEAR FROM df.created_at)::int
          END AS submission_fy
      FROM data_files_datafile df
  )
  SELECT
      submission_fy,
      COUNT(*) AS total_submissions_that_fy,
      COUNT(*) FILTER (WHERE submission_fy - data_fy >= 2) AS historical_submissions,
      ROUND(
          100.0 * COUNT(*) FILTER (WHERE submission_fy - data_fy >= 2) / NULLIF(COUNT(*), 0),
          1
      ) AS pct_historical,
      COUNT(DISTINCT stt_id) FILTER (WHERE submission_fy - data_fy >= 2) AS distinct_stts_submitting_historical
  FROM submissions
  GROUP BY submission_fy
  ORDER BY submission_fy;

  -- Oldest FY submitted per Year

  WITH submissions AS (
      SELECT
          df.year AS data_fy,
          CASE
              WHEN EXTRACT(MONTH FROM df.created_at) > 11
                   OR (EXTRACT(MONTH FROM df.created_at) = 11
                       AND EXTRACT(DAY FROM df.created_at) >= 15)
              THEN EXTRACT(YEAR FROM df.created_at)::int + 1
              ELSE EXTRACT(YEAR FROM df.created_at)::int
          END AS submission_fy
      FROM data_files_datafile df
  )
  SELECT
      submission_fy,
      MIN(data_fy) AS oldest_data_fy_submitted,
      submission_fy - MIN(data_fy) AS max_fys_back
  FROM submissions
  GROUP BY submission_fy
  ORDER BY submission_fy;

  -- Submission Lag Distirubtion

  WITH submissions AS (
      SELECT
          df.id,
          df.year AS data_fy,
          CASE
              WHEN EXTRACT(MONTH FROM df.created_at) > 11
                   OR (EXTRACT(MONTH FROM df.created_at) = 11
                       AND EXTRACT(DAY FROM df.created_at) >= 15)
              THEN EXTRACT(YEAR FROM df.created_at)::int + 1
              ELSE EXTRACT(YEAR FROM df.created_at)::int
          END AS submission_fy
      FROM data_files_datafile df
  )
  SELECT
      submission_fy - data_fy AS fys_back,
      COUNT(*) AS total_submissions,
      ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_all
  FROM submissions
  GROUP BY fys_back
  ORDER BY fys_back;

  -- Total Records

  SELECT COUNT(*) FROM data_files_datafile;
