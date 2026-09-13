
import os
import math
import warnings
from typing import Optional

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import pyodbc
import streamlit as st

warnings.filterwarnings("ignore")

# ============================================================
# GIGBASE
# AI-POWERED GIG ECONOMY MANAGEMENT SYSTEM
#
# This version is written for the ACTUAL GigBase schema:
# Users
# Freelancers
# Clients
# Skills
# Freelancer_Skills
# Projects
# Bids
# Contracts
# Milestones
# Payments
# Currency_Rates
# Earnings_Log
# Reviews
# Fraud_Flags
# Freelancer_Rankings
# Demand_Trends
#
# Important real relationships:
# Users -> Freelancers / Clients
# Clients -> Projects
# Projects -> Bids / Contracts
# Freelancers -> Bids / Contracts / Earnings / Skills / Rankings
# Contracts -> Milestones / Reviews
# Milestones -> Payments
# Reviews -> Fraud_Flags
# Skills -> Freelancer_Skills / Demand_Trends
# ============================================================

st.set_page_config(
    page_title="GigBase | AI-Powered Gig Economy Management System",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ------------------------------------------------------------
# Styling
# ------------------------------------------------------------
st.markdown(
    """
    <style>
    .block-container {
        padding-top: 2rem;
        padding-bottom: 2rem;
        max-width: 1500px;
    }
    h1 {
        margin-top: 0 !important;
        padding-top: 0 !important;
        line-height: 1.25 !important;
    }
    [data-testid="stMetric"] {
        border: 1px solid #d9dee7;
        border-radius: 12px;
        padding: 14px;
        background: white;
    }
    .info-card {
        border: 1px solid #d9dee7;
        border-radius: 12px;
        padding: 14px;
        margin: 8px 0;
        background: white;
    }
    .small-note {
        color: #667085;
        font-size: 0.86rem;
    }
    </style>
    """,
    unsafe_allow_html=True,
)

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------
SERVER = os.getenv("GIGBASE_SERVER", r"localhost\SQLEXPRESS")
DATABASE = os.getenv("GIGBASE_DATABASE", "GigBase")
USERNAME = os.getenv("GIGBASE_USERNAME", "")
PASSWORD = os.getenv("GIGBASE_PASSWORD", "")
DRIVER = os.getenv("GIGBASE_DRIVER", "ODBC Driver 17 for SQL Server")
TRUSTED_CONNECTION = os.getenv(
    "GIGBASE_TRUSTED_CONNECTION", "yes"
).lower() in {"yes", "true", "1"}


# ------------------------------------------------------------
# SQL connection
# ------------------------------------------------------------
@st.cache_resource
def get_connection():
    if TRUSTED_CONNECTION:
        cs = (
            f"DRIVER={{{DRIVER}}};"
            f"SERVER={SERVER};"
            f"DATABASE={DATABASE};"
            f"Trusted_Connection=yes;"
            f"TrustServerCertificate=yes;"
        )
    else:
        cs = (
            f"DRIVER={{{DRIVER}}};"
            f"SERVER={SERVER};"
            f"DATABASE={DATABASE};"
            f"UID={USERNAME};"
            f"PWD={PASSWORD};"
            f"TrustServerCertificate=yes;"
        )
    return pyodbc.connect(cs, timeout=10)


def query(sql, params=None):
    return pd.read_sql(sql, get_connection(), params=params)


def scalar(sql, params=None, default=0):
    """Run a one-value query without hiding SQL errors.
    Returning 0 for a failed SQL statement was the reason payment totals
    could appear as $0 even when Payments contained data.
    """
    df = query(sql, params)
    if df.empty:
        return default
    value = df.iloc[0, 0]
    if pd.isna(value):
        return default
    return value


def money_usd(v):
    return f"${float(v or 0):,.2f}"


def money_pkr(v):
    return f"PKR {float(v or 0):,.0f}"


def number(v):
    try:
        return f"{float(v):,.0f}"
    except Exception:
        return "0"


def pct(v):
    return f"{float(v or 0):.1f}%"


def safe_numeric(df, columns):
    for c in columns:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce").fillna(0)
    return df


# ------------------------------------------------------------
# Exact GigBase KPI layer
# ------------------------------------------------------------
@st.cache_data(ttl=120)
def get_platform_kpis():
    users = int(scalar("SELECT COUNT(*) FROM dbo.Users"))
    freelancers = int(scalar("SELECT COUNT(*) FROM dbo.Freelancers"))
    clients = int(scalar("SELECT COUNT(*) FROM dbo.Clients"))
    projects = int(scalar("SELECT COUNT(*) FROM dbo.Projects"))
    bids = int(scalar("SELECT COUNT(*) FROM dbo.Bids"))
    contracts = int(scalar("SELECT COUNT(*) FROM dbo.Contracts"))
    milestones = int(scalar("SELECT COUNT(*) FROM dbo.Milestones"))
    payments = int(scalar("SELECT COUNT(*) FROM dbo.Payments"))
    reviews = int(scalar("SELECT COUNT(*) FROM dbo.Reviews"))
    fraud_flags = int(scalar("SELECT COUNT(*) FROM dbo.Fraud_Flags"))
    skills = int(scalar("SELECT COUNT(*) FROM dbo.Skills"))

    # Payments uses amount_usd / amount_pkr in the real schema.
    # TRY_CONVERT also protects the dashboard if a local SQL copy stores
    # a numeric value as text.
    payment_usd = float(scalar(
        """
        SELECT COALESCE(
            SUM(TRY_CONVERT(decimal(18,2), amount_usd)), 0
        )
        FROM dbo.Payments
        """
    ))
    payment_pkr = float(scalar(
        """
        SELECT COALESCE(
            SUM(TRY_CONVERT(decimal(18,2), amount_pkr)), 0
        )
        FROM dbo.Payments
        """
    ))

    project_budget = float(scalar(
        "SELECT COALESCE(SUM(budget),0) FROM dbo.Projects"
    ))
    contract_value = float(scalar(
        "SELECT COALESCE(SUM(agreed_amount),0) FROM dbo.Contracts"
    ))
    freelancer_earnings = float(scalar(
        "SELECT COALESCE(SUM(total_earned),0) FROM dbo.Earnings_Log"
    ))

    completed = int(scalar(
        "SELECT COUNT(*) FROM dbo.Projects WHERE status='Completed'"
    ))
    open_projects = int(scalar(
        "SELECT COUNT(*) FROM dbo.Projects WHERE status='Open'"
    ))
    in_progress = int(scalar(
        "SELECT COUNT(*) FROM dbo.Projects WHERE status='In Progress'"
    ))
    cancelled = int(scalar(
        "SELECT COUNT(*) FROM dbo.Projects WHERE status='Cancelled'"
    ))

    avg_rating = float(scalar(
        "SELECT COALESCE(AVG(CAST(rating AS float)),0) FROM dbo.Reviews"
    ))
    avg_payment = payment_usd / payments if payments else 0
    completion_rate = completed / projects * 100 if projects else 0
    bid_to_contract = contracts / bids * 100 if bids else 0

    return {
        "users": users,
        "freelancers": freelancers,
        "clients": clients,
        "projects": projects,
        "bids": bids,
        "contracts": contracts,
        "milestones": milestones,
        "payments": payments,
        "reviews": reviews,
        "fraud_flags": fraud_flags,
        "skills": skills,
        "payment_usd": payment_usd,
        "payment_pkr": payment_pkr,
        "project_budget": project_budget,
        "contract_value": contract_value,
        "freelancer_earnings": freelancer_earnings,
        "completed": completed,
        "open_projects": open_projects,
        "in_progress": in_progress,
        "cancelled": cancelled,
        "avg_rating": avg_rating,
        "avg_payment": avg_payment,
        "completion_rate": completion_rate,
        "bid_to_contract": bid_to_contract,
    }


# ------------------------------------------------------------
# Executive charts
# ------------------------------------------------------------
@st.cache_data(ttl=120)
def project_status_data():
    return query(
        """
        SELECT status AS Status, COUNT(*) AS Projects
        FROM dbo.Projects
        GROUP BY status
        ORDER BY Projects DESC
        """
    )


def payment_data():
    # Payments has NO payment_date in the real schema.
    # Use milestone.completed_at as the operational payment timeline.
    return query(
        """
        SELECT
            CONVERT(varchar(7), m.completed_at, 120) AS Period,
            SUM(TRY_CONVERT(decimal(18,2), p.amount_usd)) AS USD,
            SUM(TRY_CONVERT(decimal(18,2), p.amount_pkr)) AS PKR,
            COUNT(*) AS Payments
        FROM dbo.Payments p
        INNER JOIN dbo.Milestones m
            ON p.milestone_id = m.milestone_id
        WHERE m.completed_at IS NOT NULL
        GROUP BY CONVERT(varchar(7), m.completed_at, 120)
        ORDER BY Period
        """
    )


@st.cache_data(ttl=120)
def contract_status_data():
    return query(
        """
        SELECT
            CASE
                WHEN c.end_date IS NOT NULL AND c.end_date < CAST(GETDATE() AS date)
                    THEN 'Ended'
                WHEN c.start_date > CAST(GETDATE() AS date)
                    THEN 'Not Started'
                ELSE 'Active'
            END AS Contract_State,
            COUNT(*) AS Contracts
        FROM dbo.Contracts c
        GROUP BY
            CASE
                WHEN c.end_date IS NOT NULL AND c.end_date < CAST(GETDATE() AS date)
                    THEN 'Ended'
                WHEN c.start_date > CAST(GETDATE() AS date)
                    THEN 'Not Started'
                ELSE 'Active'
            END
        """
    )


# ------------------------------------------------------------
# Freelancer intelligence dataset
# ------------------------------------------------------------
@st.cache_data(ttl=120)
def freelancer_intelligence():
    sql = """
    WITH latest_rank AS
    (
        SELECT freelancer_id, score, rank_position,
               ROW_NUMBER() OVER
               (
                   PARTITION BY freelancer_id
                   ORDER BY calculated_at DESC, rank_id DESC
               ) AS rn
        FROM dbo.Freelancer_Rankings
    ),
    review_stats AS
    (
        SELECT
            c.freelancer_id,
            COUNT(r.review_id) AS review_count,
            AVG(CAST(r.rating AS float)) AS avg_rating,
            SUM(CASE WHEN r.is_flagged = 1 THEN 1 ELSE 0 END) AS flagged_reviews
        FROM dbo.Contracts c
        LEFT JOIN dbo.Reviews r
            ON c.contract_id = r.contract_id
        GROUP BY c.freelancer_id
    ),
    project_stats AS
    (
        SELECT
            c.freelancer_id,
            COUNT(DISTINCT c.contract_id) AS contract_count,
            COUNT(DISTINCT CASE
                WHEN p.status = 'Completed' THEN p.project_id
            END) AS completed_projects,
            COUNT(DISTINCT CASE
                WHEN p.status = 'In Progress' THEN p.project_id
            END) AS active_projects
        FROM dbo.Contracts c
        INNER JOIN dbo.Projects p
            ON c.project_id = p.project_id
        GROUP BY c.freelancer_id
    ),
    payment_stats AS
    (
        SELECT
            c.freelancer_id,
            COALESCE(SUM(TRY_CONVERT(decimal(18,2), pay.amount_usd)),0) AS paid_usd,
            COALESCE(SUM(TRY_CONVERT(decimal(18,2), pay.amount_pkr)),0) AS paid_pkr
        FROM dbo.Contracts c
        INNER JOIN dbo.Milestones m
            ON c.contract_id = m.contract_id
        INNER JOIN dbo.Payments pay
            ON m.milestone_id = pay.milestone_id
        GROUP BY c.freelancer_id
    ),
    earning_stats AS
    (
        SELECT
            freelancer_id,
            COALESCE(SUM(total_earned),0) AS logged_earnings,
            AVG(CAST(avg_rating AS float)) AS earnings_avg_rating
        FROM dbo.Earnings_Log
        GROUP BY freelancer_id
    ),
    fraud_stats AS
    (
        SELECT
            c.freelancer_id,
            COUNT(ff.flag_id) AS fraud_flags,
            COALESCE(AVG(CAST(ff.confidence_score AS float)),0) AS avg_fraud_confidence
        FROM dbo.Contracts c
        INNER JOIN dbo.Reviews r
            ON c.contract_id = r.contract_id
        INNER JOIN dbo.Fraud_Flags ff
            ON r.review_id = ff.review_id
        GROUP BY c.freelancer_id
    ),
    skill_stats AS
    (
        SELECT freelancer_id, COUNT(*) AS skill_count
        FROM dbo.Freelancer_Skills
        GROUP BY freelancer_id
    )
    SELECT
        f.freelancer_id AS Freelancer_ID,
        u.name AS Freelancer_Name,
        u.country AS Country,
        f.hourly_rate AS Hourly_Rate,
        f.experience_years AS Experience_Years,
        CASE WHEN f.availability = 1 THEN 'Available' ELSE 'Unavailable' END AS Availability,
        COALESCE(rs.review_count,0) AS Review_Count,
        COALESCE(rs.avg_rating,0) AS Avg_Rating,
        COALESCE(rs.flagged_reviews,0) AS Flagged_Reviews,
        COALESCE(ps.contract_count,0) AS Contracts,
        COALESCE(ps.completed_projects,0) AS Completed_Projects,
        COALESCE(ps.active_projects,0) AS Active_Projects,
        COALESCE(pay.paid_usd,0) AS Paid_USD,
        COALESCE(pay.paid_pkr,0) AS Paid_PKR,
        COALESCE(es.logged_earnings,0) AS Logged_Earnings,
        COALESCE(es.earnings_avg_rating,0) AS Earnings_Avg_Rating,
        COALESCE(fs.fraud_flags,0) AS Fraud_Flags,
        COALESCE(fs.avg_fraud_confidence,0) AS Fraud_Confidence,
        COALESCE(ss.skill_count,0) AS Skill_Count,
        COALESCE(lr.score,0) AS Ranking_Score,
        COALESCE(lr.rank_position,0) AS Rank_Position
    FROM dbo.Freelancers f
    INNER JOIN dbo.Users u
        ON f.freelancer_id = u.user_id
    LEFT JOIN review_stats rs
        ON f.freelancer_id = rs.freelancer_id
    LEFT JOIN project_stats ps
        ON f.freelancer_id = ps.freelancer_id
    LEFT JOIN payment_stats pay
        ON f.freelancer_id = pay.freelancer_id
    LEFT JOIN earning_stats es
        ON f.freelancer_id = es.freelancer_id
    LEFT JOIN fraud_stats fs
        ON f.freelancer_id = fs.freelancer_id
    LEFT JOIN skill_stats ss
        ON f.freelancer_id = ss.freelancer_id
    LEFT JOIN latest_rank lr
        ON f.freelancer_id = lr.freelancer_id
       AND lr.rn = 1
    ORDER BY COALESCE(lr.rank_position,999999)
    """
    df = query(sql)
    return safe_numeric(
        df,
        [
            "Hourly_Rate", "Experience_Years", "Review_Count",
            "Avg_Rating", "Flagged_Reviews", "Contracts",
            "Completed_Projects", "Active_Projects", "Paid_USD",
            "Paid_PKR", "Logged_Earnings", "Earnings_Avg_Rating",
            "Fraud_Flags", "Fraud_Confidence", "Skill_Count",
            "Ranking_Score", "Rank_Position",
        ],
    )


def calculate_explainable_risk(df):
    """
    Explainable decision-support score, not a claim of actual fraud.

    Signals:
    - fraud flags: strongest signal
    - flagged reviews
    - fraud confidence
    - low rating
    - very low experience
    - zero completed contracts
    - no reviews

    Missing data does NOT automatically become fraud.
    """
    if df.empty:
        return df

    out = df.copy()

    # Each component is normalized to a 0-100 contribution.
    fraud_component = (out["Fraud_Flags"].clip(0, 3) / 3) * 45
    flagged_component = (out["Flagged_Reviews"].clip(0, 2) / 2) * 15
    confidence_component = (out["Fraud_Confidence"].clip(0, 100) / 100) * 15

    rating_component = (
        ((5 - out["Avg_Rating"]).clip(0, 4) / 4) * 15
        if out["Avg_Rating"].max() > 0
        else 0
    )

    experience_component = (
        ((2 - out["Experience_Years"]).clip(0, 2) / 2) * 5
    )
    inactivity_component = (
        (out["Completed_Projects"] == 0).astype(float) * 3
        + (out["Review_Count"] == 0).astype(float) * 2
    )

    out["Fraud_Signal"] = fraud_component.round(1)
    out["Flagged_Review_Signal"] = flagged_component.round(1)
    out["Confidence_Signal"] = confidence_component.round(1)
    out["Rating_Signal"] = pd.Series(rating_component, index=out.index).round(1)
    out["Experience_Signal"] = experience_component.round(1)
    out["Activity_Signal"] = inactivity_component.round(1)

    out["Risk_Score"] = (
        out["Fraud_Signal"]
        + out["Flagged_Review_Signal"]
        + out["Confidence_Signal"]
        + out["Rating_Signal"]
        + out["Experience_Signal"]
        + out["Activity_Signal"]
    ).clip(0, 100).round(1)

    def label(x):
        if x >= 70:
            return "High Risk"
        if x >= 40:
            return "Watch"
        return "Low Risk"

    out["Risk_Level"] = out["Risk_Score"].apply(label)

    return out


# ------------------------------------------------------------
# Matching
# ------------------------------------------------------------
@st.cache_data(ttl=120)
def freelancer_skills():
    return query(
        """
        SELECT
            fs.freelancer_id AS Freelancer_ID,
            s.skill_id AS Skill_ID,
            s.skill_name AS Skill,
            s.category AS Category,
            fs.proficiency_level AS Proficiency
        FROM dbo.Freelancer_Skills fs
        INNER JOIN dbo.Skills s
            ON fs.skill_id = s.skill_id
        ORDER BY fs.freelancer_id, s.skill_name
        """
    )


def calculate_match_score(row, selected_skill=None):
    rating = min(max(float(row["Avg_Rating"]), 0), 5) / 5 * 30
    experience = min(max(float(row["Experience_Years"]), 0), 10) / 10 * 20
    rank = (
        min(max(float(row["Ranking_Score"]), 0), 100) / 100 * 15
        if row["Ranking_Score"] > 0 else 0
    )
    activity = min(float(row["Completed_Projects"]), 10) / 10 * 15
    reliability = max(0, 10 - float(row["Risk_Score"]) / 10)
    skill_bonus = 10 if selected_skill else 0

    return round(
        rating + experience + rank + activity + reliability + skill_bonus,
        1,
    )


# ------------------------------------------------------------
# Project intelligence
# ------------------------------------------------------------
@st.cache_data(ttl=120)
def project_intelligence():
    """
    Project-level management dataset.

    Each child table is aggregated separately before joining to Projects.
    This prevents Bids x Contracts x Milestones x Payments from multiplying
    the same payment or milestone several times.
    """
    return query(
        """
        WITH bid_stats AS
        (
            SELECT
                project_id,
                COUNT(*) AS Bid_Count
            FROM dbo.Bids
            GROUP BY project_id
        ),
        contract_stats AS
        (
            SELECT
                project_id,
                COUNT(*) AS Contract_Count,
                COALESCE(SUM(agreed_amount),0) AS Contract_Value
            FROM dbo.Contracts
            GROUP BY project_id
        ),
        milestone_stats AS
        (
            SELECT
                c.project_id,
                COUNT(m.milestone_id) AS Milestones,
                COUNT(pay.payment_id) AS Payment_Count,
                COALESCE(SUM(TRY_CONVERT(decimal(18,2), pay.amount_usd)),0) AS Paid_USD
            FROM dbo.Contracts c
            LEFT JOIN dbo.Milestones m
                ON c.contract_id = m.contract_id
            LEFT JOIN dbo.Payments pay
                ON m.milestone_id = pay.milestone_id
            GROUP BY c.project_id
        )
        SELECT
            p.project_id AS Project_ID,
            p.title AS Project,
            c.company_name AS Client,
            u.name AS Client_Name,
            p.budget AS Budget,
            p.deadline AS Deadline,
            p.status AS Status,
            COALESCE(b.Bid_Count,0) AS Bid_Count,
            COALESCE(ct.Contract_Count,0) AS Contract_Count,
            COALESCE(ct.Contract_Value,0) AS Contract_Value,
            COALESCE(ms.Milestones,0) AS Milestones,
            COALESCE(ms.Payment_Count,0) AS Payment_Count,
            COALESCE(ms.Paid_USD,0) AS Paid_USD
        FROM dbo.Projects p
        INNER JOIN dbo.Clients c
            ON p.client_id = c.client_id
        INNER JOIN dbo.Users u
            ON c.client_id = u.user_id
        LEFT JOIN bid_stats b
            ON p.project_id = b.project_id
        LEFT JOIN contract_stats ct
            ON p.project_id = ct.project_id
        LEFT JOIN milestone_stats ms
            ON p.project_id = ms.project_id
        ORDER BY p.project_id
        """
    )


# ------------------------------------------------------------
# Skills + demand
# ------------------------------------------------------------
@st.cache_data(ttl=120)
def skills_intelligence():
    return query(
        """
        WITH supply AS
        (
            SELECT skill_id, COUNT(*) AS Freelancer_Count
            FROM dbo.Freelancer_Skills
            GROUP BY skill_id
        ),
        latest_demand AS
        (
            SELECT
                skill_id,
                demand_score,
                growth_rate,
                month,
                ROW_NUMBER() OVER
                (
                    PARTITION BY skill_id
                    ORDER BY month DESC, trend_id DESC
                ) AS rn
            FROM dbo.Demand_Trends
        )
        SELECT
            s.skill_id AS Skill_ID,
            s.skill_name AS Skill,
            s.category AS Category,
            COALESCE(sp.Freelancer_Count,0) AS Freelancer_Supply,
            COALESCE(ld.demand_score,0) AS Demand_Score,
            COALESCE(ld.growth_rate,0) AS Growth_Rate,
            ld.month AS Demand_Month
        FROM dbo.Skills s
        LEFT JOIN supply sp
            ON s.skill_id = sp.skill_id
        LEFT JOIN latest_demand ld
            ON s.skill_id = ld.skill_id
           AND ld.rn = 1
        ORDER BY COALESCE(ld.demand_score,0) DESC
        """
    )


# ------------------------------------------------------------
# Fraud intelligence
# ------------------------------------------------------------
@st.cache_data(ttl=120)
def fraud_intelligence():
    return query(
        """
        SELECT
            ff.flag_id AS Flag_ID,
            ff.reason AS Reason,
            ff.confidence_score AS Confidence,
            ff.flagged_at AS Flagged_At,
            r.review_id AS Review_ID,
            r.rating AS Review_Rating,
            r.is_flagged AS Review_Flagged,
            ct.contract_id AS Contract_ID,
            ct.freelancer_id AS Freelancer_ID,
            u.name AS Freelancer_Name,
            p.project_id AS Project_ID,
            p.title AS Project
        FROM dbo.Fraud_Flags ff
        INNER JOIN dbo.Reviews r
            ON ff.review_id = r.review_id
        INNER JOIN dbo.Contracts ct
            ON r.contract_id = ct.contract_id
        INNER JOIN dbo.Freelancers f
            ON ct.freelancer_id = f.freelancer_id
        INNER JOIN dbo.Users u
            ON f.freelancer_id = u.user_id
        INNER JOIN dbo.Projects p
            ON ct.project_id = p.project_id
        ORDER BY ff.confidence_score DESC, ff.flagged_at DESC
        """
    )


# ------------------------------------------------------------
# Sidebar
# ------------------------------------------------------------
st.sidebar.title("GigBase")
st.sidebar.caption("AI-Powered Gig Economy Management System")

if st.sidebar.button("🔄 Refresh data", use_container_width=True):
    st.cache_data.clear()
    st.rerun()

page = st.sidebar.radio(
    "System modules",
    [
        "Executive Dashboard",
        "AI Risk & Matching",
        "Management Intelligence",
        "Data Explorer",
    ],
)

st.sidebar.divider()
st.sidebar.write(f"**Database:** {DATABASE}")
st.sidebar.write(f"**Server:** {SERVER}")

try:
    get_connection()
except Exception as exc:
    st.error("SQL Server connection failed.")
    st.code(str(exc))
    st.stop()


# ------------------------------------------------------------
# Header
# ------------------------------------------------------------
st.title("AI-Powered Gig Economy Management System")
st.caption(
    "Explainable operational intelligence for projects, payments, "
    "freelancers, skills, rankings, demand and fraud monitoring."
)


# ============================================================
# PAGE 1 — EXECUTIVE DASHBOARD
# ============================================================
if page == "Executive Dashboard":
    k = get_platform_kpis()

    st.subheader("Platform Overview")

    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Total Users", number(k["users"]))
    c2.metric("Freelancers", number(k["freelancers"]))
    c3.metric("Clients", number(k["clients"]))
    c4.metric("Projects", number(k["projects"]))

    c5, c6, c7, c8 = st.columns(4)
    c5.metric("Open", number(k["open_projects"]))
    c6.metric("In Progress", number(k["in_progress"]))
    c7.metric("Completed", number(k["completed"]))
    c8.metric("Cancelled", number(k["cancelled"]))

    st.divider()

    f1, f2, f3, f4 = st.columns(4)
    f1.metric("Payments", number(k["payments"]))
    f2.metric("Paid USD", money_usd(k["payment_usd"]))
    f3.metric("Paid PKR", money_pkr(k["payment_pkr"]))
    f4.metric("Contract Value", money_pkr(k["contract_value"]))

    st.divider()

    left, right = st.columns(2)

    with left:
        st.subheader("Project Pipeline")
        df = project_status_data()
        fig = px.bar(
            df,
            x="Status",
            y="Projects",
            text="Projects",
            title="Projects by Status",
        )
        fig.update_layout(height=390)
        st.plotly_chart(fig, use_container_width=True)

    with right:
        st.subheader("Payment Activity")
        df = payment_data()
        if not df.empty:
            fig = px.line(
                df,
                x="Period",
                y="USD",
                markers=True,
                title="Recorded Payment Volume (USD)",
            )
            fig.update_layout(height=390)
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No milestone completion dates are available for the payment timeline.")

    h1, h2, h3, h4 = st.columns(4)
    h1.metric("Completion Rate", pct(k["completion_rate"]))
    h2.metric("Average Review Rating", f'{k["avg_rating"]:.2f}/5')
    h3.metric("Bid → Contract", pct(k["bid_to_contract"]))
    h4.metric("Fraud Flags", number(k["fraud_flags"]))

    st.subheader("Management Interpretation")

    statements = []

    if k["completion_rate"] >= 70:
        statements.append(
            f"Delivery health is strong: {k['completion_rate']:.1f}% of projects are completed."
        )
    elif k["completion_rate"] >= 40:
        statements.append(
            f"Delivery is moderate: {k['completion_rate']:.1f}% of projects are completed."
        )
    else:
        statements.append(
            f"Delivery requires attention: only {k['completion_rate']:.1f}% of projects are completed."
        )

    statements.append(
        f"The platform has recorded {k['payments']:,} payment transactions "
        f"worth {money_usd(k['payment_usd'])} / {money_pkr(k['payment_pkr'])}."
    )

    if k["bid_to_contract"] >= 30:
        statements.append(
            f"Bid conversion is healthy at {k['bid_to_contract']:.1f}%."
        )
    else:
        statements.append(
            f"Bid conversion is {k['bid_to_contract']:.1f}%; management should examine proposal quality and project fit."
        )

    if k["fraud_flags"] > 0:
        statements.append(
            f"{k['fraud_flags']} fraud flags exist and should be reviewed using the Risk module."
        )
    else:
        statements.append("No fraud flags are currently recorded.")

    for s in statements:
        st.write("• " + s)

    st.caption(
        "Payment totals are taken from Payments.amount_usd and Payments.amount_pkr. "
        "Payment timing is derived from Milestones.completed_at because Payments has no date column."
    )


# ============================================================
# PAGE 2 — AI RISK & MATCHING
# ============================================================
elif page == "AI Risk & Matching":
    st.header("AI Risk & Freelancer Matching")

    st.write(
        "This module uses transparent, explainable decision-support scoring. "
        "It does not claim that a freelancer is fraudulent; it identifies "
        "operational risk signals that management can investigate."
    )

    base = freelancer_intelligence()
    risk = calculate_explainable_risk(base)

    if risk.empty:
        st.warning("No freelancer records were found.")
        st.stop()

    high = int((risk["Risk_Level"] == "High Risk").sum())
    watch = int((risk["Risk_Level"] == "Watch").sum())
    low = int((risk["Risk_Level"] == "Low Risk").sum())

    a, b, c, d = st.columns(4)
    a.metric("Freelancers Assessed", number(len(risk)))
    b.metric("High Risk", number(high))
    c.metric("Watch", number(watch))
    d.metric("Low Risk", number(low))

    st.divider()

    c1, c2 = st.columns(2)

    with c1:
        dist = risk["Risk_Level"].value_counts().reset_index()
        dist.columns = ["Risk_Level", "Freelancers"]
        fig = px.bar(
            dist,
            x="Risk_Level",
            y="Freelancers",
            text="Freelancers",
            title="Risk Distribution",
        )
        fig.update_layout(height=380)
        st.plotly_chart(fig, use_container_width=True)

    with c2:
        fig = px.histogram(
            risk,
            x="Risk_Score",
            nbins=10,
            title="Risk Score Distribution",
        )
        fig.update_layout(height=380)
        st.plotly_chart(fig, use_container_width=True)

    st.subheader("Risk Assessment")

    selected_level = st.selectbox(
        "Risk level",
        ["All", "High Risk", "Watch", "Low Risk"],
    )

    filtered = risk.copy()
    if selected_level != "All":
        filtered = filtered[filtered["Risk_Level"] == selected_level]

    display = [
        "Freelancer_ID", "Freelancer_Name", "Availability",
        "Hourly_Rate", "Experience_Years", "Avg_Rating",
        "Review_Count", "Contracts", "Completed_Projects",
        "Paid_USD", "Fraud_Flags", "Fraud_Confidence",
        "Ranking_Score", "Rank_Position", "Risk_Score", "Risk_Level"
    ]

    st.dataframe(
        filtered[display].sort_values("Risk_Score", ascending=False),
        use_container_width=True,
        hide_index=True,
    )

    st.subheader("Explain One Freelancer")

    names = risk["Freelancer_Name"].dropna().tolist()
    if names:
        chosen = st.selectbox("Select freelancer", names)
        row = risk[risk["Freelancer_Name"] == chosen].iloc[0]

        x1, x2, x3, x4 = st.columns(4)
        x1.metric("Risk Score", f'{row["Risk_Score"]:.1f}/100')
        x2.metric("Risk Level", row["Risk_Level"])
        x3.metric("Rating", f'{row["Avg_Rating"]:.2f}/5')
        x4.metric("Fraud Flags", number(row["Fraud_Flags"]))

        st.write("**Why this score?**")
        explanation = pd.DataFrame(
            {
                "Signal": [
                    "Fraud flag signal",
                    "Flagged review signal",
                    "Fraud confidence signal",
                    "Rating signal",
                    "Experience signal",
                    "Activity signal",
                ],
                "Contribution": [
                    row["Fraud_Signal"],
                    row["Flagged_Review_Signal"],
                    row["Confidence_Signal"],
                    row["Rating_Signal"],
                    row["Experience_Signal"],
                    row["Activity_Signal"],
                ],
                "Meaning": [
                    "Historical fraud-flag records connected through Reviews → Contracts → Freelancer.",
                    "Reviews explicitly marked as flagged.",
                    "Average confidence of fraud flags connected to this freelancer.",
                    "Lower review ratings create a moderate risk contribution.",
                    "Very low experience creates a small risk contribution.",
                    "No completed projects/reviews create only a weak signal.",
                ],
            }
        )
        st.dataframe(explanation, use_container_width=True, hide_index=True)

    st.divider()

    st.subheader("AI-Assisted Freelancer Matching")

    skills = freelancer_skills()
    skill_options = ["Any skill"] + sorted(skills["Skill"].dropna().unique().tolist())
    selected_skill = st.selectbox("Required skill", skill_options)

    min_rating = st.slider("Minimum rating", 0.0, 5.0, 0.0, 0.5)
    min_experience = st.slider("Minimum experience", 0, 10, 0)
    max_risk = st.slider("Maximum risk score", 0, 100, 70, 5)
    only_available = st.checkbox("Only show available freelancers", value=True)

    matches = risk.copy()

    if selected_skill != "Any skill":
        ids = skills.loc[
            skills["Skill"] == selected_skill, "Freelancer_ID"
        ].unique()
        matches = matches[matches["Freelancer_ID"].isin(ids)]

    matches = matches[
        (matches["Avg_Rating"] >= min_rating)
        & (matches["Experience_Years"] >= min_experience)
        & (matches["Risk_Score"] <= max_risk)
    ]

    if only_available:
        matches = matches[matches["Availability"] == "Available"]

    matches = matches.copy()
    matches["Match_Score"] = matches.apply(
        lambda r: calculate_match_score(
            r,
            None if selected_skill == "Any skill" else selected_skill
        ),
        axis=1,
    )

    match_cols = [
        "Freelancer_ID", "Freelancer_Name", "Availability",
        "Hourly_Rate", "Experience_Years", "Avg_Rating",
        "Completed_Projects", "Paid_USD", "Ranking_Score",
        "Rank_Position", "Risk_Score", "Risk_Level", "Match_Score"
    ]

    if matches.empty:
        st.info("No freelancers satisfy the selected matching criteria.")
    else:
        st.dataframe(
            matches.sort_values("Match_Score", ascending=False)[match_cols].head(20),
            use_container_width=True,
            hide_index=True,
        )

    st.caption(
        "Matching is a transparent ranking formula using rating, experience, "
        "ranking score, completed projects, risk score and optional skill match."
    )


# ============================================================
# PAGE 3 — MANAGEMENT INTELLIGENCE
# ============================================================
elif page == "Management Intelligence":
    st.header("Management Intelligence")

    st.write(
        "Use the controls below to move from raw database records to "
        "management-level decisions."
    )

    k = get_platform_kpis()

    # Financial KPIs
    st.subheader("1. Financial Performance")

    a, b, c, d = st.columns(4)
    a.metric("Paid USD", money_usd(k["payment_usd"]))
    b.metric("Paid PKR", money_pkr(k["payment_pkr"]))
    c.metric("Avg Payment USD", money_usd(k["avg_payment"]))
    d.metric("Logged Freelancer Earnings", money_pkr(k["freelancer_earnings"]))

    pay = payment_data()

    if not pay.empty:
        left, right = st.columns(2)

        with left:
            fig = px.area(
                pay,
                x="Period",
                y="USD",
                markers=True,
                title="Monthly Payment Value (USD)",
            )
            fig.update_layout(height=380)
            st.plotly_chart(fig, use_container_width=True)

        with right:
            fig = px.bar(
                pay,
                x="Period",
                y="Payments",
                text="Payments",
                title="Monthly Payment Transaction Count",
            )
            fig.update_layout(height=380)
            st.plotly_chart(fig, use_container_width=True)

    # Project intelligence
    st.subheader("2. Project & Contract Intelligence")

    projects = project_intelligence()
    safe_numeric(
        projects,
        [
            "Budget", "Bid_Count", "Contract_Count",
            "Contract_Value", "Milestones", "Payment_Count", "Paid_USD"
        ],
    )

    status_filter = st.multiselect(
        "Project status",
        sorted(projects["Status"].dropna().unique()),
        default=sorted(projects["Status"].dropna().unique()),
    )

    p_filtered = projects[projects["Status"].isin(status_filter)].copy()

    p1, p2, p3, p4 = st.columns(4)
    p1.metric("Projects Selected", number(len(p_filtered)))
    p2.metric("Budget", money_pkr(p_filtered["Budget"].sum()))
    p3.metric("Contract Value", money_pkr(p_filtered["Contract_Value"].sum()))
    p4.metric("Paid USD", money_usd(p_filtered["Paid_USD"].sum()))

    left, right = st.columns(2)

    with left:
        fig = px.scatter(
            p_filtered,
            x="Budget",
            y="Bid_Count",
            size="Contract_Value",
            hover_name="Project",
            title="Project Budget vs Bid Activity",
        )
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)

    with right:
        fig = px.bar(
            p_filtered.nlargest(15, "Paid_USD"),
            x="Project",
            y="Paid_USD",
            title="Top Projects by Recorded Payments",
        )
        fig.update_layout(height=400, xaxis_tickangle=-45)
        st.plotly_chart(fig, use_container_width=True)

    st.dataframe(
        p_filtered.sort_values("Paid_USD", ascending=False),
        use_container_width=True,
        hide_index=True,
    )

    # Freelancer performance
    st.subheader("3. Freelancer Performance")

    perf = freelancer_intelligence()

    if not perf.empty:
        left, right = st.columns(2)

        with left:
            fig = px.scatter(
                perf,
                x="Experience_Years",
                y="Avg_Rating",
                size="Completed_Projects",
                hover_name="Freelancer_Name",
                title="Experience vs Rating",
            )
            fig.update_layout(height=400)
            st.plotly_chart(fig, use_container_width=True)

        with right:
            top = perf.nlargest(15, "Paid_USD")
            fig = px.bar(
                top,
                x="Freelancer_Name",
                y="Paid_USD",
                title="Top Freelancers by Recorded Payments",
            )
            fig.update_layout(height=400, xaxis_tickangle=-45)
            st.plotly_chart(fig, use_container_width=True)

        st.dataframe(
            perf.sort_values("Paid_USD", ascending=False),
            use_container_width=True,
            hide_index=True,
        )

    # Skills and demand
    st.subheader("4. Skills Supply vs Market Demand")

    skill_df = skills_intelligence()
    safe_numeric(
        skill_df,
        ["Freelancer_Supply", "Demand_Score", "Growth_Rate"],
    )

    if not skill_df.empty:
        skill_df["Opportunity_Score"] = (
            skill_df["Demand_Score"]
            * (1 + skill_df["Growth_Rate"].clip(lower=-100) / 100)
            / (skill_df["Freelancer_Supply"] + 1)
        ).round(2)

        left, right = st.columns(2)

        with left:
            fig = px.bar(
                skill_df.nlargest(15, "Demand_Score"),
                x="Skill",
                y="Demand_Score",
                title="Highest Current Skill Demand",
            )
            fig.update_layout(height=420, xaxis_tickangle=-45)
            st.plotly_chart(fig, use_container_width=True)

        with right:
            fig = px.scatter(
                skill_df,
                x="Freelancer_Supply",
                y="Demand_Score",
                size="Growth_Rate",
                hover_name="Skill",
                title="Skill Supply vs Demand",
            )
            fig.update_layout(height=420)
            st.plotly_chart(fig, use_container_width=True)

        st.dataframe(
            skill_df.sort_values("Opportunity_Score", ascending=False),
            use_container_width=True,
            hide_index=True,
        )

        st.caption(
            "Opportunity Score is an explainable indicator: higher demand and growth "
            "combined with lower freelancer supply produce a higher opportunity value."
        )

    # Fraud
    st.subheader("5. Fraud & Trust Intelligence")

    fraud = fraud_intelligence()

    if fraud.empty:
        st.info("No fraud flags are currently recorded.")
    else:
        q1, q2, q3 = st.columns(3)
        q1.metric("Fraud Flags", number(len(fraud)))
        q2.metric(
            "Average Confidence",
            f'{pd.to_numeric(fraud["Confidence"], errors="coerce").mean():.1f}%'
        )
        q3.metric(
            "Flagged Reviews",
            number(fraud["Review_Flagged"].sum())
        )

        fig = px.histogram(
            fraud,
            x="Confidence",
            nbins=10,
            title="Fraud Flag Confidence Distribution",
        )
        fig.update_layout(height=350)
        st.plotly_chart(fig, use_container_width=True)

        st.dataframe(
            fraud,
            use_container_width=True,
            hide_index=True,
        )

    st.subheader("6. Management Recommendations")

    recommendations = []

    if k["completion_rate"] < 50:
        recommendations.append(
            "Investigate project delivery bottlenecks because completion is below 50%."
        )
    else:
        recommendations.append(
            "Maintain delivery controls; the current completion rate is at least 50%."
        )

    if k["bid_to_contract"] < 25:
        recommendations.append(
            "Bid-to-contract conversion is low; review pricing, freelancer fit and project quality."
        )
    else:
        recommendations.append(
            "Bid-to-contract conversion is reasonable; continue monitoring project-fit quality."
        )

    if k["fraud_flags"] > 0:
        recommendations.append(
            "Review high-confidence fraud flags manually before taking account-level action."
        )

    if not skill_df.empty:
        opportunity = skill_df.nlargest(3, "Opportunity_Score")
        if not opportunity.empty:
            names = ", ".join(opportunity["Skill"].astype(str).tolist())
            recommendations.append(
                f"Potential skill-supply opportunities based on the current model: {names}."
            )

    for r in recommendations:
        st.write("• " + r)

    st.caption(
        "Management recommendations are generated from database KPIs and transparent rules; "
        "they are decision support rather than autonomous business decisions."
    )


