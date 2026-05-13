https://www.youtube.com/watch?v=_UZ1ngy-kOI

These detailed notes for designing a system like **Dropbox or Google Drive** are based on the system design interview breakdown provided in the sources.

### **1. Core Requirements**
The design focuses on three primary **functional requirements**:
*   **File Upload/Download:** Users must be able to upload files to and download them from remote storage.
*   **Automatic Syncing:** Files should automatically sync across all connected devices (e.g., local folder changes are reflected in remote storage and vice versa).
*   **Out of Scope:** Designing a custom blob storage system (like S3) is considered out of scope; existing cloud solutions should be utilized.

**Non-Functional Requirements** (qualities of the system):
*   **Availability over Consistency (CAP Theorem):** It is acceptable for a user to see an older version of a file briefly (eventual consistency) as long as the system remains highly available for downloads and views.
*   **Low Latency:** Uploads and downloads should be as fast as possible.
*   **Large File Support:** The system should support files up to **50 GB**.
*   **Resumable Uploads:** If an upload is interrupted, users should be able to pick up where they left off.
*   **High Data Integrity:** Sync accuracy must be high so that file states eventually match across all folders and remote storage.

---

### **2. Core Entities and Data Model**
The system relies on a few central objects that are persisted and exchanged via APIs:
*   **File:** The raw bytes stored in blob storage (e.g., AWS S3).
*   **File Metadata:** Stored in a database (SQL or NoSQL like DynamoDB) containing:
    *   File ID, Name, Mime Type, and Size.
    *   Owner ID (foreign key to a User table).
    *   **S3 Link:** A pointer to the raw bytes in blob storage.
    *   **Timestamps:** Creation and Update times to track changes.
    *   **Chunks:** A list of fingerprints and statuses for each file segment (for large files).
*   **User:** Basic user information and session tokens/JWTs for authentication.

---

### **3. System Architecture and High-Level Design**
The architecture consists of several key components:
*   **Client Application:** A local app on the user's device that monitors a **local folder** for changes using OS-level APIs like `FileSystemWatcher` (Windows) or `FSEvents` (macOS). It maintains a **Local DB** to track file metadata and fingerprints locally.
*   **API Gateway/Load Balancer:** Handles authentication, rate limiting, and routing requests to specific microservices.
*   **File Service:** Manages metadata operations and coordinates the upload/download process.
*   **Sync Service:** Specifically handles "get changes" requests to help clients determine what needs to be updated.
*   **Blob Storage (S3):** Used for cheap, scalable storage of large binary data.

---

### **4. Deep Dive: Handling Large Files & Resumability**
Standard `POST` requests are insufficient for 50 GB files due to gateway size limits (e.g., 10MB) and bandwidth waste. The solution involves:
*   **Chunking:** The client splits large files into smaller segments (e.g., **5 MB chunks**).
*   **Pre-signed URLs:** Instead of sending bytes through the File Service, the service provides a secure, time-limited link from S3. The client uploads chunks **directly to S3**.
*   **Fingerprinting:** Each chunk is hashed to create a unique ID (fingerprint). This allows the system to identify if a specific chunk has already been uploaded, enabling **resumable uploads** by only sending missing fingerprints.
*   **Trust but Verify:** To prevent clients from lying about upload status, the File Service can either verify the upload directly with S3 or use **S3 Notifications** (Change Data Capture) to update metadata automatically.

---

### **5. Deep Dive: Optimization and Consistency**
#### **Low Latency**
*   **Parallelism:** Uploading multiple chunks in parallel maximizes available bandwidth.
*   **Compression:** The client can compress text-based files (like `.txt` or `.docx`) to reduce bytes sent over the network. However, it should skip already compressed media files (like `.jpeg` or `.mp4`) to avoid unnecessary CPU overhead.
*   **CDN:** While CDNs bring data closer to users, they may be unnecessary and expensive for Dropbox unless a specific file is being shared globally and frequently.

#### **Sync Accuracy and Consistency**
*   **Adaptive Polling:** The client periodically checks the Sync Service for changes. The frequency can increase when the user is active in the folder.
*   **Delta Sync:** Instead of downloading a whole 50 GB file when a small change occurs, the client only downloads the **changed chunks** and re-stitches the file locally.
*   **Reconciliation (Recon):** A background process that periodically (e.g., weekly) compares the local folder/DB against the remote storage to fix any inconsistencies caused by bugs or connection issues.
*   **Event Bus (Optional):** Using a tool like Kafka with a **sync cursor** can provide an audit trail and version control, though it may be overkill for a basic sync requirement.