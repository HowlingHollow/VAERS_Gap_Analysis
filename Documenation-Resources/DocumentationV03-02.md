# 2021-2022 VAERS DATA ANALYSIS

### Author: Jared White

### Last Updated: March 18, 2024

### [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/deed.en)

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

8,783 reports still remain in which no date is included. Since the date the form was received is not more than 1-2 days after the time it was completed, this is addressed in the first step of cleaning.

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

- [x] Remove reports dated outside outside of scope & obvious errors.

- [x] Address Missing Values & Outliers using free text symptom descriptions where possible.

- [x] Clean drastic numeric outliers & obvious miscalculations.

- [x] Calculate Statistical Significance of remaining sample size.

- [x] Copy all post-COVID Vaccination Reports to new working database.

### Selective Cleaning as Pertains to Scope.

The majority of the cleaning will focus on removing obvious entry errors, deleting rows that are out of scope, and informing key missing values from symptom descriptions where possible.

#### Branch the Database with Git

Since this is the start of significant changes it to the data base, its a good time to start using version control:

```bash
➜ git init
➜ git add --all
➜ git commit -m "Pre-Cleaning DB"
➜ git branch cleaning
➜ git checkout cleaning
```

### Inform Missing Dates

There are no reports in which recvdate is not during 2021 or 2022, but 8,873 in which todays_date is blank. For these reports, the date the form was received is used to inform the date that it was completed. Recvdate can then be dropped, along with x_stay and v_fundby, 

```sql
SELECT COUNT(*) FROM data WHERE 
    recvdate NOT LIKE "%2021" AND
    recvdate NOT LIKE "%2022";

SELECT COUNT(*) FROM data WHERE 
    todays_date = "";

UPDATE data SET todays_date = recvdate 
    WHERE vaers_id IN (
    SELECT vaers_id FROM data WHERE 
        todays_date = "");
# Console: 8,783 rows affected
ALTER TABLE data DROP COLUMN recvdate;
ALTER TABLE data DROP COLUMN x_stay;
ALTER TABLE data DROP COLUMN v_fundby;
```

### Copying only COVID Vaccination Reports and Relevant Columns into a New Table.

This will make cleaning faster, and provide ease for importing into R later in the analysis. The symptom versions, vaccination route and site are not copied because they are not relevant to the analysis. The vax_name is redundant to vax_type and vax_manu and is not copied. Due to the 1:many relationship of the tables and the need to retain unique id values, only the first five symptoms of each report can be transferred to the new table. However, the original symptom table is retained for future reference. Reports with vaccination type COVID19-2 are included by the WHERE clause.

```sql
CREATE TABLE covid AS 
    SELECT data.*, 
            vax.vax_type, vax.vax_manu, vax.vax_lot, vax.vax_dose_series,
            symptoms.symptom1, symptoms.symptom2, symptoms.symptom3, symptoms.symptom4, symptoms.symptom5
        FROM data
    INNER JOIN vax ON data.vaers_id = vax.vaers_id
    LEFT JOIN symptoms ON data.vaers_id = symptoms.vaers_id
    WHERE vax.vax_type LIKE "%COVID%"
    GROUP BY data.vaers_id;
```

### Inferring Missing Key Values where Possible and Removing Duplicates

The following Queries were used to identify and update the age column from the symptom text for 2 reports, and remove 3 erroneous or irrelevant reports.

```sql
SELECT vaers_id, age_yrs, symptom_text FROM covid WHERE symptom_text LIKE "%age updated%"
    OR symptom_text LIKE "%age was updated%";


SELECT vaers_id, age_yrs, symptom_text FROM covid WHERE (symptom_text LIKE "%age change%"
    OR symptom_text LIKE "%age was change%")
    AND (symptom_text NOT LIKE "%dosage change%"
    AND symptom_text NOT LIKE "%dosage was change%");
```

The following queries were used to remove several duplicate and out-of-scope entries:

