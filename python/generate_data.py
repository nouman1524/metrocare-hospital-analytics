"""Generate synthetic MetroCare hospital data as CSV files (star-schema shaped).

Deterministic (seeded) so every run produces the same ~3,850 records:
    8 departments + 40 doctors + 500 patients + 731 dates
    + 1,500 appointments + 1,071 bills = 3,850
All data is fictional; no real patient information is used.

Usage:
    python python/generate_data.py            # writes to ./data
    python python/generate_data.py --out some/dir
"""
import argparse
import csv
import random
from datetime import date, timedelta
from pathlib import Path

SEED = 42
N_PATIENTS = 500
N_APPOINTMENTS = 1500
N_COMPLETED = 1071
N_CANCELLED = 270
N_NO_SHOW = N_APPOINTMENTS - N_COMPLETED - N_CANCELLED  # 159
DOCTORS_PER_DEPT = 5
START, END = date(2024, 1, 1), date(2025, 12, 31)

# department -> (specialization, (min bill, max bill))
DEPARTMENTS = {
    "Cardiology": ("Cardiologist", (250, 900)),
    "Orthopedics": ("Orthopedic Surgeon", (300, 1100)),
    "Pediatrics": ("Pediatrician", (80, 250)),
    "Neurology": ("Neurologist", (280, 950)),
    "Oncology": ("Oncologist", (400, 1500)),
    "Emergency": ("Emergency Physician", (200, 1200)),
    "Dermatology": ("Dermatologist", (90, 320)),
    "General Medicine": ("General Physician", (60, 200)),
}

FIRST_NAMES = [
    "Ayesha", "Ali", "Fatima", "Hassan", "Zainab", "Usman", "Maryam", "Bilal",
    "Sana", "Hamza", "Hira", "Omar", "Noor", "Ahmed", "Iqra", "Saad", "Laiba",
    "Daniyal", "Mehwish", "Farhan", "Amna", "Kamran", "Rabia", "Imran", "Sidra",
]
LAST_NAMES = [
    "Khan", "Ahmed", "Malik", "Hussain", "Sheikh", "Butt", "Raza", "Qureshi",
    "Iqbal", "Siddiqui", "Chaudhry", "Mirza", "Ansari", "Javed", "Nawaz",
]
CITIES = ["Rawalpindi", "Islamabad", "Lahore", "Karachi", "Peshawar", "Faisalabad", "Multan"]
DOC_PREFIX = "Dr."


def name(rng):
    return f"{rng.choice(FIRST_NAMES)} {rng.choice(LAST_NAMES)}"


def write_csv(path, header, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"  {path.name:<22} {len(rows):>5} rows")


def main(out_dir: Path):
    rng = random.Random(SEED)
    out_dir.mkdir(parents=True, exist_ok=True)

    # ---- dim_department -------------------------------------------------
    dept_names = list(DEPARTMENTS)
    dim_department = [(i + 1, n) for i, n in enumerate(dept_names)]
    dept_key = {n: k for k, n in dim_department}

    # ---- dim_doctor -----------------------------------------------------
    dim_doctor, doctor_dept = [], {}
    dk = 1
    for dept in dept_names:
        spec = DEPARTMENTS[dept][0]
        for _ in range(DOCTORS_PER_DEPT):
            dim_doctor.append((dk, f"{DOC_PREFIX} {name(rng)}", spec, dept_key[dept]))
            doctor_dept[dk] = dept
            dk += 1

    # ---- dim_patient ----------------------------------------------------
    dim_patient = []
    for pk in range(1, N_PATIENTS + 1):
        birth = date(1940, 1, 1) + timedelta(days=rng.randint(0, 365 * 80))
        dim_patient.append((
            pk, name(rng), rng.choice(["Male", "Female"]), birth.isoformat(),
            rng.choice(CITIES), rng.random() < 0.65,
        ))
    insured = {p[0]: p[5] for p in dim_patient}

    # ---- dim_date -------------------------------------------------------
    dates = [START + timedelta(days=i) for i in range((END - START).days + 1)]
    dim_date = [
        (int(d.strftime("%Y%m%d")), d.isoformat(), d.year, (d.month - 1) // 3 + 1,
         d.month, d.strftime("%B"), d.strftime("%Y-%m"), d.isoweekday(),
         d.strftime("%A"), d.isoweekday() >= 6)
        for d in dates
    ]

    # ---- fact_appointments ---------------------------------------------
    statuses = (["Completed"] * N_COMPLETED + ["Cancelled"] * N_CANCELLED
                + ["No-Show"] * N_NO_SHOW)
    rng.shuffle(statuses)
    # mild upward volume trend over the two years so MoM growth is meaningful
    weights = [1 + 0.5 * i / len(dates) for i in range(len(dates))]
    appt_dates = rng.choices(dates, weights=weights, k=N_APPOINTMENTS)
    appt_dates.sort()

    fact_appointments, completed = [], []
    for ak, (d, status) in enumerate(zip(appt_dates, statuses), start=1):
        doc = rng.randint(1, len(dim_doctor))
        pat = rng.randint(1, N_PATIENTS)
        dept = dept_key[doctor_dept[doc]]
        dkey = int(d.strftime("%Y%m%d"))
        fact_appointments.append((ak, dkey, pat, doc, dept, status))
        if status == "Completed":
            completed.append((ak, dkey, pat, doc, dept))

    # ---- fact_billing (one bill per completed appointment) ---------------
    fact_billing = []
    for bk, (ak, dkey, pat, doc, dept) in enumerate(completed, start=1):
        lo, hi = DEPARTMENTS[doctor_dept[doc]][1]
        amount = round(rng.uniform(lo, hi), 2)
        ptype = "Insurance" if insured[pat] and rng.random() < 0.9 else "Self-Pay"
        pstatus = "Paid" if rng.random() < 0.88 else "Pending"
        fact_billing.append((bk, ak, dkey, pat, doc, dept, ptype, pstatus, amount))

    # ---- write ----------------------------------------------------------
    print(f"Writing CSVs to {out_dir}")
    write_csv(out_dir / "dim_department.csv", ["department_key", "department_name"], dim_department)
    write_csv(out_dir / "dim_doctor.csv",
              ["doctor_key", "doctor_name", "specialization", "department_key"], dim_doctor)
    write_csv(out_dir / "dim_patient.csv",
              ["patient_key", "patient_name", "gender", "birth_date", "city", "has_insurance"],
              dim_patient)
    write_csv(out_dir / "dim_date.csv",
              ["date_key", "full_date", "year", "quarter", "month_num", "month_name",
               "year_month", "day_of_week_num", "day_of_week", "is_weekend"], dim_date)
    write_csv(out_dir / "fact_appointments.csv",
              ["appointment_key", "date_key", "patient_key", "doctor_key",
               "department_key", "status"], fact_appointments)
    write_csv(out_dir / "fact_billing.csv",
              ["billing_key", "appointment_key", "date_key", "patient_key", "doctor_key",
               "department_key", "payment_type", "payment_status", "amount"], fact_billing)

    total = (len(dim_department) + len(dim_doctor) + len(dim_patient) + len(dim_date)
             + len(fact_appointments) + len(fact_billing))
    print(f"Total records: {total:,}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path,
                        default=Path(__file__).resolve().parent.parent / "data")
    main(parser.parse_args().out)
