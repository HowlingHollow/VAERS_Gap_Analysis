library(DBI)
library(RSQLite)
library(tidyverse)
library(lubridate)
library(janitor)
library(scales)
library(stringr)
library(stringi)
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


# ==== BREAK - CLEANING BELOW ==== #


# Making executive decision to clean dates before first EUA for Covid-19 Vax.
del1 <- df %>% filter(vax_date<'2020-12-11') %>% select(vaers_id)
df <- rows_delete(df, del1)
# Doing same for report and symptom onset date.
del2 <- df %>% filter(todays_date<'2020-12-11') %>% select(vaers_id)
df <- rows_delete(df, del2)
del3 <- df %>% filter(onset_date<'2020-12-11') %>% select(vaers_id, onset_date)
df <- rows_delete(df, del3)
rm(del1,del2,del3)

############################################


#return rows where date of report is before onset of symptoms, 
# or symptom onset is before date of vaccination.
bad_dates <- df %>% filter(vax_date>onset_date | onset_date>todays_date) %>% 
  select(vaers_id, todays_date, vax_date, onset_date, numdays, 
         age_yrs, sex, state)
# 17,208 reports with illogical order of dates (about 2%).

#return rows where age is below 0.5 years, above 2.5X standard deviation 
# from mean, or missing.
age_sd <- sd(df$age_yrs)
age_mean <- mean(df$age_yrs)

bad_age <- df %>% filter(age_yrs<0.5 | age_yrs>(2.5*age_sd)+age_mean | is.na(age_yrs)) %>% 
  select(vaers_id, todays_date, vax_date, onset_date, numdays, 
         age_yrs, sex, state)
# 84,267 rows

#return rows with no sex.
no_sex <- df %>% filter(is.na(sex)) %>% 
  select(vaers_id, todays_date, vax_date, onset_date, numdays, 
          age_yrs, sex, state)
# 35,266 rows

# return rows where interval from vaccination to symptom onset is above
# 2.5X standard deviation from the mean, or missing.
inter_mean <- mean(df$numdays)
inter_sd <- sd(df$numdays)
bad_inter <- df %>% filter(numdays>(2.5*inter_sd)+inter_mean | is.na(inter_mean)) %>% 
  select(vaers_id, todays_date, vax_date, onset_date, numdays, 
         age_yrs, sex, state)
# 37,615 rows

# return rows missing state
no_state <- df %>% filter(is.na(state)) %>% 
  select(vaers_id, todays_date, vax_date, onset_date, numdays, 
         age_yrs, sex, state)
# 138,265 reports

# return rows missing Vaccine lot number
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

# set vars and vectors for scales and plot.
start_month <- as.Date("2021-01-01")
end_month <- as.Date("2022-12-31")
x_lim1 <- c(start_month, end_month)

two_month_seq <- seq(start_month, end_month, by = "2 months")
month_labels <- format(two_month_seq, "%b '%y")

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


#plot total number of missing values per category, including lot number
no_lot$category <- "vaccine lot"
ms_out_categories <- bind_rows(bad_age, bad_dates, bad_inter, 
                               no_sex, no_state, no_lot) %>% 
  group_by(category) %>% summarise(count = n()) %>% arrange(desc(count))

bad_rpt_counts <- bind_rows(bad_age, bad_dates, bad_inter, 
                            no_sex, no_state, no_lot) %>% 
  group_by(category) %>% summarise(count = n()) %>% 
  arrange(desc(count))

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
## ====^^CHART 2^^ ==== ##


# clean up.
rm(bad_age, bad_dates, bad_inter, 
   no_sex, no_state, good_ids, no_lot)

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
  
# organized jitter point plot of length of freetext (y) and missing/outlying values or complete report

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

# count of values in each category
rpt_category <- len_categories %>% group_by(vaers_id) %>%
  reframe(category = category)
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
