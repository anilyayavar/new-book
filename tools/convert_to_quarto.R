# Convert the bookdown sources (*.Rmd) of "R for Audit Analytics" to a Quarto book.
# Run once from the book folder:  Rscript tools/convert_to_quarto.R
# It writes *.qmd files and _quarto.yml, and deletes the *.Rmd files it converted.

setwd(normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))), "..")))

read_utf8  <- function(f) readLines(f, encoding = "UTF-8", warn = FALSE)
write_utf8 <- function(x, f) writeLines(enc2utf8(x), f, useBytes = TRUE)

# bookdown order: index first, then alphabetical
rmd <- sort(list.files(pattern = "\\.Rmd$"))
rmd <- c("index.Rmd", setdiff(rmd, "index.Rmd"))

is_fence <- function(x) grepl("^\\s*```", x)
chunk_label_re <- "^(\\s*```\\{r[ ,]+)([A-Za-z0-9_.-]+)(\\s*[,}].*)$"

fig_id <- function(lab) ifelse(grepl("^fig[-_]", lab), paste0("fig-", substring(lab, 5)), paste0("fig-", lab))

# ---- pass 1: collect labels -------------------------------------------------
all_text <- unlist(lapply(rmd, read_utf8))
hdr <- grep(chunk_label_re, all_text, value = TRUE)
fig_labels <- unique(sub(chunk_label_re, "\\2", hdr[grepl("fig\\.cap", hdr)]))
tab_labels <- unique(regmatches(all_text, gregexpr("(?<=\\\\@ref\\(tab:)[^)]+", all_text, perl = TRUE)) |> unlist())
sec_ids <- unique(sub(".*\\{#([^} ]+)\\}.*", "\\1", grep("^#+ .*\\{#[^}]+\\}", all_text, value = TRUE)))

# ---- text-level conversions --------------------------------------------------
convert_text <- function(txt) {
  # ```{=tex} wrappers around equations
  txt <- gsub("```\\{=tex\\}\\s*\n(\\\\begin\\{equation\\}.*?\\\\end\\{equation\\})\\s*\n```", "\\1", txt, perl = TRUE)
  # labelled and unlabelled equations
  txt <- gsub("(?s)\\\\begin\\{equation\\}\\s*\n?(.*?)\\s*\\(\\\\#eq:([^)]+)\\)\\s*\\\\end\\{equation\\}",
              "$$\n\\1\n$$ {#eq-\\2}", txt, perl = TRUE)
  txt <- gsub("(?s)\\\\begin\\{equation\\}\\s*\n?(.*?)\\s*\\\\end\\{equation\\}", "$$\n\\1\n$$", txt, perl = TRUE)
  # pipe-table captions
  txt <- gsub("Table: \\(\\\\#tab:([^)]+)\\) ([^\n]*)", "Table: \\2 {#tbl-\\1}", txt, perl = TRUE)
  # drop the word before a reference, Quarto prints "Figure 2.1", "Chapter 3" etc. itself
  txt <- gsub("(?i)\\b(figures?|fig\\.?|tables?|equations?|eq\\.?|chapters?|sections?|appendix)(-|\\s+)(?=\\\\@ref\\()",
              "", txt, perl = TRUE)
  # references
  txt <- gsub("\\\\@ref\\(tab:([^)]+)\\)", "@tbl-\\1", txt, perl = TRUE)
  txt <- gsub("\\\\@ref\\(eq:([^)]+)\\)", "@eq-\\1", txt, perl = TRUE)
  m <- gregexpr("\\\\@ref\\(fig:([^)]+)\\)", txt, perl = TRUE)
  regmatches(txt, m) <- lapply(regmatches(txt, m), function(r) paste0("@", fig_id(sub("\\\\@ref\\(fig:([^)]+)\\)", "\\1", r))))
  txt <- gsub("\\\\@ref\\(([^):]+)\\)", "@sec-\\1", txt, perl = TRUE)
  # explicit heading ids and in-text anchor links
  txt <- gsub("(?m)^(#+ .*)\\{#(?!sec-)([^} ]+)\\}", "\\1{#sec-\\2}", txt, perl = TRUE)
  for (id in sec_ids) txt <- gsub(paste0("](#", id, ")"), paste0("](#sec-", id, ")"), txt, fixed = TRUE)
  txt
}

convert_lines <- function(x) {
  in_chunk <- FALSE
  for (i in seq_along(x)) {
    if (is_fence(x[i])) {
      if (!in_chunk && grepl(chunk_label_re, x[i])) {
        lab <- sub(chunk_label_re, "\\2", x[i])
        new <- if (lab %in% fig_labels) fig_id(lab) else if (lab %in% tab_labels) paste0("tbl-", lab) else lab
        x[i] <- sub(chunk_label_re, paste0("\\1", new, "\\3"), x[i])
      }
      in_chunk <- !in_chunk
    }
  }
  x
}

slug <- function(h) {
  h <- sub("\\s*\\{.*\\}\\s*$", "", sub("^#\\s+", "", h))
  h <- gsub("[^a-z0-9]+", "-", tolower(h))
  substr(gsub("^-|-$", "", h), 1, 40)
}

