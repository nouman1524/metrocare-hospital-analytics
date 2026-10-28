-- =====================================================================
-- MetroCare Hospital Analytics | Star schema (PostgreSQL)
-- 6 tables: 4 dimensions + 2 facts
-- =====================================================================

DROP SCHEMA IF EXISTS metrocare CASCADE;
CREATE SCHEMA metrocare;
SET search_path TO metrocare;

-- ---------------------------------------------------------------------
-- Dimensions
-- ---------------------------------------------------------------------
CREATE TABLE dim_department (
    department_key   INT PRIMARY KEY,
    department_name  VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE dim_doctor (
    doctor_key       INT PRIMARY KEY,
    doctor_name      VARCHAR(80) NOT NULL,
    specialization   VARCHAR(60) NOT NULL,
    department_key   INT NOT NULL REFERENCES dim_department (department_key)
);

CREATE TABLE dim_patient (
    patient_key      INT PRIMARY KEY,
    patient_name     VARCHAR(80) NOT NULL,
    gender           VARCHAR(10) NOT NULL CHECK (gender IN ('Male', 'Female')),
    birth_date       DATE NOT NULL,
    city             VARCHAR(60) NOT NULL,
    has_insurance    BOOLEAN NOT NULL
);

CREATE TABLE dim_date (
    date_key         INT PRIMARY KEY,          -- yyyymmdd
    full_date        DATE NOT NULL UNIQUE,
    year             INT NOT NULL,
    quarter          INT NOT NULL,
    month_num        INT NOT NULL,
    month_name       VARCHAR(10) NOT NULL,
    year_month       CHAR(7) NOT NULL,         -- yyyy-mm (sorts correctly)
    day_of_week_num  INT NOT NULL,             -- 1 = Monday
    day_of_week      VARCHAR(10) NOT NULL,
    is_weekend       BOOLEAN NOT NULL
);

-- ---------------------------------------------------------------------
-- Facts
-- ---------------------------------------------------------------------
CREATE TABLE fact_appointments (
    appointment_key  INT PRIMARY KEY,
    date_key         INT NOT NULL REFERENCES dim_date (date_key),
    patient_key      INT NOT NULL REFERENCES dim_patient (patient_key),
    doctor_key       INT NOT NULL REFERENCES dim_doctor (doctor_key),
    department_key   INT NOT NULL REFERENCES dim_department (department_key),
    status           VARCHAR(12) NOT NULL
                     CHECK (status IN ('Completed', 'Cancelled', 'No-Show'))
);

CREATE TABLE fact_billing (
    billing_key      INT PRIMARY KEY,
    appointment_key  INT NOT NULL UNIQUE REFERENCES fact_appointments (appointment_key),
    date_key         INT NOT NULL REFERENCES dim_date (date_key),
    patient_key      INT NOT NULL REFERENCES dim_patient (patient_key),
    doctor_key       INT NOT NULL REFERENCES dim_doctor (doctor_key),
    department_key   INT NOT NULL REFERENCES dim_department (department_key),
    payment_type     VARCHAR(12) NOT NULL CHECK (payment_type IN ('Insurance', 'Self-Pay')),
    payment_status   VARCHAR(10) NOT NULL CHECK (payment_status IN ('Paid', 'Pending')),
    amount           NUMERIC(10, 2) NOT NULL CHECK (amount >= 0)
);

-- ---------------------------------------------------------------------
-- Indexes on foreign keys (join performance for DirectQuery / refresh)
-- ---------------------------------------------------------------------
CREATE INDEX ix_appt_date    ON fact_appointments (date_key);
CREATE INDEX ix_appt_doctor  ON fact_appointments (doctor_key);
CREATE INDEX ix_appt_dept    ON fact_appointments (department_key);
CREATE INDEX ix_appt_patient ON fact_appointments (patient_key);
CREATE INDEX ix_bill_date    ON fact_billing (date_key);
CREATE INDEX ix_bill_doctor  ON fact_billing (doctor_key);
CREATE INDEX ix_bill_dept    ON fact_billing (department_key);
CREATE INDEX ix_bill_patient ON fact_billing (patient_key);
