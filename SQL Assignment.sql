/* SOLUTION FOR SQL ASSESSMENT
Dialect: PostgreSQL
Assumptions:
1. 'gross_transaction_value' is stored as a string with a '$' symbol (e.g., '$58') and must be cleaned for calculations.
2. 'refund_item' column acts as the refund timestamp. If NULL, the item was not refunded.
3. 'purchase_time' and 'refund_item' are valid timestamp formats.
4. The tables are joined using 'item_id' (and 'store_id' where applicable, though 'item_id' appears unique per item variant).
*/

-- 1. What is the count of purchases per month (excluding refunded purchases)?
SELECT 
    TO_CHAR(purchase_time, 'YYYY-MM') AS year_month,
    COUNT(*) AS purchase_count
FROM transactions
WHERE refund_item IS NULL
GROUP BY 1
ORDER BY 1;

-- 2. How many stores receive at least 5 orders/transactions in October 2020?
SELECT count(*) as store_count
FROM (
    SELECT store_id
    FROM transactions
    WHERE purchase_time >= '2020-10-01' 
      AND purchase_time < '2020-11-01'
    GROUP BY store_id
    HAVING COUNT(*) >= 5
) sub;

-- 3. For each store, what is the shortest interval (in min) from purchase to refund time?
SELECT 
    store_id,
    MIN(EXTRACT(EPOCH FROM (refund_item - purchase_time))/60) AS shortest_refund_mins
FROM transactions
WHERE refund_item IS NOT NULL
GROUP BY store_id;

-- 4. What is the gross_transaction_value of every store’s first order?
WITH StoreFirstOrder AS (
    SELECT 
        store_id,
        gross_transaction_value,
        ROW_NUMBER() OVER(PARTITION BY store_id ORDER BY purchase_time ASC) as rn
    FROM transactions
)
SELECT store_id, gross_transaction_value
FROM StoreFirstOrder
WHERE rn = 1;

-- 5. What is the most popular item name that buyers order on their first purchase?
WITH BuyerFirstPurchase AS (
    SELECT 
        t.buyer_id,
        t.item_id,
        ROW_NUMBER() OVER(PARTITION BY t.buyer_id ORDER BY t.purchase_time ASC) as rn
    FROM transactions t
)
SELECT 
    i.item_name,
    COUNT(*) as popularity_count
FROM BuyerFirstPurchase bfp
JOIN items i ON bfp.item_id = i.item_id
WHERE bfp.rn = 1
GROUP BY i.item_name
ORDER BY popularity_count DESC
LIMIT 1;

-- 6. Create a flag indicating whether the refund can be processed (within 72 hours of purchase).
SELECT 
    buyer_id,
    purchase_time,
    refund_item,
    CASE 
        WHEN refund_item IS NOT NULL 
             AND (EXTRACT(EPOCH FROM (refund_item - purchase_time))/3600) <= 72 
        THEN 'Yes' 
        ELSE 'No' 
    END AS refund_processable_flag
FROM transactions;

-- 7. Create a rank by buyer_id and filter for only the second purchase per buyer.
WITH RankedTransactions AS (
    SELECT 
        buyer_id,
        store_id,
        item_id,
        gross_transaction_value,
        purchase_time,
        ROW_NUMBER() OVER(PARTITION BY buyer_id ORDER BY purchase_time ASC) as rank_val
    FROM transactions
)
SELECT *
FROM RankedTransactions
WHERE rank_val = 2;

-- 8. Find the second transaction time per buyer (without using min/max).
WITH BuyerHistory AS (
    SELECT 
        buyer_id,
        purchase_time,
        ROW_NUMBER() OVER(PARTITION BY buyer_id ORDER BY purchase_time ASC) as rn
    FROM transactions
)
SELECT 
    buyer_id,
    purchase_time as second_transaction_time
FROM BuyerHistory
WHERE rn = 2;