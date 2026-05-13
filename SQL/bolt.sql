/* =====================================================
   BOLT-STYLE SQL INTERVIEW NOTES (COPY-READY)
   Focus: Practical + medium/hard SQL patterns
   Table assumed: employees(employee_id, department_id, salary, manager_id)
   ===================================================== */


/* =====================================================
   1. TOP N PER GROUP (Top 3 salaries per department)
   ===================================================== */
-- Topic: Window Functions - DENSE_RANK
-- Usecase: Get top 3 salaries per department including ties

SELECT *
FROM (
         SELECT *,
                DENSE_RANK() OVER (
               PARTITION BY department_id
               ORDER BY salary DESC
           ) AS rnk
         FROM employees
     ) t
WHERE rnk <= 3;



/* =====================================================
   2. EMPLOYEES ABOVE DEPARTMENT AVERAGE
   ===================================================== */
-- Topic: Window Aggregates - AVG OVER
-- Usecase: Find employees earning more than their department average

SELECT employee_id, department_id, salary
FROM (
         SELECT *,
                AVG(salary) OVER (
               PARTITION BY department_id
           ) AS dept_avg
         FROM employees
     ) t
WHERE salary > dept_avg;



/* =====================================================
   3. DEPARTMENTS WITH HIGHEST AVERAGE SALARY
   ===================================================== */
-- Topic: Aggregation + GROUP BY
-- Usecase: Rank departments by average salary

SELECT department_id, AVG(salary) AS avg_salary
FROM employees
GROUP BY department_id
ORDER BY avg_salary DESC;



/* =====================================================
   4. EMPLOYEES WITHOUT A DEPARTMENT
   ===================================================== */
-- Topic: LEFT JOIN + NULL filtering
-- Usecase: Find employees not assigned to any department

SELECT e.*
FROM employees e
         LEFT JOIN departments d
                   ON e.department_id = d.id
WHERE d.id IS NULL;



/* =====================================================
   5. EMPLOYEES EARNING MORE THAN THEIR MANAGER
   ===================================================== */
-- Topic: Self Join
-- Usecase: Compare employee salary with manager salary

SELECT e.employee_id, e.salary
FROM employees e
         JOIN employees m
              ON e.manager_id = m.employee_id
WHERE e.salary > m.salary;



/* =====================================================
   6. DUPLICATE SALARY DETECTION
   ===================================================== */
-- Topic: Aggregation
-- Usecase: Find salaries appearing more than once

SELECT salary, COUNT(*) AS cnt
FROM employees
GROUP BY salary
HAVING COUNT(*) > 1;



/* =====================================================
   7. RUNNING TOTAL PER DEPARTMENT
   ===================================================== */
-- Topic: Window Aggregation - Running SUM
-- Usecase: Cumulative salary within department

SELECT *,
       SUM(salary) OVER (
           PARTITION BY department_id
           ORDER BY employee_id
       ) AS running_total
FROM employees;



/* =====================================================
   8. PREVIOUS SALARY COMPARISON
   ===================================================== */
-- Topic: Window Functions - LAG
-- Usecase: Compare with previous employee in department

SELECT *,
       salary - LAG(salary) OVER (
           PARTITION BY department_id
           ORDER BY employee_id
       ) AS diff_from_prev
FROM employees;



/* =====================================================
   9. MONTHLY GROWTH / TREND (GENERAL PATTERN)
   ===================================================== */
-- Topic: LAG + Calculation
-- Usecase: Compare current row with previous row

SELECT *,
       (salary - LAG(salary) OVER (ORDER BY employee_id)) AS change
FROM employees;



/* =====================================================
   10. NTH HIGHEST SALARY
   ===================================================== */
-- Topic: Ranking
-- Usecase: Find 2nd highest salary

SELECT *
FROM (
         SELECT *,
                DENSE_RANK() OVER (
               ORDER BY salary DESC
           ) AS rnk
         FROM employees
     ) t
WHERE rnk = 2;



/* =====================================================
   11. LEFT JOIN: FIND NON-MATCHING RECORDS
   ===================================================== */
-- Topic: Anti Join Pattern
-- Usecase: Find departments without employees

SELECT d.*
FROM departments d
         LEFT JOIN employees e
                   ON d.id = e.department_id
WHERE e.employee_id IS NULL;



/* =====================================================
   12. GROUP BY WITH HAVING
   ===================================================== */
-- Topic: Aggregation Filtering
-- Usecase: Departments with more than 5 employees

SELECT department_id, COUNT(*) AS cnt
FROM employees
GROUP BY department_id
HAVING COUNT(*) > 5;



/* =====================================================
   13. RANK COMPARISON (ROW_NUMBER vs RANK vs DENSE_RANK)
   ===================================================== */
-- Topic: Ranking Differences
-- Usecase: Understand tie handling

SELECT *,
       ROW_NUMBER() OVER (PARTITION BY department_id ORDER BY salary DESC) AS row_num,
    RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rnk,
    DENSE_RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS dense_rnk
FROM employees;



/* =====================================================
   14. FIND LATEST RECORD PER GROUP
   ===================================================== */
-- Topic: Window + Ranking
-- Usecase: Get most recent record per employee (example pattern)

SELECT *
FROM (
         SELECT *,
                ROW_NUMBER() OVER (
               PARTITION BY department_id
               ORDER BY employee_id DESC
           ) AS rn
         FROM employees
     ) t
WHERE rn = 1;



/* =====================================================
   15. EXISTS vs IN (FILTERING PATTERN)
   ===================================================== */
-- Topic: Subquery filtering
-- Usecase: Find employees belonging to valid departments

SELECT e.*
FROM employees e
WHERE EXISTS (
    SELECT 1
    FROM departments d
    WHERE d.id = e.department_id
);