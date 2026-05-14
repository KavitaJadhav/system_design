https://www.youtube.com/watch?v=yz1jtze4qr8


Based on the source provided, here are the detailed notes for designing a system like Yelp at a senior engineer level:

### **1. Requirements**
*   **Functional Requirements:**
    *   Users must be able to **search for businesses** by name, category, and location (latitude/longitude).
    *   Users should be able to **view a business page** containing details and its corresponding reviews.
    *   Users can **leave a review**, which includes a mandatory 1-to-5 star rating and optional text.
    *   **Scale:** The system must support **100 million daily active users (DAU)** and **10 million businesses**.
    *   **Constraint:** Each user is restricted to one review per business.
*   **Non-Functional Requirements:**
    *   **High Availability over Strong Consistency:** It is acceptable for a new review or business description to take a few minutes to propagate across the globe rather than failing the request to ensure perfect consistency.
    *   **Low Latency Search:** Search results should ideally return in **less than 500 milliseconds**.
    *   **Scalability:** The system must handle the specified high traffic and data volume.

### **2. Core Entities**
The primary nouns or database tables for the system include:
*   **Business:** Contains ID, name, description, address, latitude, longitude, and category.
*   **Review:** Contains ID, user ID, business ID, rating, text, and a "created at" timestamp.
*   **User:** Contains ID and other standard account settings like hashed passwords.

### **3. API Design (REST)**
*   **`GET /businesses` (Search):** Uses query parameters for category, location, and name. It includes **pagination** (page and limit) to handle large result sets.
*   **`GET /businesses/:id`:** Retrieves specific business details.
*   **`GET /businesses/:id/reviews`:** Retrieves reviews for a business, paginated to allow for **lazy loading** on the client side.
*   **`POST /businesses/:id/reviews`:** Creates a new review; this endpoint requires **authentication**.

### **4. High-Level Design (HLD)**
*   **Architecture:** A client communicates through an **API Gateway**, which handles authentication and routes requests to specific microservices.
*   **Services:**
    *   **Business Service:** Handles search and metadata retrieval.
    *   **Review Service:** Manages the creation and retrieval of reviews.
*   **Database:** A relational database like **PostgreSQL** is recommended because of the direct relationships between businesses and reviews and the manageable size of 10 million business records.

### **5. Deep Dives & Optimizations**
*   **Calculating Average Ratings:** To keep ratings accurate "up to the minute," updates are performed within a **database transaction**. When a new review is added, the service updates the total number of ratings and recalculates the average rating on the business row atomically.
*   **Concurrency Control:** To prevent race conditions when multiple users review the same business simultaneously, the system can use **row locking (pessimistic locking)** or **Optimistic Concurrency Control (OCC)**.
*   **Ensuring One Review Per User:** While the client and application service should have logic to prevent duplicate submissions, the source emphasizes placing a **composite unique constraint** on `(user_id, business_id)` at the database level to ensure data integrity.
*   **Geospatial Search Optimization:** Instead of introducing a complex external search engine like ElasticSearch, the source recommends using PostgreSQL extensions:
    *   **PostGIS:** For efficient geospatial indexing of latitude and longitude.
    *   **Full Text Search:** To handle complex name and category queries with Gin or inverted indexes.
    *   This approach avoids the operational overhead of **Change Data Capture (CDC)** and maintaining consistency between two different data stores.
