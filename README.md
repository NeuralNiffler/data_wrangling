# WHOOP Visualisations - Data Wrangling & Analysis

**Authors:** Monish Pahwa & Robin Schmid

This study project tidies individual personal data categories (sleep, recovery, and cycle) to generate cross-functional insights. 
*Note: The actual data retrieval via API is excluded from this repository for privacy reasons.*
Documentation about the API and what the data retrieved means can be found here https://developer.whoop.com/api

## 🛠 Tools & Data
* **Coding Language:** R
* **Package Management:** `renv`
* **Core Package:** `tidyverse`
* **Data:** Personal data fetched via WHOOP API Endpoints for a 100-day period (Dec 25 - Mar 26).

## 🚀 Setup & Execution

1. **Install Dependencies**
   Run `renv::restore()` to load the required environment. 
   *(If `renv` is not installed, run `install.packages("renv")` first).*

2. **Execution Options**
   Depending on the preferred evaluation method, the project can be run in two ways:

   * **Option A: Automated Execution (Knit)**
     Knit the `visualisation.Rmd` document. This will automatically run the underlying data pipelines (sleep, recovery, cycle) and generate the final HTML document.

   * **Option B: Manual Execution (Chunk-by-Chunk)**
     1. Navigate to the `preprocessing/` folder.
     2. Run the individual `.Rmd` files (e.g., sleep, recovery) chunk by chunk. Each file outputs a tidied dataset as an `.rds` file.
     3. Run `combine_tidy_data.Rmd`. *(Note: This strictly requires the `.rds` files generated in the previous step).*
     4. Run `visualisation.Rmd` to generate the graphics.

## 📁 Project Structure

| Path | Content |
| --- | --- |
| `visualisation.Rmd` | **Main document:** runs the pipelines and generates the final graphics / HTML output. |
| `data/` | Stores input data (direct results from API) and output data (cleaned & combined `.rds` datasets). |
| `preprocessing/` | Notebooks for the individual data wrangling processes (sleep, recovery & cycle), plus the notebook for combining all three datasets. |
| `util/` | Helper scripts with utility functions (e.g., outlier detection, applying timezone offsets). |
| `renv/` | Internal folder for package management. |
| `renv.lock` | Lockfile for restoring the exact R environment. |





