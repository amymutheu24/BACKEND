# KICD Attachment Management System — Backend

Welcome to the backend repository for the KICD Attachment Management System. This project is built using Spring Boot and PostgreSQL, and it uses Flyway for automated database migrations.

## Local Setup Guide

Follow these steps to set up the backend on your local machine. You only need to do this once; the application manages database migrations automatically after the initial setup.

### Prerequisites

Make sure you have the following installed:
- **Java 17+**
- **PostgreSQL 16** — [Download here](https://www.postgresql.org/download/)
- **Maven** (or simply use the `./mvnw` wrapper included in the project)

### Step 1: Create the Database

Open **psql**, **pgAdmin**, or **DBeaver** and run the following command to create the database:

```sql
CREATE DATABASE kicd_db;
```

> **Note:** You only ever run this command once. All tables, roles, and seed data are generated automatically when the application starts.

### Step 2: Configure Database Credentials

Open `src/main/resources/application-dev.yml` and update the `username` and `password` properties to match your local PostgreSQL credentials:

```yaml
spring:
  datasource:
    username: postgres     # ← change to your local postgres username
    password: postgres     # ← change to your local postgres password
```
*(The default username and password for a local PostgreSQL installation are usually both `postgres`.)*

### Step 3: Run the Application

Start the application with the `dev` profile active.

**Using the Maven Wrapper (Recommended):**
```bash
# On Linux/macOS
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev

# On Windows
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=dev"
```

**Using IntelliJ IDEA:**
1. Go to `Run > Edit Configurations`
2. Find your Spring Boot run configuration
3. Under `Active profiles`, type `dev`
4. Click Run

### What happens on startup?

When the application starts, you should see Flyway executing the database migrations in the console logs. Flyway will automatically create all **15 tables** and insert the required seed data (e.g., Roles, Departments, and System Settings).

Once the application is running, the REST API endpoints are ready for testing using Postman or any other API client.

## Troubleshooting

- **App fails to start with `Connection refused`**: Ensure your local PostgreSQL service is running.
- **`database "kicd_db" does not exist`**: You skipped Step 1. Run the `CREATE DATABASE kicd_db;` command and restart the application.
- **`password authentication failed for user "postgres"`**: Your credentials in `application-dev.yml` are incorrect. Update them and try again.