# Creates the simulated data of an imaginary state health insurance scheme,
# used in the chapters on PCA, k-means clustering and association rules.
# All names and numbers are made up. Run from the book folder:
#   Rscript tools/make_health_scheme_data.R
# Writes Data/ssy_hospitals.csv, Data/ssy_packages.csv and Data/ssy_claims.csv

suppressPackageStartupMessages(library(tidyverse))
set.seed(2024)

# ---- Package master ---------------------------------------------------------
packages <- tribble(
  ~package_code, ~package_name,                     ~specialty,          ~rate,  ~surgical, ~day_care, ~typical_los,
  "M01", "Acute febrile illness",                   "General Medicine",   9000,  FALSE, FALSE, 4,
  "M02", "Acute gastroenteritis",                   "General Medicine",   8000,  FALSE, FALSE, 3,
  "M03", "Pneumonia",                               "General Medicine",  15000,  FALSE, FALSE, 6,
  "M04", "Dengue fever",                            "General Medicine",  12000,  FALSE, FALSE, 5,
  "M05", "Diabetic ketoacidosis",                   "General Medicine",  20000,  FALSE, FALSE, 5,
  "S01", "Appendectomy",                            "General Surgery",   25000,  TRUE,  FALSE, 3,
  "S02", "Inguinal hernia repair",                  "General Surgery",   22000,  TRUE,  FALSE, 2,
  "S03", "Laparoscopic cholecystectomy",            "General Surgery",   35000,  TRUE,  FALSE, 3,
  "G01", "Hysterectomy",                            "Gynaecology",       30000,  TRUE,  FALSE, 4,
  "G02", "Caesarean delivery",                      "Obstetrics",        12000,  TRUE,  FALSE, 4,
  "G03", "Normal delivery",                         "Obstetrics",         6000,  FALSE, FALSE, 2,
  "O01", "Cataract surgery with lens",              "Ophthalmology",     10000,  TRUE,  TRUE,  0,
  "R01", "Total knee replacement",                  "Orthopaedics",      90000,  TRUE,  FALSE, 6,
  "R02", "Fracture fixation",                       "Orthopaedics",      30000,  TRUE,  FALSE, 4,
  "C01", "Coronary angioplasty",                    "Cardiology",       120000,  TRUE,  FALSE, 3,
  "A01", "ICU stay (add-on)",                       "Add-on",            15000,  FALSE, FALSE, NA,
  "A02", "Blood transfusion (add-on)",              "Add-on",             3000,  FALSE, FALSE, NA,
  "A03", "CT scan (add-on)",                        "Add-on",             3500,  FALSE, FALSE, NA,
  "A04", "Ultrasound abdomen (add-on)",             "Add-on",             1000,  FALSE, FALSE, NA,
  "A05", "Diagnostic laparoscopy (add-on)",         "Add-on",            12000,  FALSE, FALSE, NA,
  "A06", "Intraocular lens (add-on)",               "Add-on",             4000,  FALSE, FALSE, NA
)
main_pkgs <- packages |> filter(specialty != "Add-on")

# ---- Hospital master --------------------------------------------------------
districts <- c("Amarpur", "Belapur", "Chandpur", "Devgarh",
               "Fatehpur", "Gopalganj", "Haripur", "Kishanpur")

prefixes <- c("Shanti", "Jeevan Jyoti", "Sanjivani", "Lifeline", "Sunrise", "Krishna",
              "Sai Kripa", "Ganga", "Seva Sadan", "Navjeevan", "Arogyam", "Matrika",
              "Dhanvantari", "Suraksha", "Shubham", "Vatsalya", "Prerna", "Ashirwad",
              "Kalyan", "Mangalam", "Sparsh", "Nirmal", "Disha", "Umeed", "Raksha",
              "Anand", "Pragati", "Sahyog", "Kamdhenu", "Chetna", "Samarpan", "Swasthya",
              "Saket", "Pushpanjali", "Trinetra", "Vardaan", "Aastha", "Sukhmani",
              "Parivar", "Sneh", "Kaveri", "Narmada", "Himgiri", "Sagar", "Vindhya",
              "Mahima", "Nidaan", "Arpan", "Kiran", "Sharda", "Gayatri", "Jagriti",
              "Utkarsh", "Abhay", "Prakash", "Lotus", "Tulsi", "Shivam", "Om Sai",
              "Pratiksha", "Amrit", "Sanjeevani Care", "Dev", "Vishwas", "Uday",
              "Akshay", "Saraswati", "Harsh", "Indu", "Jyoti", "Madhuban", "Neelkanth")
