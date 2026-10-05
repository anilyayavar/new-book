# Pages of the earlier bookdown site had different names. So that old links and
# bookmarks still work, write a small page for each old name that forwards to the
# matching page of this book. Runs after rendering. Never overwrites a real page.
out_dir <- Sys.getenv("QUARTO_PROJECT_OUTPUT_DIR", "docs")
if (nzchar(Sys.getenv("QUARTO_PROJECT_OUTPUT_FILES")) &&
    !file.exists(file.path(out_dir, "index.html"))) quit(save = "no")

map <- read.csv("tools/old-pages.csv", stringsAsFactors = FALSE)
for (i in seq_len(nrow(map))) {
  target <- file.path(out_dir, map$old[i])
  if (file.exists(target) && !any(grepl("http-equiv=\"refresh\"", readLines(target, warn = FALSE)))) next
  new <- map$new[i]
  writeLines(c(
    "<!DOCTYPE html>",
    "<html lang=\"en\"><head><meta charset=\"utf-8\">",
    "<title>R for Audit Analytics</title>",
    sprintf("<link rel=\"canonical\" href=\"%s\">", new),
    sprintf("<meta http-equiv=\"refresh\" content=\"0; url=%s\">", new),
    "</head><body>",
    sprintf("<p>This page has moved. <a href=\"%s\">Go to the new page</a>.</p>", new),
    "</body></html>"), target)
}
