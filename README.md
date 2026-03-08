# Steam Game Revenue Analysis

## Overview
This project analyzes whether player satisfaction is associated with publisher revenue outcomes on Steam. Using public Steam-related datasets, the project compares review sentiment, review volume, and engagement-related variables to see which factors are most closely associated with commercial performance.

## Research Question
Do happier players lead to better revenue outcomes for publishers on Steam, or are reach and engagement stronger indicators of success?

## Data Sources
This project combines public data from multiple sources, including:
- Steam store metadata
- SteamSpy
- IGDB
- Publisher-level revenue data from Gamealytic

## Tools Used
- Jupyter Notebook
- Python
- pandas
- SQL
- SQLite
- Data visualization libraries
- Regression modeling

## Methodology
The project follows four main stages:
1. Import and clean Steam game and publisher data
2. Merge datasets and engineer variables for analysis
3. Explore relationships between review metrics, engagement, and revenue
4. Build regression models to compare which variables are the most useful predictors of publisher revenue

## Key Findings
The analysis suggests that review score by itself is not a strong predictor of publisher revenue. Review volume appears to be more informative, and engagement measures add some value, though their explanatory power remains limited on their own. A combined model performs better than single-variable models, but still explains only part of the variation in publisher revenue.

## Repository Contents
- `Final_Report.ipynb` — main notebook containing data cleaning, analysis, and modeling
- `README.md` — project summary and instructions
- `data/` — data files used in the project
- `figures/` — exported charts and visuals, if included

## How to Run
1. Clone this repository
2. Open the notebook in Jupyter Notebook or JupyterLab
3. Install the required Python packages
4. Run the notebook cells in order

## Notes
This project uses publicly available data, so some business variables that may affect revenue — such as marketing spend, wishlist counts, and platform promotion — are not included. As a result, the findings should be interpreted as evidence of association rather than a complete explanation of revenue outcomes.

## Future Improvements
Future work could incorporate richer commercial and visibility data, improve feature engineering for engagement, and test additional modeling approaches.

## Author
Skye Huang and Alen Chan