suffixes <- c("Hospital", "Nursing Home", "Multispeciality Hospital", "Medical Centre")

n_public <- 48
n_private <- 72
hospitals <- tibble(
  hospital_id = sprintf("H%03d", 1:(n_public + n_private)),
  type = c(rep("Public", n_public), rep("Private", n_private)),
  district = c(rep(districts, each = n_public / 8), sample(districts, n_private, replace = TRUE))
) |>
  mutate(
    hospital_name = c(
      paste("District Hospital", districts),
      paste0("CHC ", rep(districts, each = 5), "-", rep(1:5, 8)),
      paste(sample(prefixes, n_private), sample(suffixes, n_private, replace = TRUE))
    ),
    beds = if_else(type == "Public", sample(30:150, n(), replace = TRUE),
                   sample(15:100, n(), replace = TRUE)),
    beds = if_else(str_starts(hospital_name, "District"), sample(200:300, n(), replace = TRUE), beds)
  )

# Hidden behaviour profiles (not written to the CSV files)
private_ids <- hospitals$hospital_id[hospitals$type == "Private"]
camp_ids    <- sample(private_ids, 6)                       # high volume, camps, unbundling
upcode_ids  <- sample(setdiff(private_ids, camp_ids), 2)    # excess ICU add-ons

profile <- hospitals |>
  mutate(group = case_when(hospital_id %in% camp_ids ~ "camp",
                           hospital_id %in% upcode_ids ~ "upcode",
                           TRUE ~ "normal"),
         claims_per_bed = case_when(group == "camp" ~ runif(n(), 7, 9),
                                    type == "Public" ~ runif(n(), 2, 4),
                                    TRUE ~ runif(n(), 2.5, 5)),
         n_claims = pmax(40, round(beds * claims_per_bed)))

# Package mix by type of hospital
mix_public  <- c(M01 = 14, M02 = 12, M03 = 8, M04 = 8, M05 = 5, S01 = 5, S02 = 5, S03 = 3,
                 G01 = 3, G02 = 9, G03 = 16, O01 = 6, R01 = 1, R02 = 4, C01 = 1)
mix_private <- c(M01 = 8, M02 = 7, M03 = 6, M04 = 6, M05 = 4, S01 = 7, S02 = 7, S03 = 8,
                 G01 = 5, G02 = 8, G03 = 5, O01 = 8, R01 = 6, R02 = 6, C01 = 6)
mix_camp    <- c(M01 = 3, M02 = 3, M03 = 1, M04 = 2, M05 = 1, S01 = 14, S02 = 12, S03 = 6,
                 G01 = 18, G02 = 3, G03 = 2, O01 = 30, R01 = 2, R02 = 2, C01 = 1)

fy_days <- seq(as.Date("2024-04-01"), as.Date("2025-03-31"), by = "day")
weekend <- fy_days[wday(fy_days, week_start = 1) >= 6]
weekday <- fy_days[wday(fy_days, week_start = 1) < 6]

