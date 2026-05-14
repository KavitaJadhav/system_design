https://www.youtube.com/watch?v=18Fg5Akhkqw&t=1s

These detailed notes on designing a backend for Tinder are based on the framework provided by a former Meta staff engineer, covering requirements, data modeling, high-level design, and deep dives into scalability and consistency.

### **1. System Requirements**
#### **Functional Requirements**
*   **User Preferences:** Users can set matching criteria such as **age range, gender, and search radius**.
*   **Recommendation Stack:** Users view a stack of potential matches based on their preferences and **current location** (proximity is key).
*   **Swiping:** Users swipe left (no) or right (yes) on profiles.
*   **Matching & Notifications:** If two users swipe right on each other, they match and receive a notification.
*   **Constraint:** The system must **avoid showing repeat profiles** that a user has already swiped on.

#### **Non-Functional Requirements**
*   **Consistency for Swipes:** Prioritize consistency to ensure that mutual matches are identified immediately, triggering the "it's a match" celebration.
*   **Low Latency Stack Loading:** The recommendation stack should load in **under 300ms** to provide a real-time feel.
*   **High Write Throughput:** With approximately 10 million daily active users swiping 100 times a day, the system must handle a peak of roughly **100,000 swipes per second**.

---

### **2. Core Entities & API Design**
#### **Entities**
*   **Profile:** Stores user details and preferences (age, gender, radius).
*   **Swipe:** Records the decision (yes/no) between two users.
*   **Match:** Identifies a mutual "yes" between two users.

#### **Key APIs**
*   `POST /profiles`: Sets user preferences.
*   `GET /stacks`: Retrieves potential matches using current **latitude and longitude**.
*   `POST /swipes/{userId}`: Records a swipe decision. Authentication should be handled via **JWT or session tokens** in the header rather than passing user IDs in the request body.

---

### **3. High-Level Design**
*   **API Gateway:** Handles routing, authentication, and rate limiting.
*   **Profile Service:** Manages user preferences and initial stack generation, typically backed by a **SQL database**.
*   **Swipe Service:** Dedicated service for high-volume swiping. It is separated from the Profile Service because its traffic pattern is much more write-heavy.
*   **Swipe Database:** Uses **Cassandra** due to its high write throughput and linear scalability, as it batches writes to memory before flushing them to disk.
*   **Notification Service:** Uses **APNs (Apple)** or **FCM (Android)** to send asynchronous push notifications to the first person who swiped when a match occurs.

---

### **4. Deep Dives**
#### **Consistency in Swipes**
A challenge arises when two users swipe right simultaneously. In an **eventually consistent** system like Cassandra, they might both check for an inverse swipe, see nothing, and miss the match. Solutions include:
*   **Redis Cache:** Use Redis with **atomic operations** (since it is single-threaded) to track swipes and check for matches instantly before updating the main database.
*   **PostgreSQL with Row-Level Locking:** Switch to a relational database that uses **ACID properties** to lock a single row containing both users' IDs during a swipe, ensuring one update happens at a time.

#### **Geospatial Latency**
Querying latitude and longitude in a standard SQL database is inefficient for 2D data.
*   **Geospatial Indexes:** Use extensions like **PostGIS** for PostgreSQL or a search-optimized database like **ElasticSearch** to handle location-based filtering efficiently.
*   **Pre-computation:** A **Cron job** can pre-compute recommendation stacks nightly and store them in a **Stack Cache** (Redis) for O(1) lookup.

#### **Avoiding Repeat Profiles**
Checking against every historical swipe is data-intensive (~36.5 TB per year).
*   **Bloom Filters:** A space-efficient, probabilistic data structure that can quickly check if a user has likely been seen before, though it may occasionally yield false positives.
*   **Constraint Adjustment:** A "Staff-level" engineering proposal is to **allow repeat profiles after 30–90 days**, which allows the system to clear old cache data and improves the user experience by resurfacing potential matches.

---

### **5. Leveling Expectations for Interviews**
*   **Mid-level:** Focus on basic functional requirements and simple caching.
*   **Senior:** Lead one or two deep dives and explain the trade-offs between different database technologies.
*   **Staff:** Proactively identify consistency issues (like the simultaneous swipe problem) and propose high-level architectural or product-level changes.