```sql
DELETE FROM covid WHERE symptom_text IN "%On 29 Dec 2020, the patient received their first of two planned doses of mRNA-1273 intramuscularly for prophylaxis of COVID-19 infection.  On 29 Dec 2020, after vaccine administration, the nurse called to report that the patient had been administered a 1mL dose instead of 0.5mL dose of the vaccine. No side effects were reported due to the event.%"
                AND vaers_id != 942591;
    # 13 duplicates removed
DELETE FROM covid WHERE symptom_text LIKE "%Vaccine was stored at -20 Degrees F so outside of the Temperature range; A spontaneous report was received from a pharmacist concerning a patient who received Moderna's COVID-19 vaccine (mRNA-1273) that was stored at -20 degrees F, so outside of the temperature range.  The patient's medical history was not provided. No relevant concomitant medications were reported.   On an unknown date, the patient received their first of two planned doses of mRNA-1273 intramuscularly for prophylaxis of COVID-19 infection. The reporter stated the COVID-19 vaccine was stored at -20 degrees Fahrenheit; outside of the recommended temperature range. No treatment information was provided.  Action taken with mRNA-1273 in response to the event was not reported.  The event, vaccine that was stored at -20 degrees F so outside of the temperature range, was considered resolved.; Reporter's Comments: This case concerns a patient who received their first of two planned doses of mRNA-1273 (Lot unknown), reporting Product storage error without any associated adverse events.%"
                AND vaers_id != 945622;
    #141 duplicates removed
DELETE FROM covid WHERE symptom_text LIKE "%Vaccinated with vial that might have had a temperature excursion; Vaccinated with vial that might have had a temperature excursion; Vaccinated with vial that might have had a temperature excursion; A spontaneous report was received from a nurse concerning a patient who received Moderna's COVID-19 vaccine (mRNA-1273) and was vaccinated with vial that might have had a temperature excursion.  The patient's medical history was not provided. No relevant concomitant medications were reported.   On 22 Dec 2020, the nurse reported a shipment was received. The vial arrived frozen and was placed in a freezer at recommended temperature.   On 02 Jan 2021, the freezer had failed, and the temperature alarm system did not alert anyone. It was noted that the freezer temperature at 5:50 AM was -5 degrees Celsius (C), at 7:50 AM the freezer was a 1.5 C. It remained between from 9.7 C at 12:51 PM then went to 8.3 C at 1:51 PM then down to -8.7 C at 2:51 PM.  On 03 Jan 2021 8:45 PM, the freezer returned to its normal temperature of -20.9 C, -1 C then went to 5.5 C at 11:56 PM.  On 04 Jan 2021, the temperature climbed to 19.4 C. On the same day, the patient received their first of two planned doses of mRNA-1273 (Lot number: 025J20-2A, 025L20A, or 027L20A) intramuscularly for prophylaxis of COVID-19 infection and experienced vaccination with vial that might have had a temperature excursion  No treatment information was provided.  Action taken with mRNA-1273 in response to the event was not reported.   The outcome of the event, vaccinated with vial that might have had a temperature excursion, was considered resolved on 04 Jan 2021.; Reporter's Comments: This report refers to a case of out of specification product use, product temperature excursion issue, and product storage error for mRNA-1273. There were no reported AEs associated with this case.%"
                AND vaers_id != 945776;
    #466 duplicates removed
DELETE FROM covid WHERE symptom_text LIKE "%Normal flu-like symptoms; Soreness in their arms; Vaccinated 18 hours after puncture of the vial; A spontaneous report was received from a physician concerning a patient who received Moderna COVID-19 vaccine (mRNA-1273) and experienced product storage error, normal flu-like symptoms, and pain in arm.   The patient's medical history was not provided. No relevant concomitant medications were reported.  On 07 Jan 2021, the patient received their first of two planned doses of mRNA-1273 for prophylaxis of COVID-19 infection.   On 07 Jan 2021, the patient was vaccinated with a product that was outside of the 6-hour window from when the vial was punctured. The patient also experienced normal flu-like symptoms and arm soreness.    No treatment information was provided.  Action taken with mRNA-1273 in response to the events was not reported.   The outcome of the event product storage error was considered recovered/resolved on 07 Jan 2021.  The outcome of the events flu-like symptoms and pain in arm was unknown.  The reporter did not provide an assessment for the events product storage error, flu-like symptoms, and pain in arm..; Reporter's Comments: This case concerns a patient, who experienced non-serious unexpected events of out of specification product use, influenza like illness and pain in extremity. There were no reported AEs associated with this case of out of specification product use. The event of, influenza like illness and pain in extremity occurred on an unspecified date after mRNA-1273 (lot # unknown) administration. The treatment details were not provided. Very limited information regarding this event has been provided at this time.  Based on temporal association between the use of the product and the start date of the events, a causal relationship cannot be excluded.%"
                AND vaers_id != 946854;
    #8 duplicates removed
DELETE FROM covid WHERE symptom_text LIKE "%Administered vials that were exposed to room temperature for more than 12 hours; A spontaneous report was received from an employee and a physician concerning a patient, who received Moderna's COVID-19 vaccine (mRNA-1273) and was administered with product that was exposed to room temperature for more than twelve hours.   The patient's medical history was not provided. No relevant concomitant medications were reported.   On 04 Jan 2021, a freezer containing a vial of mRNA-1273 failed.  At 1:11 A.M. the vial experienced a temperature excursion, exceeding 8 degrees Celsius. Over time the dose thawed and reached room temperature.  On 04 Jan 2021, the patient received their first of two planned doses of mRNA-1273 intramuscularly for prophylaxis of COVID-19 infection and was administered with product that was exposed to room temperature for more than twelve hours.  No treatment information was provided.  Action taken with mRNA-1273 in response to the event was not reported.   The event, administered with product that was exposed to room  temperature for more than twelve hours, was resolved on 04 Jan 2021.; Reporter's Comments: This case concerns a patient of unknown gender and age who received their first of two planned doses of mRNA-1273 (Lot unknown), reporting Product that was exposed to room temperature for more than twelve hours without any associated adverse events.%"
                AND vaers_id != 974597;
    #769 duplicates removed
DELETE FROM covid WHERE vaers_id = 927464;
    #1 duplicate removed
DELETE FROM covid WHERE symptom_text LIKE "%A spontaneous report was received from a pharmacist concerning a patient who received Moderna's COVID-19 vaccine (mRNA-1273) that was stored at -20 degrees F, so outside of the temperature range. The patient's medical history was not provided. No relevant concomitant medications were reported. On an unknown date, the patient received their first of two planned doses of mRNA-1273 intramuscularly for prophylaxis of COVID-19 infection. The reporter stated the COVID-19 vaccine was stored at -20 degrees Fahrenheit; outside of the recommended temperature range. No treatment information was provided. Action taken with mRNA-1273 in response to the event was not reported. The event, vaccine that was stored at -20 degrees F so outside of the temperature range, was considered resolved.; Reporter's Comments: This case concerns a patient who received their first of two planned doses of mRNA-1273 (Lot unknown), reporting Product storage error without any associated adverse events.%"
                AND vaers_id != 945889;
    #3 duplicates removed
DELETE FROM covid WHERE vaers_id = 951954 and vaers_id = 951953;
    # 2 duplicates removed
DELETE FROM covid WHERE symptom_text LIKE "%Patient given 0.25ml instead of 0.5ml; A spontaneous report was received from a physician concerning a patient of unknown age and gender, who received Moderna's COVID-19 vaccine (mRNA-1273) was given 0.25ml instead of 0.5ml.   There were no medical history and concomitant medications reported.  On 16 Jan 2021, the patient received their first of two planned doses of mRNA-1273 intramuscularly for prophylaxis of COVID-19 infection.   On 16 Jan 2021, the patient was vaccinated with 0.25ml instead of 0.5ml.  No treatment information was provided.  Action taken with mRNA-1273 in response to the event was not reported.   The event,%"
                AND vaers_id != 980991;
    #12 duplicates removed
DELETE FROM covid WHERE symptom_text LIKE "%On 22 Dec 2020, the nurse reported a shipment was received. The vial arrived frozen and was placed in a freezer at recommended temperature.   On 02 Jan 2021, the freezer had failed, and the temperature alarm system did not alert anyone. It was noted that the freezer temperature at 5:50 AM was -5 degrees Celsius (C), at 7:50 AM the freezer was a 1.5 C. It remained between from 9.7 C at 12:51 PM then went to 8.3 C at 1:51 PM then down to -8.7 C at 2:51 PM.  On 03 Jan 2021 8:45 PM, the freezer returned to its normal temperature of -20.9 C, -1 C then went to 5.5 C at 11:56 PM.  On 04 Jan 2021, the temperature climbed to 19.4 C. On the same day, the patient received their first of two planned doses of mRNA-1273 (Lot number: 025J20-2A, 025L20A, or 027L20A) intramuscularly for prophylaxis of COVID-19 infection and experienced vaccination with vial that might have had a temperature excursion  No treatment information was provided.  Action taken with mRNA-1273 in response to the event was not reported.   The outcome of the event, vaccinated with vial that might have had a temperature excursion, was considered resolved on 04 Jan 2021.; Reporter's Comments: This report refers to a case of out of specification product use, product temperature excursion issue, and product storage error for mRNA-1273. There were no reported AEs associated w%"
                AND vaers_id != 960825;
    #131 duplicates removed
DELETE FROM covid WHERE symptom_text LIKE "%Administered vials that were exposed to room temperature for more than 12 hours; A spontaneous report  was received from an employee and a physician concerning a patient, who received Moderna's COVID-19 vaccine (mRNA-1273) and was administered with product that was exposed to room temperature for more than twelve hours.   The patient's medical history was not provided. No relevant concomitant medications were reported.   On 04 Jan 2021, a freezer containing a vial of mRNA-1273 failed.  At 1:11 A.M. the vial experienced a temperature excursion, exceeding 8 degrees Celsius. Over time the dose thawed and reached room temperature.  On 04 Jan 2021, the patient received their first of two planned doses of mRNA-1273 intramuscularly for prophylaxis of COVID-19 infection and was administered with product that was exposed to room temperature for more than twelve hours.  No treatment information was provided.  Action taken with mRNA-1273 in response to the event was not reported.   The event, administered with product that was exposed to room  temperature for more than twelve hours, was resolved on 04 Jan 2021.; Reporter's Comments: This case concerns a patient of unknown gender and age who received their first of two planned doses of mRNA-1273 (Lot unknown), reporting Product that was exposed to room temperature for more than twelve hours without any associated adverse events.%"
                AND vaers_id != 976569;
    #43 duplicates were removed
DELETE FROM covid WHERE symptom_text LIKE "% unknown age, who received COVID-19 Vaccine and some vaccine leaked out of syringe on patient's arm. The patient's medical history was not provided. No relevant concomitant medications were reported.  On 04 Feb 2021, the patient received their first of two planned doses (Batch number not provided) intramuscularly in the arm for prophylaxis of COVID-19 infection. On 04 Feb 2021, the nurse reported that while administering the COVID vaccine some of the vaccine leaked out of the syringe on the patient's arm. Treatment information was not provided. Action taken with second dose response to the event was not provided. The event was considered resolved on 04 Feb 2021; Reporter's Comments: This report refers to a case of Incorrect dose administered  with no associated AEs.%"
                AND vaers_id != 1032585;
    #1 duplicate removed
```

