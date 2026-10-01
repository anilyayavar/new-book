# Creates simulated text data for the imaginary Sarvajan Swasthya Yojana (SSY),
# used in the chapters on text analytics, sentiment analysis and text visualisation.
# Needs Data/ssy_hospitals.csv (run tools/make_health_scheme_data.R first).
#   Rscript tools/make_ssy_text_data.R
# Writes Data/ssy_grievances.csv and Data/ssy_feedback.csv. All text is made up.

suppressPackageStartupMessages(library(tidyverse))
set.seed(311)

hospitals <- read_csv("Data/ssy_hospitals.csv", show_col_types = FALSE)
camp_ids  <- c("H116", "H071", "H070", "H098", "H063", "H066")
pick <- function(x) sample(x, 1)

# ---- Grievances ---------------------------------------------------------------
themes <- list(
  money = list(
    category = c("Demand of money", "Demand of money", "Other"),
    text = c(
      "Hospital staff demanded Rs {amt} from us for medicines although treatment is free under the scheme.",
      "We were asked to pay {amt} rupees in cash before the operation. No receipt was given.",
      "The doctor said the package does not cover the medicines and took Rs. {amt} from my father.",
      "They took money ({amt}) for blood test and x-ray. Is this not covered under SSY card?",
      "At discharge the counter asked {amt}/- extra, they said card amount is finished."
    )),
  camp = list(
    category = c("Other", "Other", "Quality of care", "Other"),
    text = c(
      "A vehicle from the hospital came to our village for a free health camp and took {n} people for operation the same day.",
      "Agent of the hospital told villagers that free operation is available, took us in their van on Sunday.",
      "Health camp was held in the panchayat bhawan, many old people were taken for eye operation, they were sent back next day.",
      "Hospital people came to village camp and said everyone must get checked, then my mother was admitted and operated.",
      "Camp ke baad hospital le gaye, operation kar diya. Nobody explained anything to us."
    )),
  surgery = list(
    category = c("Quality of care", "Other", "Other"),
    text = c(
      "My wife is only {age} years old but they removed her uterus saying it is necessary, we were not told about any other option.",
      "Doctor did operation of appendix without any test, now my son has pain and they are not attending.",
      "My uterus was removed at age {age}, I had only small stomach pain. Now I feel weak all the time.",
      "They did operation in a hurry and discharged next day, the wound has not healed and there is pus.",
      "Second operation was done within one month, again my card was swiped."
    )),
  denial = list(
    category = c("Denial of treatment", "Denial of treatment", "Card/eligibility"),
    text = c(
      "Hospital refused to admit my father saying SSY card is not valid, though card is active.",
      "We went to the hospital in emergency but they said scheme beds are full and sent us away.",
      "Card is not accepted, staff says server is down for last {n} days.",
      "They refused treatment saying this disease is not in package list."
    )),
  delay = list(
    category = c("Delay", "Delay", "Other"),
    text = c(
      "Patient was not discharged for {n} days after treatment, they said approval is pending from insurance.",
      "Pre-authorisation was not given for {n} days and operation was delayed.",
      "Claim is pending and hospital is asking us to wait, my father is still in ward."
    )),
  quality = list(
    category = c("Quality of care", "Quality of care", "Other"),
    text = c(
      "Ward was dirty and toilets were not cleaned, no drinking water for patients.",
      "Nurses were rude and did not come at night even after calling many times.",
      "Food was not given to the patient as promised under the scheme.",
      "Doctor visited only once in {n} days, junior staff was handling everything."
    ))
)

openers <- c("", "Sir, ", "Respected sir, ", "Dear Sir/Madam, ", "To the officer, ", "Sir ji, ", "")
closers <- c("", " Please take action.", " Kindly help us.", " Please look into the matter urgently.",
             " Contact me on {phone}.", " Mobile no {phone}.", " We are poor people, please help.", "")

fill <- function(s) {
  s |>
    str_replace_all("\\{amt\\}", as.character(pick(c(500, 1000, 1500, 2000, 2500, 3000, 5000, 8000)))) |>
    str_replace_all("\\{n\\}", as.character(pick(2:9))) |>
    str_replace_all("\\{age\\}", as.character(pick(24:36))) |>
    str_replace_all("\\{phone\\}", paste0(pick(6:9), paste(sample(0:9, 9, TRUE), collapse = "")))
}
messy <- function(s) {
  r <- runif(1)
  if (r < 0.10) s <- toupper(s)
  else if (r < 0.20) s <- tolower(s)
  if (runif(1) < 0.15) s <- str_replace_all(s, "\\.", " .")
  if (runif(1) < 0.10) s <- str_replace(s, "hospital", "hospitl")
  if (runif(1) < 0.10) s <- str_replace(s, "operation", "opration")
  if (runif(1) < 0.15) s <- paste0(s, "  ")
  s
}

