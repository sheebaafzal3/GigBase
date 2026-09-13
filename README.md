# GigBase — AI-Powered Gig Economy Management System

GigBase is an AI-powered gig economy management system designed to support freelancers, clients, and platform managers through intelligent data-driven decision making.

The system combines a **Python Streamlit dashboard** with a **Microsoft SQL Server database** to provide freelancer risk assessment, intelligent freelancer matching, financial insights, project intelligence, fraud monitoring, and management recommendations.

---

##  Project Overview

The gig economy generates large amounts of data related to freelancers, clients, projects, bids, contracts, milestones, payments, reviews, skills, earnings, and demand trends.

GigBase transforms this operational data into actionable intelligence.

The system focuses on three major intelligent capabilities:

1. **AI-Powered Risk Scoring**
2. **Intelligent Freelancer Matching**
3. **Management Intelligence**

It also provides an interactive executive dashboard and a data exploration module.

---

##  Project Objectives

The main objectives of GigBase are to:

- Monitor gig economy platform performance
- Evaluate freelancer reliability and risk
- Identify potentially fraudulent or suspicious activity
- Match freelancers with projects using multiple performance factors
- Analyze freelancer earnings and performance
- Monitor project and contract activity
- Analyze skill supply and market demand
- Provide management-level recommendations
- Convert SQL Server data into meaningful business intelligence
- Provide explainable scoring rather than black-box predictions

---

#  Key Features

## 1. Executive Dashboard

The Executive Dashboard provides a high-level overview of the GigBase platform.

It includes:

- Total users
- Total freelancers
- Total clients
- Total projects
- Total contracts
- Total payments
- Average freelancer rating
- Project status distribution
- Payment trends
- Platform activity indicators

The dashboard is designed to give managers a quick understanding of the current state of the platform.

---

## 2. AI Risk & Matching

GigBase provides explainable intelligence for freelancer evaluation.

### Freelancer Risk Scoring

The system evaluates freelancers using signals such as:

- Fraud flag count
- Flagged reviews
- Fraud confidence scores
- Average rating
- Experience
- Platform activity
- Earnings/performance information

The result is an interpretable risk score and risk classification.

Example classifications include:

- Low Risk
- Medium Risk
- High Risk

Rather than producing an unexplained prediction, the system shows the factors contributing to the risk assessment.

### Intelligent Freelancer Matching

The matching engine ranks freelancers according to factors such as:

- Career rating
- Experience
- Freelancer ranking
- Completed projects
- Risk level
- Relevant skills

A matching score is calculated to help identify suitable freelancers for project opportunities.

---

#  3. Management Intelligence

The Management Intelligence module converts operational data into management-level insights.

It analyzes:

### Financial Performance

- Total payment value
- Payment trends
- Freelancer earnings
- Monthly earnings
- Financial activity

### Project & Contract Intelligence

- Open projects
- Completed projects
- Projects in progress
- Contract activity
- Project budgets
- Contract values
- Milestone progress

### Freelancer Performance

- Average ratings
- Experience
- Earnings
- Project activity
- Rankings
- Risk indicators

### Skills & Market Demand

The system compares:

- Freelancer skill availability
- Skill demand
- Demand scores
- Growth rates

This helps identify skills that may have increasing market demand.

### Fraud Monitoring

The platform monitors:

- Flagged reviews
- Fraud flags
- Fraud confidence
- Suspicious activity indicators

### Management Recommendations

Based on the calculated indicators, GigBase generates actionable recommendations for platform management.

---

#  4. Data Explorer

The Data Explorer provides direct visibility into the SQL Server database.

It allows users to:

- Browse database tables
- Inspect table structures
- View records
- Examine data quality
- Download table data as CSV

This makes the system useful not only as a dashboard but also as a data exploration and management tool.

---

#  Database Architecture

GigBase uses **Microsoft SQL Server** as its relational database.

The database contains the following major entities:

```text
Users
 ├── Freelancers
 └── Clients

Clients
 └── Projects
      ├── Bids
      └── Contracts
           ├── Milestones
           │    └── Payments
           └── Reviews
                └── Fraud_Flags

Freelancers
 ├── Freelancer_Skills
 ├── Bids
 ├── Contracts
 ├── Earnings_Log
 └── Freelancer_Rankings

Skills
 ├── Freelancer_Skills
 └── Demand_Trends
