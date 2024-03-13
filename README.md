# VAERS 2021 & 2022 Gap Analysis
Author: Jared White  CC-BY-4.0
Last Updated: March 3rd, 2024

### Focus and Scope
- Determine the current state of completeness and reliability of the VAERS database during the COVID-19 Pandemic.
- Analyze possible correlations of missing and outlying reports with other attributes in the dataset:
    -  Geographic & Demographic Information.
    -  Length & desnity of medical terminology within free-text symptom descriptions.
- Determine whether incomplete & unreliable reports strongly correlate with increased news reporting on mRNA & COVID Vaccines.
- If analysis shows the need, use the insights gained to develop criteria for a reporting system that is more robust and reliable during times of heightened public awareness.

## Please Understand the Data, its Nature, and Limitations Before Coming to Any Conclusions Based on This Project!
#### Understand what VAERS is:
[https://vaers.hhs.gov/about.html](https://vaers.hhs.gov/about.html)
#### Understand the Proper Way to Interpret the Data:
[https://vaers.hhs.gov/data/dataguide.html](https://vaers.hhs.gov/data/dataguide.html)
#### Read the Project Documentation and CDC Data Use Guide included in this project. The main points are:
- The VAERS dataset is not comprehensive. Underreporting is a core limitation of all passive reporting systems.
- It is not verifiable or reliable. Due to restrictions on personal health information, the public dataset is completely anonymized.
- **Correlation does not equal Causation:** Nothing in the dataset or this project can prove any link between adverse reations or symptoms and a vaccine or its manufacturer.
#### The original archived dataset can be found at:
[https://vaers.hhs.gov/data/datasets.html](https://vaers.hhs.gov/data/datasets.html)
#### The current version of the Data Use Guide is here:
[https://vaers.hhs.gov/docs/VAERSDataUseGuide_en_September2021.pdf](https://vaers.hhs.gov/docs/VAERSDataUseGuide_en_September2021.pdf)
- The Data Use Guides and other CDC Resources are also included in this project.

### For initial exploratory analysis and current progress, please see the Roadmap presentation and Documentation.

### Community Feedback and Contribution is Welcome!
- Particularly with the newscycle analysis portion of the project. If you're interested and have experience building webscrapers, please message me.
- Also, insight from experts in healthcare and vaccine development is extremely valuable!

### Some SQL Snippets From the Documentation Used to Create the Visuals in the Roadmap
Get the number of reports with missing key values:

```sql
SELECT COUNT(*) FROM (
    SELECT vaers_id, state, age_yrs, sex, numdays FROM data 
        WHERE sex = "U"
        OR state = ""
        OR age_yrs = ""
        OR numdays = "");
            #271,112
```

Create Bins for missing values and combinations thereof:

```sql
WITH categories AS (
    SELECT vaers_id AS id, 
    CASE WHEN
            sex = "U" AND state = "" AND age_yrs = "" AND numdays = "" THEN 'all'
        WHEN sex = "U" AND state = "" AND age_yrs = ""  AND numdays != "" THEN 'sex+state+age'
        WHEN sex = "U" AND state = "" AND age_yrs != "" AND numdays = "" THEN 'sex+state+days'
        WHEN sex = "U" AND state != "" AND age_yrs = "" AND numdays = "" THEN 'sex+age+days'
        WHEN sex = "U" AND state = "" AND age_yrs != "" AND numdays != "" THEN 'sex+state'
        WHEN sex = "U" AND state != "" AND age_yrs != "" AND numdays = "" THEN 'sex+days'
        WHEN sex = "U" AND state != "" AND age_yrs = "" AND numdays != ""  THEN 'sex+age'
        WHEN sex = "U" AND state != "" AND age_yrs != "" AND numdays != "" THEN 'sex'
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

Looking into interval between vaccination and symptom onset:

```sql
SELECT AVG(interval) FROM (
    SELECT vaers_id, numdays AS interval FROM data
        WHERE numdays != "");

SELECT vaers_id, numdays AS interval FROM data
    WHERE numdays != ""
    AND numdays > 180;
            # 41,984 rows loaded

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
