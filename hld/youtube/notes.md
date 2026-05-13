https://www.youtube.com/watch?v=IUrQ5_g3XKs&list=PL5q3E8eRUieWtYLmRU3z94-vGRcwKr9tM&index=9
https://www.youtube.com/watch?v=IUrQ5_g3XKs&list=PL5q3E8eRUieWtYLmRU3z94-vGRcwKr9tM&index=10

IMPORTANT
 - Video chunking at upload
 - Video chunking at download - for adaptive bit rate
 - Store manifest file i s3 - it will have chunks info.. and store reference in db



### **System Design Framework**
The interview follows a structured framework to ensure all aspects of the system are covered:
1.  **Requirements:** Define functional and non-functional needs.
2.  **Core Entities:** Identify the "nouns" or data to be persisted.
3.  **API:** Define the contract between the user and the system.
4.  **High-Level Design:** Satisfy functional requirements with a simple architecture.
5.  **Deep Dives:** Address non-functional requirements like scale, latency, and reliability.

---

### **1. Requirements and Scale**
*   **Functional Requirements:** Users must be able to **upload videos** and **watch/stream videos**.
*   **Scale Estimates:**
    *   **1 million uploads** per day.
    *   **100 million daily active users** (DAU).
    *   **Max video size:** 256 GB (approx. 12 hours).
*   **Non-Functional Requirements:**
    *   **Availability over Consistency:** It is acceptable if a video uploaded in one region takes a few minutes to appear globally.
    *   **Low Latency Streaming:** Aim for "first pixels" on the screen in under **500 milliseconds**, even in low bandwidth environments.
    *   **Scalability:** The system must handle the defined upload and view volumes.

---

### **2. Core Entities and API**
*   **Entities:**
    *   **User:** Information about the person uploading or watching.
    *   **Video (Raw Bytes):** The actual video file data.
    *   **Video Metadata:** Title, description, and settings.
*   **API Endpoints:**
    *   `POST /videos`: Initially used for small videos, later modified for large uploads.
    *   `GET /videos/{id}`: Returns metadata and the video stream.

---

### **3. The Upload Path (Handling Large Files)**
To handle **256 GB videos**, a standard POST request is insufficient due to API Gateway limits (e.g., AWS has a 10MB limit).
*   **Multi-part Upload:** The client chunks the video and uploads it directly to blob storage (like **S3** or **GCS**) using **pre-signed URLs**.
*   **Asynchronous Processing:** Once the upload is complete, S3 triggers an **S3 Notification**. A worker then updates the video metadata status to "uploaded" and provides the final S3 URL.

---

### **4. The Streaming Path (Latency and Quality)**
Downloading a full 10GB or 256GB file for playback causes massive latency.
*   **Chunking for Playback:** A **chunker** worker breaks the full video into small **2 to