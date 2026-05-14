https://www.youtube.com/watch?v=Yv9q8d11Y7k&t=1s

This scalable notification system is designed to handle industrial-level traffic, supporting approximately **one million notifications per minute** across various channels like SMS, Email, and Push notifications.

### **1. Core Requirements**
The system is built to satisfy both functional needs for users and non-functional needs for high-scale performance.

*   **Functional Requirements:**
    *   **Multi-channel Support:** Email, SMS, and in-app push notifications.
    *   **Notification Types:** Real-time notifications (e.g., OTPs) and scheduled notifications (e.g., promotional activities).
    *   **Templating:** A system for clients to create fixed templates where variables (like a user's name or a specific product) are dynamically injected.
    *   **Status Tracking:** A dashboard for clients to monitor if a notification is pending, sent, or delivered.
    *   **User Preferences:** End users can opt-in or opt-out of specific notification channels (e.g., receive email but not SMS).

*   **Non-Functional Requirements:**
    *   **High Availability over Consistency:** Based on the CAP theorem, the system prioritizes being available. Eventual consistency is acceptable for template updates or preference changes.
    *   **Latency:** Critical notifications like OTPs must be **near real-time**, while promotional messages can tolerate a **5–10 second delay**.
    *   **Durability:** The system must ensure that once a notification is accepted, it is not lost due to system failures.

---

### **2. System Entities and API Design**
The system distinguishes between **Clients** (organizations like Amazon/Uber) and **Users** (the individuals receiving notifications).

*   **Key Entities:** User, Client, Notification Preference, Content, Template, and Delivery Status.
*   **Major API Endpoints:**
    *   `POST /template`: To create and save notification templates.
    *   `POST /notification`: To trigger a notification. It requires a `template_id`, `recipient_id`, `variables` for the persona, `channel` (SMS/Email/Push), `priority` (High/Medium/Low), and an optional `schedule` timestamp.
    *   `POST /user/preference`: Allows users to set their channel preferences.

---

### **3. High-Level Architecture**
The architecture uses a **microservices approach** to handle scale.

*   **API Gateway & Load Balancer:** Handles authentication, authorization, routing, and **rate limiting** to prevent system abuse.
*   **Template Service:** Manages the creation and versioning of notification templates stored in a **Template DB** (Postgres or NoSQL).
*   **User Preference Service:** Manages user settings. It uses a **Kafka broker** to buffer preference changes, which a consumer then writes to the **User Preference DB** to handle high write volumes.
*   **Notification Service:** The core module that receives requests from clients and orchestrates the delivery flow.

---

### **4. Deep Dive: Scalable Delivery Flow**
To prevent bottlenecks, the system uses a **Kafka-based "Notification Queue"** to decouple the notification service from the delivery providers.

*   **Topic Segregation:** Notifications are categorized in Kafka topics based on **Priority** (Critical, Standard, Promotional) and **Channel** (Email, SMS, Push). This results in 9 distinct combinations (e.g., Critical-SMS, Promotional-Email) to ensure different traffic types don't interfere with each other.
*   **Notification Providers:** Specialized consumer services (SMS Provider, Email Provider, In-app Provider) read from specific Kafka topics and interact with third-party services like **Twilio/MSG91** (SMS), **SendGrid/SES** (Email), or **FCM/APNS** (Push).
*   **Ensuring Durability (The Outbox Pattern):**
    *   For standard/promotional messages, the Notification Service writes to an **Outbox Table** and a **Notification DB** first.
    *   A **CDC (Change Data Capture) pipeline** then moves these records to Kafka. This ensures that even if Kafka goes down, the message is safely persisted in the database.
*   **Optimizing for OTP (Low Latency):** Because OTPs are time-sensitive, they **bypass the Outbox/CDC flow** and are pushed directly to Kafka to minimize latency. If an OTP is lost, the user can simply request a retry.

---

### **5. Reporting and Optimization**
*   **User Preference Cache:** To avoid expensive database lookups for every notification, providers check a **Redis cache** to see if a user has opted out of a channel.
*   **Reporting Service:** Fetches the final status of notifications from the **Notification DB**.
*   **Analytics (Notification Event DB):** Uses a **BigQuery** table to store micro-level status changes (scheduled → sent → delivered) for detailed tracking.
*   **Webhooks:** External providers (like Twilio) use webhooks to send delivery confirmations back to the system, which are then processed via a **Delivery Status Kafka topic** to update the internal databases.
*   **Rate Limiting:** Implemented at the API Gateway to stop spammers and at the Provider level to ensure the system doesn't exceed the rate limits of third-party external services.
* 