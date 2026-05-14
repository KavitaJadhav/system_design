https://www.youtube.com/watch?v=hLvB2haod5w&t=3227s

This report provides detailed notes on designing a distributed job scheduler, such as Airflow or Celery, based on the provided source.

### **1. Requirements Gathering**
To design a system at scale, it is essential to first define the scope through functional and non-functional requirements.

#### **Functional Requirements**
*   **Create and Schedule Jobs:** Users can schedule jobs to run immediately, at a specific future time, or as recurring cron jobs.
*   **Monitoring Dashboard:** A platform for users to track job success, failure, and specific error reasons in real-time.
*   **Job Manipulation:** Users must be able to update, reschedule, or cancel jobs, even if they are already running.

#### **Non-Functional Requirements**
*   **Scalability:** The system must handle high peak traffic, supporting approximately **10,000 concurrent jobs per second**.
*   **High Availability:** Using the CAP theorem, the system prioritizes availability over strict consistency. It follows an **eventual consistency** model, meaning a one-to-two-second delay in job visibility on the dashboard is acceptable.
*   **At-Least-Once Execution:** The system must guarantee that every scheduled job runs at least once.
*   **Low Latency:** Jobs should be picked up for execution within **2 seconds** of their scheduled time.

---

### **2. Core Entities and API Design**
The core entities of the system include the **Job** (the task), the **Scheduler** (timing logic), and the **Executor** (the component that runs the task).

#### **Public REST APIs**
*   `POST /v1/job`: Create or schedule a job; returns a `job_id`.
*   `GET /v1/job/{id}`: Retrieve job metadata.
*   `GET /v1/job/{id}/status`: Monitor the real-time status of a job.
*   `PUT /v1/job/{id}`: Update metadata or the scheduled time.
*   `DELETE /v1/job/{id}`: Cancel a job.
*   `POST /v1/job/{id}/run`: Manually trigger a job to run immediately.

---

### **3. System Architecture (High-Level and Low-Level)**
The system is built using a microservices architecture to distribute responsibility and handle scale.

#### **Component Breakdown**
*   **API Gateway & Load Balancer:** Handles authentication, rate limiting, and routing traffic to backend services.
*   **Job Service & Search Service:** The Job Service handles write/edit operations (create, update, delete), while a separate Search Service handles read requests for job metadata and status to improve performance.
*   **Kafka Broker:** Acts as an ingestion buffer. Instead of writing directly to the database, the Job Service pushes requests to Kafka, which a Consumer Service then processes to update the DB, making the system resilient to traffic spikes.
*   **Watcher Service:** A critical "watcher" that scans the Job DB every 20 seconds. It fetches all jobs scheduled for the next 5 minutes (a sliding window) and pushes them into a Kafka "run" queue.
*   **Job Consumer & Executor Service:** The Consumer pulls jobs from the Kafka run queue and hands them to Workers/Executors. The Executor is where the actual code (Python scripts, Docker images, etc.) runs.

---

### **4. Database Schema (PostgreSQL)**
The source recommends a relational database like PostgreSQL for storing flat job information.

*   **Job Table:** Stores metadata, including `job_id`, `name`, `schedule_type` (cron/immediate), `status` (paused/scheduled), `schedule_time`, `cron_expression`, `payload`, and `max_retries`.
*   **Job Run Table:** Tracks individual executions. Attributes include `job_id`, `status` (queued, running, success, failed), `start_time`, `end_time`, `modified_time`, `executor_id`, and `attempt_number`.

---

### **5. Key Workflows and Edge Case Handling**

#### **Failure & Retries**
*   **Failed Job Execution:** If a job fails, the Executor notifies Kafka. The job is pushed to a **Retry Topic**, and the Consumer attempts a re-trigger until the `max_retries` count is reached. If it continues to fail, it is moved to a **Dead Letter Queue (DLQ)**.
*   **Dead Executor Detection:** Executors update the `modified_time` in the Job Run table every 10 seconds while a job is running. If the Watcher Service finds a job in "Running" status with a `modified_time` older than 15 seconds, it assumes the executor server died and re-triggers the job.

#### **Canceling Running Jobs**
Because jobs are distributed, the system uses a **Redis cache** to store cancel requests. Running executors poll this cache every 10 seconds. If a cancel entry exists for their current job, they stop execution immediately.

#### **Optimization & Race Conditions**
*   **Immediate Jobs:** If a user schedules a job to run "now" or within a very short window (e.g., under 1 minute), the Job Service bypasses the Watcher Service and pushes it directly to the Kafka run queue.
*   **DB Performance:** The Job DB should be **partitioned by schedule time** and **indexed by job ID** to facilitate fast lookups by the Watcher Service.
*   **Kafka Constraint:** Kafka's FIFO nature can delay immediate jobs if many future jobs are already queued. Alternatives like **Redis Sorted Sets** or **Amazon SQS** can be used to ensure jobs execute exactly on time by sorting entries by timestamp.