common_chunk <- c("```{r}", "#| include: false", "source(\"_common.R\")", "```", "")

# ---- pass 2: convert and split each file -------------------------------------
toc <- list()        # list of list(part=, file=)
current_part <- NA
appendix <- FALSE

for (f in rmd) {
  txt <- paste(read_utf8(f), collapse = "\n")
  txt <- sub("^---\n.*?\n---\n", "", txt, perl = TRUE)         # index YAML moves to _quarto.yml
  if (f == "99-references.Rmd") next
  x <- convert_lines(strsplit(convert_text(txt), "\n", fixed = TRUE)[[1]])

  # find level-1 headings outside chunks
  in_chunk <- FALSE; h1 <- integer()
  for (i in seq_along(x)) {
    if (is_fence(x[i])) { in_chunk <- !in_chunk; next }
    if (!in_chunk && grepl("^# ", x[i])) h1 <- c(h1, i)
  }
  base <- sub("\\.Rmd$", "", f)
  pieces <- list(); pending_part <- NA
  starts <- h1
  # leading text before the first H1 (if any) is kept with the first chapter
  for (k in seq_along(starts)) {
    line <- x[starts[k]]
    end <- if (k < length(starts)) starts[k + 1] - 1 else length(x)
    if (grepl("^# Part", line) || grepl("^# \\(APPENDIX\\)", line)) {
      if (grepl("APPENDIX", line)) appendix <- TRUE
      else pending_part <- trimws(sub("\\s*\\{.*\\}\\s*$", "", sub("^# ", "", sub("Part[- ]?([IVX]+):?", "Part \\1:", line))))
      next
    }
    from <- if (length(pieces) == 0) 1 else starts[k]
    body <- x[from:end]
    body <- body[!(grepl("^# Part", body) | grepl("^# \\(APPENDIX\\)", body))]
    name <- if (length(pieces) == 0) base else paste0(base, "-", slug(line))
    pieces[[length(pieces) + 1]] <- list(name = name, body = body, part = pending_part, appendix = appendix)
    pending_part <- NA
  }
  for (p in pieces) {
    write_utf8(c(common_chunk, p$body), paste0(p$name, ".qmd"))
    if (!is.na(p$part)) current_part <- p$part
    toc[[length(toc) + 1]] <- list(file = paste0(p$name, ".qmd"), part = if (p$appendix) "APPENDIX" else current_part)
  }
  unlink(f)
}
unlink("99-references.Rmd")
write_utf8(c("# References {.unnumbered}", "", "::: {#refs}", ":::"), "references.qmd")

# ---- _quarto.yml -------------------------------------------------------------
files <- vapply(toc, `[[`, "", "file"); parts <- vapply(toc, function(t) if (is.na(t$part)) "" else t$part, "")
y <- c("  chapters:")
pre <- files[parts == ""]
for (fl in pre) y <- c(y, paste0("    - ", fl))
for (pt in unique(parts[!parts %in% c("", "APPENDIX")])) {
  y <- c(y, paste0("    - part: \"", pt, "\""), "      chapters:")
  for (fl in files[parts == pt]) y <- c(y, paste0("        - ", fl))
}
y <- c(y, "    - references.qmd", "  appendices:")
for (fl in files[parts == "APPENDIX"]) y <- c(y, paste0("    - ", fl))

yml <- c(
  "project:",
  "  type: book",
  "  output-dir: _book",
  "",
  "book:",
  "  title: \"R for Audit Analytics\"",
  "  author: \"Anil Goyal\"",
  "  date: today",
  "  site-url: https://anilyayavar.github.io/new-book/",
  "  repo-url: https://github.com/anilyayavar/new-book",
  "  repo-actions: [edit, issue]",
  "  cover-image: images/cover.jpg",
  "  description: \"This book is intended for auditors performing exploratory data analytics using R programming language, mainly Base R and Tidyverse.\"",
  "  license: \"CC BY-NC\"",
  y,
  "",
  "bibliography: [book.bib, packages.bib]",
  "csl: chicago-fullnote-bibliography.csl",
  "",
  "execute:",
  "  freeze: auto",
  "",
  "format:",
  "  html:",
  "    theme:",
  "      light: cosmo",
  "      dark: darkly",
  "    css: style.css",
  "    code-link: true",
  "    toc-depth: 3",
  "    fig-align: center",
  "",
  "editor: source"
)
write_utf8(yml, "_quarto.yml")

write_utf8(c(
  "# Shared setup, sourced at the top of every chapter.",
  "# Bookdown ran all chapters in one R session. Quarto runs each chapter separately,",
  "# so anything a chapter needs from an earlier one must be loaded here or in that chapter.",
  "library(knitr)",
  "options(knitr.kable.NA = \"\")"
), "_common.R")

cat("Converted", length(files), "chapter files\n")
cat("fig labels", length(fig_labels), " tab labels", length(tab_labels), " sec ids", length(sec_ids), "\n")
