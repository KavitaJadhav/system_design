-- ROW_NUMBER()
-- gives arbitrary rows when ties
-- gives exact number of rows asked

-- DENSE_RANK()
-- keep the ties
-- gives all the rows with same rank

-- employees
    -- department_id
    -- employee_id
    -- salary

-- Question
-- Give top 3 salaries from all departments with employee_id and dept_id

select data.employee_id, data.department_id, data.salary
from (select employee_id,
             department_id,
             salary,
             DENSE_RANK() OVER(partition by department_id order by salary desc) as rank
      from employees) data
where data.rank <= 3


select data.employee_id, data.department_id, data.salary
from (select employee_id,
             department_id,
             salary,
             ROW_NUMBER() OVER(partition by department_id order by salary desc) as row_num
      from employees) data
where data.row_num <= 3

-- other functions
-- top N per group → think ROW_NUMBER / DENSE_RANK
-- compare with average → AVG() OVER
-- previous / next → LAG / LEAD
-- running total → SUM() OVER ORDER BY

/* =====================================================
   1. ROW_NUMBER() → Top N rows (strict, no ties)
   ===================================================== */
SELECT *
FROM (
         SELECT e.*,
                ROW_NUMBER() OVER (
               PARTITION BY department_id          -- reset per department
               ORDER BY salary DESC                -- highest salary first
           ) AS rn
         FROM employees e
     ) t
WHERE rn <= 3;                                     -- exactly 3 rows per dept



/* =====================================================
   2. DENSE_RANK() → Top N with ties (most common)
   ===================================================== */
SELECT *
FROM (
         SELECT e.*,
                DENSE_RANK() OVER (
               PARTITION BY department_id
               ORDER BY salary DESC
           ) AS rnk
         FROM employees e
     ) t
WHERE rnk <= 3;                                    -- includes ties



/* =====================================================
   3. RANK() → Ranking with gaps
   ===================================================== */
SELECT e.*,
       RANK() OVER (
           PARTITION BY department_id
           ORDER BY salary DESC
       ) AS rnk                                    -- ranks like 1,2,2,4
FROM employees e;



/* =====================================================
   4. SUM() OVER → Total per department (no GROUP BY)
   ===================================================== */
SELECT e.*,
       SUM(salary) OVER (
           PARTITION BY department_id
       ) AS dept_total                             -- same total repeated per row
FROM employees e;



/* =====================================================
   5. Running Total (Cumulative Sum)
   ===================================================== */
SELECT e.*,
       SUM(salary) OVER (
           PARTITION BY department_id
           ORDER BY employee_id                    -- defines running order
       ) AS running_total
FROM employees e;



/* =====================================================
   6. AVG() OVER → Compare with department average
   ===================================================== */
SELECT *
FROM (
         SELECT e.*,
                AVG(salary) OVER (
               PARTITION BY department_id
           ) AS avg_salary
         FROM employees e
     ) t
WHERE salary > avg_salary;                         -- above-average earners



/* =====================================================
   7. LAG() → Previous row value
   ===================================================== */
SELECT e.*,
       LAG(salary) OVER (
           PARTITION BY department_id
           ORDER BY employee_id
       ) AS prev_salary                            -- previous employee salary
FROM employees e;



/* =====================================================
   8. LEAD() → Next row value
   ===================================================== */
SELECT e.*,
       LEAD(salary) OVER (
           PARTITION BY department_id
           ORDER BY employee_id
       ) AS next_salary                            -- next employee salary
FROM employees e;



/* =====================================================
   9. Difference using LAG()
   ===================================================== */
SELECT e.*,
       salary - LAG(salary) OVER (
           PARTITION BY department_id
           ORDER BY employee_id
       ) AS salary_diff                            -- change from previous
FROM employees e;



/* =====================================================
   10. FIRST_VALUE() → Highest salary in department
   ===================================================== */
SELECT e.*,
       FIRST_VALUE(salary) OVER (
           PARTITION BY department_id
           ORDER BY salary DESC
       ) AS highest_salary                         -- same value for all rows in dept
FROM employees e;