9,240 rows still contain duplicate symptom descriptions. While this query will result in some valid multi-person reports that were processed in batch by healthcare workers, it will be much more efficient while affecting only about 1% of the data base:

```sql
DELETE FROM covid WHERE vaers_id IN (
    SELECT vaers_id
    FROM covid
    GROUP BY symptom_text
    HAVING count(*) >= 2);
    #9,240 rows deleted
```

903,061 rows remain after cleaning duplicates, approximately 91% of the original dataset. 

### Branch the DB again, then prepare import to RStudio.

```bash
# to commit the changes made in SQLiteStudio
git add --all
git commit -m "cleaned in SQLiteStudio"
# add a new brach for working in RStudio
git branch forR
git checkout forR
```

The following queries are used to set proper boolean values and unknown or missing values for compatibility when importing to R. The true NULL values will be handled in R.

```sql
UPDATE covid SET died = (CASE WHEN died = "Y" THEN "TRUE"
                            WHEN died = "" THEN "FALSE" END);

UPDATE covid SET l_threat = (CASE WHEN l_threat = "Y" THEN "TRUE"
                            WHEN l_threat = "" THEN "FALSE" END);

UPDATE covid SET er_visit = (CASE WHEN er_visit = "Y" THEN "TRUE"
                            WHEN er_visit = "" THEN "FALSE"
                            END);

UPDATE covid SET hospital = (CASE WHEN hospital = "Y" THEN "TRUE"
                            WHEN hospital = "" THEN "FALSE"
                            END);

UPDATE recovd SET revovd = (CASE WHEN recovd = "Y" THEN "TRUE"
                            WHEN recovd = "N" THEN "FALSE"
                            END);


UPDATE covid SET birth_defect = (CASE WHEN birth_defect = "Y" THEN "TRUE"
                            WHEN birth_defect = "" THEN "FALSE"
                            END);
```