make_claims <- function(h) {
  n <- h$n_claims
  mix <- switch(h$group, camp = mix_camp, if (h$type == "Public") mix_public else mix_private)
  pkg <- sample(names(mix), n, replace = TRUE, prob = mix)
  p_weekend <- if (h$group == "camp") 0.35 else 0.2
  adm <- if_else(runif(n) < p_weekend, sample(weekend, n, TRUE), sample(weekday, n, TRUE))
  info <- main_pkgs[match(pkg, main_pkgs$package_code), ]
  los_factor <- if (h$group == "camp") 0.6 else if (h$type == "Public") 1.2 else 1
  los <- if_else(info$day_care, 0L,
                 pmax(0L, as.integer(round(info$typical_los * los_factor + rnorm(n, 0, 1)))))
  female <- case_when(pkg %in% c("G01", "G02", "G03") ~ TRUE, TRUE ~ runif(n) < 0.5)
  age <- case_when(
    pkg %in% c("G02", "G03") ~ sample(19:35, n, TRUE),
    pkg == "G01" & h$group == "camp" ~ sample(24:45, n, TRUE),
    pkg == "G01" ~ sample(40:62, n, TRUE),
    pkg %in% c("O01", "R01") ~ sample(52:82, n, TRUE),
    pkg == "C01" ~ sample(42:78, n, TRUE),
    TRUE ~ sample(5:75, n, TRUE)
  )
  # Add-on packages
  addons <- map_chr(seq_len(n), function(i) {
    p <- pkg[i]
    a <- character(0)
    icu_p <- switch(p, C01 = 0.9, M05 = 0.4, M03 = 0.2, R01 = 0.2, 0.04)
    if (h$group == "upcode" && p %in% c("M01", "M02", "M03", "M04", "M05")) icu_p <- 0.6
    if (runif(1) < icu_p) a <- c(a, "A01")
    if (runif(1) < switch(p, R01 = 0.4, G02 = 0.2, G01 = 0.15, 0.02)) a <- c(a, "A02")
    if (runif(1) < switch(p, M03 = 0.3, R02 = 0.5, 0.03)) a <- c(a, "A03")
    if (runif(1) < switch(p, S03 = 0.7, S01 = 0.3, M02 = 0.1, 0.02)) a <- c(a, "A04")
    if (h$group == "camp" && p == "S01" && runif(1) < 0.7) a <- c(a, "A05")
    if (h$group == "camp" && p == "O01" && runif(1) < 0.8) a <- c(a, "A06")
    paste(a, collapse = ";")
  })
  tibble(hospital_id = h$hospital_id, admission_date = adm,
         discharge_date = adm + los, package_main = pkg, addons = addons,
         patient_female = female, patient_age = age, group = h$group)
}

claims <- profile |>
  split(~hospital_id) |>
  map(make_claims) |>
  list_rbind()

# Patient ids, with some patients readmitted within 30 days
claims <- claims |>
  arrange(hospital_id, admission_date) |>
  mutate(patient_id = sprintf("P%06d", sample(1e5:9.99e5, n())))
readmit_rate <- c(normal = 0.03, upcode = 0.05, camp = 0.10)
for (g in names(readmit_rate)) {
  idx <- which(claims$group == g)
  for (i in idx[runif(length(idx)) < readmit_rate[g]]) {
    earlier <- which(claims$hospital_id == claims$hospital_id[i] &
                     claims$admission_date < claims$admission_date[i] &
                     claims$admission_date >= claims$admission_date[i] - 30)
    if (length(earlier) > 0) {
      j <- earlier[length(earlier)]
      claims$patient_id[i] <- claims$patient_id[j]
      claims$patient_female[i] <- claims$patient_female[j]
      claims$patient_age[i] <- claims$patient_age[j]
    }
  }
}

# Claim amount is the sum of package rates
rate_of <- setNames(packages$rate, packages$package_code)
claims <- claims |>
  mutate(packages = if_else(addons == "", package_main, paste(package_main, addons, sep = ";")),
         claim_amount = map_dbl(str_split(packages, ";"), \(p) sum(rate_of[p])),
         gender = if_else(patient_female, "F", "M")) |>
  arrange(admission_date, hospital_id) |>
  mutate(claim_id = sprintf("CL%06d", row_number())) |>
  select(claim_id, hospital_id, patient_id, gender, age = patient_age,
         admission_date, discharge_date, packages, claim_amount)

dir.create("Data", showWarnings = FALSE)
write_csv(hospitals |> select(hospital_id, hospital_name, type, district, beds),
          "Data/ssy_hospitals.csv")
write_csv(packages, "Data/ssy_packages.csv")
write_csv(claims, "Data/ssy_claims.csv")

cat("hospitals:", nrow(hospitals), " claims:", nrow(claims), "\n")
cat("camp:", camp_ids, " upcode:", upcode_ids, "\n")
