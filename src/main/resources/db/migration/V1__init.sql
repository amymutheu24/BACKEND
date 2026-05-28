-- =============================================================
-- KICD Attachment Management System — Full Schema
-- Version  : 1.0.0
-- Engine   : PostgreSQL 16
-- Migration: V1__init.sql  (Flyway single-file baseline)
-- Drop into:  src/main/resources/db/migration/V1__init.sql
-- =============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -------------------------------------------------------------
-- 1. ROLES
-- -------------------------------------------------------------
CREATE TABLE roles (
    role_id     BIGSERIAL   PRIMARY KEY,
    role_name   VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO roles (role_name, description) VALUES
    ('STUDENT',     'Student applying for attachment opportunities'),
    ('COORDINATOR', 'Staff managing opportunities and placements'),
    ('ADMIN',       'System administrator with full access');

-- -------------------------------------------------------------
-- 2. USERS
-- -------------------------------------------------------------
CREATE TABLE users (
    user_id                     BIGSERIAL    PRIMARY KEY,
    public_id                   UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    role_id                     BIGINT       NOT NULL REFERENCES roles(role_id) ON DELETE RESTRICT,
    email                       VARCHAR(255) NOT NULL UNIQUE,
    password_hash               VARCHAR(255) NOT NULL,
    is_active                   BOOLEAN      NOT NULL DEFAULT TRUE,
    is_deleted                  BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at                  TIMESTAMPTZ,
    email_verified              BOOLEAN      NOT NULL DEFAULT FALSE,
    email_verification_token    VARCHAR(255),
    email_token_expires_at      TIMESTAMPTZ,
    failed_login_attempts       INTEGER      NOT NULL DEFAULT 0,
    account_locked_until        TIMESTAMPTZ,
    last_login_at               TIMESTAMPTZ,
    created_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_users_email_format CHECK (email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$')
);

CREATE INDEX idx_users_email     ON users(email)      WHERE is_deleted = FALSE;
CREATE INDEX idx_users_public_id ON users(public_id);
CREATE INDEX idx_users_role_id   ON users(role_id);

-- -------------------------------------------------------------
-- 3. DEPARTMENTS
-- -------------------------------------------------------------
CREATE TABLE departments (
    department_id   BIGSERIAL    PRIMARY KEY,
    public_id       UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    department_name VARCHAR(100) NOT NULL UNIQUE,
    department_code VARCHAR(20)  NOT NULL UNIQUE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_departments_code ON departments(department_code);

INSERT INTO departments (department_name, department_code) VALUES
    ('Information Technology',        'IT'),
    ('Computer Science',              'CS'),
    ('Business Administration',       'BA'),
    ('Communication & Journalism',    'CJ'),
    ('Education',                     'EDU'),
    ('Library & Information Science', 'LIS');

-- -------------------------------------------------------------
-- 4. STUDENTS
-- -------------------------------------------------------------
CREATE TABLE students (
    student_id        BIGSERIAL    PRIMARY KEY,
    public_id         UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id           BIGINT       NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    department_id     BIGINT       REFERENCES departments(department_id) ON DELETE SET NULL,
    admission_number  VARCHAR(50)  NOT NULL UNIQUE,
    first_name        VARCHAR(100) NOT NULL,
    last_name         VARCHAR(100) NOT NULL,
    phone_number      VARCHAR(20),
    date_of_birth     DATE,
    gender            VARCHAR(20)  CHECK (gender IN ('MALE','FEMALE','OTHER','PREFER_NOT_TO_SAY')),
    course_name       VARCHAR(150) NOT NULL,
    year_of_study     INTEGER      NOT NULL CHECK (year_of_study BETWEEN 1 AND 8),
    gpa               DECIMAL(3,2) CHECK (gpa BETWEEN 0.00 AND 4.00),
    bio               TEXT,
    profile_photo_url TEXT,
    profile_completed BOOLEAN      NOT NULL DEFAULT FALSE,
    is_deleted        BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at        TIMESTAMPTZ,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_students_user_id      ON students(user_id);
CREATE INDEX idx_students_admission_no ON students(admission_number);
CREATE INDEX idx_students_department   ON students(department_id);

-- -------------------------------------------------------------
-- 5. COORDINATORS
-- -------------------------------------------------------------
CREATE TABLE coordinators (
    coordinator_id    BIGSERIAL    PRIMARY KEY,
    public_id         UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id           BIGINT       NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    department_id     BIGINT       REFERENCES departments(department_id) ON DELETE SET NULL,
    staff_number      VARCHAR(50)  NOT NULL UNIQUE,
    first_name        VARCHAR(100) NOT NULL,
    last_name         VARCHAR(100) NOT NULL,
    phone_number      VARCHAR(20),
    job_title         VARCHAR(150),
    profile_photo_url TEXT,
    is_deleted        BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at        TIMESTAMPTZ,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_coordinators_user_id ON coordinators(user_id);
CREATE INDEX idx_coordinators_dept    ON coordinators(department_id);

-- -------------------------------------------------------------
-- 6. OPPORTUNITIES
-- -------------------------------------------------------------
CREATE TABLE opportunities (
    opportunity_id       BIGSERIAL    PRIMARY KEY,
    public_id            UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    coordinator_id       BIGINT       NOT NULL REFERENCES coordinators(coordinator_id) ON DELETE RESTRICT,
    department_id        BIGINT       REFERENCES departments(department_id) ON DELETE SET NULL,
    title                VARCHAR(255) NOT NULL,
    company_name         VARCHAR(255) NOT NULL,
    company_website      VARCHAR(500),
    location             VARCHAR(255) NOT NULL,
    location_type        VARCHAR(20)  NOT NULL DEFAULT 'ON_SITE'
                                      CHECK (location_type IN ('ON_SITE','REMOTE','HYBRID')),
    description          TEXT         NOT NULL,
    requirements         TEXT         NOT NULL,
    skills_required      TEXT[],
    min_gpa              DECIMAL(3,2) CHECK (min_gpa BETWEEN 0.00 AND 4.00),
    eligible_years       INTEGER[],
    slots_available      INTEGER      NOT NULL CHECK (slots_available > 0),
    slots_filled         INTEGER      NOT NULL DEFAULT 0 CHECK (slots_filled >= 0),
    application_deadline TIMESTAMPTZ  NOT NULL,
    attachment_start     DATE,
    attachment_end       DATE,
    duration_weeks       INTEGER,
    stipend_amount       DECIMAL(12,2),
    stipend_currency     VARCHAR(10)  DEFAULT 'KES',
    status               VARCHAR(20)  NOT NULL DEFAULT 'DRAFT'
                                      CHECK (status IN ('DRAFT','OPEN','CLOSED','EXPIRED','CANCELLED')),
    view_count           INTEGER      NOT NULL DEFAULT 0,
    is_deleted           BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at           TIMESTAMPTZ,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_slots_filled_lte_available CHECK (slots_filled <= slots_available),
    CONSTRAINT chk_deadline_future            CHECK (application_deadline > created_at),
    CONSTRAINT chk_attachment_dates           CHECK (
        attachment_end IS NULL OR attachment_start IS NULL OR attachment_end > attachment_start
    )
);

CREATE INDEX idx_opportunities_status      ON opportunities(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_opportunities_coordinator ON opportunities(coordinator_id);
CREATE INDEX idx_opportunities_department  ON opportunities(department_id);
CREATE INDEX idx_opportunities_deadline    ON opportunities(application_deadline);
CREATE INDEX idx_opportunities_created_at  ON opportunities(created_at DESC);
CREATE INDEX idx_opportunities_fts         ON opportunities
    USING GIN (to_tsvector('english', title || ' ' || company_name || ' ' || description));

-- -------------------------------------------------------------
-- 7. APPLICATIONS
-- -------------------------------------------------------------
CREATE TABLE applications (
    application_id    BIGSERIAL   PRIMARY KEY,
    public_id         UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    student_id        BIGINT      NOT NULL REFERENCES students(student_id) ON DELETE RESTRICT,
    opportunity_id    BIGINT      NOT NULL REFERENCES opportunities(opportunity_id) ON DELETE RESTRICT,
    cover_letter      TEXT,
    status            VARCHAR(30) NOT NULL DEFAULT 'PENDING'
                                  CHECK (status IN ('PENDING','UNDER_REVIEW','APPROVED','REJECTED','WITHDRAWN','PLACED','COMPLETED')),
    remarks           TEXT,
    reviewed_by       BIGINT      REFERENCES coordinators(coordinator_id),
    applied_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at       TIMESTAMPTZ,
    status_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted        BOOLEAN     NOT NULL DEFAULT FALSE,
    deleted_at        TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (student_id, opportunity_id)
);

CREATE INDEX idx_applications_student     ON applications(student_id);
CREATE INDEX idx_applications_opportunity ON applications(opportunity_id);
CREATE INDEX idx_applications_status      ON applications(status);
CREATE INDEX idx_applications_applied_at  ON applications(applied_at DESC);

-- -------------------------------------------------------------
-- 8. PLACEMENTS
-- -------------------------------------------------------------
CREATE TABLE placements (
    placement_id        BIGSERIAL   PRIMARY KEY,
    public_id           UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    application_id      BIGINT      NOT NULL UNIQUE REFERENCES applications(application_id) ON DELETE RESTRICT,
    confirmed_by        BIGINT      NOT NULL REFERENCES coordinators(coordinator_id),
    start_date          DATE        NOT NULL,
    end_date            DATE        NOT NULL,
    supervisor_name     VARCHAR(200),
    supervisor_email    VARCHAR(255),
    supervisor_phone    VARCHAR(30),
    reporting_address   TEXT,
    placement_status    VARCHAR(30) NOT NULL DEFAULT 'PENDING_START'
                                    CHECK (placement_status IN ('PENDING_START','ACTIVE','COMPLETED','CANCELLED')),
    cancellation_reason TEXT,
    confirmed_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_placement_dates CHECK (end_date > start_date)
);

CREATE INDEX idx_placements_application  ON placements(application_id);
CREATE INDEX idx_placements_status       ON placements(placement_status);
CREATE INDEX idx_placements_confirmed_by ON placements(confirmed_by);

-- -------------------------------------------------------------
-- 9. DOCUMENTS
-- -------------------------------------------------------------
CREATE TABLE documents (
    document_id       BIGSERIAL    PRIMARY KEY,
    public_id         UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    student_id        BIGINT       NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    document_type     VARCHAR(50)  NOT NULL
                                   CHECK (document_type IN ('CV','APPLICATION_LETTER','TRANSCRIPT','NATIONAL_ID','OTHER')),
    original_filename VARCHAR(255) NOT NULL,
    stored_filename   VARCHAR(255) NOT NULL UNIQUE,
    storage_path      TEXT         NOT NULL,
    storage_bucket    VARCHAR(100) NOT NULL,
    mime_type         VARCHAR(100) NOT NULL CHECK (mime_type = 'application/pdf'),
    file_size_bytes   BIGINT       NOT NULL CHECK (file_size_bytes <= 2097152),
    checksum_sha256   VARCHAR(64)  NOT NULL,
    virus_scan_status VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                                   CHECK (virus_scan_status IN ('PENDING','CLEAN','INFECTED','FAILED')),
    virus_scan_at     TIMESTAMPTZ,
    is_deleted        BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at        TIMESTAMPTZ,
    uploaded_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_documents_student     ON documents(student_id);
CREATE INDEX idx_documents_type        ON documents(document_type);
CREATE INDEX idx_documents_scan_status ON documents(virus_scan_status);

-- -------------------------------------------------------------
-- 10. NOTIFICATIONS
-- -------------------------------------------------------------
CREATE TABLE notifications (
    notification_id     BIGSERIAL   PRIMARY KEY,
    public_id           UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id             BIGINT      NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    title               VARCHAR(255) NOT NULL,
    message             TEXT        NOT NULL,
    notification_type   VARCHAR(50) NOT NULL
                                    CHECK (notification_type IN (
                                        'ACCOUNT_CREATED','EMAIL_VERIFIED',
                                        'OPPORTUNITY_POSTED',
                                        'APPLICATION_SUBMITTED','APPLICATION_UNDER_REVIEW',
                                        'APPLICATION_APPROVED','APPLICATION_REJECTED',
                                        'PLACEMENT_CONFIRMED','PLACEMENT_STARTED','PLACEMENT_COMPLETED',
                                        'DEADLINE_REMINDER','SYSTEM_ANNOUNCEMENT'
                                    )),
    related_entity_type VARCHAR(50),
    related_entity_id   BIGINT,
    is_read             BOOLEAN     NOT NULL DEFAULT FALSE,
    read_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user    ON notifications(user_id);
CREATE INDEX idx_notifications_unread  ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

-- -------------------------------------------------------------
-- 11. REFRESH TOKENS
-- -------------------------------------------------------------
CREATE TABLE refresh_tokens (
    token_id      BIGSERIAL    PRIMARY KEY,
    user_id       BIGINT       NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token_hash    VARCHAR(255) NOT NULL UNIQUE,
    device_info   VARCHAR(500),
    ip_address    INET,
    issued_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at    TIMESTAMPTZ  NOT NULL,
    revoked       BOOLEAN      NOT NULL DEFAULT FALSE,
    revoked_at    TIMESTAMPTZ,
    revoke_reason VARCHAR(100)
);

CREATE INDEX idx_refresh_tokens_user       ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_hash       ON refresh_tokens(token_hash);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);

-- -------------------------------------------------------------
-- 12. PASSWORD RESET TOKENS
-- -------------------------------------------------------------
CREATE TABLE password_reset_tokens (
    token_id   BIGSERIAL    PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ  NOT NULL,
    used       BOOLEAN      NOT NULL DEFAULT FALSE,
    used_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_prt_user_id    ON password_reset_tokens(user_id);
CREATE INDEX idx_prt_token_hash ON password_reset_tokens(token_hash);

-- -------------------------------------------------------------
-- 13. AUDIT LOGS
-- -------------------------------------------------------------
CREATE TABLE audit_logs (
    log_id           BIGSERIAL    PRIMARY KEY,
    user_id          BIGINT       REFERENCES users(user_id) ON DELETE SET NULL,
    action           VARCHAR(100) NOT NULL,
    entity_type      VARCHAR(100) NOT NULL,
    entity_id        BIGINT,
    entity_public_id UUID,
    old_value        JSONB,
    new_value        JSONB,
    ip_address       INET,
    user_agent       TEXT,
    request_id       UUID,
    outcome          VARCHAR(20)  NOT NULL CHECK (outcome IN ('SUCCESS','FAILURE','PARTIAL')),
    failure_reason   TEXT,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_user_id    ON audit_logs(user_id);
CREATE INDEX idx_audit_entity     ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_created_at ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_action     ON audit_logs(action);

-- -------------------------------------------------------------
-- 14. APPLICATION STATUS HISTORY
-- -------------------------------------------------------------
CREATE TABLE application_status_history (
    history_id     BIGSERIAL   PRIMARY KEY,
    application_id BIGINT      NOT NULL REFERENCES applications(application_id) ON DELETE CASCADE,
    from_status    VARCHAR(30),
    to_status      VARCHAR(30) NOT NULL,
    changed_by     BIGINT      REFERENCES users(user_id),
    remarks        TEXT,
    changed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ash_application ON application_status_history(application_id);
CREATE INDEX idx_ash_changed_at  ON application_status_history(changed_at DESC);

-- -------------------------------------------------------------
-- 15. SYSTEM SETTINGS
-- -------------------------------------------------------------
CREATE TABLE system_settings (
    setting_id    BIGSERIAL    PRIMARY KEY,
    setting_key   VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT         NOT NULL,
    description   TEXT,
    is_public     BOOLEAN      NOT NULL DEFAULT FALSE,
    updated_by    BIGINT       REFERENCES users(user_id),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO system_settings (setting_key, setting_value, description, is_public) VALUES
    ('max_applications_per_student',  '5',               'Maximum concurrent active applications per student', FALSE),
    ('max_file_size_mb',              '2',               'Maximum document upload size in MB',                 TRUE),
    ('allowed_file_types',            'application/pdf', 'Comma-separated MIME types',                         TRUE),
    ('jwt_access_token_expiry_min',   '60',              'Access token expiry in minutes',                     FALSE),
    ('jwt_refresh_token_expiry_days', '30',              'Refresh token expiry in days',                       FALSE),
    ('max_login_attempts',            '5',               'Failed attempts before account lock',                FALSE),
    ('account_lock_duration_min',     '30',              'Account lock duration in minutes',                   FALSE),
    ('notification_email_enabled',    'true',            'Whether email notifications are active',             FALSE),
    ('maintenance_mode',              'false',           'Puts system in read-only maintenance mode',          TRUE),
    ('deadline_reminder_days_before', '3',               'Days before deadline to send reminder',              FALSE);