### 

### Import dataset into R, set proper data types, and Convert dates to ISO.

```r
library(DBI)
library(RSQLite)
library(tidyverse)
library(lubridate)
library(janitor)

#connect to the database and add the raw data
con <- dbConnect(SQLite(), dbname="VaersReproduction.db")
query <- dbSendQuery(con, "SELECT * FROM covid")
df_raw <- dbFetch(query, n = -1)
dbClearResult(query)

# Create index of logical values according to whether they match na_strings,
# then use index to set NAs.
na_strings <- c("", " ", "U", "UNK", "unknown", "Unknown",
                "UNKNOWN", "N/A")
idx <- Reduce("|", lapply(na_strings, "==", df_raw))
is.na(df_raw) <- idx

#set logical data types of df
df_lg <- df_raw %>% mutate_at(c('l_threat', 'er_visit', 'hospital', 'disable',
                                'recovd'), as.logical)

#convert the dates to ISO and clean up a bunch of memory.
df <- df_lg %>% mutate_at(c('datedied', 'vax_date', 'onset_date',
                            'todays_date'), mdy)
rm(con,df_lg,idx,query,na_strings,df_raw)
```

### Cleaning obvious entry errors and out-of-scope values in date columns.

The first Emergency use Authorization of COVID-19 Vaccinations was issued on 2020-12-11 [(source)](https://www.fda.gov/news-events/press-announcements/fda-approves-first-covid-19-vaccine). Dates before this will be considered an entry error, or possibly research trials which are out of scope. These 3,638 reports are removed:

**Note:** **First human trials began 2020-04-12 [(source)](https://www.nature.com/articles/s41541-020-0188-3). 1,745 reports contain vaccination dates before this date.**

```r
# number of COVID-19 reports before first human trials began.
df %>% count(vax_date < '2020-04-12')
# Making executive decision to clean dates before first EUA for Covid-19 Vax.
del1 <- df %>% filter(vax_date<'2020-12-11') %>% select(vaers_id)
df <- rows_delete(df, del1)
# Doing same for report and symptom onset date.
del2 <- df %>% filter(todays_date<'2020-12-11') %>% select(vaers_id)
df <- rows_delete(df, del2)
del3 <- df %>% filter(onset_date<'2020-12-11') %>% select(vaers_id, onset_date)
df <- rows_delete(df, del3)
rm(del1,del2,del3)
```

### Categorizing Missing and Outlying Values

##### Illogical Order of reported Dates

After removing obvious errors, 17,208 reports remain wherein either the date of report is before symptom onset, or symptom onset is before date of vaccination (approximately 2% after cleaning entry errors).

```r
#return rows where date of report is before onset of symptoms, 
# or symptom onset is before date of vaccination.
bad_dates <- df %>% filter(vax_date>onset_date | onset_date>todays_date) %>% 
  select(vaers_id, todays_date, vax_date, onset_date, numdays, 
         age_yrs, sex, state)
View(bad_dates)
# 17,208 reports with illogical order of dates (about 2%).
```

##### Ages

Ages below 6 months (0.5 years), or 2.5 times the standard deviation above the mean (105 years old) are considered outliers. The table created below contains 84,267 reports with outlying or missing reporter ages:

```r
#return rows where age is below 0.5 years, above 2.5X standard deviation 
# from mean, or missing.
age_sd <- sd(df$age_yrs)
age_mean <- mean(df$age_yrs)

bad_age <- df %>% filter(age_yrs<0.5 | age_yrs>(2.5*age_sd)+age_mean | is.na(age_yrs)) %>% 
  select(vaers_id, todays_date, vax_date, onset_date, numdays, 
         age_yrs, sex, state)
# 84,267 rows
```

##### Sex

The following table hold all reports that are missing information on the sex of the reporter (35,266 reports):

```r
#return rows with no sex.
no_sex <- df %>% filter(is.na(sex)) %>% 
  select(vaers_id, todays_date, vax_date, onset_date, numdays, 
          age_yrs, sex, state)
# 35,266 rows
```

##### Vaccination to Symptom Onset Interval

The numdays column is calculated within the VAERS system by subtracting the date of vaccination from the date of symptom onset, expressed in a number of days. Due to this, if either of these date values are missing, the interval value will be blank. The following table is created to hold all reports where the numdays values are blank or 2.5 times the standard deviation above the mean (considered outliers). 37,615 reports meet this criteria:

```r
# return rows where interval from vaccination to symptom onset is above
# 2.5X standard deviation from the mean, or missing.
inter_mean <- mean(df$numdays)
inter_sd <- sd(df$numdays)
bad_inter <- df %>% filter(numdays>(2.5*inter_sd)+inter_mean | is.na(inter_mean)) %>% 
  select(vaers_id, todays_date, vax_date, onset_date, numdays, 
         age_yrs, sex, state)
# 37,615 rows
```

##### State

Aside from missing vaccine lot number, this is category holds the largest amount of missing values. 138,265 reports are missing the state of origin.

```r
# return rows missing state
no_state <- df %>% filter(is.na(state)) %>% 
  select(vaers_id, todays_date, vax_date, onset_date, numdays, 
         age_yrs, sex, state)
# 138,265 reports
```

##### Missing Vaccine Lot Number

The lot number of the vaccine that the patient received is vital to informing public safety and effective vaccine R&D, however over 30% (280,844 reports) of the cleaned post COVID-VAX dateset is missing this information.

```r
# return rows missing Vaccine lot number
no_lot <- df %>% filter(is.na(vax_lot)) %>% 
  select(vaers_id, todays_date, vax_date, onset_date, numdays, 
         age_yrs, sex, state)
#280,844

# get number of reports missing state and lot.
no_state_lot <- bind_rows(no_state, no_lot) %>% group_by(vaers_id)
```

##### Demographically complete & non-outlying reports:

Due to the drastic number of reports missing Vaccine Lot Number, this metric should be evaluated separately and is not considered in the following table, which holds only reports that have complete and non-outlying information for age, dates, vax-onset interval, sex, and state. 671,595 reports meet this criteria (just under 75% of the cleaned COVID dataset).

```r
# get the complete, logical, non-outlying reports minus missing lot numbers
good_ids <- df %>% select(vaers_id, todays_date) %>% 
  anti_join(bad_age, by = "vaers_id") %>%
  anti_join(bad_dates, by = "vaers_id") %>%
  anti_join(bad_inter, by = "vaers_id") %>%
  anti_join(no_sex, by = "vaers_id") %>%
  anti_join(no_state, by = "vaers_id")
```

### Time-Series graph of completeness & outliers/missing values

##### Make a summary of monthly category counts

A 'category' columns is added to each table, and they are joined together again to create a monthly summary of the number of complete reports and missing/outlying values from each category:

```r
# combine the missing/outlying report tables and make time series graphs
bad_age$category <- "age"
bad_dates$category <- "dates"
bad_inter$category <- "interval"
no_sex$category <- "sex"
no_state$category <- "state"
good_ids$category <- "complete reports"
categories <- bind_rows(bad_age, bad_dates, bad_inter, 
                                      no_sex, no_state, good_ids)

# summarize the categories by monthly count.

monthly_cat <- categories %>% 
  group_by(month = floor_date(todays_date, "month"), category) %>% 
  summarise(count = n())
```

###### Plot the data

In the following line chart, the monthly number of complete & non-outlying reports is shown alongside the number of missing or outlying values from all reports. It is important to note that there may be than one missing value in each report. Complete reports is included to give context to the other categories. Each category, including complete reports trends together with the total number of reports, however, from November 2021 to February 2022, the number of complete reports falls while the other categories remain relatively constant or rise. This is also the time-frame in which a significant number of outlying intervals between vaccination and symptom onset are first reported.

```r
# set vars and vectors for scales and plot.
start_month <- as.Date("2021-01-01")
end_month <- as.Date("2022-12-31")
x_lim1 <- c(start_month, end_month)

two_month_seq <- seq(start_month, end_month, by = "2 months")
month_labels <- format(two_month_seq, "%b '%y")

# make a consistent color palette for multiple charts
palette1 <- c("black","#530143","#61D04F","#020189","#28E2E5","#CD0BBC","#fd4e03","#F5C710", "gray62")
names(palette1) <- c("complete reports","state","dates","sex","interval","vaccine lot","age")

ggplot(data = monthly_cat) + geom_line(aes(x = month, y = count, color = category)) +
  scale_x_date(breaks = two_month_seq,
               labels = month_labels,
               limits = x_lim1) +
  scale_y_continuous(breaks = seq(0,100000, by = 10000)) +
  scale_color_manual(values = palette1)
  labs(title = "Number of Missing & Outlying Values vs Complete Reports Over Time",
       subtitle = "(More than One Missing Value per Report Possible)",
       caption = "CDC VAERS Archives 2021 - 2022",
       x = "Month of Report",
       y = "Number of Values (Complete Reports)")
```

There are two large spikes in total reporting, March to April and  August of 2021. The latter of these spikes saw a significant increase incomplete/outlying demographic information. This could be due to one or both of the following factors: a decrease in reporting quality from healthcare providers (likely due to under-staffing issues), and/or an increase public-sentiment driven reports as news reporting on vaccine safety increased.

### Total Number of Missing & Outlying Values by Category

There are by far more reports that do not contain the vaccine lot number than any other category (over twice as many missing values than the next largest category). It is surprising that this is the case, since the vaccine lot number is specified on the individual's proof of vaccination card. The ability to correlate an increase in adverse events to a specific vaccine lot or manufacturing batch is essential to the usefulness of VAERS in informing quality control and further research for vaccine manufacturers. In the unlikely event that the reporting individual no longer has access to their vaccine's lot number, this information can be informed from the records of the facility where the vaccination was received.

- Together, missing vaccine lot numbers and state of origin comprise over 70% of missing values in the dataset.
  
  - As a number of unique reports which are missing one of or both of these values, this is 419,109 (over 46% of the entire dataset after cleaning).

```r
#plot total number of missing values per category, including lot number
no_lot$category <- "vaccine lot"
ms_out_categories <- bind_rows(bad_age, bad_dates, bad_inter, 
                               no_sex, no_state, no_lot) %>% 
  group_by(category) %>% summarise(count = n()) %>% arrange(desc(count))

ggplot(data = ms_out_categories) + 
  geom_col(aes(x = factor(category, levels = category), y = count, fill = category,)) +
  scale_fill_manual(values = palette1) +
  geom_text(aes(label = count, x = category, y = 1.1*count, 
                fontface = 'bold')) +
  scale_y_continuous(breaks = seq(0,300001, by = 50000)) +
  labs(title = "Total Number of Missing and Outlying Values",
       subtitle = "Including Missing Vaccine Lot Numbers",
       caption = "CDC VAERS Archives 2021 - 2022",
       x = "Category (Missing/Outlying Value)",
       y = "Count of Missing/Outlying Values")
```

### Missing/Outlying Values vs Length of Symptom Descriptions

The inclusion of non-UTF8 characters in the free-text symptom description data prevents this information from being converted to a character length without altering it first. OpenAI GPT 3.5 was used to create a custom function that scrubs all non-UTF8 characters from the free-text fields before summarizing them by category according the length in characters.

```r
#function to clean freetext of non utf8 characters
#WRITTEN BY OPENAI GPT 3.5
  # Define a function to remove non-UTF-8 characters
remove_non_utf8 <- function(text) {
  # Define the UTF-8 range using regular expressions
  utf8_range <- "[\\x01-\\x7F]|[\\xC2-\\xDF][\\x80-\\xBF]|\\xE0[\\xA0-\\xBF][\\x80-\\xBF]|[\\xE1-\\xEC\\xEE\\xEF][\\x80-\\xBF]{2}|\\xED[\\x80-\\x9F][\\x80-\\xBF]|\\xF0[\\x90-\\xBF][\\x80-\\xBF]{2}|[\\xF1-\\xF3][\\x80-\\xBF]{3}|\\xF4[\\x80-\\x8F][\\x80-\\xBF]{2}"
  # Remove non-UTF-8 characters using regular expression
  clean_text <- stri_replace_all_regex(text, pattern = sprintf("[^%s]+", utf8_range), replacement = "")
  return(clean_text)
}
# END GPT WRITTEN CODE (and thank you OpenAI, that was real pain)
```

It is common for the symptom text field to be concatenated between initial patient self-descriptions,  healthcare provider notes and accounts, vaccine manufacture comments, and information from follow-up correspondence with VAERS officials. More often than not, this field does not explicitly delineate between the multiple sources of statements within the same field. Furthermore, they are often repetitive due to an automated scripted restatement of the initial report.

It is still surprising to see, however, that the 'complete reports' category (reports which have all non-outlying demographic information and vaccine lot numbers present), has the lowest average character count and the highest number of reports with no symptom description. This is likely due to a large representation of reports filed by healthcare facilities within this category. Since the dataset contains fields for MedDRA terminology of symptom descriptions, this is likely the preferred method of recording this information. MedDRA is a proprietary medical terminology encoding system and is not within the immediate scope of this project. However, further analysis on the number of recorded MedDRA terms by complete and missing/outlying attribute categories could be implemented in a future phase of the analysis.

This jittered strip plot shows that the highest density of symptom description lengths is approximately 6,000 to 7,000 characters and below for most categories, with number reports missing sex quickly dissipating at around 5,000 characters. Additionally, there are similar clusters of outliers in the 28,000 range between missing state and vaccine lot numbers, the two largest categories of missing values.

```r
# jittered strip plot of length of freetext (y) and missing/outlying values or complete report
# make a table of all reports with id, category, lenth of text
bad_dates_len <- df %>% filter(vax_date>onset_date | onset_date>todays_date) %>% 
  group_by(vaers_id) %>% 
  summarise(length = stri_length(remove_non_utf8(symptom_text)))
bad_dates_len$category <- "dates"

bad_age_len <- df %>% filter(age_yrs<0.5 | age_yrs>(2.5*age_sd)+age_mean | is.na(age_yrs)) %>% 
  group_by(vaers_id) %>% 
  summarise(length = stri_length(remove_non_utf8(symptom_text)))
bad_age_len$category <- "age"

no_sex_len <- df %>% filter(is.na(sex)) %>% 
  group_by(vaers_id) %>% 
  summarise(length = stri_length(remove_non_utf8(symptom_text)))
no_sex_len$category <- "sex"

bad_inter_len <- df %>% filter(numdays>(2.5*inter_sd)+inter_mean | is.na(inter_mean)) %>% 
  group_by(vaers_id) %>% 
  summarise(length = stri_length(remove_non_utf8(symptom_text)))
bad_inter_len$category <- "interval"

no_state_len <- df %>% filter(is.na(state)) %>% 
  group_by(vaers_id) %>% 
  summarise(length = stri_length(remove_non_utf8(symptom_text)))
no_state_len$category <- "state"

no_lot_len <- df %>% filter(is.na(vax_lot)) %>% 
  group_by(vaers_id) %>% 
  summarise(length = stri_length(remove_non_utf8(symptom_text)))
no_lot_len$category <- "vaccine lot"

complete_len <- df %>% select(vaers_id, symptom_text) %>% 
  anti_join(bad_age_len, by = "vaers_id") %>%
  anti_join(bad_dates_len, by = "vaers_id") %>%
  anti_join(bad_inter_len, by = "vaers_id") %>%
  anti_join(no_sex_len, by = "vaers_id") %>%
  anti_join(no_state_len, by = "vaers_id") %>% 
  anti_join(no_lot_len, by = "vaers_id") %>% 
  group_by(vaers_id) %>% 
  summarise(length = stri_length(remove_non_utf8(symptom_text)))
complete_len$category <- "complete reports"

len_categories <- bind_rows(bad_dates_len,bad_age_len,no_sex_len,bad_inter_len,
                            no_state_len, no_lot_len,complete_len)
#clean up
rm(bad_dates_len,bad_age_len,no_sex_len,bad_inter_len,
   no_state_len, no_lot_len,complete_len)

#average text length per category
len_summ <- len_categories %>% drop_na() %>% group_by(category) %>% 
  reframe(count = n(), total = sum(length)) %>% reframe(category = category, average = total/count)

#count with no text per category
notext_summ <- len_categories %>% filter(length <= 5) %>% group_by(category) %>% 
  reframe(count = n())

# count of reports in each category
rpt_category <- len_categories %>% group_by(vaers_id) %>%
  reframe(category = category, reports = n())
rpt_category_counts <- rpt_category %>% group_by(category) %>% 
  summarise(total = n())
rm(rpt_category)

# This plot has to make over 1 million individual points, but its worth the wait
ggplot(data = len_categories)+ 
  geom_jitter(aes(x = category, y = length, color = category))+
  geom_text(data = len_summ, aes(label = round(average), x = category, y = 27000, 
                                 fontface = 'bold', color = category,),
            show.legend = FALSE) +
  annotate(geom = "text", y = 28000, x = 4, label = "Averages:", fontface = 'bold') +
  scale_color_manual(values = palette1) +
  geom_text(data = notext_summ, aes(label = count, x = category, y = -1500,
                                    fontface = "italic", color = category),
            show.legend = FALSE)+
  annotate(geom = "text", y = -500, x = 4, label = "Reports with No Symptom Description:",
           fontface = "italic") +
  scale_y_continuous(breaks = seq(0,30000, by = 5000)) +
  labs(title = "Length of Free-Text Symptom Descriptions + Follow-Up Notes by Category",
       subtitle = "(Including Complete Reports)",
       caption = "CDC VAERS Archives 2021 - 2022",
       x = "Category (Missing/Outlying Value)",
       y = "Length of Free Text Symptom Description + Notes")
```

# Presentation Outline

### Introduction - 3 Minutes

- **Who are you?**
  
  - I am Jared White, an entry-level data analysts with a background in statistics, LLM Q&A Annotation, and technical writing.

- **What are you talking about?**
  
  - VAERS is the Vaccine Adverse Event Reporting System. It is a passive, anonymous, and public-facing reporting system developed and maintained by the CDC for people who experience adverse events or symptoms following vaccination.
    
    - Private citizens are not required to report to VAERS, but many healthcare providers are.
    
    - Anyone can easily file a VAERS report online. It is a federal crime to knowingly file a false VAERS report.
    
    - The public VAERS archives are completely anonymized, but otherwise uncleaned.
    
    - Any given VAERS report cannot prove a causal link between an adverse event and a vaccine or manufacturer, but trends in reporting can show correlations between a vaccine and an increase in adverse events.

- **Why do I care?**
  
  - This presentation will Identify the gap between the current and ideal states of VAERS' ability to provide important and accurate information to public safety and vaccine R&D initiatives during pandemics and times of heightened public awareness. 
  
  - By identifying correlations with incomplete and outlying reports, actionable recommendations are made to improve the usefulness of VAERS to the public and to vaccine manufacturers.

### Purpose, Basics, & Cleaning Procedures - 5 Minutes

- **Why does it matter?**
  
  - Accurate and complete records of post vaccination adverse events and symptoms are essential for informing public safety and vaccine R&D.
    
    - From 2020 to 2021, the number of post-vaccination adverse event reports increased by over 400%.
    
    - Approximately 92% of all VAERS reports made during 2021 & 2022 were filed after the subject received a COVID-19 vaccination.

- **What is the key information in the data?**
  
  - **Dates:** Vaccination, symptom onset, and report filing, as well as interval between vaccination and symptom onset.
    
    - 54,823 Reports with missing / Outlying Information.
  
  - **Demographic & Geographic:** subject age, sex, and state of residence
    
    - 226,058 Reports with missing / outlying values.
  
  - **Lot Number** of the vaccine the subject received.
    
    - 280844 Reports with missing / outlying values.
  
  - **Symptom Description:** These are free-text fields describing the event, the length of which is analyzed in correlation to other factors. These are highly unstructured and concatenated between self-experience descriptions, healthcare provider comments, vaccine manufacture comments, and follow-up notes from subsequent processing and contacts by VAERS employees.

- **How did you verify the data?**
  
  - This analysis focuses solely on COVID-19 vax related reports.
  
  - 10,830 duplicates, and 3,638 obvious entry errors (dates before first EUA) were removed.
  
  - After cleaning, 899,423 post COVID-19 Vaccination reports were analyzed.
    
    - Approximately 56% of these reports contain no outlying or missing key pieces of information.

### Chart 1: Time Series - 4 Minutes

##### PAUSE FOR 5 SECONDS

- **What am I looking at?**
  
  - This is a time-series chart that shows the monthly number of missing values as well as complete reports.
  
  - Due to the drastically large number of reports missing the vaccine lot number, this category is not included in this time series, and these missing values are included in the 'complete reports' category.
  
  - It's important to note that the colored lines represent counts of individual missing or outlying values, and the black line, for complete reports, represents a total number of reports.
    
    - There can be more than one missing value per report.
    
    - The complete reports line is used to give context to the overall trend of reporting.

- **What should I be noticing?**
  
  - The first spike of reports (April of '21) show a much lower number of incomplete and outlying information than the second spike (July of '21)
    
    - The second spike also coincides with the first noticeable number of illogical date time time-lines and outlying intervals between vaccination and first experience of adverse symptoms.
    
    - This second spike could suggest a negative correlation between report quality and public sentiment.
  
  - Following the second spike, the number of complete and accurate reports decreases more quickly than the missing & outlying values.

### Chart 2: Totals of Missing & Outlying Values - 4 Minutes

##### PAUSE FOR 5 SECONDS

- **What am I looking at?**
  
  - These columns display the proportion of missing & outlying values between the categories.
  
  - The completeness of the dataset changes drastically once Vaccine Lot Number is taken into account.

- **What should I be noticing?**
  
  - The number of reports missing Lot Number is twice that of the next largest category.
  
  - The ability to link an increase in adverse events to a specific vaccine lot or manufacturing batch is essential to informing quality control and further research for vaccine manufacturers.
    
    - The two two key pieces of information in identifying whether a specific vaccine batch may have quality control issues (lot number and state) account for approximately 70% of the missing or outlying information.
    
    - The vaccine lot number is specified on the individual's proof of vaccination card.
    
    - This information can also be informed from the records of the facility where the vaccination was received.
  
  - Age of the reported, the next most medically significant piece of information, is the third largest category of outlying and missing information.

### Chart 3: Symptom Description Length - 4 Minutes

##### PAUSE FOR 5 SECONDS

- **What is that?**
  
  - This chart plots the character length of each reports' free-text symptom descriptions with its category of incomplete or outlying information.
  
  - Each point represents either one missing value or one complete report, and that point's height shows how long the symptom description field is for that report. 
  
  - As with the other charts, there may be more than one missing value per report, and that will result in a point in each of the corresponding categories, except for the category of each report.

- **Its pretty, but what does it mean?**
  
  - The vast majority of all reports fall underneath the 5,000 character range.
    
    - Reports missing the sex of the reporter are much less likely to contain a symptom description greater than 5,000 characters.
  
  - Interestingly, otherwise complete and non-outlying reports contain the shortest average symptom descriptions, and have drastically more reports with no description than all other categories.
    
    - This could be due to the presence of separate fields for symptom information in MedDRA terms. This is used by healthcare providers to quickly and concisely record medical descriptions in a proprietary linguistic encoding system.
    
    - This could suggest that healthcare facilities are more likely to provide complete and accurate reports than individuals.
  
  - The symptom description field is also concatenated between multiple sources of information, is highly unstructured, and not clearly delineated. It may also be repetitive due to automating processing.
    
    - As it may include additional notes from subsequent correspondence with the subject, this suggest minimal effectiveness of these follow-up notes in addressing key pieces of outlying and missing information.
  
  - A distinct cluster of outliers forms at the 27,000 to 30,000 character range. This could be a starting point for further investigation into effectiveness of automated text processing on the symptom descriptions.

### Recommendations & Direction for Investigation - 5 Minutes

**Immediate Improvements:**

1. Incorporate a simple 'Report Made By' field, wherein the source of the report is either selected or generated. This will clearly delineate reports filed online by individuals, by qualified healthcare officials, or other sources implemented as needed.

2. Develop standardized procedures for follow-ups with subjects or healthcare providers to inform/confirm missing & possibly incorrect values. Separate the notes from these follow-ups from the initial symptom descriptions. This will make the database more usefully structured and easily searchable. If new information on a report is gained, add it to the appropriate field.

3. Develop an API system integrated with healthcare facility records to automatically inform key pieces of information such as vaccine lot number. This can be done securely with pre-anonymized information. This will drastically cut the amount of missing key information needed to inform the public and manufacturers on vaccine safety.

4. Develop fall-back quality assurance protocols to be implemented during times of peak reporting to maintain report quality and completeness. This includes commonsense checks on dates and numeric values and required key information fields.

**Further Investigation (Next Steps of the Project):**

1. Develop quantitative data on the density of COVID-19 Vaccine subject reporting in the news cycles during the later phase of the pandemic. Analyze this alongside time-series of incomplete & outlying reports to further inform correlations.

2. Build and train a NLP model to process free-text symptom description fields to further inform the reliability of any given report.

### Please see analysis presentation on GitHub.

# Property of Jared White

### You may use and/or disseminate any portion of this project, but you must clearly state credit to the original contributor(s).
