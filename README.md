# VAERS 2021 & 2022 Gap Analysis

Author: Jared White

Last Updated: March 3rd, 2024

Licensing: CC-BY-4.0 [Creative Commons Attribution](https://creativecommons.org/licenses/by/4.0/deed.en)

### Purpose and Scope
- Determine the current state of completeness and reliability of the VAERS database during the COVID-19 Pandemic.
- Analyze possible correlations of missing and outlying reports with other attributes in the dataset:
    -  Geographic & Demographic Information.
    -  Length & density of medical terminology within free-text symptom descriptions.
##### Extended Goals:
- Determine whether incomplete & unreliable reports strongly correlate with increased news reporting on mRNA & COVID Vaccines.
- If analysis shows the need, use the insights gained to develop criteria for a reporting system that is more robust and reliable during times of heightened public awareness.

### My Favorite Visualization Created with ggplot2
This jittered strip plot shows the relationship between the length of free-text symptom descriptions (in characters) and a categorization of missing / outlying values from each report. Check out the analysis phase 1 [presentation](https://github.com/HowlingHollow/VAERS_Gap_Analysis/blob/main/VAERS-GAP-ANALYSIS-PHASE1.pptx) for more!
![strip plot](https://github.com/HowlingHollow/VAERS_Gap_Analysis/blob/main/assets/chart3desclength.png)

## Please Understand the Data, its Nature, and Limitations Before Coming to Any Conclusions Based on This Project!
#### Understand what VAERS is:
[https://vaers.hhs.gov/about.html](https://vaers.hhs.gov/about.html)
#### Understand the Proper Way to Interpret the Data:
[https://vaers.hhs.gov/data/dataguide.html](https://vaers.hhs.gov/data/dataguide.html)
#### Read the Project [Documentation](https://github.com/HowlingHollow/VAERS_Gap_Analysis/blob/main/Documenation-Resources/DocumentationV03-02.md) and CDC Data Use Guide included in this project. The main points are:
- The VAERS dataset is not comprehensive. Underreporting is a core limitation of all passive reporting systems.
- It is not verifiable or reliable. Due to restrictions on personal health information, the public dataset is completely anonymized.
- **Correlation does not equal Causation:** Nothing in the dataset or this project can prove any link between adverse reations or symptoms and a vaccine or its manufacturer.
#### The original archived dataset can be found at:
[https://vaers.hhs.gov/data/datasets.html](https://vaers.hhs.gov/data/datasets.html)
#### The current version of the Data Use Guide is here:
[https://vaers.hhs.gov/docs/VAERSDataUseGuide_en_September2021.pdf](https://vaers.hhs.gov/docs/VAERSDataUseGuide_en_September2021.pdf)
- The Data Use Guides and other CDC Resources are also included in this project.

### Time Series of Categorized Reports
###### Complete Reports vs Missing Values, See Project [Documentation](https://github.com/HowlingHollow/VAERS_Gap_Analysis/blob/main/Documenation-Resources/DocumentationV03-02.md) and speaker notes in [presentation](https://github.com/HowlingHollow/VAERS_Gap_Analysis/blob/main/VAERS-GAP-ANALYSIS-PHASE1.pptx).
![Time Series](https://github.com/HowlingHollow/VAERS_Gap_Analysis/blob/main/assets/chart1-timeseries.png)
*Interval refers to number of days between vaccination and symptom onset. Missing lot numbers included in complete reports for this chart.

### Community Feedback and Contribution is Welcome!
- Particularly with the newscycle analysis portion of the project. If you're interested and have experience building webscrapers, please message me.
- Also, insight from experts in healthcare and vaccine development is extremely valuable!

### Snippets of code in R used to summarize, visualize, and calculate statistics
##### All of this and much more in [Vaers.r Script](https://github.com/HowlingHollow/VAERS_Gap_Analysis/blob/main/Vaers.r)
Use a logical index to efficiently set massive amounts of NAs inconsistently recorded within the dataset:
```r
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
Splitting the DF into subcategories of reports and manageable columns, then using anti-joins to get uncategorized reports:
```r
# lots of work above this in the documentation
no_lot <- df %>% filter(is.na(vax_lot)) %>% 
  select(vaers_id, todays_date, vax_date, onset_date, numdays, 
         age_yrs, sex, state)
#280,844

# get the complete, logical, non-outlying reports minus missing lot numbers
good_ids <- df %>% select(vaers_id, todays_date) %>% 
  anti_join(bad_age, by = "vaers_id") %>%
  anti_join(bad_dates, by = "vaers_id") %>%
  anti_join(bad_inter, by = "vaers_id") %>%
  anti_join(no_sex, by = "vaers_id") %>%
  anti_join(no_state, by = "vaers_id")
# 671,595 reports

# get number of reports missing state and lot.
no_state_lot <- bind_rows(no_state, no_lot) %>% group_by(vaers_id)

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

Creating beautifully color consistent plots:
```r
# make a consistent color palette for multiple charts
palette1 <- c("black","#530143","#61D04F","#020999","#28E2E5","#CD0BBC","#fd4e03","#F5C710", "gray62")
names(palette1) <- c("complete reports","state","dates","sex","interval","vaccine lot","age")

ggplot(data = monthly_cat) + geom_line(aes(x = month, y = count, color = category)) +
  scale_x_date(breaks = two_month_seq,
               labels = month_labels,
               limits = x_lim1) +
  scale_y_continuous(breaks = seq(0,100000, by = 10000)) +
  scale_color_manual(values = palette1) +
  labs(title = "Number of Missing & Outlying Values vs Complete Reports Over Time",
       subtitle = "(Lot Number Excluded, More than One Missing Value per Report Possible)",
       caption = "CDC VAERS Archives 2021 - 2022",
       x = "Month of Report",
       y = "Number of Values (Complete Reports)")
## ===== ^^CHART 1^^ ==== ##
```

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
