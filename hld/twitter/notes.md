https://www.youtube.com/watch?v=Nfa-uUHuFHg

[//]: # (High scalibility -)

[//]: # (- cloud autoscaling to manage increase/decreased load)

[//]: # (- Message queue )

[//]: # (    - to update follower users timeline when a new tweet is added)

[//]: # (    - Index and update data in elastic search)

[//]: # (- Evantual consistant)

[//]: # ()
[//]: # (Auth service)

[//]: # (- separate from profile service to be able to chanage to managed service in future like aws cognito)

[//]: # (- )

[//]: # ()


This system design for a Twitter clone focuses on a microservices architecture designed to handle hundreds of millions of daily active users with low latency and high availability.

### **1. Requirements Definition**
*   **Functional Requirements:** Users must be able to **create, edit, and delete tweets**, follow other users, and view a **timeline** of tweets from those they follow. Additionally, the system must support **likes, replies, retweets**, and a **search** function.
*   **Non-Functional Requirements:** The system targets **99.99% uptime**, high throughput for frequent read/write operations, and **incredibly low latency** to ensure a snappy user experience.

### **2. High-Level Architecture**
*   **Client & Load Balancing:** Requests from web and mobile apps (iOS/Android) hit a **Layer 7 load balancer** using a **round-robin routing algorithm**. A Layer 7 balancer is preferred because it can make content-based routing decisions.
*   **API Gateway:** This serves as the entry point for the **microservices architecture**, forwarding requests to the appropriate independent services.

### **3. Core Services and Data Storage**
*   **Tweet CRUD Service:** Handles the lifecycle of a tweet. Tweets are stored in a **NoSQL document database** (like MongoDB) as JSON objects, which avoid complex joins and allow for rapid read/write operations.
*   **Media Storage:** All media attachments (images, videos) are stored in an **Object Store like Amazon S3**, while the Tweet document stores only the reference link.
*   **Reply CRUD Service:** Replies are stored in a **separate document store** to allow the service to scale independently and prevent individual tweet documents from becoming too large and unwieldy.
*   **Search Service:** Uses **Elasticsearch** to provide full-text search capabilities with low latency. Data is synced from the primary database to Elasticsearch using **Change Data Capture (CDC)**.
*   **Profile & Social Graph:** User profile data is stored in a **SQL database** for structured attributes and ACID compliance. **Follower connections** are stored in a **Graph Database**, which is optimized for mapping social networks and recommendation systems.

### **4. Timeline Generation (Fan-out Strategy)**
The timeline service is the most complex component and uses a **hybrid approach** to balance performance:
*   **Fan-out on Write (for average users):** When a user tweets, it is placed on a **message queue**. Workers then update the **timeline cache** of every follower. This makes reading the timeline "lightning fast" because the data is pre-prepared.
*   **Fan-out on Read (for "Mega Influencers"):** For users with millions of followers, updating every cache immediately would overwhelm the system. Instead, their tweets are fetched and integrated into a follower's feed only when that follower specifically requests their timeline.

### **5. Performance and Optimization**
*   **Caching:** A **Redis or Memcached** layer is added to the read path to serve popular tweets quickly without hitting the database.
*   **CDN:** Static content, media assets, and frequently accessed tweets are distributed via a **Content Delivery Network (CDN)** to place content geographically closer to users and reduce latency.
*   **Rate Limiting:** Implemented on the right path (API Gateway) to prevent bot activity and **DDOS attacks**.

### **6. Security, Monitoring, and Testing**
*   **Security:** Includes an **Auth Service** for authentication/authorization, **encryption at rest and in transit** (HTTPS), and input validation to prevent SQL injection or cross-site scripting.
*   **Monitoring:** System health is tracked via **Prometheus and Grafana**. Centralized logging is handled by an **ELK stack** (Elasticsearch, Logstash, Kibana), and real-time alerts are managed through tools like **PagerDuty**.
*   **Testing:** The system undergoes **load testing** for new features and automated **unit and integration tests** via CI/CD tools like Jenkins or GitHub Actions. Regular **backup and recovery testing** is also required to ensure data integrity.