# ============================================================
# PAGE 4 — DATA EXPLORER
# ============================================================
else:
    st.header("Data Explorer")

    st.write(
        "Inspect the live GigBase SQL Server tables. This page is included "
        "for validation and debugging of the management calculations."
    )

    tables = query(
        """
        SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA='dbo'
          AND TABLE_TYPE='BASE TABLE'
        ORDER BY TABLE_NAME
        """
    )

    selected_table = st.selectbox(
        "Select table",
        tables["TABLE_NAME"].tolist(),
    )

    structure = query(
        """
        SELECT
            ORDINAL_POSITION,
            COLUMN_NAME,
            DATA_TYPE,
            CHARACTER_MAXIMUM_LENGTH,
            IS_NULLABLE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA='dbo'
          AND TABLE_NAME=?
        ORDER BY ORDINAL_POSITION
        """,
        [selected_table],
    )

    st.subheader("Table Structure")
    st.dataframe(
        structure,
        use_container_width=True,
        hide_index=True,
    )

    row_limit = st.slider(
        "Rows to display",
        min_value=10,
        max_value=500,
        value=100,
        step=10,
    )

    data = query(
        f"SELECT TOP {int(row_limit)} * FROM dbo.[{selected_table}]"
    )

    st.subheader(f"Records — {selected_table}")
    st.write(f"Rows returned: {len(data):,}")
    st.dataframe(
        data,
        use_container_width=True,
        hide_index=True,
    )

    # Basic data-quality checks
    st.subheader("Data Quality")

    q1, q2, q3 = st.columns(3)
    q1.metric("Rows in sample", number(len(data)))
    q2.metric("Columns", number(len(data.columns)))
    q3.metric("Missing cells", number(int(data.isna().sum().sum())))

    if not data.empty:
        nulls = (
            data.isna()
            .sum()
            .reset_index()
        )
        nulls.columns = ["Column", "Missing"]
        nulls = nulls[nulls["Missing"] > 0]

        if not nulls.empty:
            st.dataframe(
                nulls.sort_values("Missing", ascending=False),
                use_container_width=True,
                hide_index=True,
            )
        else:
            st.success("No NULL values found in the displayed sample.")

    csv = data.to_csv(index=False).encode("utf-8")

    st.download_button(
        "Download CSV",
        data=csv,
        file_name=f"gigbase_{selected_table.lower()}.csv",
        mime="text/csv",
    )
