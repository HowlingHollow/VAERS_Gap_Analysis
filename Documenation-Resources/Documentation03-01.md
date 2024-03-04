# 2021-2022 VAERS DATA ANALYSIS

### Author: Jared White

### Last Updated: March 3, 2024

#### Understanding What the Data Is and Isn't

##### *What is VAERS?*

- The Vaccine Adverse Event Reporting System.

- From the official VAERS site:
  *"Established in 1990, the Vaccine Adverse Event Reporting System (VAERS) is a
  national early warning system to detect possible safety problems in
  U.S.-licensed vaccines. VAERS is co-managed by the Centers for
  Disease Control and Prevention (CDC) and the U.S. Food and Drug
  Administration (FDA). VAERS accepts and analyzes reports of adverse
  events (possible side effects) after a person has received a vaccination.”*

- *"VAERS is a passive reporting system, meaning it relies on individuals to
  send in reports of their experiences to CDC and FDA. VAERS is not
  designed to determine if a vaccine caused a health problem, but is
  especially useful for detecting unusual or unexpected patterns of
  adverse event reporting that might indicate a possible safety problem
  with a vaccine.”*
  [(https://vaers.hhs.gov/about.html) ](https://vaers.hhs.gov/about.html)

##### *What are the Limitations of VAERS?*

- **It is not comprehensive:** *"’Underreporting’ is one of the main limitations of passive surveillance systems, including VAERS. The term, underreporting refers to the fact that VAERS receives reports for only a small fraction of actual adverse events.”*

- **It is not Verifiable or Reliable by Nature:** *“VAERS reports can be submitted voluntarily by anyone, including healthcare providers, patients, or family members. Reports vary in quality and completeness. They often lack details and sometimes can have information that contains errors.”*

- **VAERS is Completely Anonymous** due to regulations on handling of PHI, however: *“… reports to VAERS that appear to be potentially false or fabricated with the intent to mislead CDC and FDA may be reviewed before they are added to the VAERS database. Knowingly filing a false VAERS report is a violation of Federal law (18 U.S. Code § 1001) punishable by fine and imprisonment.”*

- **It tracks Correlation, not Causation:** *“A report to VAERS generally does not prove that the identified vaccine(s) caused the adverse event described. It only confirms that the reported event occurred sometime after vaccine was given. No proof that the event was caused by the vaccine is required in order for VAERS to accept the report. VAERS accepts all reports without judging whether the event was caused by the vaccine.”*

        [(https://vaers.hhs.gov/data/dataguide.html)]((https://vaers.hhs.gov/data/dataguide.html))

- **Only Initial Reports are Publicly Available:** *“When multiple reports of a single case or event are received, only the first report received is included In the publicly accessible dataset. Subsequent reports may contain additional or conflicting data, and there is no assurance that the data provided in the public dataset is the most accurate or current available.”*
  
  (VAERS Data Use Guide, September 2021)
  
  This means that none of the data, statistics, or analysis contained within this report can definitively prove anything about a certain vaccine, company, organization, or any other product, person, or entity. Even the most careful and comprehensive analysis is only as trustworthy as the underlying data that it is based on. 

### Download the Dataset and Import it into SQLite3

The VAERS Dataset is downloaded in calendar yearly .zip archives from: https://vaers.hhs.gov/data/datasets.html

The Data Use Guide PDF is provided at the same link. This is essential for understanding the data and reproducing this report. Herein the September 2021 Revision is referenced, and the sope of this project is the 2021 and 2022 archives.

Each yearly archive contains 3 files, where the filename shown is prepended by the year in 4 digit format:

1. VAERSDATA.CSV – This is the bulk of the relevant data to be analyzed. It includes demographic information, medical history and preexisting conditions, date of vaccination and symptom onset, whether the subject died or was hospitalized, free-text symptom descriptions (varied and concatenated between self-reporters and medical professionals) and several other fields.

2. VAERSVAX.CSV – This table contains information, including type and manufacture, about the vaccination(s) that the subject received.

3. VAERSSYMPTOMS.CSV – This file contains the symptoms reported in MedDRA terms and the MedDRA version of this term. MedDRA is proprietary encoding system used by the medical industry to shorten symptom descriptions.

Due to limitations with SQLite's data type detection when importing CSV files, and the VAERS database using all capitol letters for column headers, a new database schema is manually created:

```sql
sqlite> CREATE TABLE data ( 
                vaers_id INTEGER PRIMARY KEY, NOT NULL, 
                recvdate TEXT, 
                state TEXT, 
                age_yrs REAL, 
                cage_yr REAL, 
                cage_mo REAL, 
                sex TEXT, 
                rpt_date TEXT,
                symptom_text TEXT,
                died TEXT,
                datedied TEXT,
                l_threat TEXT,
                er_visit TEXT,
                hospital TEXT,
                hospdays TEXT,
                x_stay TEXT,
                disable TEXT,
                recovd TEXT,
                vax_date TEXT,
                onset_date TEXT,
                numdays INTEGER,
                lab_data TEXT,
                v_adminby TEXT,
                v_fundby TEXT,
                other_meds TEXT,
                cur_ill TEXT,
                history TEXT,
                prior_vax TEXT,
                splttype TEXT,
                form_vers INTEGER,
                todays_date TEXT,
                birth_defect TEXT,
                ofc_visit TEXT,
                er_ed_visit TEXT,
                allergies TEXT );
```

```sql
sqlite> CREATE TABLE vax (
                vaers_id INTEGER,
                vax_type TEXT,
                vax_manu TEXT,
                vax_lot TEXT, 
                vax_dose_series TEXT, 
                vax_route TEXT, 
                vax_site TEXT, 
                vax_name TEXT);
```

```sql
sqlite> CREATE TABLE symptoms ( 
                vaers_id INTEGER,
                symptom1 TEXT, 
                symptomversion1 REAL, 
                symptom2 TEXT, 
                symptomversion2 REAL, 
                symptom3 TEXT, 
                symptomversion3 REAL, 
                symptom4 TEXT, 
                symptomversion4 REAL, 
                symptom5 TEXT, 
                symptomversion5 REAL );
```

The headers can be removed from each of the 6 CSV files with Bash, then the linecount of each file is stored to a text file to verify a complete import:

```bash
$: for filename in ./*.csv; do tail -n +2 "$filename" > "$filename.tmp" && mv "$filename.tmp" "nohead/$filename"; done
$: for filename in ./nohead/*.csv; do wc -l "$filename" >> ./nohead/linecount.txt; done
```

Verify the database directory and schema, then import the 2021 files:

```bash
sqlite> .database
sqlite> .schema
sqlite> .mode csv    #set mode for redundancy's sake
sqlite> .import --csv nohead/2021VAERSDATA.csv data
sqlite> .import --csv nohead/2021VAERSVAX.csv vax
sqlite> .import --csv nohead/2021VAERSSYMPTOMS.csv symptoms
```

Get the line count from the tables in the SQLITE database, and compare to linecount.txt, then repeat the process for the 2022 archives. Finally, back up the database before beginning to manipulate the data.

```sql
SELECT COUNT(*) FROM data;
SELECT COUNT(*) FROM vax;
SELECT COUNT(*) FROM symptoms;
```

### Data Manipulation: Prepare for Cleaning and Analysis

##### Combining Multiple Age Columns:

*“The sum of the two variables CAGE_YR and CAGE_MO provide the calculated age of a person. For example, if CAGE_YR = 1 and CAGE_MO = 0.5, then the age of the individual is 1.5 years, or 1 year 6 months.”*

(Date Use Guide)

3,359 reports where calculated age years is missing or 0, and calculated age months is not missing and greater than 0. For these reports, cage_yr is filled in with the value from cage_mo.

```sql
SELECT COUNT(*) FROM ( 
    SELECT vaers_id, age_yrs, cage_yr, cage_mo FROM data 
        WHERE (cage_yr = "0.0" OR cage_yr = "") 
        AND (cage_mo IS NOT "" AND cage_mo > 0.0)
       GROUP BY vaers_id);

UPDATE data SET cage_yr = cage_mo 
        WHERE (cage_yr = "0.0" or cage_yr = "") 
        and (cage_mo is not "" and cage_mo > 0.0);
# Console reports 3,359 rows affected.
```

Limited manual cleaning is performed at this point. 1 age value is changed from 118 to 68, according to information in the symptom text. The cage_yr values are manually deleted for 7 reports which include "corrected to an unknown age" in the symptom text field. The following queries reveal these reports:

```sql
SELECT * FROM data 
    WHERE cage_yr > 116 
    AND cage_yr IS NOT "" 
    AND age_yrs = "" 
    ORDER BY cage_yr DESC;

SELECT * FROM data 
    WHERE symptom_text 
    LIKE "%corrected to an unknown age%" 
    AND cage_yr IS NOT "" 
    ORDER BY cage_yr DESC;
```

The same process is used to combine age_yrs and cage_yr in 7,343 reports where age_yrs is 0 or missing, and cage_yr is not missing and greater than 0. This provides one single column for the age of the subject, but a significant number of outliers and NULLS still exist within this metric.

```sql
SELECT COUNT(*) FROM (
  SELECT vaers_id, age_yrs, cage_yr FROM data
      WHERE (age_yrs = 0.0 OR age_yrs = "") 
      AND (cage_yr IS NOT "" AND cage_yr > 0.0) 
    GROUP BY vaers_id);

UPDATE data SET age_yrs = cage_yr 
    WHERE (age_yrs = 0.0 OR age_yrs = "") 
    AND (cage_yr IS NOT "" AND cage_yr > 0.0);
```

##### Combining the Two Columns for Date of Report

VAERS Form 2.0 was implemented on June 30th 2017.[(https://wonder.cdc.gov/wonder/help/vaers.html)]()

However, both form versions were still being accepted during 2021 and 2022. With Version 2.0, the field rpt_date was replaced by todays_date, with both being described as “Date form completed” (Data Guide). 959 values from rpt_date are copied to todays_date:

```sql
SELECT COUNT (*) FROM (
    SELECT rpt_date, todays_date, form_vers FROM data 
        WHERE rpt_date != "" 
        AND form_vers = 1
        GROUP BY vaers_id);


UPDATE data SET todays_date = rpt_date WHERE vaers_id IN (
    SELECT vaers_id FROM data
    WHERE rpt_date != "" 
    AND form_vers = 1 
    AND todays_date = "");
```

8,783 reports still remain in which no date is included.

##### Combining the Columns for Emergency Room, Urgent Care, and Doctor Visit

With the implementation of form version 2.0, column er_visit was split into 2 columns: **er_ed_visit** for Emergency Room or Urgent Care visits, and ofc_visit for Doctor's Office or other Clinic visits. For the 1,038 version 1 reports there is no way to know which type of healthcare provider was visited, so the columns are recombined into er_visit:

```sql
SELECT COUNT(*) FROM (
    SELECT vaers_id FROM data 
            WHERE er_visit = ""
            AND (er_ed_visit = "Y"
            OR ofc_visit = "Y");


UPDATE data SET er_visit = "Y" WHERE vaers_id IN (
    SELECT vaers_id FROM data 
            WHERE er_visit = ""
            AND (er_ed_visit = "Y"
            OR ofc_visit = "Y"));
```

The Hospitalization and 'Life-Threatening' columns are kept separate. 264,926 rows are updated with this change.

##### Removing Redundant Fields

After backing up the database file again, the 5 fields that have been combined into other columns are removed: cage_mo, cage_yr, rpt_date, er_ed_visit, and ofc_visit.

```sql
ALTER TABLE data DROP COLUMN cage_mo;
ALTER TABLE data DROP COLUMN cage_yr;
ALTER TABLE data DROP COLUMN rpt_date;
ALTER TABLE data DROP COLUMN er_ed_visit;
ALTER TABLE data DROP COLUMN ofc_visit;
```

### Preliminary Statistical Exploration

Significant missing data and correctable outliers still exist within the dataset. The following statistics and calculations are only for exploratory analysis and to inform further processes.

- There are 271,112 Reports (27.32% of total) which are missing one or more of the key fields: sex, age, state, and number of days between vaccination and onset (numdays). These queries were used to create the bar graph on slide 3 of the current roadmap:

```sql
SELECT COUNT(*) FROM (
    SELECT vaers_id, state, age_yrs, sex, numdays FROM data 
        WHERE sex = "U"
        OR state = ""
        OR age_yrs = ""
        OR numdays = "");
            #271,112
```

```sql
WITH categories AS (
    SELECT vaers_id AS id, 
    CASE WHEN
            sex = "U"
            AND state = ""
            AND age_yrs = ""
            AND numdays = ""
        THEN 'all'
        WHEN 
            sex = "U"
            AND state = ""
            AND age_yrs = ""
            AND numdays != ""
        THEN 'sex+state+age'
        WHEN
            sex = "U"
            AND state = ""
            AND age_yrs != ""
            AND numdays = ""
        THEN 'sex+state+days'
        WHEN
            sex = "U"
            AND state != ""
            AND age_yrs = ""
            AND numdays = ""
        THEN 'sex+age+days'
        WHEN
            sex = "U"
            AND state = ""
            AND age_yrs != ""
            AND numdays != ""
        THEN 'sex+state'
        WHEN
            sex = "U"
            AND state != ""
            AND age_yrs != ""
            AND numdays = ""
        THEN 'sex+days'
        WHEN
            sex = "U"
            AND state != ""
            AND age_yrs = ""
            AND numdays != ""
        THEN 'sex+age'
        WHEN
            sex = "U"
            AND state != ""
            AND age_yrs != ""
            AND numdays != ""
        THEN 'sex'
        # CODE BELOW WAS WRITTEN BY GPT 3.5 BECAUSE THIS IS TEDIOUS
        WHEN sex != 'U' AND state = '' AND age_yrs = '' AND numdays = '' THEN 'state+age+days'
        WHEN sex != 'U' AND state = '' AND age_yrs != '' AND numdays = '' THEN 'state+days'
        WHEN sex != 'U' AND state = '' AND age_yrs = '' AND numdays != '' THEN 'state+age'
        WHEN sex != 'U' AND state = '' AND age_yrs != '' AND numdays != '' THEN 'state'
        WHEN sex != 'U' AND state != '' AND age_yrs = '' AND numdays = '' THEN 'age+days'
        WHEN sex != 'U' AND state != '' AND age_yrs = '' AND numdays != '' THEN 'age'
        WHEN sex != 'U' AND state != '' AND age_yrs != '' AND numdays = '' THEN 'days'
    # END CODE WRITTEN BY GPT    
    ELSE 'notmissing'
    END AS 'missing_category'
        FROM data)

SELECT missing_category, COUNT(id) FROM categories
    GROUP BY missing_category;
```

The average time between vaccination and symptom onset was 39.04 days, calculated with a significant number of extreme outliers.

```sql
SELECT AVG(interval) FROM (
    SELECT vaers_id, numdays AS interval FROM data
        WHERE numdays != "");

SELECT vaers_id, numdays AS interval FROM data
    WHERE numdays != ""
    AND numdays > 180;
            # 41,984 rows loaded
```

These outliers are not cleaned yet because they hold insight to the reliability and gap analysis. The following query was used to create the histogram on slide 8 of the current roadmap:

```sql
WITH intervals AS (
    SELECT vaers_id AS id,
    CASE WHEN numdays = 0 THEN "same day" 
        WHEN numdays > 0
            AND numdays <= 7 THEN "1 day - 1 week"    
        WHEN numdays > 7 
            AND numdays <= 14 THEN "1-2 weeks"    
        WHEN numdays > 14 
            AND numdays <= 28 THEN "2-4 weeks"
        WHEN numdays > 28
            AND numdays <= 59 THEN "1-2 months"
        WHEN numdays > 59
            AND numdays <= 120 THEN "2-4 months"
        WHEN numdays > 120
            AND numdays <= 180 THEN "4-6 months"
        WHEN numdays > 180
            AND numdays <= 360 THEN "6 months to 1 year"
        ELSE "greater than 1 year"
    END AS 'int_cat' 
    FROM data WHERE numdays != '')

SELECT int_cat, COUNT(id) FROM intervals
        JOIN data on intervals.id = data.vaers_id
        GROUP BY int_cat;
```

### Next Steps: Cleaning

- Remove reports dated outside of scope & obvious errors.

- Address Missing Values & Outliers using free text symptom descriptions where possible.

- Conservatively clean drastic outliers & miscalculations.

- Calculate Statistical Significance of remaining sample size.

- Copy all post-COVID Vaccination Reports to new working database.

### Please see roadmap presentation on GitHub for more information.

# Property of Jared White

### You may use and/or disseminate any portion of this project, but you must clearly state credit to the original contributor(s).
