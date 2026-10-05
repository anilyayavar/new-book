# R for Audit Analytics

*Data analytics for auditors, with R and the tidyverse*, by [Anil Goyal](https://www.linkedin.com/in/anil-kumar-goyal/).

**Read the book online, free: <https://anilyayavar.github.io/new-book/>**

<a href="https://anilyayavar.github.io/new-book/index.html"><img src="images/cover.jpg" alt="Cover of R for Audit Analytics" width="300"/></a>

## About the book

A practical guide to data analytics for auditors, in government and elsewhere, using the free and open-source R language. No knowledge of programming is assumed. Every technique is explained in plain language and shown at work on an audit problem, with Indian examples and realistic simulated data in which irregularities are planted for the analysis to find.

The book follows the course of an audit, in nine parts:

1. **R Foundations**. The R language from the beginning.
2. **Getting Data Ready**. Reading files, including PDFs and messy Excel. Cleaning, joining and reshaping. Dates, and data too large for Excel.
3. **Working with Text Fields**. Cleaning text, regular expressions, and validating PAN, GSTIN and Aadhaar.
4. **Exploring and Sampling**. Charts, descriptive statistics, audit sampling and statistical tests.
5. **Forensic Tests**. Rule-based validation, Benford's law, Nigrini's tests, duplicates, fuzzy matching, record linkage, gaps and process mining.
6. **Modelling and Risk Scoring**. Regression, logistic regression, decision trees, random forests and DEA.
7. **Finding Hidden Patterns**. PCA, clustering, association rules, time series and anomaly detection.
8. **Beyond Tables**. Text analytics, networks and maps.
9. **Reporting**. Reproducible audit reports and working papers.

An **Audit Question Finder** in the appendices lists common audit questions and the section that answers each one.

## Building the book

The book is written in [Quarto](https://quarto.org). To build it yourself, you need R (version 4.5 or later), Quarto (which comes with RStudio), and the R packages listed in the appendix *R packages used in this book*, which gives a single command to install them all. Then, in the project folder, run

```
quarto render
```

The rendered book is written to the `docs` folder, which GitHub Pages publishes.

## Credits

The R package used in the book for matching names by their sound, a full implementation of the Double Metaphone algorithm, was developed by **Atharv Tyagi** during an internship under the author's guidance.

## Licence, disclaimer and feedback

<a href="https://anilyayavar.github.io/new-book/">R for Audit Analytics</a> by Anil Goyal is licensed under [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/). You may share and adapt it for non-commercial purposes, with credit to the author.

The author works for the Government of India. The opinions expressed in the book are personal to the author, and are not to be construed as those of the Government of India. All data in the book is either sample data available with R, open data, or data simulated by the author; none of it pertains to any entity handled by the author in his official capacity.

Suggestions and corrections are welcome, by [email](mailto:anilyayavar@gmail.com) or through the [issues](https://github.com/anilyayavar/new-book/issues) of this repository.
