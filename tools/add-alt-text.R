out_dir <- Sys.getenv("QUARTO_PROJECT_OUTPUT_DIR", "docs")
files <- Sys.getenv("QUARTO_PROJECT_OUTPUT_FILES")
files <- if (nzchar(files)) strsplit(files, "\n")[[1]] else list.files(out_dir, "\\.html$", full.names = TRUE)
files <- files[grepl("\\.html$", files) & file.exists(files)]

strip_tags <- function(x) {
  x <- gsub("<[^>]+>", "", x)
  x <- gsub("&nbsp;| ", " ", x)
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  x <- gsub("\\s+", " ", x)
  x <- sub("^\\s*(Figure|Table)\\s+[A-Z0-9.]+:\\s*", "", x)
  x <- gsub("\"", "&quot;", trimws(x), fixed = TRUE)
  x
}

# an <img> that has no alt text, or an empty one
no_alt <- "<img(?![^>]*\\balt=\"[^\"]+\")([^>]*?)(\\s*alt=\"\")?([^>]*)>"
put_alt <- function(img, alt) {
  gsub(no_alt, paste0("<img\\1\\3 alt=\"", gsub("\\\\", "\\\\\\\\", alt), "\">"), img, perl = TRUE)
}

for (f in files) {
  html <- paste(readLines(f, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  html0 <- html

  # 1. figures with a caption take the caption as alt text
  figs <- gregexpr("(?s)<figure[^>]*>.*?</figure>", html, perl = TRUE)[[1]]
  if (figs[1] != -1) {
    pieces <- regmatches(html, list(figs))[[1]]
    for (k in seq_along(pieces)) {
      cap <- regmatches(pieces[k], regexpr("(?s)<figcaption[^>]*>.*?</figcaption>", pieces[k], perl = TRUE))
      if (!length(cap)) next
      alt <- strip_tags(cap)
      if (nzchar(alt)) pieces[k] <- put_alt(pieces[k], alt)
    }
    regmatches(html, list(figs)) <- list(pieces)
  }

  # 2. any image still without alt text is described by the section it sits in
  title <- strip_tags(regmatches(html, regexpr("(?s)<title>.*?</title>", html, perl = TRUE)))
  title <- sub("^\\s*\\d+\\s+", "", sub(" . R for Audit Analytics$", "", title))
  m <- gregexpr("(?s)<h[1-4][^>]*>.*?</h[1-4]>|<img[^>]*>", html, perl = TRUE)[[1]]
  if (m[1] != -1) {
    pieces <- regmatches(html, list(m))[[1]]
    section <- title
    for (k in seq_along(pieces)) {
      if (startsWith(pieces[k], "<h")) {
        h <- sub("^\\s*[0-9.]+\\s+", "", strip_tags(pieces[k]))
        if (nzchar(h)) section <- h
      } else if (grepl(no_alt, pieces[k], perl = TRUE)) {
        pieces[k] <- put_alt(pieces[k], paste0("Output for: ", section))
      }
    }
    regmatches(html, list(m)) <- list(pieces)
  }

  if (!identical(html, html0)) writeLines(html, f, useBytes = TRUE)
}
