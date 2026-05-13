https://www.youtube.com/watch?v=6K6ihHNkO_0

https://www.youtube.com/watch?v=M4lR_Va97cQ

This comprehensive report outlines the design and implementation of a **proximity service**, a system used to find nearby points of interest (like restaurants or gas stations) based on a user's geographic location.

### 1. System Requirements and Scale
To design a robust proximity service, such as one for a business review app like Yelp, the following requirements are established:
*   **Functional Requirements:** Users must be able to search for businesses within a specified radius based on their latitude and longitude. Business owners need **CRUD (Create, Read, Update, Delete)** capabilities, though updates do not need to be real-time.
*   **Non-functional Requirements:** The system requires **low latency** for quick searches and **high availability** to manage traffic spikes.
*   **Estimated Scale:** Based on 100 million daily active users (DAU) making five queries each, the system must handle approximately **5,000 queries per second (QPS)**. While the business metadata (names, reviews) may reach the low terabyte range, the core geospatial index for 200 million businesses is relatively tiny, estimated at only **5–6 gigabytes**.

### 2. High-Level Architecture
The system is divided into two primary stateless services behind a **load balancer**:
*   **Location-Based Service (LBS):** This is the core component that handles high-volume, read-heavy search queries (5,000 QPS) to find nearby businesses quickly.
*   **Business Service:** This service manages the CRUD operations for business information. Because data changes infrequently, it is a strong candidate for **caching**.
*   **Database Topology:** A **primary-secondary setup** is recommended. The primary database handles writes, while multiple read replicas manage the heavy search load.

### 3. Geospatial Indexing Techniques
Standard database indexing on separate latitude and longitude columns is inefficient because it requires intersecting two massive datasets, often resulting in slow table scans. Effective designs map two-dimensional data into a one-dimensional searchable index.

#### A. Geohashing (Recommended for Scale)
Geohash reduces location data into a searchable string of letters and digits.
*   **How it Works:** The world is recursively divided into quadrants, with bits assigned to each (e.g., 00, 01, 10, 11). This binary sequence is then encoded—Source 1 highlights **base32 encoding**, while Source 2 mentions **base64**.
*   **Precision Levels:** For most proximity services, a precision level of **4 to 6** is ideal, covering radii from 0.5km to 20km.
*   **Boundary Edge Cases:** Two locations physically close to each other might have different prefixes if they fall on opposite sides of a quadrant boundary. The solution is to fetch results from the user's current grid plus its **eight neighboring grids**.
*   **Pros:** It is simple to implement in any relational database using a `LIKE` operator (e.g., `WHERE geohash LIKE 'abc%'`).

#### B. Quad Trees
A Quad Tree is an in-memory data structure that partitions 2D space by recursively subdividing quadrants until a leaf node contains a specific number of businesses (e.g., 100).
*   **Challenges:** Unlike Geohashing, Quad Trees are **difficult to maintain** and balance. Since businesses are not uniformly distributed, some nodes become very deep (densely populated areas), while others remain empty.
*   **Operational Constraints:** Updates require rebuilding the tree in memory, and servers must maintain multiple copies (read and write) to stay operational. Therefore, it is generally **not recommended** for real-world production compared to other methods.

#### C. Specialized Database Solutions
*   **PostGIS (PostgreSQL):** An extension that allows for direct geospatial queries in SQL using functions like `ST_DWithin`.
*   **Elasticsearch:** Offers "plug and play" geospatial search capabilities by default.
*   **Recommendation:** Use Geohash for simple location searches (like finding drivers), but opt for PostGIS or Elasticsearch if the search requires **fuzzy text matching** alongside location (e.g., searching for "McDonald's" nearby).

### 4. Data Schema and Query Flow
The geospatial index table should be kept lean to ensure it fits in memory:
*   **Schema:** At its core, the table needs only `geohash` and `business_id`. A compound key of both makes removals efficient.
*   **Query Lifecycle:**
    1.  The LBS receives a latitude/longitude and radius.
    2.  The service calculates the appropriate Geohash and its eight neighbors.
    3.  The database returns the `business_id`s and coordinates for those grids.
    4.  The service calculates the exact distance, ranks the results, and returns them to the user.