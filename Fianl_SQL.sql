/* ==============================================================================
Query 1: Review Score Distribution Check
==============================================================================
WHAT: Inspects the distribution of raw review score descriptions to identify unstable or invalid sentiment categories.
HOW : Uses GROUP BY on the review_query_review_score_desc column and aggregates with COUNT(*), ordering the results descending.
WHY : This ensures data quality by identifying non-sentiment labels (e.g., "No user reviews") that must be filtered out before conducting the main sentiment analysis.
*/
SELECT review_query_review_score_desc, COUNT(*) AS game_count
FROM steam_store
GROUP BY review_query_review_score_desc
ORDER BY game_count DESC;

/* ==============================================================================
Query 2: Store Type Validation
==============================================================================
WHAT: Summarizes the counts of different store entry types within the Steam Store dataset.
HOW : Utilizes GROUP BY on the store_type column and aggregates with COUNT(*), sorting by frequency.
WHY : This helps confirm the presence of non-game entries (like mods or advertising) which need to be excluded to keep the analysis focused strictly on commercial game performance.
*/
SELECT store_type, COUNT(*) AS game_count
FROM steam_store
GROUP BY store_type
ORDER BY game_count DESC;

/* ==============================================================================
Query 3: SteamSpy Ownership Ranges Distribution
==============================================================================
WHAT: Evaluates how the estimated ownership ranges are formatted and distributed in the SteamSpy dataset.
HOW : Applies GROUP BY on the owners column, aggregates with COUNT(*), and uses LIMIT 10 to show the most frequent ownership range buckets.
WHY : Understanding the structure of these raw range strings is necessary before transforming them into numeric midpoint estimates for the commercial scale proxy.
*/
SELECT owners, COUNT(*) AS game_count
FROM steamspy
GROUP BY owners
ORDER BY game_count DESC
LIMIT 10;

/* ==============================================================================
Query 4: IGDB Metadata Missingness Check
==============================================================================
WHAT: Checks for missing values across key classification and rating fields in the IGDB dataset.
HOW : Uses multiple SELECT statements with COUNT(*) and a WHERE ... IS NULL clause, combined using UNION ALL to create a single summary table.
WHY : This identifies which metadata fields are complete enough to be used as reliable controls in the later comparative analysis.
*/
SELECT 'Missing genres' AS issue, COUNT(*) AS row_count
FROM igdb
WHERE igdb_genres IS NULL
UNION ALL
SELECT 'Missing game modes' AS issue, COUNT(*) AS row_count
FROM igdb
WHERE igdb_game_modes IS NULL
UNION ALL
SELECT 'Missing total rating' AS issue, COUNT(*) AS row_count
FROM igdb
WHERE igdb_total_rating IS NULL
UNION ALL
SELECT 'Missing release date' AS issue, COUNT(*) AS row_count
FROM igdb
WHERE igdb_first_release_date IS NULL;

/* ==============================================================================
Query 5: Game Review Sentiment and Publisher Revenue Mapping
==============================================================================
WHAT: Combines game-level review score descriptions with publisher-level financial data and tiers.
HOW : Uses an INNER JOIN to merge the steam_store (s) and publisher_games (p) tables on their shared steam_id primary/foreign key.
WHY : This creates the foundational dataset needed to explore whether higher categorical review sentiments (e.g., "Overwhelmingly Positive") consistently align with higher publisher revenue tiers.
*/

SELECT 
    s.steam_id, 
    s.store_name, 
    s.review_query_review_score_desc, 
    p.publisher_name, 
    p.publisher_tier, 
    p.publisher_total_revenue
FROM steam_store AS s
INNER JOIN publisher_games AS p 
    ON s.steam_id = p.steam_id;

/* ==============================================================================
Query 6: Publisher Tier and Review Sentiment Baseline
==============================================================================
WHAT: Aggregates the count of games by their publisher revenue tier and review score description.
HOW : Employs an INNER JOIN to merge the steam_store and publisher_games tables on steam_id within a subquery, and an outer query that uses GROUP BY on both tier and review score description.
WHY : This establishes the baseline relationship to see if high-revenue and low-revenue publishers differ significantly in their distribution of review sentiments.
*/
SELECT
  publisher_tier,
  review_query_review_score_desc,
  COUNT(*) AS game_count
FROM (
  SELECT
    s.steam_id,
    s.review_query_review_score_desc,
    p.publisher_tier
  FROM steam_store AS s
  INNER JOIN publisher_games AS p
  ON s.steam_id = p.steam_id
)
GROUP BY publisher_tier, review_query_review_score_desc
ORDER BY publisher_tier, game_count DESC;

