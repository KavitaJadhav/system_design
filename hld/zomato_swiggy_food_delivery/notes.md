https://www.youtube.com/watch?v=rZyAgZuuZiA

Detailed notes on the system design for a food delivery application like Zomato, Swiggy, or Uber Eats are provided below based on the source:

### **1. Requirements Gathering**
*   **Functional Requirements:**
    *   **User Provisioning:** Sign up and login capabilities.
    *   **Discovery:** View nearby open restaurants and search for specific menus or restaurants.
    *   **Ordering:** View menus, add multiple items to a cart, and place orders via successful payment.
    *   **Fulfillment:** Restaurants accept and prepare orders; delivery partners are allocated for pickup and delivery.
    *   **Tracking:** Provide real-time location updates and order status to the user.
*   **Non-Functional Requirements:**
    *   **Scale:** Support for approximately **50 million users** and **1 million restaurants**.
    *   **CAP Theorem Application:** The system favors **availability** for searching and browsing (showing nearby restaurants) and **consistency** for payments and order placement.
    *   **Architecture:** A **microservices** or distributed architecture is necessary to handle the high traffic volume.

### **2. Core Entities & API Design**
*   **Core Entities:** User, Restaurant, Food Menu/Item, Delivery Agent, and Payment Module.
*   **Key Public APIs:**
    *   `POST /register`: Onboards users with metadata (name, email, address).
    *   `GET /restaurants`: Returns nearby restaurants using **latitude, longitude, and radius** parameters with pagination.
    *   `GET /restaurant/{id}/menu`: Retrieves food items available at a specific restaurant.
    *   `POST /cart`: Adds items (food ID and quantity) to a specific **restaurant-based cart**.
    *   `POST /order`: Initiates the checkout process and returns an Order ID.
    *   `GET /track/{orderId}`: Provides real-time status (prepared, dispatched, etc.).

### **3. High-Level Architecture (HLD)**
The system involves three major actors: the **User**, the **Restaurant**, and the **Delivery Agent**.
*   **API Gateway & Load Balancer:** Handles authentication, authorization, rate limiting, and routing traffic using algorithms like **Round Robin**.
*   **Primary Services:**
    *   **User Service:** Manages user onboarding and session management (JWT tokens).
    *   **Search Service:** Queries restaurant data based on user location and search terms.
    *   **Cart & Order Services:** Handles the selection of items and the multi-step checkout process.
    *   **Payment Gateway:** Third-party integration to handle financial transactions.
    *   **Delivery Matching Service:** Logic to find and assign nearby delivery partners.
    *   **Location Update Service:** Receives frequent geographical pings from delivery agents.

### **4. Deep Dive & Low-Level Design (LLD)**
*   **Search & Discovery:**
    *   Uses **Elastic Search** for high-performance searching by title and location.
    *   A **CDC (Change Data Capture) pipeline** syncs data from the relational Restaurant DB to Elastic Search in a document format.
    *   **S3 Buckets** (Blob storage) store high-resolution images of restaurants and food items.
*   **Relational Databases:**
    *   **User/Restaurant/Order DBs:** Typically use **PostgreSQL or MySQL** to maintain complex relationships and ensure data integrity.
    *   **Cart Logic:** Carts are restaurant-specific; switching restaurants clears the current cart to prevent multi-restaurant orders.
*   **Event-Driven Order Workflow:**
    *   The **Order Service** uses a **Kafka broker** to manage asynchronous tasks.
    *   Once a payment is successful, events are published to topics for:
        1.  Updating the **Order Database**.
        2.  Triggering the **Notification Service** for the user.
        3.  Alerting the **Restaurant Acceptance Service** to get confirmation from the kitchen.
*   **Delivery Logistics:**
    *   **Proximity Search:** Uses **Geohashing** to find the nearest idle drivers.
    *   **Real-time Tracking:** Drivers update their location every 5–10 seconds.
    *   To handle the massive write load from thousands of drivers, updates go through a **Kafka gateway** to a **Redis cache** with a **TTL (Time To Live)**.
    *   **WebSockets:** A **WebSocket Manager** and Gateway maintain persistent connections to provide the user with live "map" updates of the delivery partner.
    * 