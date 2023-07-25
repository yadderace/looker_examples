# vw_cohort_analysis.view.lkml

include: "vw_fct_login.view.lkml"

view: vw_cohort_analysis {
  derived_table: {
    sql:

    WITH base_set AS (
      SELECT DISTINCT
        DATE_TRUNC(open_date, MONTH) AS open_date,
        user_id
      FROM ${vw_fct_login.SQL_TABLE_NAME} AS fct
    ),


      temp_cohorts AS (
      SELECT
      open_date,
      cohort
      FROM UNNEST([0, 1, 2, 3, 4, 5, 6]) AS cohort
      JOIN UNNEST(
      GENERATE_DATE_ARRAY(
      DATE_TRUNC((SELECT MIN(open_date) FROM base_set) , MONTH),
      DATE_TRUNC((SELECT MAX(open_date) FROM base_set), MONTH),
      INTERVAL 1 MONTH
      )) AS open_date
      ),

      total_open_date AS (
      SELECT
      open_date,
      DENSE_RANK() OVER(ORDER BY open_date ASC) as date_rank,
      COUNT(DISTINCT user_id) AS user_open_date
      FROM base_set
      GROUP BY 1
      ),

      cohorts AS (
      SELECT open_date,
      user_id,
      [ 0
      {% for i in (1..6) %}
      , IFNULL(DATE_DIFF(LEAD(open_date, {{i}}) OVER (PARTITION BY user_id ORDER BY open_date ASC), open_date, MONTH), -1)
      {% endfor %}
      ] AS cohorts_array
      FROM base_set
      ),

      flattened_cohorts AS (
      SELECT user_id,
      open_date,
      cohort,
      FROM cohorts, cohorts.cohorts_array AS cohort
      WHERE cohort BETWEEN 0 AND 6
      ),

      result AS (
      SELECT
      COALESCE(flt.open_date, tc.open_date) AS open_date,
      COALESCE(flt.cohort, tc.cohort) AS cohort,
      ted.user_open_date,
      COUNT(DISTINCT flt.user_id) AS retained_users,
      FROM flattened_cohorts AS flt
      FULL OUTER JOIN temp_cohorts AS tc
      ON flt.open_date = tc.open_date
      AND flt.cohort = tc.cohort
      INNER JOIN total_open_date AS ted
      ON tc.open_date = ted.open_date
      GROUP BY 1, 2, 3
      )

      SELECT * FROM result;;
  }


  dimension: user_id {
    label: "User ID"
    type: string
    sql: ${TABLE}.user_id ;;
  }

  dimension: cohort {
    label: "Cohort #"
    type: number
    sql: ${TABLE}.cohort ;;
  }

  dimension: total {
    label: "Total Users"
    type: number
    sql: ${TABLE}.user_open_date;;
  }

  dimension: cohort_custom {
    label: "Cohort (Custom)"
    type: string
    sql:
    CONCAT('Month ', ${cohort});;
    order_by_field: cohort
  }

  dimension_group: open {
    type: time
    label: "Open"
    timeframes: [
      date,
      month,
      week
    ]
    convert_tz: no
    sql: ${TABLE}.open_date ;;
  }

  dimension: open_date_custom {
    label: "Open Date (Custom)"
    type: string
    sql:
    FORMAT_DATE('%Y %B', ${open_date});;
    order_by_field: open_date
  }

  measure: users {
    label: "Users"
    type: sum
    sql: ${TABLE}.retained_users ;;
  }

  measure: total_cohort0_users {
    label: "Total Users (C0)"
    description: "Total users in cohort 0"
    type: sum
    sql: ${TABLE}.user_open_date;;
    value_format: "[>=1000000]0.0,,\"M\";[>=1000]0.0,\"K\";0.0"
  }

  measure: retention {
    label: "Retention"
    type: number
    sql:  IF(${total_cohort0_users} = 0, 0 ,${users} / ${total_cohort0_users});;
    value_format_name: percent_2
    html: {% if value >= 0.70 %}
        <div style='border-radius: 5px; background: #5A55F2; width: 50px;'>
          {{rendered_value}}
        </div>
      {% elsif value >= 0.40 %}

      <div style='border-radius: 5px; background: #7142DB; width: 50px;'>
      {{rendered_value}}
      </div>

      {% elsif value > 0 %}

      <div style='border-radius: 5px; background: #B04BF9; width: 50px;'>
      {{rendered_value}}
      </div>

      {% else %}

      <div style='border-radius: 5px; background: #A29FF4; width: 50px;'>
      {{rendered_value}}
      </div>

      {% endif %};;
  }

}
