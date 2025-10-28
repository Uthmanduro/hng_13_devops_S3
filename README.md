> **Blue/Green Node.js Service Deployment using **Nginx Upstreams**, **Docker Compose**, and **Automatic Failover\*\*.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Endpoints](#-endpoints)
- [Project Structure](#-project-structure)
- [Environment Variables](#-environment-variables)
- [Setup & Usage](#️-setup--usage)

---

## 🎯 Overview

This project demonstrates a **Blue/Green deployment pattern** using **Nginx** as a load balancer in front of two identical Node.js applications — Blue (active) and Green (standby).

The configuration ensures:

- **Automatic failover** if the active instance becomes unhealthy.
- **Zero downtime** for clients (Nginx retries within the same request).
- **Manual switch** between Blue and Green using environment variables.
- **Preservation of app headers** (`X-App-Pool`, `X-Release-Id`).

---

## 🌐 Endpoints

| Method | Endpoint                  | Description                     |
| ------ | ------------------------- | ------------------------------- |
| `GET`  | `/version`                | Returns app version and headers |
| `GET`  | `/healthz`                | Health/liveness probe           |
| `POST` | `/chaos/start?mode=error` | Simulates failure               |
| `POST` | `/chaos/stop`             | Stops simulated failure         |

---

## 🧩 Project Structure

├── docker-compose.yml
├── .env.example
├── nginx/
│ ├── nginx.conf.template
│ └── docker-entrypoint.sh
├── README.md
└── DECISION.md (optional)

---

## ⚙️ Environment Variables

Copy `.env.example` → `.env` and configure:

| Variable           | Description                              | Example                 |
| ------------------ | ---------------------------------------- | ----------------------- |
| `BLUE_IMAGE`       | Docker image for Blue instance           | `ghcr.io/org/app:blue`  |
| `GREEN_IMAGE`      | Docker image for Green instance          | `ghcr.io/org/app:green` |
| `ACTIVE_POOL`      | Which pool is active (`blue` or `green`) | `blue`                  |
| `RELEASE_ID_BLUE`  | Release identifier for Blue              | `v1.0.0-blue`           |
| `RELEASE_ID_GREEN` | Release identifier for Green             | `v1.0.0-green`          |
| `PORT`             | Internal Node app port                   | `3000`                  |

---

## 🧰️ Setup & Usage

### 1️⃣ Clone the repository

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>

cp .env.example .env

docker compose up -d

docker ps

```