/* ==============================================================================
Query 7: Publisher Revenue Ranking
==============================================================================
WHAT: Ranks publishers based on their total historical revenue to understand market concentration.
HOW : Uses the RANK() OVER (ORDER BY publisher_total_revenue DESC) window function on a subquery that extracts DISTINCT publisher financial records.
WHY : This highlights that publisher revenue is highly concentrated among a few top players, suggesting that scale might be driven by structural advantages rather than just player sentiment.
*/
SELECT publisher_name, publisher_class, publisher_tier, publisher_total_revenue,
RANK() OVER (ORDER BY publisher_total_revenue DESC) AS revenue_rank
FROM (
  SELECT DISTINCT publisher_name, publisher_class, publisher_tier, publisher_total_revenue
  FROM publisher_games
)
ORDER BY revenue_rank, publisher_name
LIMIT 15;

/* ==============================================================================
Query 8: Modeling Data - Review Score and Publisher Revenue
==============================================================================
WHAT: Extracts game-level review scores and connects them to their corresponding publisher's total revenue.
HOW : Connects steam_store and publisher_games using an INNER JOIN on steam_id, filtering out null values with the WHERE clause.
WHY : This creates the core dataset used for scatter plots and initial regression models to test if review sentiment alone is a strong predictor of publisher revenue.
*/
SELECT
  s.steam_id,
  s.store_name,
  s.review_query_review_score,
  s.review_query_total_reviews,
  p.publisher_name,
  p.publisher_tier,
  p.publisher_total_revenue
FROM steam_store AS s
INNER JOIN publisher_games AS p
  ON s.steam_id = p.steam_id
WHERE s.review_query_review_score IS NOT NULL
  AND p.publisher_total_revenue IS NOT NULL;

/* ==============================================================================
Query 9: Publisher Catalog Concentration
==============================================================================
WHAT: Identifies the single most-reviewed game for each publisher to evaluate catalog concentration.
HOW : Uses a ROW_NUMBER() window function partitioned by publisher_name and ordered by total reviews descending. An INNER JOIN connects publisher_games and steam_store. The outer query filters for catalog_rank = 1.
WHY : This helps determine if top-tier publishers rely on a single massive hit or maintain consistently high engagement across multiple titles, adding depth to the analysis of review volume and publisher scale.
*/
WITH RankedPublisherGames AS (
    SELECT 
        p.publisher_name,
        p.publisher_tier,
        s.store_name,
        s.review_query_total_reviews,
        ROW_NUMBER() OVER (PARTITION BY p.publisher_name ORDER BY s.review_query_total_reviews DESC) AS catalog_rank
    FROM publisher_games AS p
    INNER JOIN steam_store AS s ON p.steam_id = s.steam_id
    WHERE s.review_query_total_reviews IS NOT NULL
)
SELECT 
    publisher_name,
    publisher_tier,
    store_name AS top_game_by_volume,
    review_query_total_reviews AS top_game_reviews
FROM RankedPublisherGames
WHERE catalog_rank = 1
ORDER BY top_game_reviews DESC
LIMIT 15;

/* ==============================================================================
Query 10: Modeling Data - Engagement Intensity and Publisher Revenue
==============================================================================
WHAT: Retrieves the stickiness percentage for each game alongside its publisher's total revenue to measure engagement.
HOW : Joins publisher_games and steamspy via an INNER JOIN on the app ID, filtering for valid, positive stickiness values using the WHERE clause.
WHY : This prepares the dataset to evaluate whether post-purchase engagement intensity is a stronger predictor of commercial success than initial review sentiment.
*/
SELECT
  p.steam_id,
  p.publisher_tier,
  p.publisher_total_revenue,
  spy.stickiness_pct
FROM publisher_games AS p
INNER JOIN steamspy AS spy
ON p.steam_id = spy.appid
WHERE spy.stickiness_pct IS NOT NULL
AND spy.stickiness_pct > 0
AND p.publisher_total_revenue IS NOT NULL;

/* ==============================================================================
Query 11: Comprehensive Modeling Data - Sentiment, Volume, and Engagement
==============================================================================
WHAT: Combines review sentiment (positives/negatives), review volume, and engagement metrics with publisher revenue for multiple regression analysis.
HOW : Uses an INNER JOIN to link steam_store to publisher_games, and a LEFT JOIN to attach engagement data from steamspy, ensuring required fields are non-null.
WHY : This unified dataset allows the analysis to simultaneously evaluate the impact of review sentiment, audience scale (review volume), and player engagement on publisher-level commercial outcomes.
*/
SELECT
  s.steam_id,
  s.review_query_total_positive,
  s.review_query_total_negative,
  s.review_query_total_reviews,
  spy.stickiness_pct,
  p.publisher_total_revenue
FROM steam_store AS s
INNER JOIN publisher_games AS p
  ON s.steam_id = p.steam_id
LEFT JOIN steamspy AS spy
  ON s.steam_id = spy.appid
WHERE s.review_query_total_reviews IS NOT NULL
AND p.publisher_total_revenue IS NOT NULL;