n_griev <- 800
theme_prob_normal <- c(money = 0.16, camp = 0.02, surgery = 0.04, denial = 0.30, delay = 0.22, quality = 0.26)
theme_prob_camp   <- c(money = 0.30, camp = 0.30, surgery = 0.30, denial = 0.03, delay = 0.02, quality = 0.05)

griev_hosp <- c(sample(camp_ids, 220, replace = TRUE),
                sample(setdiff(hospitals$hospital_id, camp_ids), n_griev - 220, replace = TRUE))

grievances <- map(griev_hosp, function(h) {
  pr <- if (h %in% camp_ids) theme_prob_camp else theme_prob_normal
  th <- sample(names(pr), 1, prob = pr)
  txt <- paste0(pick(openers), fill(pick(themes[[th]]$text)), fill(pick(closers)))
  tibble(hospital_id = h, category = pick(themes[[th]]$category), text = messy(txt))
}) |>
  list_rbind() |>
  mutate(received_on = sort(as.Date("2024-04-01") + sample(0:364, n(), replace = TRUE))) |>
  sample_frac() |>
  arrange(received_on) |>
  mutate(grievance_id = sprintf("GR%04d", row_number())) |>
  left_join(hospitals |> select(hospital_id, district), by = "hospital_id") |>
  select(grievance_id, received_on, district, hospital_id, category, text)

# ---- Patient feedback ------------------------------------------------------------
pos <- c("Doctors were very good and caring.", "Treatment was free and the staff was helpful.",
         "Very clean ward and good food.", "Nurses were kind and attentive.",
         "Excellent care, my mother recovered quickly.", "Good hospital, everything was explained properly.",
         "Thank you, the operation was successful.", "Staff was polite and the doctor was experienced.")
neg <- c("Staff was rude and careless.", "We had to pay for medicines, it was not free.",
         "Ward was dirty and smelly.", "Long wait, nobody attended to us.",
         "Discharged too early, still in pain.", "Doctor was not available, very poor service.",
         "They forced us to get operation done.", "Bad experience, worst hospital.")
neutral <- c("Treatment was done.", "Stayed for some days.", "Operation done under scheme.",
             "Discharged after treatment.")
negated <- c("Food was not good.", "The doctor was not helpful.", "Not happy with the treatment.",
             "Toilets were not clean.")

n_fb <- 1500
fb_hosp <- sample(hospitals$hospital_id, n_fb, replace = TRUE)
feedback <- map(fb_hosp, function(h) {
  p <- if (h %in% camp_ids) c(0.15, 0.55, 0.15, 0.15) else c(0.55, 0.15, 0.20, 0.10)
  kind <- sample(c("pos", "neg", "neutral", "negated"), 1, prob = p)
  s1 <- pick(get(kind))
  s2 <- if (runif(1) < 0.4) paste(" ", pick(get(sample(c("pos", "neg", "neutral"), 1, prob = c(p[1], p[2] + p[4], p[3]))))) else ""
  tibble(hospital_id = h, comment = paste0(s1, s2), rating = NA_integer_)
}) |>
  list_rbind() |>
  mutate(feedback_id = sprintf("FB%04d", row_number()), .before = 1)

# Star rating loosely follows the comment
score <- str_count(feedback$comment, regex(paste(c("good", "caring", "helpful", "clean", "kind",
                                                   "excellent", "thank", "polite", "successful"),
                                                 collapse = "|"), ignore_case = TRUE)) -
         str_count(feedback$comment, regex(paste(c("rude", "pay", "dirty", "nobody", "pain", "poor",
                                                   "forced", "bad", "not "), collapse = "|"),
                                           ignore_case = TRUE))
feedback$rating <- pmin(5L, pmax(1L, as.integer(round(3 + score + rnorm(n_fb, 0, 0.6)))))

write_csv(grievances, "Data/ssy_grievances.csv")
write_csv(feedback, "Data/ssy_feedback.csv")
cat("grievances:", nrow(grievances), " feedback:", nrow(feedback), "\n")
