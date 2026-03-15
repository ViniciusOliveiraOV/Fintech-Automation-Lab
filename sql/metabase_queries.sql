-- 1) Daily revenue
SELECT
  DATE(created_at) AS day,
  SUM(amount_total) AS daily_revenue
FROM payments
WHERE status = 'paid'
GROUP BY DATE(created_at)
ORDER BY day;

-- 2) Total revenue
SELECT
  SUM(amount_total) AS total_revenue
FROM payments
WHERE status = 'paid';

-- 3) Payments count
SELECT
  COUNT(*) AS payments_count
FROM payments
WHERE status = 'paid';

-- 4) Average order value
SELECT
  AVG(amount_total) AS average_order_value
FROM payments
WHERE status = 'paid';
