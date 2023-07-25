# looker_examples.model
connection: "bigquery_connection"

include: "/cohort_retention_analysis/vw_cohort_analysis.view.lkml"

explore: explore_cohort_analysis {
  label: "Cohort Analysis"
  view_label: "DT Cohort Analysis"
  from: vw_cohort_analysis
}
