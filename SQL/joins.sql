-- employees
-- department_id
-- employee_id
-- salary
-- departments
-- id
-- name

-- Question
-- Fetch employee with department name
select e.employee_id, d.department_id, d.department_name
from employees e
         join departments d on e.department_id = d.id;

-- Departments with total salary > 100000
select department_id, sum(salary) as total
from employees e
group by department_id
having sum(salary) > 100000;

-- Employees earning above department average
-- correlated subquery
select employee_id, salary
from department e
where salary > (select avg(salary) from employees where department_id = e.department_id);

-- window functions (better performance)
SELECT employee_id, department_id, salary
FROM (SELECT employee_id,
             department_id,
             salary,
             AVG(salary) OVER (
            PARTITION BY department_id
        ) AS dept_avg
      FROM employees) t
WHERE salary > dept_avg;


-- Create an index on employees table
create index employees_primary_key on employees (employee_id)

-- ACID transaction
-- Atomicity → all or nothing
-- Consistency → valid state
-- Isolation → no interference
-- Durability → persists after commit
BEGIN;

UPDATE accounts
SET balance = balance - 100
WHERE id = 1;
UPDATE accounts
SET balance = balance + 100
WHERE id = 2;

COMMIT;

-- Locks (Concurrency control)
-- Row-level lock
-- Table-level lock

-- Pagination
-- Fetch page 2 with 10 records
select *
from employees
order by employee_id limit 10
offset 10

-- NULL Handling
SELECT COALESCE(salary, 0)
FROM employees;

-- Categorize salaries
SELECT employee_id,
       CASE
           WHEN salary > 100000 THEN 'High'
           WHEN salary > 50000 THEN 'Medium'
           ELSE 'Low'
           END AS category
FROM employees;


/* =====================================================
   1. TOP N PER GROUP (Top 3 salaries per department)
   ===================================================== */
-- Topic: Window Functions - DENSE_RANK
-- Usecase: Get top 3 highest salaries per department (include ties)

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
   2. NTH HIGHEST SALARY (Overall)
   ===================================================== */
-- Topic: Window Functions - DENSE_RANK
-- Usecase: Find nth highest salary in the company

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
   3. EMPLOYEES ABOVE DEPARTMENT AVERAGE
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
   4. RUNNING TOTAL PER DEPARTMENT
   ===================================================== */
-- Topic: Window Aggregates - Running SUM
-- Usecase: Cumulative salary within each department

SELECT *,
       SUM(salary) OVER (
           PARTITION BY department_id
           ORDER BY employee_id
       ) AS running_total
FROM employees;



/* =====================================================
   5. PREVIOUS ROW COMPARISON
   ===================================================== */
-- Topic: Window Functions - LAG
-- Usecase: Compare salary with previous employee in department

SELECT *,
       LAG(salary) OVER (
           PARTITION BY department_id
           ORDER BY employee_id
       ) AS prev_salary
FROM employees;



/* =====================================================
   6. NEXT ROW COMPARISON
   ===================================================== */
-- Topic: Window Functions - LEAD
-- Usecase: Look ahead to next employee's salary

SELECT *,
       LEAD(salary) OVER (
           PARTITION BY department_id
           ORDER BY employee_id
       ) AS next_salary
FROM employees;



/* =====================================================
   7. EMPLOYEES WITHOUT DEPARTMENT
   ===================================================== */
-- Topic: LEFT JOIN + NULL filtering
-- Usecase: Find employees not assigned to any department

SELECT e.*
FROM employees e
         LEFT JOIN departments d
                   ON e.department_id = d.id
WHERE d.id IS NULL;



/* =====================================================
   8. DEPARTMENTS WITHOUT EMPLOYEES
   ===================================================== */
-- Topic: Anti Join Pattern
-- Usecase: Find departments that have no employees

SELECT d.*
FROM departments d
         LEFT JOIN employees e
                   ON d.id = e.department_id
WHERE e.employee_id IS NULL;



/* =====================================================
   9. EMPLOYEES EARNING MORE THAN THEIR MANAGER
   ===================================================== */
-- Topic: Self Join
-- Usecase: Compare employee salary with manager salary

SELECT e.employee_id, e.salary
FROM employees e
         JOIN employees m
              ON e.manager_id = m.employee_id
WHERE e.salary > m.salary;



/* =====================================================
   10. GROUP BY WITH HAVING
   ===================================================== */
-- Topic: Aggregation + HAVING
-- Usecase: Departments with total salary greater than threshold

SELECT department_id, SUM(salary) AS total_salary
FROM employees
GROUP BY department_id
HAVING SUM(salary) > 100000;



/* =====================================================
   11. DUPLICATE SALARY DETECTION
   ===================================================== */
-- Topic: Aggregation
-- Usecase: Find salaries that appear more than once

SELECT salary, COUNT(*) AS cnt
FROM employees
GROUP BY salary
HAVING COUNT(*) > 1;



/* =====================================================
   12. DIFFERENCE BETWEEN CONSECUTIVE ROWS
   ===================================================== */
-- Topic: Window Functions - LAG
-- Usecase: Salary change compared to previous employee

SELECT *,
       salary - LAG(salary) OVER (
           PARTITION BY department_id
           ORDER BY employee_id
       ) AS salary_diff
FROM employees;



/* =====================================================
   13. RANK VS DENSE_RANK VS ROW_NUMBER
   ===================================================== */
-- Topic: Ranking comparison
-- Usecase: Understand ranking behavior

SELECT *,
       ROW_NUMBER() OVER (PARTITION BY department_id ORDER BY salary DESC) AS row_num,
    RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rnk,
    DENSE_RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS dense_rnk
FROM employees;



/* =====================================================
   14. DEPARTMENT TOTAL SALARY USING WINDOW FUNCTION
   ===================================================== */
-- Topic: Window Aggregation vs GROUP BY
-- Usecase: Show total salary per department without collapsing rows

SELECT *,
       SUM(salary) OVER (PARTITION BY department_id) AS dept_total
FROM employees;



/* =====================================================
   15. FIRST VALUE IN EACH DEPARTMENT
   ===================================================== */
-- Topic: Window Function - FIRST_VALUE
-- Usecase: Get highest salary in department for each row

SELECT *,
       FIRST_VALUE(salary) OVER (
           PARTITION BY department_id
           ORDER BY salary DESC
       ) AS highest_salary
FROM employees;