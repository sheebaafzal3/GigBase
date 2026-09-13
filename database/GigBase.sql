
USE master;
GO
IF DB_ID('GigBase') IS NOT NULL
BEGIN
    ALTER DATABASE GigBase SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE GigBase;
END;
GO
CREATE DATABASE GigBase;
GO
USE GigBase;
GO

-- CREATING TABLES

CREATE TABLE dbo.Users
(
    user_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    email NVARCHAR(150) NOT NULL UNIQUE,
    role NVARCHAR(20) NOT NULL,
    country NVARCHAR(100) NOT NULL,
    join_date DATE NOT NULL,
    CONSTRAINT CK_Users_Role CHECK (role IN ('Freelancer','Client'))
);
CREATE TABLE dbo.Freelancers
(
    freelancer_id INT PRIMARY KEY,
    hourly_rate DECIMAL(10,2) NOT NULL,
    experience_years INT NOT NULL,
    availability BIT NOT NULL,
    CONSTRAINT FK_Freelancers_Users FOREIGN KEY (freelancer_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT CK_Freelancers_Rate CHECK (hourly_rate > 0),
    CONSTRAINT CK_Freelancers_Experience CHECK (experience_years >= 0)
);
CREATE TABLE dbo.Clients
(
    client_id INT PRIMARY KEY,
    company_name NVARCHAR(150) NOT NULL,
    industry NVARCHAR(100) NOT NULL,
    total_spent DECIMAL(12,2) NOT NULL,
    CONSTRAINT FK_Clients_Users FOREIGN KEY (client_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT CK_Clients_Spent CHECK (total_spent >= 0)
);
CREATE TABLE dbo.Skills
(
    skill_id INT IDENTITY(1,1) PRIMARY KEY,
    skill_name NVARCHAR(100) NOT NULL UNIQUE,
    category NVARCHAR(100) NOT NULL
);
CREATE TABLE dbo.Freelancer_Skills
(
    freelancer_id INT NOT NULL,
    skill_id INT NOT NULL,
    proficiency_level NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_Freelancer_Skills PRIMARY KEY (freelancer_id, skill_id),
    CONSTRAINT FK_FreelancerSkills_Freelancer FOREIGN KEY (freelancer_id) REFERENCES dbo.Freelancers(freelancer_id),
    CONSTRAINT FK_FreelancerSkills_Skill FOREIGN KEY (skill_id) REFERENCES dbo.Skills(skill_id)
);
CREATE TABLE dbo.Projects
(
    project_id INT IDENTITY(1,1) PRIMARY KEY,
    client_id INT NOT NULL,
    title NVARCHAR(200) NOT NULL,
    budget DECIMAL(12,2) NOT NULL,
    deadline DATE NOT NULL,
    status NVARCHAR(30) NOT NULL,
    CONSTRAINT FK_Projects_Clients FOREIGN KEY (client_id) REFERENCES dbo.Clients(client_id),
    CONSTRAINT CK_Projects_Budget CHECK (budget > 0),
    CONSTRAINT CK_Projects_Status CHECK (status IN ('Open','In Progress','Completed','Cancelled'))
);
CREATE TABLE dbo.Bids
(
    bid_id INT IDENTITY(1,1) PRIMARY KEY,
    project_id INT NOT NULL,
    freelancer_id INT NOT NULL,
    proposed_amount DECIMAL(12,2) NOT NULL,
    bid_time DATETIME2 NOT NULL,
    CONSTRAINT FK_Bids_Projects FOREIGN KEY (project_id) REFERENCES dbo.Projects(project_id),
    CONSTRAINT FK_Bids_Freelancers FOREIGN KEY (freelancer_id) REFERENCES dbo.Freelancers(freelancer_id),
    CONSTRAINT CK_Bids_Amount CHECK (proposed_amount > 0)
);
CREATE TABLE dbo.Contracts
(
    contract_id INT IDENTITY(1,1) PRIMARY KEY,
    project_id INT NOT NULL,
    freelancer_id INT NOT NULL,
    agreed_amount DECIMAL(12,2) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NULL,
    CONSTRAINT FK_Contracts_Projects FOREIGN KEY (project_id) REFERENCES dbo.Projects(project_id),
    CONSTRAINT FK_Contracts_Freelancers FOREIGN KEY (freelancer_id) REFERENCES dbo.Freelancers(freelancer_id),
    CONSTRAINT CK_Contracts_Amount CHECK (agreed_amount > 0)
);
CREATE TABLE dbo.Milestones
(
    milestone_id INT IDENTITY(1,1) PRIMARY KEY,
    contract_id INT NOT NULL,
    title NVARCHAR(200) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    status NVARCHAR(30) NOT NULL,
    completed_at DATETIME2 NULL,
    CONSTRAINT FK_Milestones_Contracts FOREIGN KEY (contract_id) REFERENCES dbo.Contracts(contract_id),
    CONSTRAINT CK_Milestones_Amount CHECK (amount > 0),
    CONSTRAINT CK_Milestones_Status CHECK (status IN ('Pending','Completed','Cancelled'))
);
CREATE TABLE dbo.Payments
(
    payment_id INT IDENTITY(1,1) PRIMARY KEY,
    milestone_id INT NOT NULL UNIQUE,
    amount_pkr DECIMAL(15,2) NOT NULL,
    amount_usd DECIMAL(15,2) NOT NULL,
    exchange_rate DECIMAL(12,6) NOT NULL,
    CONSTRAINT FK_Payments_Milestones FOREIGN KEY (milestone_id) REFERENCES dbo.Milestones(milestone_id),
    CONSTRAINT CK_Payments_PKR CHECK (amount_pkr > 0),
    CONSTRAINT CK_Payments_USD CHECK (amount_usd > 0),
    CONSTRAINT CK_Payments_Rate CHECK (exchange_rate > 0)
);
CREATE TABLE dbo.Currency_Rates
(
    rate_id INT IDENTITY(1,1) PRIMARY KEY,
    currency_code CHAR(3) NOT NULL,
    rate_to_usd DECIMAL(15,6) NOT NULL,
    recorded_at DATETIME2 NOT NULL,
    CONSTRAINT CK_Currency_Rate CHECK (rate_to_usd > 0)
);
CREATE TABLE dbo.Earnings_Log
(
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    freelancer_id INT NOT NULL,
    month DATE NOT NULL,
    total_earned DECIMAL(15,2) NOT NULL,
    avg_rating DECIMAL(4,2) NOT NULL,
    CONSTRAINT FK_EarningsLog_Freelancers FOREIGN KEY (freelancer_id) REFERENCES dbo.Freelancers(freelancer_id),
    CONSTRAINT CK_Earnings_Earned CHECK (total_earned >= 0),
    CONSTRAINT CK_Earnings_Rating CHECK (avg_rating BETWEEN 1 AND 5)
);
CREATE TABLE dbo.Reviews
(
    review_id INT IDENTITY(1,1) PRIMARY KEY,
    contract_id INT NOT NULL,
    rating DECIMAL(3,2) NOT NULL,
    comment NVARCHAR(1000),
    is_flagged BIT NOT NULL DEFAULT 0,
    CONSTRAINT FK_Reviews_Contracts FOREIGN KEY (contract_id) REFERENCES dbo.Contracts(contract_id),
    CONSTRAINT CK_Reviews_Rating CHECK (rating BETWEEN 1 AND 5)
);
CREATE TABLE dbo.Fraud_Flags
(
    flag_id INT IDENTITY(1,1) PRIMARY KEY,
    review_id INT NOT NULL,
    reason NVARCHAR(500) NOT NULL,
    confidence_score DECIMAL(5,2) NOT NULL,
    flagged_at DATETIME2 NOT NULL,
    CONSTRAINT FK_FraudFlags_Reviews FOREIGN KEY (review_id) REFERENCES dbo.Reviews(review_id),
    CONSTRAINT CK_Fraud_Confidence CHECK (confidence_score BETWEEN 0 AND 100)
);
CREATE TABLE dbo.Freelancer_Rankings
(
    rank_id INT IDENTITY(1,1) PRIMARY KEY,
    freelancer_id INT NOT NULL,
    score DECIMAL(6,2) NOT NULL,
    rank_position INT NOT NULL,
    calculated_at DATETIME2 NOT NULL,
    CONSTRAINT FK_Rankings_Freelancers FOREIGN KEY (freelancer_id) REFERENCES dbo.Freelancers(freelancer_id),
    CONSTRAINT CK_Ranking_Score CHECK (score >= 0),
    CONSTRAINT CK_Ranking_Position CHECK (rank_position > 0)
);
CREATE TABLE dbo.Demand_Trends
(
    trend_id INT IDENTITY(1,1) PRIMARY KEY,
    skill_id INT NOT NULL,
    demand_score DECIMAL(10,2) NOT NULL,
    month DATE NOT NULL,
    growth_rate DECIMAL(8,2) NOT NULL,
    CONSTRAINT FK_DemandTrends_Skills FOREIGN KEY (skill_id) REFERENCES dbo.Skills(skill_id),
    CONSTRAINT CK_Demand_Score CHECK (demand_score >= 0)
);
GO
--  INSERT 80 USERS

SET IDENTITY_INSERT dbo.Users ON;
INSERT INTO dbo.Users (user_id,name,email,role,country,join_date) VALUES
(1,'Ali Khan','freelancer1@gigbase.pk','Freelancer','Pakistan','2024-01-19'),
(2,'Ayesha Ahmed','freelancer2@gigbase.pk','Freelancer','Pakistan','2024-01-28'),
(3,'Hamza Malik','freelancer3@gigbase.pk','Freelancer','Pakistan','2024-02-06'),
(4,'Fatima Noor','freelancer4@gigbase.pk','Freelancer','Pakistan','2024-02-15'),
(5,'Usman Tariq','freelancer5@gigbase.pk','Freelancer','Pakistan','2024-02-24'),
(6,'Hassan Raza','freelancer6@gigbase.pk','Freelancer','Pakistan','2024-03-04'),
(7,'Sana Iqbal','freelancer7@gigbase.pk','Freelancer','Pakistan','2024-03-13'),
(8,'Bilal Shah','freelancer8@gigbase.pk','Freelancer','Pakistan','2024-03-22'),
(9,'Hira Aslam','freelancer9@gigbase.pk','Freelancer','Pakistan','2024-03-31'),
(10,'Omer Farooq','freelancer10@gigbase.pk','Freelancer','Pakistan','2024-04-09'),
(11,'Zainab Ali','freelancer11@gigbase.pk','Freelancer','Pakistan','2024-04-18'),
(12,'Danish Khan','freelancer12@gigbase.pk','Freelancer','Pakistan','2024-04-27'),
(13,'Maham Tariq','freelancer13@gigbase.pk','Freelancer','Pakistan','2024-05-06'),
(14,'Saad Ahmed','freelancer14@gigbase.pk','Freelancer','Pakistan','2024-05-15'),
(15,'Maryam Raza','freelancer15@gigbase.pk','Freelancer','Pakistan','2024-05-24'),
(16,'Talha Siddiqui','freelancer16@gigbase.pk','Freelancer','Pakistan','2024-06-02'),
(17,'Iqra Khan','freelancer17@gigbase.pk','Freelancer','Pakistan','2024-06-11'),
(18,'Arham Malik','freelancer18@gigbase.pk','Freelancer','Pakistan','2024-06-20'),
(19,'Anum Shah','freelancer19@gigbase.pk','Freelancer','Pakistan','2024-06-29'),
(20,'Huzaifa Noor','freelancer20@gigbase.pk','Freelancer','Pakistan','2024-07-08'),
(21,'Laiba Ahmed','freelancer21@gigbase.pk','Freelancer','Pakistan','2024-07-17'),
(22,'Abdullah Raza','freelancer22@gigbase.pk','Freelancer','Pakistan','2024-07-26'),
(23,'Eman Fatima','freelancer23@gigbase.pk','Freelancer','Pakistan','2024-08-04'),
(24,'Rayan Khan','freelancer24@gigbase.pk','Freelancer','Pakistan','2024-08-13'),
(25,'Mehwish Ali','freelancer25@gigbase.pk','Freelancer','Pakistan','2024-08-22'),
(26,'Fahad Iqbal','freelancer26@gigbase.pk','Freelancer','Pakistan','2024-08-31'),
(27,'Kiran Aslam','freelancer27@gigbase.pk','Freelancer','Pakistan','2024-09-09'),
(28,'Shahzaib Tariq','freelancer28@gigbase.pk','Freelancer','Pakistan','2024-09-18'),
(29,'Muneeb Raza','freelancer29@gigbase.pk','Freelancer','Pakistan','2024-09-27'),
(30,'Areeba Khan','freelancer30@gigbase.pk','Freelancer','Pakistan','2024-10-06'),
(31,'Junaid Malik','freelancer31@gigbase.pk','Freelancer','Pakistan','2024-10-15'),
(32,'Komal Noor','freelancer32@gigbase.pk','Freelancer','Pakistan','2024-10-24'),
(33,'Yousuf Ahmed','freelancer33@gigbase.pk','Freelancer','Pakistan','2024-11-02'),
(34,'Sadia Raza','freelancer34@gigbase.pk','Freelancer','Pakistan','2024-11-11'),
(35,'Adeel Shah','freelancer35@gigbase.pk','Freelancer','Pakistan','2024-11-20'),
(36,'Misha Khan','freelancer36@gigbase.pk','Freelancer','Pakistan','2024-11-29'),
(37,'Rehan Ali','freelancer37@gigbase.pk','Freelancer','Pakistan','2024-12-08'),
(38,'Aiman Tariq','freelancer38@gigbase.pk','Freelancer','Pakistan','2024-12-17'),
(39,'Waleed Ahmed','freelancer39@gigbase.pk','Freelancer','Pakistan','2024-12-26'),
(40,'Nimra Raza','freelancer40@gigbase.pk','Freelancer','Pakistan','2025-01-04'),
(41,'Ahsan Malik','client1@gigbase.pk','Client','Pakistan','2024-02-16'),
(42,'Rimsha Noor','client2@gigbase.pk','Client','Pakistan','2024-02-27'),
(43,'Dawood Khan','client3@gigbase.pk','Client','Pakistan','2024-03-09'),
(44,'Mahnoor Ali','client4@gigbase.pk','Client','Pakistan','2024-03-20'),
(45,'Sameer Raza','client5@gigbase.pk','Client','Pakistan','2024-03-31'),
(46,'Saba Ahmed','client6@gigbase.pk','Client','Pakistan','2024-04-11'),
(47,'Ibrahim Shah','client7@gigbase.pk','Client','Pakistan','2024-04-22'),
(48,'Aleena Khan','client8@gigbase.pk','Client','Pakistan','2024-05-03'),
(49,'Noman Iqbal','client9@gigbase.pk','Client','Pakistan','2024-05-14'),
(50,'Rida Aslam','client10@gigbase.pk','Client','Pakistan','2024-05-25'),
(51,'Hamza Raza','client11@gigbase.pk','Client','Pakistan','2024-06-05'),
(52,'Madiha Noor','client12@gigbase.pk','Client','Pakistan','2024-06-16'),
(53,'Faris Khan','client13@gigbase.pk','Client','Pakistan','2024-06-27'),
(54,'Amna Ali','client14@gigbase.pk','Client','Pakistan','2024-07-08'),
(55,'Shayan Ahmed','client15@gigbase.pk','Client','Pakistan','2024-07-19'),
(56,'Maham Raza','client16@gigbase.pk','Client','Pakistan','2024-07-30'),
(57,'Zubair Malik','client17@gigbase.pk','Client','Pakistan','2024-08-10'),
(58,'Hania Khan','client18@gigbase.pk','Client','Pakistan','2024-08-21'),
(59,'Rayyan Ali','client19@gigbase.pk','Client','Pakistan','2024-09-01'),
(60,'Sundas Noor','client20@gigbase.pk','Client','Pakistan','2024-09-12'),
(61,'Haris Ahmed','client21@gigbase.pk','Client','Pakistan','2024-09-23'),
(62,'Areeba Raza','client22@gigbase.pk','Client','Pakistan','2024-10-04'),
(63,'Musa Khan','client23@gigbase.pk','Client','Pakistan','2024-10-15'),
(64,'Nashit Ali','client24@gigbase.pk','Client','Pakistan','2024-10-26'),
(65,'Esha Tariq','client25@gigbase.pk','Client','Pakistan','2024-11-06'),
(66,'Ayan Malik','client26@gigbase.pk','Client','Pakistan','2024-11-17'),
(67,'Alina Noor','client27@gigbase.pk','Client','Pakistan','2024-11-28'),
(68,'Rafay Ahmed','client28@gigbase.pk','Client','Pakistan','2024-12-09'),
(69,'Inaya Khan','client29@gigbase.pk','Client','Pakistan','2024-12-20'),
(70,'Shahmeer Raza','client30@gigbase.pk','Client','Pakistan','2024-12-31'),
(71,'Areej Ali','client31@gigbase.pk','Client','Pakistan','2025-01-11'),
(72,'Zayan Ahmed','client32@gigbase.pk','Client','Pakistan','2025-01-22'),
(73,'Anaya Raza','client33@gigbase.pk','Client','Pakistan','2025-02-02'),
(74,'Ilyas Khan','client34@gigbase.pk','Client','Pakistan','2025-02-13'),
(75,'Hiba Noor','client35@gigbase.pk','Client','Pakistan','2025-02-24'),
(76,'Murtaza Ali','client36@gigbase.pk','Client','Pakistan','2025-03-07'),
(77,'Saira Ahmed','client37@gigbase.pk','Client','Pakistan','2025-03-18'),
(78,'Rameez Khan','client38@gigbase.pk','Client','Pakistan','2025-03-29'),
(79,'Minal Raza','client39@gigbase.pk','Client','Pakistan','2025-04-09'),
(80,'Kashif Malik','client40@gigbase.pk','Client','Pakistan','2025-04-20');
SET IDENTITY_INSERT dbo.Users OFF;
GO

-- 3. INSERT 40 FREELANCERS
INSERT INTO dbo.Freelancers (freelancer_id,hourly_rate,experience_years,availability) VALUES
(1,23.65,2,1),
(2,25.30,3,1),
(3,26.95,4,1),
(4,28.60,5,1),
(5,30.25,6,1),
(6,31.90,7,1),
(7,33.55,8,1),
(8,35.20,9,0),
(9,36.85,10,1),
(10,38.50,1,1),
(11,40.15,2,1),
(12,41.80,3,1),
(13,43.45,4,1),
(14,45.10,5,1),
(15,46.75,6,1),
(16,48.40,7,0),
(17,50.05,8,1),
(18,51.70,9,1),
(19,53.35,10,1),
(20,55.00,1,1),
(21,56.65,2,1),
(22,58.30,3,1),
(23,59.95,4,1),
(24,61.60,5,0),
(25,63.25,6,1),
(26,64.90,7,1),
(27,66.55,8,1),
(28,68.20,9,1),
(29,69.85,10,1),
(30,71.50,1,1),
(31,73.15,2,1),
(32,74.80,3,0),
(33,76.45,4,1),
(34,78.10,5,1),
(35,79.75,6,1),
(36,81.40,7,1),
(37,83.05,8,1),
(38,84.70,9,1),
(39,86.35,10,1),
(40,88.00,1,0);
GO

--  INSERT 40 CLIENTS
INSERT INTO dbo.Clients (client_id,company_name,industry,total_spent) VALUES
(41,'Ahmed Enterprises','Technology',6000.00),
(42,'TechVision Pvt Ltd','E-Commerce',7425.00),
(43,'Digital Solutions','Marketing',8850.00),
(44,'Creative Hub','Finance',10275.00),
(45,'PakTech Solutions','Education',11700.00),
(46,'Karachi Commerce','Healthcare',13125.00),
(47,'Lahore Innovations','Retail',14550.00),
(48,'Islamabad Media','Media',15975.00),
(49,'BluePeak Systems','Technology',17400.00),
(50,'Nexa Digital','E-Commerce',18825.00),
(51,'Prime Retail','Marketing',20250.00),
(52,'Urban Foods','Finance',21675.00),
(53,'CloudWorks','Education',23100.00),
(54,'SmartBiz Pakistan','Healthcare',24525.00),
(55,'Vertex Labs','Retail',25950.00),
(56,'Crescent Marketing','Media',27375.00),
(57,'NextGen Apps','Technology',28800.00),
(58,'BrightPath Consulting','E-Commerce',30225.00),
(59,'CodeCraft Pakistan','Marketing',31650.00),
(60,'PixelPoint Studio','Finance',33075.00),
(61,'DataBridge Ltd','Education',34500.00),
(62,'MarketWave','Healthcare',35925.00),
(63,'Alpha Traders','Retail',7350.00),
(64,'GreenLeaf Organics','Media',8775.00),
(65,'SecureNet Pakistan','Technology',10200.00),
(66,'Insight Analytics','E-Commerce',11625.00),
(67,'Skyline Media','Marketing',13050.00),
(68,'RapidSoft','Finance',14475.00),
(69,'Nova Commerce','Education',15900.00),
(70,'PakGrowth','Healthcare',17325.00),
(71,'Orbit Solutions','Retail',18750.00),
(72,'Visionary Brands','Media',20175.00),
(73,'ConnectPro','Technology',21600.00),
(74,'Digital Nest','E-Commerce',23025.00),
(75,'MetroTech','Marketing',24450.00),
(76,'Fusion Works','Finance',25875.00),
(77,'EcomSphere','Education',27300.00),
(78,'PrimeEdge','Healthcare',28725.00),
(79,'WebMatrix','Retail',30150.00),
(80,'InnovatePK','Media',31575.00);
GO

--  INSERT 12 SKILLS
INSERT INTO dbo.Skills (skill_name,category) VALUES
('Web Development','Development'),
('App Development','Development'),
('Data Entry','Administrative'),
('Graphic Design','Design'),
('Digital Marketing','Marketing'),
('SEO','Marketing'),
('Content Writing','Writing'),
('Customer Support','Support'),
('Python','Development'),
('SQL','Data'),
('UI/UX Design','Design'),
('Data Analysis','Data');
GO

--. INSERT 100 FREELANCER-SKILL RELATIONSHIPS
INSERT INTO dbo.Freelancer_Skills (freelancer_id,skill_id,proficiency_level) VALUES
(1,1,'Advanced'),
(1,5,'Advanced'),
(1,8,'Intermediate'),
(2,2,'Beginner'),
(2,6,'Beginner'),
(2,9,'Expert'),
(3,3,'Advanced'),
(3,7,'Advanced'),
(3,10,'Intermediate'),
(4,4,'Beginner'),
(4,8,'Beginner'),
(4,11,'Expert'),
(5,5,'Advanced'),
(5,9,'Advanced'),
(5,12,'Intermediate'),
(6,6,'Beginner'),
(6,10,'Beginner'),
(6,1,'Expert'),
(7,7,'Advanced'),
(7,11,'Advanced'),
(7,2,'Intermediate'),
(8,8,'Beginner'),
(8,12,'Beginner'),
(8,3,'Expert'),
(9,9,'Advanced'),
(9,1,'Advanced'),
(9,4,'Intermediate'),
(10,10,'Beginner'),
(10,2,'Beginner'),
(10,5,'Expert'),
(11,11,'Advanced'),
(11,3,'Advanced'),
(11,6,'Intermediate'),
(12,12,'Beginner'),
(12,4,'Beginner'),
(12,7,'Expert'),
(13,1,'Advanced'),
(13,5,'Advanced'),
(13,8,'Intermediate'),
(14,2,'Beginner'),
(14,6,'Beginner'),
(14,9,'Expert'),
(15,3,'Advanced'),
(15,7,'Advanced'),
(15,10,'Intermediate'),
(16,4,'Beginner'),
(16,8,'Beginner'),
(16,11,'Expert'),
(17,5,'Advanced'),
(17,9,'Advanced'),
(17,12,'Intermediate'),
(18,6,'Beginner'),
(18,10,'Beginner'),
(18,1,'Expert'),
(19,7,'Advanced'),
(19,11,'Advanced'),
(19,2,'Intermediate'),
(20,8,'Beginner'),
(20,12,'Beginner'),
(20,3,'Expert'),
(21,9,'Advanced'),
(21,1,'Advanced'),
(22,10,'Beginner'),
(22,2,'Beginner'),
(23,11,'Advanced'),
(23,3,'Advanced'),
(24,12,'Beginner'),
(24,4,'Beginner'),
(25,1,'Advanced'),
(25,5,'Advanced'),
(26,2,'Beginner'),
(26,6,'Beginner'),
(27,3,'Advanced'),
(27,7,'Advanced'),
(28,4,'Beginner'),
(28,8,'Beginner'),
(29,5,'Advanced'),
(29,9,'Advanced'),
(30,6,'Beginner'),
(30,10,'Beginner'),
(31,7,'Advanced'),
(31,11,'Advanced'),
(32,8,'Beginner'),
(32,12,'Beginner'),
(33,9,'Advanced'),
(33,1,'Advanced'),
(34,10,'Beginner'),
(34,2,'Beginner'),
(35,11,'Advanced'),
(35,3,'Advanced'),
(36,12,'Beginner'),
(36,4,'Beginner'),
(37,1,'Advanced'),
(37,5,'Advanced'),
(38,2,'Beginner'),
(38,6,'Beginner'),
(39,3,'Advanced'),
(39,7,'Advanced'),
(40,4,'Beginner'),
(40,8,'Beginner');
GO

-- 7. INSERT 80 PROJECTS
INSERT INTO dbo.Projects (client_id,title,budget,deadline,status) VALUES
(41,'E-Commerce Website 1',3725.00,'2026-10-05','In Progress'),
(42,'Mobile Banking Application 2',4450.00,'2026-10-09','Completed'),
(43,'Digital Marketing Campaign 3',5175.00,'2026-10-13','Open'),
(44,'Brand Identity Design 4',5900.00,'2026-10-17','Open'),
(45,'SEO Optimization 5',6625.00,'2026-10-21','In Progress'),
(46,'Customer Support System 6',7350.00,'2026-10-25','Completed'),
(47,'Business Data Entry 7',8075.00,'2026-10-29','Open'),
(48,'Content Writing Campaign 8',8800.00,'2026-11-02','Open'),
(49,'Python Data Analysis 9',9525.00,'2026-11-06','In Progress'),
(50,'SQL Reporting Dashboard 10',10250.00,'2026-11-10','Completed'),
(51,'UI UX Redesign 11',10975.00,'2026-11-14','Open'),
(52,'Inventory Management System 12',11700.00,'2026-11-18','Open'),
(53,'E-Commerce Website 13',12425.00,'2026-11-22','In Progress'),
(54,'Mobile Banking Application 14',13150.00,'2026-11-26','Completed'),
(55,'Digital Marketing Campaign 15',13875.00,'2026-11-30','Open'),
(56,'Brand Identity Design 16',14600.00,'2026-12-04','Open'),
(57,'SEO Optimization 17',15325.00,'2026-12-08','In Progress'),
(58,'Customer Support System 18',16050.00,'2026-12-12','Completed'),
(59,'Business Data Entry 19',16775.00,'2026-12-16','Open'),
(60,'Content Writing Campaign 20',17500.00,'2026-12-20','Open'),
(61,'Python Data Analysis 21',18225.00,'2026-12-24','In Progress'),
(62,'SQL Reporting Dashboard 22',18950.00,'2026-12-28','Completed'),
(63,'UI UX Redesign 23',19675.00,'2027-01-01','Open'),
(64,'Inventory Management System 24',20400.00,'2027-01-05','Open'),
(65,'E-Commerce Website 25',21125.00,'2026-10-01','In Progress'),
(66,'Mobile Banking Application 26',21850.00,'2026-10-05','Completed'),
(67,'Digital Marketing Campaign 27',22575.00,'2026-10-09','Open'),
(68,'Brand Identity Design 28',3300.00,'2026-10-13','Open'),
(69,'SEO Optimization 29',4025.00,'2026-10-17','In Progress'),
(70,'Customer Support System 30',4750.00,'2026-10-21','Completed'),
(71,'Business Data Entry 31',5475.00,'2026-10-25','Open'),
(72,'Content Writing Campaign 32',6200.00,'2026-10-29','Open'),
(73,'Python Data Analysis 33',6925.00,'2026-11-02','In Progress'),
(74,'SQL Reporting Dashboard 34',7650.00,'2026-11-06','Completed'),
(75,'UI UX Redesign 35',8375.00,'2026-11-10','Open'),
(76,'Inventory Management System 36',9100.00,'2026-11-14','Open'),
(77,'E-Commerce Website 37',9825.00,'2026-11-18','In Progress'),
(78,'Mobile Banking Application 38',10550.00,'2026-11-22','Completed'),
(79,'Digital Marketing Campaign 39',11275.00,'2026-11-26','Open'),
(80,'Brand Identity Design 40',12000.00,'2026-11-30','Open'),
(41,'SEO Optimization 41',12725.00,'2026-12-04','In Progress'),
(42,'Customer Support System 42',13450.00,'2026-12-08','Completed'),
(43,'Business Data Entry 43',14175.00,'2026-12-12','Open'),
(44,'Content Writing Campaign 44',14900.00,'2026-12-16','Open'),
(45,'Python Data Analysis 45',15625.00,'2026-12-20','In Progress'),
(46,'SQL Reporting Dashboard 46',16350.00,'2026-12-24','Completed'),
(47,'UI UX Redesign 47',17075.00,'2026-12-28','Open'),
(48,'Inventory Management System 48',17800.00,'2027-01-01','Open'),
(49,'E-Commerce Website 49',18525.00,'2027-01-05','In Progress'),
(50,'Mobile Banking Application 50',19250.00,'2026-10-01','Completed'),
(51,'Digital Marketing Campaign 51',19975.00,'2026-10-05','Open'),
(52,'Brand Identity Design 52',20700.00,'2026-10-09','Open'),
(53,'SEO Optimization 53',21425.00,'2026-10-13','In Progress'),
(54,'Customer Support System 54',22150.00,'2026-10-17','Completed'),
(55,'Business Data Entry 55',22875.00,'2026-10-21','Open'),
(56,'Content Writing Campaign 56',3600.00,'2026-10-25','Open'),
(57,'Python Data Analysis 57',4325.00,'2026-10-29','In Progress'),
(58,'SQL Reporting Dashboard 58',5050.00,'2026-11-02','Completed'),
(59,'UI UX Redesign 59',5775.00,'2026-11-06','Open'),
(60,'Inventory Management System 60',6500.00,'2026-11-10','Open'),
(61,'E-Commerce Website 61',7225.00,'2026-11-14','In Progress'),
(62,'Mobile Banking Application 62',7950.00,'2026-11-18','Completed'),
(63,'Digital Marketing Campaign 63',8675.00,'2026-11-22','Open'),
(64,'Brand Identity Design 64',9400.00,'2026-11-26','Open'),
(65,'SEO Optimization 65',10125.00,'2026-11-30','In Progress'),
(66,'Customer Support System 66',10850.00,'2026-12-04','Completed'),
(67,'Business Data Entry 67',11575.00,'2026-12-08','Open'),
(68,'Content Writing Campaign 68',12300.00,'2026-12-12','Open'),
(69,'Python Data Analysis 69',13025.00,'2026-12-16','In Progress'),
(70,'SQL Reporting Dashboard 70',13750.00,'2026-12-20','Completed'),
(71,'UI UX Redesign 71',14475.00,'2026-12-24','Open'),
(72,'Inventory Management System 72',15200.00,'2026-12-28','Open'),
(73,'E-Commerce Website 73',15925.00,'2027-01-01','In Progress'),
(74,'Mobile Banking Application 74',16650.00,'2027-01-05','Completed'),
(75,'Digital Marketing Campaign 75',17375.00,'2026-10-01','Open'),
(76,'Brand Identity Design 76',18100.00,'2026-10-05','Open'),
(77,'SEO Optimization 77',18825.00,'2026-10-09','In Progress'),
(78,'Customer Support System 78',19550.00,'2026-10-13','Completed'),
(79,'Business Data Entry 79',20275.00,'2026-10-17','Open'),
(80,'Content Writing Campaign 80',21000.00,'2026-10-21','Open');
GO

-- 8. INSERT 160 BIDS
INSERT INTO dbo.Bids (project_id,freelancer_id,proposed_amount,bid_time) VALUES
(1,1,3278.00,'2026-09-02 10:00:00'),
(1,13,3538.75,'2026-09-02 11:00:00'),
(2,2,3916.00,'2026-09-03 10:00:00'),
(2,14,4227.50,'2026-09-03 11:00:00'),
(3,3,4554.00,'2026-09-04 10:00:00'),
(3,15,4916.25,'2026-09-04 11:00:00'),
(4,4,5192.00,'2026-09-05 10:00:00'),
(4,16,5605.00,'2026-09-05 11:00:00'),
(5,5,5830.00,'2026-09-06 10:00:00'),
(5,17,6293.75,'2026-09-06 11:00:00'),
(6,6,6468.00,'2026-09-07 10:00:00'),
(6,18,6982.50,'2026-09-07 11:00:00'),
(7,7,7106.00,'2026-09-08 10:00:00'),
(7,19,7671.25,'2026-09-08 11:00:00'),
(8,8,7744.00,'2026-09-09 10:00:00'),
(8,20,8360.00,'2026-09-09 11:00:00'),
(9,9,8382.00,'2026-09-01 10:00:00'),
(9,21,9048.75,'2026-09-01 11:00:00'),
(10,10,9020.00,'2026-09-02 10:00:00'),
(10,22,9737.50,'2026-09-02 11:00:00'),
(11,11,9658.00,'2026-09-03 10:00:00'),
(11,23,10426.25,'2026-09-03 11:00:00'),
(12,12,10296.00,'2026-09-04 10:00:00'),
(12,24,11115.00,'2026-09-04 11:00:00'),
(13,13,10934.00,'2026-09-05 10:00:00'),
(13,25,11803.75,'2026-09-05 11:00:00'),
(14,14,11572.00,'2026-09-06 10:00:00'),
(14,26,12492.50,'2026-09-06 11:00:00'),
(15,15,12210.00,'2026-09-07 10:00:00'),
(15,27,13181.25,'2026-09-07 11:00:00'),
(16,16,12848.00,'2026-09-08 10:00:00'),
(16,28,13870.00,'2026-09-08 11:00:00'),
(17,17,13486.00,'2026-09-09 10:00:00'),
(17,29,14558.75,'2026-09-09 11:00:00'),
(18,18,14124.00,'2026-09-01 10:00:00'),
(18,30,15247.50,'2026-09-01 11:00:00'),
(19,19,14762.00,'2026-09-02 10:00:00'),
(19,31,15936.25,'2026-09-02 11:00:00'),
(20,20,15400.00,'2026-09-03 10:00:00'),
(20,32,16625.00,'2026-09-03 11:00:00'),
(21,21,16038.00,'2026-09-04 10:00:00'),
(21,33,17313.75,'2026-09-04 11:00:00'),
(22,22,16676.00,'2026-09-05 10:00:00'),
(22,34,18002.50,'2026-09-05 11:00:00'),
(23,23,17314.00,'2026-09-06 10:00:00'),
(23,35,18691.25,'2026-09-06 11:00:00'),
(24,24,17952.00,'2026-09-07 10:00:00'),
(24,36,19380.00,'2026-09-07 11:00:00'),
(25,25,18590.00,'2026-09-08 10:00:00'),
(25,37,20068.75,'2026-09-08 11:00:00'),
(26,26,19228.00,'2026-09-09 10:00:00'),
(26,38,20757.50,'2026-09-09 11:00:00'),
(27,27,19866.00,'2026-09-01 10:00:00'),
(27,39,21446.25,'2026-09-01 11:00:00'),
(28,28,2904.00,'2026-09-02 10:00:00'),
(28,40,3135.00,'2026-09-02 11:00:00'),
(29,29,3542.00,'2026-09-03 10:00:00'),
(29,1,3823.75,'2026-09-03 11:00:00'),
(30,30,4180.00,'2026-09-04 10:00:00'),
(30,2,4512.50,'2026-09-04 11:00:00'),
(31,31,4818.00,'2026-09-05 10:00:00'),
(31,3,5201.25,'2026-09-05 11:00:00'),
(32,32,5456.00,'2026-09-06 10:00:00'),
(32,4,5890.00,'2026-09-06 11:00:00'),
(33,33,6094.00,'2026-09-07 10:00:00'),
(33,5,6578.75,'2026-09-07 11:00:00'),
(34,34,6732.00,'2026-09-08 10:00:00'),
(34,6,7267.50,'2026-09-08 11:00:00'),
(35,35,7370.00,'2026-09-09 10:00:00'),
(35,7,7956.25,'2026-09-09 11:00:00'),
(36,36,8008.00,'2026-09-01 10:00:00'),
(36,8,8645.00,'2026-09-01 11:00:00'),
(37,37,8646.00,'2026-09-02 10:00:00'),
(37,9,9333.75,'2026-09-02 11:00:00'),
(38,38,9284.00,'2026-09-03 10:00:00'),
(38,10,10022.50,'2026-09-03 11:00:00'),
(39,39,9922.00,'2026-09-04 10:00:00'),
(39,11,10711.25,'2026-09-04 11:00:00'),
(40,40,10560.00,'2026-09-05 10:00:00'),
(40,12,11400.00,'2026-09-05 11:00:00'),
(41,1,11198.00,'2026-09-06 10:00:00'),
(41,13,12088.75,'2026-09-06 11:00:00'),
(42,2,11836.00,'2026-09-07 10:00:00'),
(42,14,12777.50,'2026-09-07 11:00:00'),
(43,3,12474.00,'2026-09-08 10:00:00'),
(43,15,13466.25,'2026-09-08 11:00:00'),
(44,4,13112.00,'2026-09-09 10:00:00'),
(44,16,14155.00,'2026-09-09 11:00:00'),
(45,5,13750.00,'2026-09-01 10:00:00'),
(45,17,14843.75,'2026-09-01 11:00:00'),
(46,6,14388.00,'2026-09-02 10:00:00'),
(46,18,15532.50,'2026-09-02 11:00:00'),
(47,7,15026.00,'2026-09-03 10:00:00'),
(47,19,16221.25,'2026-09-03 11:00:00'),
(48,8,15664.00,'2026-09-04 10:00:00'),
(48,20,16910.00,'2026-09-04 11:00:00'),
(49,9,16302.00,'2026-09-05 10:00:00'),
(49,21,17598.75,'2026-09-05 11:00:00'),
(50,10,16940.00,'2026-09-06 10:00:00'),
(50,22,18287.50,'2026-09-06 11:00:00'),
(51,11,17578.00,'2026-09-07 10:00:00'),
(51,23,18976.25,'2026-09-07 11:00:00'),
(52,12,18216.00,'2026-09-08 10:00:00'),
(52,24,19665.00,'2026-09-08 11:00:00'),
(53,13,18854.00,'2026-09-09 10:00:00'),
(53,25,20353.75,'2026-09-09 11:00:00'),
(54,14,19492.00,'2026-09-01 10:00:00'),
(54,26,21042.50,'2026-09-01 11:00:00'),
(55,15,20130.00,'2026-09-02 10:00:00'),
(55,27,21731.25,'2026-09-02 11:00:00'),
(56,16,3168.00,'2026-09-03 10:00:00'),
(56,28,3420.00,'2026-09-03 11:00:00'),
(57,17,3806.00,'2026-09-04 10:00:00'),
(57,29,4108.75,'2026-09-04 11:00:00'),
(58,18,4444.00,'2026-09-05 10:00:00'),
(58,30,4797.50,'2026-09-05 11:00:00'),
(59,19,5082.00,'2026-09-06 10:00:00'),
(59,31,5486.25,'2026-09-06 11:00:00'),
(60,20,5720.00,'2026-09-07 10:00:00'),
(60,32,6175.00,'2026-09-07 11:00:00'),
(61,21,6358.00,'2026-09-08 10:00:00'),
(61,33,6863.75,'2026-09-08 11:00:00'),
(62,22,6996.00,'2026-09-09 10:00:00'),
(62,34,7552.50,'2026-09-09 11:00:00'),
(63,23,7634.00,'2026-09-01 10:00:00'),
(63,35,8241.25,'2026-09-01 11:00:00'),
(64,24,8272.00,'2026-09-02 10:00:00'),
(64,36,8930.00,'2026-09-02 11:00:00'),
(65,25,8910.00,'2026-09-03 10:00:00'),
(65,37,9618.75,'2026-09-03 11:00:00'),
(66,26,9548.00,'2026-09-04 10:00:00'),
(66,38,10307.50,'2026-09-04 11:00:00'),
(67,27,10186.00,'2026-09-05 10:00:00'),
(67,39,10996.25,'2026-09-05 11:00:00'),
(68,28,10824.00,'2026-09-06 10:00:00'),
(68,40,11685.00,'2026-09-06 11:00:00'),
(69,29,11462.00,'2026-09-07 10:00:00'),
(69,1,12373.75,'2026-09-07 11:00:00'),
(70,30,12100.00,'2026-09-08 10:00:00'),
(70,2,13062.50,'2026-09-08 11:00:00'),
(71,31,12738.00,'2026-09-09 10:00:00'),
(71,3,13751.25,'2026-09-09 11:00:00'),
(72,32,13376.00,'2026-09-01 10:00:00'),
(72,4,14440.00,'2026-09-01 11:00:00'),
(73,33,14014.00,'2026-09-02 10:00:00'),
(73,5,15128.75,'2026-09-02 11:00:00'),
(74,34,14652.00,'2026-09-03 10:00:00'),
(74,6,15817.50,'2026-09-03 11:00:00'),
(75,35,15290.00,'2026-09-04 10:00:00'),
(75,7,16506.25,'2026-09-04 11:00:00'),
(76,36,15928.00,'2026-09-05 10:00:00'),
(76,8,17195.00,'2026-09-05 11:00:00'),
(77,37,16566.00,'2026-09-06 10:00:00'),
(77,9,17883.75,'2026-09-06 11:00:00'),
(78,38,17204.00,'2026-09-07 10:00:00'),
(78,10,18572.50,'2026-09-07 11:00:00'),
(79,39,17842.00,'2026-09-08 10:00:00'),
(79,11,19261.25,'2026-09-08 11:00:00'),
(80,40,18480.00,'2026-09-09 10:00:00'),
(80,12,19950.00,'2026-09-09 11:00:00');
GO

-- 9. INSERT 80 CONTRACTS
INSERT INTO dbo.Contracts (project_id,freelancer_id,agreed_amount,start_date,end_date) VALUES
(1,3,3352.50,'2026-07-02','2026-08-02'),
(2,6,4005.00,'2026-07-03','2026-08-04'),
(3,9,4657.50,'2026-07-04','2026-08-06'),
(4,12,5310.00,'2026-07-05','2026-08-08'),
(5,15,5962.50,'2026-07-06','2026-08-10'),
(6,18,6615.00,'2026-07-07','2026-08-12'),
(7,21,7267.50,'2026-07-08','2026-08-14'),
(8,24,7920.00,'2026-07-09','2026-08-16'),
(9,27,8572.50,'2026-07-10','2026-08-18'),
(10,30,9225.00,'2026-07-11','2026-08-20'),
(11,33,9877.50,'2026-07-12','2026-08-22'),
(12,36,10530.00,'2026-07-13','2026-08-24'),
(13,39,11182.50,'2026-07-14','2026-08-26'),
(14,2,11835.00,'2026-07-15','2026-08-28'),
(15,5,12487.50,'2026-07-16','2026-08-30'),
(16,8,13140.00,'2026-07-17','2026-09-01'),
(17,11,13792.50,'2026-07-18','2026-09-03'),
(18,14,14445.00,'2026-07-19','2026-09-05'),
(19,17,15097.50,'2026-07-20','2026-09-07'),
(20,20,15750.00,'2026-07-21','2026-09-09'),
(21,23,16402.50,'2026-07-22','2026-09-11'),
(22,26,17055.00,'2026-07-23','2026-09-13'),
(23,29,17707.50,'2026-07-24','2026-09-15'),
(24,32,18360.00,'2026-07-25','2026-09-17'),
(25,35,19012.50,'2026-07-01','2026-08-25'),
(26,38,19665.00,'2026-07-02','2026-08-27'),
(27,1,20317.50,'2026-07-03','2026-08-29'),
(28,4,2970.00,'2026-07-04','2026-08-31'),
(29,7,3622.50,'2026-07-05','2026-09-02'),
(30,10,4275.00,'2026-07-06','2026-08-05'),
(31,13,4927.50,'2026-07-07','2026-08-07'),
(32,16,5580.00,'2026-07-08','2026-08-09'),
(33,19,6232.50,'2026-07-09','2026-08-11'),
(34,22,6885.00,'2026-07-10','2026-08-13'),
(35,25,7537.50,'2026-07-11','2026-08-15'),
(36,28,8190.00,'2026-07-12','2026-08-17'),
(37,31,8842.50,'2026-07-13','2026-08-19'),
(38,34,9495.00,'2026-07-14','2026-08-21'),
(39,37,10147.50,'2026-07-15','2026-08-23'),
(40,40,10800.00,'2026-07-16','2026-08-25'),
(41,3,11452.50,'2026-07-17','2026-08-27'),
(42,6,12105.00,'2026-07-18','2026-08-29'),
(43,9,12757.50,'2026-07-19','2026-08-31'),
(44,12,13410.00,'2026-07-20','2026-09-02'),
(45,15,14062.50,'2026-07-21','2026-09-04'),
(46,18,14715.00,'2026-07-22','2026-09-06'),
(47,21,15367.50,'2026-07-23','2026-09-08'),
(48,24,16020.00,'2026-07-24','2026-09-10'),
(49,27,16672.50,'2026-07-25','2026-09-12'),
(50,30,17325.00,'2026-07-01','2026-08-20'),
(51,33,17977.50,'2026-07-02','2026-08-22'),
(52,36,18630.00,'2026-07-03','2026-08-24'),
(53,39,19282.50,'2026-07-04','2026-08-26'),
(54,2,19935.00,'2026-07-05','2026-08-28'),
(55,5,20587.50,'2026-07-06','2026-08-30'),
(56,8,3240.00,'2026-07-07','2026-09-01'),
(57,11,3892.50,'2026-07-08','2026-09-03'),
(58,14,4545.00,'2026-07-09','2026-09-05'),
(59,17,5197.50,'2026-07-10','2026-09-07'),
(60,20,5850.00,'2026-07-11','2026-08-10'),
(61,23,6502.50,'2026-07-12','2026-08-12'),
(62,26,7155.00,'2026-07-13','2026-08-14'),
(63,29,7807.50,'2026-07-14','2026-08-16'),
(64,32,8460.00,'2026-07-15','2026-08-18'),
(65,35,9112.50,'2026-07-16','2026-08-20'),
(66,38,9765.00,'2026-07-17','2026-08-22'),
(67,1,10417.50,'2026-07-18','2026-08-24'),
(68,4,11070.00,'2026-07-19','2026-08-26'),
(69,7,11722.50,'2026-07-20','2026-08-28'),
(70,10,12375.00,'2026-07-21','2026-08-30'),
(71,13,13027.50,'2026-07-22','2026-09-01'),
(72,16,13680.00,'2026-07-23','2026-09-03'),
(73,19,14332.50,'2026-07-24','2026-09-05'),
(74,22,14985.00,'2026-07-25','2026-09-07'),
(75,25,15637.50,'2026-07-01','2026-08-15'),
(76,28,16290.00,'2026-07-02','2026-08-17'),
(77,31,16942.50,'2026-07-03','2026-08-19'),
(78,34,17595.00,'2026-07-04','2026-08-21'),
(79,37,18247.50,'2026-07-05','2026-08-23'),
(80,40,18900.00,'2026-07-06','2026-08-25');
GO

-- INSERT 160 MILESTONES (2 PER CONTRACT)
INSERT INTO dbo.Milestones (contract_id,title,amount,status,completed_at) VALUES
(1,'Milestone 1',1676.25,'Completed','2026-09-05 12:00:00'),
(1,'Milestone 2',1676.25,'Completed','2026-09-06 12:00:00'),
(2,'Milestone 1',2002.50,'Completed','2026-09-05 12:00:00'),
(2,'Milestone 2',2002.50,'Completed','2026-09-06 12:00:00'),
(3,'Milestone 1',2328.75,'Completed','2026-09-05 12:00:00'),
(3,'Milestone 2',2328.75,'Completed','2026-09-06 12:00:00'),
(4,'Milestone 1',2655.00,'Completed','2026-09-05 12:00:00'),
(4,'Milestone 2',2655.00,'Completed','2026-09-06 12:00:00'),
(5,'Milestone 1',2981.25,'Completed','2026-09-05 12:00:00'),
(5,'Milestone 2',2981.25,'Completed','2026-09-06 12:00:00'),
(6,'Milestone 1',3307.50,'Completed','2026-09-05 12:00:00'),
(6,'Milestone 2',3307.50,'Completed','2026-09-06 12:00:00'),
(7,'Milestone 1',3633.75,'Completed','2026-09-05 12:00:00'),
(7,'Milestone 2',3633.75,'Completed','2026-09-06 12:00:00'),
(8,'Milestone 1',3960.00,'Completed','2026-09-05 12:00:00'),
(8,'Milestone 2',3960.00,'Completed','2026-09-06 12:00:00'),
(9,'Milestone 1',4286.25,'Completed','2026-09-05 12:00:00'),
(9,'Milestone 2',4286.25,'Completed','2026-09-06 12:00:00'),
(10,'Milestone 1',4612.50,'Completed','2026-09-05 12:00:00'),
(10,'Milestone 2',4612.50,'Completed','2026-09-06 12:00:00'),
(11,'Milestone 1',4938.75,'Completed','2026-09-05 12:00:00'),
(11,'Milestone 2',4938.75,'Completed','2026-09-06 12:00:00'),
(12,'Milestone 1',5265.00,'Completed','2026-09-05 12:00:00'),
(12,'Milestone 2',5265.00,'Completed','2026-09-06 12:00:00'),
(13,'Milestone 1',5591.25,'Completed','2026-09-05 12:00:00'),
(13,'Milestone 2',5591.25,'Completed','2026-09-06 12:00:00'),
(14,'Milestone 1',5917.50,'Completed','2026-09-05 12:00:00'),
(14,'Milestone 2',5917.50,'Completed','2026-09-06 12:00:00'),
(15,'Milestone 1',6243.75,'Completed','2026-09-05 12:00:00'),
(15,'Milestone 2',6243.75,'Completed','2026-09-06 12:00:00'),
(16,'Milestone 1',6570.00,'Completed','2026-09-05 12:00:00'),
(16,'Milestone 2',6570.00,'Completed','2026-09-06 12:00:00'),
(17,'Milestone 1',6896.25,'Completed','2026-09-05 12:00:00'),
(17,'Milestone 2',6896.25,'Completed','2026-09-06 12:00:00'),
(18,'Milestone 1',7222.50,'Completed','2026-09-05 12:00:00'),
(18,'Milestone 2',7222.50,'Completed','2026-09-06 12:00:00'),
(19,'Milestone 1',7548.75,'Completed','2026-09-05 12:00:00'),
(19,'Milestone 2',7548.75,'Completed','2026-09-06 12:00:00'),
(20,'Milestone 1',7875.00,'Completed','2026-09-05 12:00:00'),
(20,'Milestone 2',7875.00,'Completed','2026-09-06 12:00:00'),
(21,'Milestone 1',8201.25,'Completed','2026-09-05 12:00:00'),
(21,'Milestone 2',8201.25,'Completed','2026-09-06 12:00:00'),
(22,'Milestone 1',8527.50,'Completed','2026-09-05 12:00:00'),
(22,'Milestone 2',8527.50,'Completed','2026-09-06 12:00:00'),
(23,'Milestone 1',8853.75,'Completed','2026-09-05 12:00:00'),
(23,'Milestone 2',8853.75,'Completed','2026-09-06 12:00:00'),
(24,'Milestone 1',9180.00,'Completed','2026-09-05 12:00:00'),
(24,'Milestone 2',9180.00,'Completed','2026-09-06 12:00:00'),
(25,'Milestone 1',9506.25,'Completed','2026-09-05 12:00:00'),
(25,'Milestone 2',9506.25,'Completed','2026-09-06 12:00:00'),
(26,'Milestone 1',9832.50,'Completed','2026-09-05 12:00:00'),
(26,'Milestone 2',9832.50,'Completed','2026-09-06 12:00:00'),
(27,'Milestone 1',10158.75,'Completed','2026-09-05 12:00:00'),
(27,'Milestone 2',10158.75,'Completed','2026-09-06 12:00:00'),
(28,'Milestone 1',1485.00,'Completed','2026-09-05 12:00:00'),
(28,'Milestone 2',1485.00,'Completed','2026-09-06 12:00:00'),
(29,'Milestone 1',1811.25,'Completed','2026-09-05 12:00:00'),
(29,'Milestone 2',1811.25,'Completed','2026-09-06 12:00:00'),
(30,'Milestone 1',2137.50,'Completed','2026-09-05 12:00:00'),
(30,'Milestone 2',2137.50,'Completed','2026-09-06 12:00:00'),
(31,'Milestone 1',2463.75,'Completed','2026-09-05 12:00:00'),
(31,'Milestone 2',2463.75,'Completed','2026-09-06 12:00:00'),
(32,'Milestone 1',2790.00,'Completed','2026-09-05 12:00:00'),
(32,'Milestone 2',2790.00,'Completed','2026-09-06 12:00:00'),
(33,'Milestone 1',3116.25,'Completed','2026-09-05 12:00:00'),
(33,'Milestone 2',3116.25,'Completed','2026-09-06 12:00:00'),
(34,'Milestone 1',3442.50,'Completed','2026-09-05 12:00:00'),
(34,'Milestone 2',3442.50,'Completed','2026-09-06 12:00:00'),
(35,'Milestone 1',3768.75,'Completed','2026-09-05 12:00:00'),
(35,'Milestone 2',3768.75,'Completed','2026-09-06 12:00:00'),
(36,'Milestone 1',4095.00,'Completed','2026-09-05 12:00:00'),
(36,'Milestone 2',4095.00,'Completed','2026-09-06 12:00:00'),
(37,'Milestone 1',4421.25,'Completed','2026-09-05 12:00:00'),
(37,'Milestone 2',4421.25,'Completed','2026-09-06 12:00:00'),
(38,'Milestone 1',4747.50,'Completed','2026-09-05 12:00:00'),
(38,'Milestone 2',4747.50,'Completed','2026-09-06 12:00:00'),
(39,'Milestone 1',5073.75,'Completed','2026-09-05 12:00:00'),
(39,'Milestone 2',5073.75,'Completed','2026-09-06 12:00:00'),
(40,'Milestone 1',5400.00,'Completed','2026-09-05 12:00:00'),
(40,'Milestone 2',5400.00,'Completed','2026-09-06 12:00:00'),
(41,'Milestone 1',5726.25,'Completed','2026-09-05 12:00:00'),
(41,'Milestone 2',5726.25,'Pending',NULL),
(42,'Milestone 1',6052.50,'Completed','2026-09-05 12:00:00'),
(42,'Milestone 2',6052.50,'Pending',NULL),
(43,'Milestone 1',6378.75,'Completed','2026-09-05 12:00:00'),
(43,'Milestone 2',6378.75,'Pending',NULL),
(44,'Milestone 1',6705.00,'Completed','2026-09-05 12:00:00'),
(44,'Milestone 2',6705.00,'Pending',NULL),
(45,'Milestone 1',7031.25,'Completed','2026-09-05 12:00:00'),
(45,'Milestone 2',7031.25,'Pending',NULL),
(46,'Milestone 1',7357.50,'Completed','2026-09-05 12:00:00'),
(46,'Milestone 2',7357.50,'Pending',NULL),
(47,'Milestone 1',7683.75,'Completed','2026-09-05 12:00:00'),
(47,'Milestone 2',7683.75,'Pending',NULL),
(48,'Milestone 1',8010.00,'Completed','2026-09-05 12:00:00'),
(48,'Milestone 2',8010.00,'Pending',NULL),
(49,'Milestone 1',8336.25,'Completed','2026-09-05 12:00:00'),
(49,'Milestone 2',8336.25,'Pending',NULL),
(50,'Milestone 1',8662.50,'Completed','2026-09-05 12:00:00'),
(50,'Milestone 2',8662.50,'Pending',NULL),
(51,'Milestone 1',8988.75,'Completed','2026-09-05 12:00:00'),
(51,'Milestone 2',8988.75,'Pending',NULL),
(52,'Milestone 1',9315.00,'Completed','2026-09-05 12:00:00'),
(52,'Milestone 2',9315.00,'Pending',NULL),
(53,'Milestone 1',9641.25,'Completed','2026-09-05 12:00:00'),
(53,'Milestone 2',9641.25,'Pending',NULL),
(54,'Milestone 1',9967.50,'Completed','2026-09-05 12:00:00'),
(54,'Milestone 2',9967.50,'Pending',NULL),
(55,'Milestone 1',10293.75,'Completed','2026-09-05 12:00:00'),
(55,'Milestone 2',10293.75,'Pending',NULL),
(56,'Milestone 1',1620.00,'Completed','2026-09-05 12:00:00'),
(56,'Milestone 2',1620.00,'Pending',NULL),
(57,'Milestone 1',1946.25,'Completed','2026-09-05 12:00:00'),
(57,'Milestone 2',1946.25,'Pending',NULL),
(58,'Milestone 1',2272.50,'Completed','2026-09-05 12:00:00'),
(58,'Milestone 2',2272.50,'Pending',NULL),
(59,'Milestone 1',2598.75,'Completed','2026-09-05 12:00:00'),
(59,'Milestone 2',2598.75,'Pending',NULL),
(60,'Milestone 1',2925.00,'Completed','2026-09-05 12:00:00'),
(60,'Milestone 2',2925.00,'Pending',NULL),
(61,'Milestone 1',3251.25,'Completed','2026-09-05 12:00:00'),
(61,'Milestone 2',3251.25,'Pending',NULL),
(62,'Milestone 1',3577.50,'Completed','2026-09-05 12:00:00'),
(62,'Milestone 2',3577.50,'Pending',NULL),
(63,'Milestone 1',3903.75,'Completed','2026-09-05 12:00:00'),
(63,'Milestone 2',3903.75,'Pending',NULL),
(64,'Milestone 1',4230.00,'Completed','2026-09-05 12:00:00'),
(64,'Milestone 2',4230.00,'Pending',NULL),
(65,'Milestone 1',4556.25,'Completed','2026-09-05 12:00:00'),
(65,'Milestone 2',4556.25,'Pending',NULL),
(66,'Milestone 1',4882.50,'Completed','2026-09-05 12:00:00'),
(66,'Milestone 2',4882.50,'Pending',NULL),
(67,'Milestone 1',5208.75,'Completed','2026-09-05 12:00:00'),
(67,'Milestone 2',5208.75,'Pending',NULL),
(68,'Milestone 1',5535.00,'Completed','2026-09-05 12:00:00'),
(68,'Milestone 2',5535.00,'Pending',NULL),
(69,'Milestone 1',5861.25,'Completed','2026-09-05 12:00:00'),
(69,'Milestone 2',5861.25,'Pending',NULL),
(70,'Milestone 1',6187.50,'Completed','2026-09-05 12:00:00'),
(70,'Milestone 2',6187.50,'Pending',NULL),
(71,'Milestone 1',6513.75,'Completed','2026-09-05 12:00:00'),
(71,'Milestone 2',6513.75,'Pending',NULL),
(72,'Milestone 1',6840.00,'Completed','2026-09-05 12:00:00'),
(72,'Milestone 2',6840.00,'Pending',NULL),
(73,'Milestone 1',7166.25,'Completed','2026-09-05 12:00:00'),
(73,'Milestone 2',7166.25,'Pending',NULL),
(74,'Milestone 1',7492.50,'Completed','2026-09-05 12:00:00'),
(74,'Milestone 2',7492.50,'Pending',NULL),
(75,'Milestone 1',7818.75,'Completed','2026-09-05 12:00:00'),
(75,'Milestone 2',7818.75,'Pending',NULL),
(76,'Milestone 1',8145.00,'Completed','2026-09-05 12:00:00'),
(76,'Milestone 2',8145.00,'Pending',NULL),
(77,'Milestone 1',8471.25,'Completed','2026-09-05 12:00:00'),
(77,'Milestone 2',8471.25,'Pending',NULL),
(78,'Milestone 1',8797.50,'Completed','2026-09-05 12:00:00'),
(78,'Milestone 2',8797.50,'Pending',NULL),
(79,'Milestone 1',9123.75,'Completed','2026-09-05 12:00:00'),
(79,'Milestone 2',9123.75,'Pending',NULL),
(80,'Milestone 1',9450.00,'Completed','2026-09-05 12:00:00'),
(80,'Milestone 2',9450.00,'Pending',NULL);
GO

-- 11. INSERT 120 PAYMENTS (ONE PAYMENT PER COMPLETED MILESTONE)
INSERT INTO dbo.Payments (milestone_id,amount_pkr,amount_usd,exchange_rate) VALUES
(1,477731.25,1676.25,285.000000),
(2,477731.25,1676.25,285.000000),
(3,570712.50,2002.50,285.000000),
(4,570712.50,2002.50,285.000000),
(5,663693.75,2328.75,285.000000),
(6,663693.75,2328.75,285.000000),
(7,756675.00,2655.00,285.000000),
(8,756675.00,2655.00,285.000000),
(9,849656.25,2981.25,285.000000),
(10,849656.25,2981.25,285.000000),
(11,942637.50,3307.50,285.000000),
(12,942637.50,3307.50,285.000000),
(13,1035618.75,3633.75,285.000000),
(14,1035618.75,3633.75,285.000000),
(15,1128600.00,3960.00,285.000000),
(16,1128600.00,3960.00,285.000000),
(17,1221581.25,4286.25,285.000000),
(18,1221581.25,4286.25,285.000000),
(19,1314562.50,4612.50,285.000000),
(20,1314562.50,4612.50,285.000000),
(21,1407543.75,4938.75,285.000000),
(22,1407543.75,4938.75,285.000000),
(23,1500525.00,5265.00,285.000000),
(24,1500525.00,5265.00,285.000000),
(25,1593506.25,5591.25,285.000000),
(26,1593506.25,5591.25,285.000000),
(27,1686487.50,5917.50,285.000000),
(28,1686487.50,5917.50,285.000000),
(29,1779468.75,6243.75,285.000000),
(30,1779468.75,6243.75,285.000000),
(31,1872450.00,6570.00,285.000000),
(32,1872450.00,6570.00,285.000000),
(33,1965431.25,6896.25,285.000000),
(34,1965431.25,6896.25,285.000000),
(35,2058412.50,7222.50,285.000000),
(36,2058412.50,7222.50,285.000000),
(37,2151393.75,7548.75,285.000000),
(38,2151393.75,7548.75,285.000000),
(39,2244375.00,7875.00,285.000000),
(40,2244375.00,7875.00,285.000000),
(41,2337356.25,8201.25,285.000000),
(42,2337356.25,8201.25,285.000000),
(43,2430337.50,8527.50,285.000000),
(44,2430337.50,8527.50,285.000000),
(45,2523318.75,8853.75,285.000000),
(46,2523318.75,8853.75,285.000000),
(47,2616300.00,9180.00,285.000000),
(48,2616300.00,9180.00,285.000000),
(49,2709281.25,9506.25,285.000000),
(50,2709281.25,9506.25,285.000000),
(51,2802262.50,9832.50,285.000000),
(52,2802262.50,9832.50,285.000000),
(53,2895243.75,10158.75,285.000000),
(54,2895243.75,10158.75,285.000000),
(55,423225.00,1485.00,285.000000),
(56,423225.00,1485.00,285.000000),
(57,516206.25,1811.25,285.000000),
(58,516206.25,1811.25,285.000000),
(59,609187.50,2137.50,285.000000),
(60,609187.50,2137.50,285.000000),
(61,702168.75,2463.75,285.000000),
(62,702168.75,2463.75,285.000000),
(63,795150.00,2790.00,285.000000),
(64,795150.00,2790.00,285.000000),
(65,888131.25,3116.25,285.000000),
(66,888131.25,3116.25,285.000000),
(67,981112.50,3442.50,285.000000),
(68,981112.50,3442.50,285.000000),
(69,1074093.75,3768.75,285.000000),
(70,1074093.75,3768.75,285.000000),
(71,1167075.00,4095.00,285.000000),
(72,1167075.00,4095.00,285.000000),
(73,1260056.25,4421.25,285.000000),
(74,1260056.25,4421.25,285.000000),
(75,1353037.50,4747.50,285.000000),
(76,1353037.50,4747.50,285.000000),
(77,1446018.75,5073.75,285.000000),
(78,1446018.75,5073.75,285.000000),
(79,1539000.00,5400.00,285.000000),
(80,1539000.00,5400.00,285.000000),
(81,1631981.25,5726.25,285.000000),
(83,1724962.50,6052.50,285.000000),
(85,1817943.75,6378.75,285.000000),
(87,1910925.00,6705.00,285.000000),
(89,2003906.25,7031.25,285.000000),
(91,2096887.50,7357.50,285.000000),
(93,2189868.75,7683.75,285.000000),
(95,2282850.00,8010.00,285.000000),
(97,2375831.25,8336.25,285.000000),
(99,2468812.50,8662.50,285.000000),
(101,2561793.75,8988.75,285.000000),
(103,2654775.00,9315.00,285.000000),
(105,2747756.25,9641.25,285.000000),
(107,2840737.50,9967.50,285.000000),
(109,2933718.75,10293.75,285.000000),
(111,461700.00,1620.00,285.000000),
(113,554681.25,1946.25,285.000000),
(115,647662.50,2272.50,285.000000),
(117,740643.75,2598.75,285.000000),
(119,833625.00,2925.00,285.000000),
(121,926606.25,3251.25,285.000000),
(123,1019587.50,3577.50,285.000000),
(125,1112568.75,3903.75,285.000000),
(127,1205550.00,4230.00,285.000000),
(129,1298531.25,4556.25,285.000000),
(131,1391512.50,4882.50,285.000000),
(133,1484493.75,5208.75,285.000000),
(135,1577475.00,5535.00,285.000000),
(137,1670456.25,5861.25,285.000000),
(139,1763437.50,6187.50,285.000000),
(141,1856418.75,6513.75,285.000000),
(143,1949400.00,6840.00,285.000000),
(145,2042381.25,7166.25,285.000000),
(147,2135362.50,7492.50,285.000000),
(149,2228343.75,7818.75,285.000000),
(151,2321325.00,8145.00,285.000000),
(153,2414306.25,8471.25,285.000000),
(155,2507287.50,8797.50,285.000000),
(157,2600268.75,9123.75,285.000000),
(159,2693250.00,9450.00,285.000000);
GO

-- 12. INSERT 24 CURRENCY-RATE RECORDS
INSERT INTO dbo.Currency_Rates (currency_code,rate_to_usd,recorded_at) VALUES
('USD',0.990000,'2026-04-01 09:00:00'),
('PKR',0.003465,'2026-04-01 09:00:00'),
('AED',0.269527,'2026-04-01 09:00:00'),
('GBP',1.296900,'2026-04-01 09:00:00'),
('USD',1.000000,'2026-05-01 09:00:00'),
('PKR',0.003500,'2026-05-01 09:00:00'),
('AED',0.272250,'2026-05-01 09:00:00'),
('GBP',1.310000,'2026-05-01 09:00:00'),
('USD',1.010000,'2026-05-31 09:00:00'),
('PKR',0.003535,'2026-05-31 09:00:00'),
('AED',0.274973,'2026-05-31 09:00:00'),
('GBP',1.323100,'2026-05-31 09:00:00'),
('USD',0.990000,'2026-06-30 09:00:00'),
('PKR',0.003465,'2026-06-30 09:00:00'),
('AED',0.269527,'2026-06-30 09:00:00'),
('GBP',1.296900,'2026-06-30 09:00:00'),
('USD',1.000000,'2026-07-30 09:00:00'),
('PKR',0.003500,'2026-07-30 09:00:00'),
('AED',0.272250,'2026-07-30 09:00:00'),
('GBP',1.310000,'2026-07-30 09:00:00'),
('USD',1.010000,'2026-08-29 09:00:00'),
('PKR',0.003535,'2026-08-29 09:00:00'),
('AED',0.274973,'2026-08-29 09:00:00'),
('GBP',1.323100,'2026-08-29 09:00:00');
GO

-- 13. INSERT 120 EARNINGS-LOG RECORDS
INSERT INTO dbo.Earnings_Log (freelancer_id,month,total_earned,avg_rating) VALUES
(1,'2026-07-01',2125.00,4.25),
(1,'2026-08-01',2425.00,4.35),
(1,'2026-09-01',2725.00,4.45),
(2,'2026-07-01',2250.00,4.95),
(2,'2026-08-01',2550.00,3.55),
(2,'2026-09-01',2850.00,3.65),
(3,'2026-07-01',2375.00,4.15),
(3,'2026-08-01',2675.00,4.25),
(3,'2026-09-01',2975.00,4.35),
(4,'2026-07-01',2500.00,4.85),
(4,'2026-08-01',2800.00,4.95),
(4,'2026-09-01',3100.00,3.55),
(5,'2026-07-01',2625.00,4.05),
(5,'2026-08-01',2925.00,4.15),
(5,'2026-09-01',3225.00,4.25),
(6,'2026-07-01',2750.00,4.75),
(6,'2026-08-01',3050.00,4.85),
(6,'2026-09-01',3350.00,4.95),
(7,'2026-07-01',2875.00,3.95),
(7,'2026-08-01',3175.00,4.05),
(7,'2026-09-01',3475.00,4.15),
(8,'2026-07-01',3000.00,4.65),
(8,'2026-08-01',3300.00,4.75),
(8,'2026-09-01',3600.00,4.85),
(9,'2026-07-01',3125.00,3.85),
(9,'2026-08-01',3425.00,3.95),
(9,'2026-09-01',3725.00,4.05),
(10,'2026-07-01',3250.00,4.55),
(10,'2026-08-01',3550.00,4.65),
(10,'2026-09-01',3850.00,4.75),
(11,'2026-07-01',3375.00,3.75),
(11,'2026-08-01',3675.00,3.85),
(11,'2026-09-01',3975.00,3.95),
(12,'2026-07-01',3500.00,4.45),
(12,'2026-08-01',3800.00,4.55),
(12,'2026-09-01',4100.00,4.65),
(13,'2026-07-01',3625.00,3.65),
(13,'2026-08-01',3925.00,3.75),
(13,'2026-09-01',4225.00,3.85),
(14,'2026-07-01',3750.00,4.35),
(14,'2026-08-01',4050.00,4.45),
(14,'2026-09-01',4350.00,4.55),
(15,'2026-07-01',3875.00,3.55),
(15,'2026-08-01',4175.00,3.65),
(15,'2026-09-01',4475.00,3.75),
(16,'2026-07-01',4000.00,4.25),
(16,'2026-08-01',4300.00,4.35),
(16,'2026-09-01',4600.00,4.45),
(17,'2026-07-01',4125.00,4.95),
(17,'2026-08-01',4425.00,3.55),
(17,'2026-09-01',4725.00,3.65),
(18,'2026-07-01',4250.00,4.15),
(18,'2026-08-01',4550.00,4.25),
(18,'2026-09-01',4850.00,4.35),
(19,'2026-07-01',4375.00,4.85),
(19,'2026-08-01',4675.00,4.95),
(19,'2026-09-01',4975.00,3.55),
(20,'2026-07-01',4500.00,4.05),
(20,'2026-08-01',4800.00,4.15),
(20,'2026-09-01',5100.00,4.25),
(21,'2026-07-01',4625.00,4.75),
(21,'2026-08-01',4925.00,4.85),
(21,'2026-09-01',5225.00,4.95),
(22,'2026-07-01',4750.00,3.95),
(22,'2026-08-01',5050.00,4.05),
(22,'2026-09-01',5350.00,4.15),
(23,'2026-07-01',4875.00,4.65),
(23,'2026-08-01',5175.00,4.75),
(23,'2026-09-01',5475.00,4.85),
(24,'2026-07-01',5000.00,3.85),
(24,'2026-08-01',5300.00,3.95),
(24,'2026-09-01',5600.00,4.05),
(25,'2026-07-01',5125.00,4.55),
(25,'2026-08-01',5425.00,4.65),
(25,'2026-09-01',5725.00,4.75),
(26,'2026-07-01',5250.00,3.75),
(26,'2026-08-01',5550.00,3.85),
(26,'2026-09-01',5850.00,3.95),
(27,'2026-07-01',5375.00,4.45),
(27,'2026-08-01',5675.00,4.55),
(27,'2026-09-01',5975.00,4.65),
(28,'2026-07-01',5500.00,3.65),
(28,'2026-08-01',5800.00,3.75),
(28,'2026-09-01',6100.00,3.85),
(29,'2026-07-01',5625.00,4.35),
(29,'2026-08-01',5925.00,4.45),
(29,'2026-09-01',6225.00,4.55),
(30,'2026-07-01',5750.00,3.55),
(30,'2026-08-01',6050.00,3.65),
(30,'2026-09-01',6350.00,3.75),
(31,'2026-07-01',5875.00,4.25),
(31,'2026-08-01',6175.00,4.35),
(31,'2026-09-01',6475.00,4.45),
(32,'2026-07-01',6000.00,4.95),
(32,'2026-08-01',6300.00,3.55),
(32,'2026-09-01',6600.00,3.65),
(33,'2026-07-01',6125.00,4.15),
(33,'2026-08-01',6425.00,4.25),
(33,'2026-09-01',6725.00,4.35),
(34,'2026-07-01',6250.00,4.85),
(34,'2026-08-01',6550.00,4.95),
(34,'2026-09-01',6850.00,3.55),
(35,'2026-07-01',6375.00,4.05),
(35,'2026-08-01',6675.00,4.15),
(35,'2026-09-01',6975.00,4.25),
(36,'2026-07-01',6500.00,4.75),
(36,'2026-08-01',6800.00,4.85),
(36,'2026-09-01',7100.00,4.95),
(37,'2026-07-01',6625.00,3.95),
(37,'2026-08-01',6925.00,4.05),
(37,'2026-09-01',7225.00,4.15),
(38,'2026-07-01',6750.00,4.65),
(38,'2026-08-01',7050.00,4.75),
(38,'2026-09-01',7350.00,4.85),
(39,'2026-07-01',6875.00,3.85),
(39,'2026-08-01',7175.00,3.95),
(39,'2026-09-01',7475.00,4.05),
(40,'2026-07-01',7000.00,4.55),
(40,'2026-08-01',7300.00,4.65),
(40,'2026-09-01',7600.00,4.75);
GO

-- 14. INSERT 80 REVIEWS
INSERT INTO dbo.Reviews (contract_id,rating,comment,is_flagged) VALUES
(1,4.80,'Good communication and professional delivery.',0),
(2,4.60,'Good communication and professional delivery.',0),
(3,4.40,'Good communication and professional delivery.',0),
(4,4.90,'Good communication and professional delivery.',0),
(5,4.20,'Good communication and professional delivery.',0),
(6,4.70,'Good communication and professional delivery.',0),
(7,3.50,'Rating requires additional verification.',0),
(8,4.50,'Good communication and professional delivery.',0),
(9,4.90,'Good communication and professional delivery.',0),
(10,4.10,'Good communication and professional delivery.',0),
(11,4.80,'Good communication and professional delivery.',0),
(12,4.60,'Good communication and professional delivery.',0),
(13,4.40,'Good communication and professional delivery.',0),
(14,4.90,'Good communication and professional delivery.',0),
(15,4.20,'Good communication and professional delivery.',0),
(16,4.70,'Good communication and professional delivery.',0),
(17,3.50,'Rating requires additional verification.',0),
(18,4.50,'Good communication and professional delivery.',0),
(19,4.90,'Good communication and professional delivery.',0),
(20,4.10,'Good communication and professional delivery.',0),
(21,4.80,'Good communication and professional delivery.',0),
(22,4.60,'Good communication and professional delivery.',0),
(23,4.40,'Good communication and professional delivery.',0),
(24,4.90,'Good communication and professional delivery.',0),
(25,4.20,'Good communication and professional delivery.',0),
(26,4.70,'Good communication and professional delivery.',0),
(27,3.50,'Rating requires additional verification.',0),
(28,4.50,'Good communication and professional delivery.',0),
(29,4.90,'Good communication and professional delivery.',0),
(30,4.10,'Good communication and professional delivery.',0),
(31,4.80,'Good communication and professional delivery.',0),
(32,4.60,'Good communication and professional delivery.',0),
(33,4.40,'Good communication and professional delivery.',0),
(34,4.90,'Good communication and professional delivery.',0),
(35,4.20,'Good communication and professional delivery.',0),
(36,4.70,'Good communication and professional delivery.',0),
(37,3.50,'Rating requires additional verification.',0),
(38,4.50,'Good communication and professional delivery.',0),
(39,4.90,'Good communication and professional delivery.',0),
(40,4.10,'Good communication and professional delivery.',0),
(41,4.80,'Good communication and professional delivery.',0),
(42,4.60,'Good communication and professional delivery.',0),
(43,4.40,'Good communication and professional delivery.',0),
(44,4.90,'Good communication and professional delivery.',0),
(45,4.20,'Good communication and professional delivery.',0),
(46,4.70,'Good communication and professional delivery.',0),
(47,3.50,'Rating requires additional verification.',0),
(48,4.50,'Good communication and professional delivery.',0),
(49,4.90,'Good communication and professional delivery.',0),
(50,4.10,'Good communication and professional delivery.',0),
(51,4.80,'Good communication and professional delivery.',0),
(52,4.60,'Good communication and professional delivery.',0),
(53,4.40,'Good communication and professional delivery.',0),
(54,4.90,'Good communication and professional delivery.',0),
(55,4.20,'Good communication and professional delivery.',0),
(56,4.70,'Good communication and professional delivery.',0),
(57,3.50,'Rating requires additional verification.',0),
(58,4.50,'Good communication and professional delivery.',0),
(59,4.90,'Good communication and professional delivery.',0),
(60,4.10,'Good communication and professional delivery.',0),
(61,4.80,'Good communication and professional delivery.',0),
(62,4.60,'Good communication and professional delivery.',0),
(63,4.40,'Good communication and professional delivery.',0),
(64,4.90,'Good communication and professional delivery.',0),
(65,4.20,'Good communication and professional delivery.',0),
(66,4.70,'Good communication and professional delivery.',0),
(67,3.50,'Rating requires additional verification.',0),
(68,4.50,'Good communication and professional delivery.',0),
(69,4.90,'Good communication and professional delivery.',0),
(70,4.10,'Good communication and professional delivery.',0),
(71,4.80,'Good communication and professional delivery.',0),
(72,4.60,'Good communication and professional delivery.',0),
(73,4.40,'Good communication and professional delivery.',0),
(74,4.90,'Good communication and professional delivery.',0),
(75,4.20,'Good communication and professional delivery.',0),
(76,4.70,'Good communication and professional delivery.',0),
(77,3.50,'Rating requires additional verification.',0),
(78,4.50,'Good communication and professional delivery.',0),
(79,4.90,'Good communication and professional delivery.',0),
(80,4.10,'Good communication and professional delivery.',0);
GO

-- 15. INSERT 8 FRAUD FLAGS
INSERT INTO dbo.Fraud_Flags (review_id,reason,confidence_score,flagged_at) VALUES
(7,'Suspicious rating pattern requires verification.',72.00,'2026-09-10 13:00:00'),
(17,'Suspicious rating pattern requires verification.',82.00,'2026-09-10 13:00:00'),
(27,'Suspicious rating pattern requires verification.',72.00,'2026-09-10 13:00:00'),
(37,'Suspicious rating pattern requires verification.',82.00,'2026-09-10 13:00:00'),
(47,'Suspicious rating pattern requires verification.',72.00,'2026-09-10 13:00:00'),
(57,'Suspicious rating pattern requires verification.',82.00,'2026-09-10 13:00:00'),
(67,'Suspicious rating pattern requires verification.',72.00,'2026-09-10 13:00:00'),
(77,'Suspicious rating pattern requires verification.',82.00,'2026-09-10 13:00:00');
GO

-- 16. INSERT 40 FREELANCER RANKINGS
INSERT INTO dbo.Freelancer_Rankings (freelancer_id,score,rank_position,calculated_at) VALUES
(20,99.00,1,'2026-09-10 14:00:00'),
(40,98.00,2,'2026-09-10 14:00:00'),
(19,97.30,3,'2026-09-10 14:00:00'),
(39,96.30,4,'2026-09-10 14:00:00'),
(18,95.60,5,'2026-09-10 14:00:00'),
(38,94.60,6,'2026-09-10 14:00:00'),
(17,93.90,7,'2026-09-10 14:00:00'),
(37,92.90,8,'2026-09-10 14:00:00'),
(16,92.20,9,'2026-09-10 14:00:00'),
(36,91.20,10,'2026-09-10 14:00:00'),
(15,90.50,11,'2026-09-10 14:00:00'),
(35,89.50,12,'2026-09-10 14:00:00'),
(14,88.80,13,'2026-09-10 14:00:00'),
(34,87.80,14,'2026-09-10 14:00:00'),
(13,87.10,15,'2026-09-10 14:00:00'),
(33,86.10,16,'2026-09-10 14:00:00'),
(12,85.40,17,'2026-09-10 14:00:00'),
(32,84.40,18,'2026-09-10 14:00:00'),
(11,83.70,19,'2026-09-10 14:00:00'),
(31,82.70,20,'2026-09-10 14:00:00'),
(10,82.00,21,'2026-09-10 14:00:00'),
(30,81.00,22,'2026-09-10 14:00:00'),
(9,80.30,23,'2026-09-10 14:00:00'),
(29,79.30,24,'2026-09-10 14:00:00'),
(8,78.60,25,'2026-09-10 14:00:00'),
(28,77.60,26,'2026-09-10 14:00:00'),
(7,76.90,27,'2026-09-10 14:00:00'),
(27,75.90,28,'2026-09-10 14:00:00'),
(6,75.20,29,'2026-09-10 14:00:00'),
(26,74.20,30,'2026-09-10 14:00:00'),
(5,73.50,31,'2026-09-10 14:00:00'),
(25,72.50,32,'2026-09-10 14:00:00'),
(4,71.80,33,'2026-09-10 14:00:00'),
(24,70.80,34,'2026-09-10 14:00:00'),
(3,70.10,35,'2026-09-10 14:00:00'),
(23,69.10,36,'2026-09-10 14:00:00'),
(2,68.40,37,'2026-09-10 14:00:00'),
(22,67.40,38,'2026-09-10 14:00:00'),
(1,66.70,39,'2026-09-10 14:00:00'),
(21,65.70,40,'2026-09-10 14:00:00');
GO

-- 17. INSERT 96 DEMAND-TREND RECORDS
INSERT INTO dbo.Demand_Trends (skill_id,demand_score,month,growth_rate) VALUES
(1,58.00,'2026-01-01',5.50),
(1,59.85,'2026-01-31',6.05),
(1,61.70,'2026-03-02',6.60),
(1,63.55,'2026-04-01',7.15),
(1,65.40,'2026-05-01',7.70),
(1,67.25,'2026-05-31',8.25),
(1,69.10,'2026-06-30',8.80),
(1,70.95,'2026-07-30',9.35),
(2,61.00,'2026-01-01',7.00),
(2,63.30,'2026-01-31',7.55),
(2,65.60,'2026-03-02',8.10),
(2,67.90,'2026-04-01',8.65),
(2,70.20,'2026-05-01',9.20),
(2,72.50,'2026-05-31',9.75),
(2,74.80,'2026-06-30',10.30),
(2,77.10,'2026-07-30',10.85),
(3,64.00,'2026-01-01',8.50),
(3,66.75,'2026-01-31',9.05),
(3,69.50,'2026-03-02',9.60),
(3,72.25,'2026-04-01',10.15),
(3,75.00,'2026-05-01',10.70),
(3,77.75,'2026-05-31',11.25),
(3,80.50,'2026-06-30',11.80),
(3,83.25,'2026-07-30',12.35),
(4,67.00,'2026-01-01',10.00),
(4,68.40,'2026-01-31',10.55),
(4,69.80,'2026-03-02',11.10),
(4,71.20,'2026-04-01',11.65),
(4,72.60,'2026-05-01',12.20),
(4,74.00,'2026-05-31',12.75),
(4,75.40,'2026-06-30',13.30),
(4,76.80,'2026-07-30',13.85),
(5,70.00,'2026-01-01',4.00),
(5,71.85,'2026-01-31',4.55),
(5,73.70,'2026-03-02',5.10),
(5,75.55,'2026-04-01',5.65),
(5,77.40,'2026-05-01',6.20),
(5,79.25,'2026-05-31',6.75),
(5,81.10,'2026-06-30',7.30),
(5,82.95,'2026-07-30',7.85),
(6,73.00,'2026-01-01',5.50),
(6,75.30,'2026-01-31',6.05),
(6,77.60,'2026-03-02',6.60),
(6,79.90,'2026-04-01',7.15),
(6,82.20,'2026-05-01',7.70),
(6,84.50,'2026-05-31',8.25),
(6,86.80,'2026-06-30',8.80),
(6,89.10,'2026-07-30',9.35),
(7,76.00,'2026-01-01',7.00),
(7,78.75,'2026-01-31',7.55),
(7,81.50,'2026-03-02',8.10),
(7,84.25,'2026-04-01',8.65),
(7,87.00,'2026-05-01',9.20),
(7,89.75,'2026-05-31',9.75),
(7,92.50,'2026-06-30',10.30),
(7,95.25,'2026-07-30',10.85),
(8,79.00,'2026-01-01',8.50),
(8,80.40,'2026-01-31',9.05),
(8,81.80,'2026-03-02',9.60),
(8,83.20,'2026-04-01',10.15),
(8,84.60,'2026-05-01',10.70),
(8,86.00,'2026-05-31',11.25),
(8,87.40,'2026-06-30',11.80),
(8,88.80,'2026-07-30',12.35),
(9,82.00,'2026-01-01',10.00),
(9,83.85,'2026-01-31',10.55),
(9,85.70,'2026-03-02',11.10),
(9,87.55,'2026-04-01',11.65),
(9,89.40,'2026-05-01',12.20),
(9,91.25,'2026-05-31',12.75),
(9,93.10,'2026-06-30',13.30),
(9,94.95,'2026-07-30',13.85),
(10,85.00,'2026-01-01',4.00),
(10,87.30,'2026-01-31',4.55),
(10,89.60,'2026-03-02',5.10),
(10,91.90,'2026-04-01',5.65),
(10,94.20,'2026-05-01',6.20),
(10,96.50,'2026-05-31',6.75),
(10,98.80,'2026-06-30',7.30),
(10,101.10,'2026-07-30',7.85),
(11,88.00,'2026-01-01',5.50),
(11,90.75,'2026-01-31',6.05),
(11,93.50,'2026-03-02',6.60),
(11,96.25,'2026-04-01',7.15),
(11,99.00,'2026-05-01',7.70),
(11,101.75,'2026-05-31',8.25),
(11,104.50,'2026-06-30',8.80),
(11,107.25,'2026-07-30',9.35),
(12,91.00,'2026-01-01',7.00),
(12,92.40,'2026-01-31',7.55),
(12,93.80,'2026-03-02',8.10),
(12,95.20,'2026-04-01',8.65),
(12,96.60,'2026-05-01',9.20),
(12,98.00,'2026-05-31',9.75),
(12,99.40,'2026-06-30',10.30),
(12,100.80,'2026-07-30',10.85);
GO



USE GigBase;
GO

-- QUICK RECORD COUNT — confirm all 16 tables have data
USE GigBase;
GO

SELECT 'Users' AS TableName, COUNT(*) AS Records FROM dbo.Users
UNION ALL
SELECT 'Freelancers', COUNT(*) FROM dbo.Freelancers
UNION ALL
SELECT 'Clients', COUNT(*) FROM dbo.Clients
UNION ALL
SELECT 'Skills', COUNT(*) FROM dbo.Skills
UNION ALL
SELECT 'Freelancer_Skills', COUNT(*) FROM dbo.Freelancer_Skills
UNION ALL
SELECT 'Projects', COUNT(*) FROM dbo.Projects
UNION ALL
SELECT 'Bids', COUNT(*) FROM dbo.Bids
UNION ALL
SELECT 'Contracts', COUNT(*) FROM dbo.Contracts
UNION ALL
SELECT 'Milestones', COUNT(*) FROM dbo.Milestones
UNION ALL
SELECT 'Payments', COUNT(*) FROM dbo.Payments
UNION ALL
SELECT 'Currency_Rates', COUNT(*) FROM dbo.Currency_Rates
UNION ALL
SELECT 'Earnings_Log', COUNT(*) FROM dbo.Earnings_Log
UNION ALL
SELECT 'Reviews', COUNT(*) FROM dbo.Reviews
UNION ALL
SELECT 'Fraud_Flags', COUNT(*) FROM dbo.Fraud_Flags
UNION ALL
SELECT 'Freelancer_Rankings', COUNT(*) FROM dbo.Freelancer_Rankings
UNION ALL
SELECT 'Demand_Trends', COUNT(*) FROM dbo.Demand_Trends;



--  Select all users 
SELECT * FROM dbo.Users;

--  Select only names and roles — choose specific columns
SELECT name, role, country, join_date
FROM dbo.Users;

--  DISTINCT — what unique roles exist?
SELECT DISTINCT role FROM dbo.Users;

--  DISTINCT — what unique industries do clients come from?
SELECT DISTINCT industry FROM dbo.Clients;

--  DISTINCT — what skill categories are on the platform?
SELECT DISTINCT category FROM dbo.Skills;

--  DISTINCT — what project statuses exist?
SELECT DISTINCT status FROM dbo.Projects;

--  DISTINCT — what milestone statuses exist?
SELECT DISTINCT status FROM dbo.Milestones;

--  DISTINCT — what currency codes are tracked?
SELECT DISTINCT currency_code FROM dbo.Currency_Rates;



--  Show only freelancer users
SELECT user_id, name, country, join_date
FROM dbo.Users
WHERE role = 'Freelancer';

--  Show only client users
SELECT user_id, name, country, join_date
FROM dbo.Users
WHERE role = 'Client';

--  Freelancers who are currently available
SELECT freelancer_id, hourly_rate, experience_years
FROM dbo.Freelancers
WHERE availability = 1;

-- Freelancers who are NOT available (currently busy)
SELECT freelancer_id, hourly_rate, experience_years
FROM dbo.Freelancers
WHERE availability = 0;

--  Projects with status = Open
SELECT project_id, title, budget, deadline
FROM dbo.Projects
WHERE status = 'Open';

--  Projects that have been completed
SELECT project_id, title, budget, deadline
FROM dbo.Projects
WHERE status = 'Completed';

--  Reviews that have been flagged as suspicious
SELECT review_id, contract_id, rating, comment
FROM dbo.Reviews
WHERE is_flagged = 1;

--  Payments larger than $5,000 USD
SELECT payment_id, milestone_id, amount_usd, amount_pkr
FROM dbo.Payments
WHERE amount_usd > 5000;

--  Freelancers with hourly rate above $50
SELECT freelancer_id, hourly_rate, experience_years
FROM dbo.Freelancers
WHERE hourly_rate > 50.00;

-- Freelancers with more than 5 years of experience
SELECT freelancer_id, hourly_rate, experience_years
FROM dbo.Freelancers
WHERE experience_years > 5;


-- AND — available freelancers with rate above $50
--     Both conditions must be true
SELECT freelancer_id, hourly_rate, experience_years
FROM dbo.Freelancers
WHERE availability = 1
  AND hourly_rate > 50.00;

--  AND — experienced AND high-rate freelancers
SELECT freelancer_id, hourly_rate, experience_years
FROM dbo.Freelancers
WHERE experience_years > 7
  AND hourly_rate > 70.00;

--  OR — projects that are Open OR In Progress (active pipeline)
--     Either condition is enough
SELECT project_id, title, budget, status
FROM dbo.Projects
WHERE status = 'Open'
   OR status = 'In Progress';

--  OR — milestones that are Pending OR Cancelled (not done yet)
SELECT milestone_id, contract_id, title, amount, status
FROM dbo.Milestones
WHERE status = 'Pending'
   OR status = 'Cancelled';

--  AND + OR combined — high-rate OR highly experienced AND available
SELECT freelancer_id, hourly_rate, experience_years, availability
FROM dbo.Freelancers
WHERE availability = 1
  AND (hourly_rate > 70 OR experience_years > 8);




--  Freelancers with hourly rate between $30 and $60 (inclusive)
SELECT freelancer_id, hourly_rate, experience_years
FROM dbo.Freelancers
WHERE hourly_rate BETWEEN 30.00 AND 60.00;

--  Projects with budget between $5,000 and $15,000
SELECT project_id, title, budget, status
FROM dbo.Projects
WHERE budget BETWEEN 5000.00 AND 15000.00;

--  Reviews with rating between 4.0 and 5.0 (good reviews)
SELECT review_id, contract_id, rating, comment
FROM dbo.Reviews
WHERE rating BETWEEN 4.0 AND 5.0;

--  Payments between $3,000 and $8,000 USD
SELECT payment_id, amount_usd, amount_pkr, exchange_rate
FROM dbo.Payments
WHERE amount_usd BETWEEN 3000 AND 8000;

--  Earnings log records between July and September 2026
SELECT freelancer_id, month, total_earned, avg_rating
FROM dbo.Earnings_Log
WHERE month BETWEEN '2026-07-01' AND '2026-09-01';

--  Contracts that started in July 2026
SELECT contract_id, project_id, freelancer_id, agreed_amount, start_date
FROM dbo.Contracts
WHERE start_date BETWEEN '2026-07-01' AND '2026-07-31';





--  IN — projects in specific statuses
SELECT project_id, title, budget, status
FROM dbo.Projects
WHERE status IN ('Open', 'In Progress');

--  IN — skills in Development or Data category
SELECT skill_id, skill_name, category
FROM dbo.Skills
WHERE category IN ('Development', 'Data');

-- IN — top 5 ranked freelancers by ID
SELECT freelancer_id, score, rank_position
FROM dbo.Freelancer_Rankings
WHERE rank_position IN (1, 2, 3, 4, 5);

--  IN — clients in Technology or E-Commerce industry
SELECT client_id, company_name, industry, total_spent
FROM dbo.Clients
WHERE industry IN ('Technology', 'E-Commerce');

--  NOT IN — milestones that are NOT completed
SELECT milestone_id, contract_id, title, amount, status
FROM dbo.Milestones
WHERE status NOT IN ('Completed');

-- NOT IN — projects that are NOT cancelled or closed
SELECT project_id, title, budget, status
FROM dbo.Projects
WHERE status NOT IN ('Cancelled');

--  IN — specific freelancer IDs (top ranked)
SELECT freelancer_id, hourly_rate, experience_years
FROM dbo.Freelancers
WHERE freelancer_id IN (20, 40, 19, 39, 18);




--  Users whose name starts with 'A'
SELECT user_id, name, role
FROM dbo.Users
WHERE name LIKE 'A%';

--  Users whose name starts with 'M'
SELECT user_id, name, role
FROM dbo.Users
WHERE name LIKE 'M%';

--  Projects whose title contains 'Marketing'
SELECT project_id, title, budget, status
FROM dbo.Projects
WHERE title LIKE '%Marketing%';

--  Projects whose title contains 'Development'
SELECT project_id, title, budget, status
FROM dbo.Projects
WHERE title LIKE '%Development%';

--  Projects whose title contains 'Python'
SELECT project_id, title, budget, status
FROM dbo.Projects
WHERE title LIKE '%Python%';

--  Skills whose name contains 'Design'
SELECT skill_id, skill_name, category
FROM dbo.Skills
WHERE skill_name LIKE '%Design%';

--  Client companies whose name starts with 'Tech'
SELECT client_id, company_name, industry
FROM dbo.Clients
WHERE company_name LIKE 'Tech%';

--  Emails from a specific pattern
SELECT user_id, name, email
FROM dbo.Users
WHERE email LIKE 'freelancer%';

--  Emails of clients
SELECT user_id, name, email
FROM dbo.Users
WHERE email LIKE 'client%';

--  Users whose name ends with 'Khan'
SELECT user_id, name, role
FROM dbo.Users
WHERE name LIKE '%Khan';




--  Freelancers sorted by hourly rate highest first
SELECT freelancer_id, hourly_rate, experience_years
FROM dbo.Freelancers
ORDER BY hourly_rate DESC;

--  Freelancers sorted by experience highest first
SELECT freelancer_id, hourly_rate, experience_years
FROM dbo.Freelancers
ORDER BY experience_years DESC;

-- Projects sorted by budget highest first
SELECT project_id, title, budget, status
FROM dbo.Projects
ORDER BY budget DESC;

--  Projects sorted by deadline soonest first
SELECT project_id, title, budget, deadline, status
FROM dbo.Projects
ORDER BY deadline ASC;

--  Freelancer rankings sorted by rank position
SELECT rank_id, freelancer_id, score, rank_position
FROM dbo.Freelancer_Rankings
ORDER BY rank_position ASC;

--  Reviews sorted by rating highest first
SELECT review_id, contract_id, rating, comment
FROM dbo.Reviews
ORDER BY rating DESC;

--  Payments sorted by USD amount highest first
SELECT payment_id, milestone_id, amount_usd, amount_pkr
FROM dbo.Payments
ORDER BY amount_usd DESC;

--  Earnings sorted by total_earned highest first
SELECT freelancer_id, month, total_earned, avg_rating
FROM dbo.Earnings_Log
ORDER BY total_earned DESC;

--  Users sorted by join_date newest first
SELECT user_id, name, role, join_date
FROM dbo.Users
ORDER BY join_date DESC;

--  Demand trends sorted by demand_score highest first
SELECT skill_id, demand_score, month, growth_rate
FROM dbo.Demand_Trends
ORDER BY demand_score DESC;




--  Top 5 most expensive projects
SELECT TOP 5 project_id, title, budget, status
FROM dbo.Projects
ORDER BY budget DESC;

--  Top 10 highest-rate freelancers
SELECT TOP 10 freelancer_id, hourly_rate, experience_years
FROM dbo.Freelancers
ORDER BY hourly_rate DESC;

--  Top 5 ranked freelancers
SELECT TOP 5 freelancer_id, score, rank_position
FROM dbo.Freelancer_Rankings
ORDER BY rank_position ASC;

--  Top 5 highest-earning months
SELECT TOP 5 freelancer_id, month, total_earned, avg_rating
FROM dbo.Earnings_Log
ORDER BY total_earned DESC;

--  Top 3 highest-paying contracts
SELECT TOP 3 contract_id, project_id, freelancer_id, agreed_amount
FROM dbo.Contracts
ORDER BY agreed_amount DESC;

--  Top 5 highest bids placed
SELECT TOP 5 bid_id, project_id, freelancer_id, proposed_amount
FROM dbo.Bids
ORDER BY proposed_amount DESC;

--  Top 5 highest payments in USD
SELECT TOP 5 payment_id, amount_usd, amount_pkr, exchange_rate
FROM dbo.Payments
ORDER BY amount_usd DESC;

--  Top 3 best-rated reviews
SELECT TOP 3 review_id, contract_id, rating, comment
FROM dbo.Reviews
ORDER BY rating DESC;


--AGGREGATE FUNCTIONS


--  COUNT — total number of records in each important table
SELECT
    (SELECT COUNT(*) FROM dbo.Users)             AS Total_Users,
    (SELECT COUNT(*) FROM dbo.Freelancers)       AS Total_Freelancers,
    (SELECT COUNT(*) FROM dbo.Clients)           AS Total_Clients,
    (SELECT COUNT(*) FROM dbo.Projects)          AS Total_Projects,
    (SELECT COUNT(*) FROM dbo.Contracts)         AS Total_Contracts,
    (SELECT COUNT(*) FROM dbo.Milestones)        AS Total_Milestones,
    (SELECT COUNT(*) FROM dbo.Payments)          AS Total_Payments,
    (SELECT COUNT(*) FROM dbo.Reviews)           AS Total_Reviews,
    (SELECT COUNT(*) FROM dbo.Fraud_Flags)       AS Total_Fraud_Flags;

--  AVG — average hourly rate of all freelancers
SELECT AVG(hourly_rate) AS Avg_Hourly_Rate
FROM dbo.Freelancers;

--  MIN and MAX — cheapest and most expensive hourly rate
SELECT
    MIN(hourly_rate) AS Cheapest_Rate,
    MAX(hourly_rate) AS Most_Expensive_Rate
FROM dbo.Freelancers;

--  SUM — total client spending across the entire platform
SELECT SUM(total_spent) AS Total_Client_Spending_USD
FROM dbo.Clients;

--  AVG — average project budget
SELECT
    AVG(budget)  AS Avg_Project_Budget,
    MIN(budget)  AS Smallest_Budget,
    MAX(budget)  AS Largest_Budget,
    SUM(budget)  AS Total_Budget_Pipeline
FROM dbo.Projects;

--  SUM and AVG — total and average payments in USD and PKR
SELECT
    SUM(amount_usd)  AS Total_Paid_USD,
    AVG(amount_usd)  AS Avg_Payment_USD,
    SUM(amount_pkr)  AS Total_Paid_PKR,
    AVG(amount_pkr)  AS Avg_Payment_PKR
FROM dbo.Payments;

--  AVG — platform average review rating
SELECT
    AVG(rating) AS Platform_Avg_Rating,
    MIN(rating) AS Lowest_Rating,
    MAX(rating) AS Highest_Rating,
    COUNT(*)    AS Total_Reviews
FROM dbo.Reviews;

--  SUM — total earnings across all freelancers all months
SELECT
    SUM(total_earned) AS Total_Platform_Earnings,
    AVG(total_earned) AS Avg_Monthly_Earnings,
    MAX(total_earned) AS Highest_Single_Month,
    MIN(total_earned) AS Lowest_Single_Month
FROM dbo.Earnings_Log;

--  AVG — average bid amount
SELECT
    AVG(proposed_amount) AS Avg_Bid_Amount,
    MIN(proposed_amount) AS Lowest_Bid,
    MAX(proposed_amount) AS Highest_Bid,
    COUNT(*)             AS Total_Bids
FROM dbo.Bids;

--  SUM — total contract value on the platform
SELECT
    SUM(agreed_amount) AS Total_Contract_Value,
    AVG(agreed_amount) AS Avg_Contract_Value,
    MAX(agreed_amount) AS Largest_Contract,
    MIN(agreed_amount) AS Smallest_Contract
FROM dbo.Contracts;



--  Count of users by role (Freelancer vs Client)
SELECT
    role,
    COUNT(*) AS User_Count
FROM dbo.Users
GROUP BY role;

--     Explains: how many projects are Open, In Progress, Completed?
SELECT
    status,
    COUNT(*)     AS Project_Count,
    SUM(budget)  AS Total_Budget,
    AVG(budget)  AS Avg_Budget
FROM dbo.Projects
GROUP BY status
ORDER BY Total_Budget DESC;

--  Total bids per project — which project attracted most bids?
SELECT
    project_id,
    COUNT(*)              AS Total_Bids,
    AVG(proposed_amount)  AS Avg_Bid,
    MAX(proposed_amount)  AS Highest_Bid,
    MIN(proposed_amount)  AS Lowest_Bid
FROM dbo.Bids
GROUP BY project_id
ORDER BY Total_Bids DESC;

--  Total bids placed by each freelancer
SELECT
    freelancer_id,
    COUNT(*) AS Bids_Placed
FROM dbo.Bids
GROUP BY freelancer_id
ORDER BY Bids_Placed DESC;

--  Total contract value per freelancer
SELECT
    freelancer_id,
    COUNT(*)           AS Total_Contracts,
    SUM(agreed_amount) AS Total_Earned_From_Contracts,
    AVG(agreed_amount) AS Avg_Contract_Value
FROM dbo.Contracts
GROUP BY freelancer_id
ORDER BY Total_Earned_From_Contracts DESC;

--  Milestone count and value by status (Completed vs Pending)
SELECT
    status,
    COUNT(*)   AS Milestone_Count,
    SUM(amount) AS Total_Amount
FROM dbo.Milestones
GROUP BY status;

--  Total client spending by industry
SELECT
    industry,
    COUNT(*)         AS Client_Count,
    SUM(total_spent) AS Industry_Total_Spent,
    AVG(total_spent) AS Avg_Spent_Per_Client
FROM dbo.Clients
GROUP BY industry
ORDER BY Industry_Total_Spent DESC;

--  Total freelancer lifetime earnings grouped by freelancer
SELECT
    freelancer_id,
    COUNT(*)          AS Months_Recorded,
    SUM(total_earned) AS Lifetime_Earnings,
    AVG(total_earned) AS Avg_Monthly_Earnings,
    AVG(avg_rating)   AS Avg_Rating
FROM dbo.Earnings_Log
GROUP BY freelancer_id
ORDER BY Lifetime_Earnings DESC;

--  Skill count per category (Development, Marketing, etc.)
SELECT
    category,
    COUNT(*) AS Skill_Count
FROM dbo.Skills
GROUP BY category;

--  Average demand score per skill (from Demand_Trends)
SELECT
    skill_id,
    COUNT(*)             AS Data_Points,
    AVG(demand_score)    AS Avg_Demand_Score,
    MAX(demand_score)    AS Peak_Demand_Score,
    AVG(growth_rate)     AS Avg_Growth_Rate
FROM dbo.Demand_Trends
GROUP BY skill_id
ORDER BY Avg_Demand_Score DESC;

--  Review count by rating bracket
SELECT
    CASE
        WHEN rating >= 4.5 THEN 'Excellent (4.5-5.0)'
        WHEN rating >= 4.0 THEN 'Good (4.0-4.4)'
        WHEN rating >= 3.0 THEN 'Average (3.0-3.9)'
        ELSE                    'Poor (Below 3.0)'
    END AS Rating_Category,
    COUNT(*) AS Review_Count
FROM dbo.Reviews
GROUP BY
    CASE
        WHEN rating >= 4.5 THEN 'Excellent (4.5-5.0)'
        WHEN rating >= 4.0 THEN 'Good (4.0-4.4)'
        WHEN rating >= 3.0 THEN 'Average (3.0-3.9)'
        ELSE                    'Poor (Below 3.0)'
    END
ORDER BY Review_Count DESC;

--  PKR exchange rate trend — average rate per recording period
SELECT
    currency_code,
    COUNT(*)             AS Rate_Records,
    AVG(rate_to_usd)     AS Avg_Rate_To_USD,
    MIN(rate_to_usd)     AS Min_Rate,
    MAX(rate_to_usd)     AS Max_Rate
FROM dbo.Currency_Rates
GROUP BY currency_code;



--  Freelancers who placed more than 3 bids
--     HAVING filters groups — cannot use WHERE for aggregate conditions
SELECT
    freelancer_id,
    COUNT(*) AS Bids_Placed
FROM dbo.Bids
GROUP BY freelancer_id
HAVING COUNT(*) > 3
ORDER BY Bids_Placed DESC;

--  Projects that received exactly 2 bids
SELECT
    project_id,
    COUNT(*) AS Bid_Count
FROM dbo.Bids
GROUP BY project_id
HAVING COUNT(*) = 2;

--  Industries where total client spending exceeds $50,000
SELECT
    industry,
    SUM(total_spent) AS Total_Spent
FROM dbo.Clients
GROUP BY industry
HAVING SUM(total_spent) > 50000
ORDER BY Total_Spent DESC;

-- Freelancers with average monthly earnings above $5,000
SELECT
    freelancer_id,
    AVG(total_earned) AS Avg_Monthly_Earnings
FROM dbo.Earnings_Log
GROUP BY freelancer_id
HAVING AVG(total_earned) > 5000
ORDER BY Avg_Monthly_Earnings DESC;

--  Skills assigned to more than 4 freelancers
SELECT
    skill_id,
    COUNT(*) AS Freelancer_Count
FROM dbo.Freelancer_Skills
GROUP BY skill_id
HAVING COUNT(*) > 4;

--  Freelancers with total contract value above $20,000
SELECT
    freelancer_id,
    COUNT(*)           AS Contracts,
    SUM(agreed_amount) AS Total_Contract_Value
FROM dbo.Contracts
GROUP BY freelancer_id
HAVING SUM(agreed_amount) > 20000
ORDER BY Total_Contract_Value DESC;

--  Projects where average bid exceeds $10,000
SELECT
    project_id,
    COUNT(*)              AS Bid_Count,
    AVG(proposed_amount)  AS Avg_Bid
FROM dbo.Bids
GROUP BY project_id
HAVING AVG(proposed_amount) > 10000
ORDER BY Avg_Bid DESC;



-- Insert a new skill
INSERT INTO dbo.Skills (skill_name, category)
VALUES ('Machine Learning', 'Data');

-- Insert a new currency rate record
INSERT INTO dbo.Currency_Rates (currency_code, rate_to_usd, recorded_at)
VALUES ('PKR', 0.003510, '2026-09-10 09:00:00');

-- Insert a new demand trend for the new skill
--     (assumes Machine Learning gets skill_id = 13)
INSERT INTO dbo.Demand_Trends (skill_id, demand_score, month, growth_rate)
VALUES (13, 95.00, '2026-08-01', 14.50);

-- Verify the inserts
SELECT * FROM dbo.Skills  WHERE skill_name = 'Machine Learning';
SELECT TOP 1 * FROM dbo.Currency_Rates ORDER BY recorded_at DESC;
SELECT * FROM dbo.Demand_Trends WHERE skill_id = 13;



-- Update a freelancer's hourly rate (they got more experience)
UPDATE dbo.Freelancers
SET hourly_rate = 95.00
WHERE freelancer_id = 40;

--  Increase all senior freelancer rates by 10%
--     (Senior = experience > 8 years)
UPDATE dbo.Freelancers
SET hourly_rate = hourly_rate * 1.10
WHERE experience_years > 8;

-- Mark a freelancer as unavailable
UPDATE dbo.Freelancers
SET availability = 0
WHERE freelancer_id = 5;

-- Restore freelancer availability
UPDATE dbo.Freelancers
SET availability = 1
WHERE freelancer_id = 5;

--  Update a project status to Completed
UPDATE dbo.Projects
SET status = 'Completed'
WHERE project_id = 3;

--  Flag a suspicious review manually
UPDATE dbo.Reviews
SET is_flagged = 1
WHERE review_id = 7;

-- Update a freelancer ranking score
UPDATE dbo.Freelancer_Rankings
SET score         = 99.50,
    calculated_at = GETDATE()
WHERE freelancer_id = 20;

--  Verify the updates
SELECT freelancer_id, hourly_rate, availability FROM dbo.Freelancers WHERE freelancer_id IN (5, 40);
SELECT project_id, title, status FROM dbo.Projects WHERE project_id = 3;
SELECT review_id, rating, is_flagged FROM dbo.Reviews WHERE review_id = 7;




--  Delete the demand trend we added for Machine Learning
DELETE FROM dbo.Demand_Trends
WHERE skill_id = 13;

--  Delete the Machine Learning skill we added
DELETE FROM dbo.Skills
WHERE skill_name = 'Machine Learning';

--  Delete the currency rate we added in the INSERT section
DELETE FROM dbo.Currency_Rates
WHERE currency_code = 'PKR'
  AND recorded_at = '2026-09-10 09:00:00';

--  Verify deletions — these should return 0 rows
SELECT * FROM dbo.Skills        WHERE skill_name = 'Machine Learning';
SELECT * FROM dbo.Demand_Trends WHERE skill_id = 13;

--  Freelancer name + their hourly rate and experience
--     Users joined to Freelancers on user_id = freelancer_id
SELECT
    u.name               AS Freelancer_Name,
    u.country,
    f.hourly_rate,
    f.experience_years,
    CASE WHEN f.availability = 1 THEN 'Available' ELSE 'Busy' END AS Status
FROM dbo.Users u
INNER JOIN dbo.Freelancers f
    ON u.user_id = f.freelancer_id
ORDER BY f.hourly_rate DESC;

--  Client name + their company and total spending
SELECT
    u.name               AS Client_Name,
    c.company_name,
    c.industry,
    c.total_spent
FROM dbo.Users u
INNER JOIN dbo.Clients c
    ON u.user_id = c.client_id
ORDER BY c.total_spent DESC;

--  Project with the client company name
SELECT
    p.project_id,
    p.title,
    p.budget,
    p.deadline,
    p.status,
    u.name               AS Client_Name,
    c.company_name
FROM dbo.Projects p
INNER JOIN dbo.Clients c
    ON p.client_id = c.client_id
INNER JOIN dbo.Users u
    ON c.client_id = u.user_id
ORDER BY p.budget DESC;

--  Bid with freelancer name and project title
SELECT
    b.bid_id,
    uf.name              AS Freelancer_Name,
    p.title              AS Project_Title,
    b.proposed_amount,
    b.bid_time
FROM dbo.Bids b
INNER JOIN dbo.Freelancers f
    ON b.freelancer_id = f.freelancer_id
INNER JOIN dbo.Users uf
    ON f.freelancer_id = uf.user_id
INNER JOIN dbo.Projects p
    ON b.project_id = p.project_id
ORDER BY b.proposed_amount DESC;

--  Contract with freelancer name and project title and client name
--     This is a 4-table join — a great one to explain!
SELECT
    c.contract_id,
    uf.name              AS Freelancer_Name,
    uc.name              AS Client_Name,
    p.title              AS Project_Title,
    c.agreed_amount,
    c.start_date,
    c.end_date
FROM dbo.Contracts c
INNER JOIN dbo.Freelancers f
    ON c.freelancer_id = f.freelancer_id
INNER JOIN dbo.Users uf
    ON f.freelancer_id = uf.user_id
INNER JOIN dbo.Projects p
    ON c.project_id = p.project_id
INNER JOIN dbo.Clients cl
    ON p.client_id = cl.client_id
INNER JOIN dbo.Users uc
    ON cl.client_id = uc.user_id
ORDER BY c.agreed_amount DESC;

--  Milestone with freelancer name and project title
SELECT
    m.milestone_id,
    m.title              AS Milestone_Title,
    m.amount,
    m.status,
    m.completed_at,
    uf.name              AS Freelancer_Name,
    p.title              AS Project_Title
FROM dbo.Milestones m
INNER JOIN dbo.Contracts c
    ON m.contract_id = c.contract_id
INNER JOIN dbo.Freelancers f
    ON c.freelancer_id = f.freelancer_id
INNER JOIN dbo.Users uf
    ON f.freelancer_id = uf.user_id
INNER JOIN dbo.Projects p
    ON c.project_id = p.project_id
ORDER BY m.amount DESC;

--  Payments with milestone title and freelancer name
SELECT
    pay.payment_id,
    m.title              AS Milestone_Title,
    pay.amount_usd,
    pay.amount_pkr,
    pay.exchange_rate,
    uf.name              AS Freelancer_Name,
    p.title              AS Project_Title
FROM dbo.Payments pay
INNER JOIN dbo.Milestones m
    ON pay.milestone_id = m.milestone_id
INNER JOIN dbo.Contracts c
    ON m.contract_id = c.contract_id
INNER JOIN dbo.Freelancers f
    ON c.freelancer_id = f.freelancer_id
INNER JOIN dbo.Users uf
    ON f.freelancer_id = uf.user_id
INNER JOIN dbo.Projects p
    ON c.project_id = p.project_id
ORDER BY pay.amount_usd DESC;

--  Review with freelancer name and project title
SELECT
    r.review_id,
    r.rating,
    r.comment,
    r.is_flagged,
    uf.name              AS Freelancer_Name,
    p.title              AS Project_Title
FROM dbo.Reviews r
INNER JOIN dbo.Contracts c
    ON r.contract_id = c.contract_id
INNER JOIN dbo.Freelancers f
    ON c.freelancer_id = f.freelancer_id
INNER JOIN dbo.Users uf
    ON f.freelancer_id = uf.user_id
INNER JOIN dbo.Projects p
    ON c.project_id = p.project_id
ORDER BY r.rating DESC;

--  Fraud flags with review details and freelancer name
SELECT
    ff.flag_id,
    ff.reason,
    ff.confidence_score,
    ff.flagged_at,
    r.rating,
    uf.name              AS Freelancer_Name
FROM dbo.Fraud_Flags ff
INNER JOIN dbo.Reviews r
    ON ff.review_id = r.review_id
INNER JOIN dbo.Contracts c
    ON r.contract_id = c.contract_id
INNER JOIN dbo.Freelancers f
    ON c.freelancer_id = f.freelancer_id
INNER JOIN dbo.Users uf
    ON f.freelancer_id = uf.user_id
ORDER BY ff.confidence_score DESC;

--  Freelancer rankings with name and hourly rate
SELECT
    fr.rank_position,
    uf.name              AS Freelancer_Name,
    f.hourly_rate,
    f.experience_years,
    fr.score
FROM dbo.Freelancer_Rankings fr
INNER JOIN dbo.Freelancers f
    ON fr.freelancer_id = f.freelancer_id
INNER JOIN dbo.Users uf
    ON f.freelancer_id = uf.user_id
ORDER BY fr.rank_position ASC;

--  Freelancer skills with skill name and proficiency
SELECT
    uf.name              AS Freelancer_Name,
    s.skill_name,
    s.category,
    fs.proficiency_level
FROM dbo.Freelancer_Skills fs
INNER JOIN dbo.Freelancers f
    ON fs.freelancer_id = f.freelancer_id
INNER JOIN dbo.Users uf
    ON f.freelancer_id = uf.user_id
INNER JOIN dbo.Skills s
    ON fs.skill_id = s.skill_id
ORDER BY uf.name, s.skill_name;

--  Demand trends with skill name
SELECT
    s.skill_name,
    s.category,
    d.demand_score,
    d.month,
    d.growth_rate
FROM dbo.Demand_Trends d
INNER JOIN dbo.Skills s
    ON d.skill_id = s.skill_id
ORDER BY d.demand_score DESC;

--  Earnings log with freelancer name
SELECT
    uf.name              AS Freelancer_Name,
    e.month,
    e.total_earned,
    e.avg_rating
FROM dbo.Earnings_Log e
INNER JOIN dbo.Freelancers f
    ON e.freelancer_id = f.freelancer_id
INNER JOIN dbo.Users uf
    ON f.freelancer_id = uf.user_id
ORDER BY e.total_earned DESC;




--  All users with their freelancer details (NULL if they are a Client)
SELECT
    u.user_id,
    u.name,
    u.role,
    f.hourly_rate,
    f.experience_years,
    f.availability
FROM dbo.Users u
LEFT JOIN dbo.Freelancers f
    ON u.user_id = f.freelancer_id;

--  All freelancers with their ranking (NULL if not yet ranked)
SELECT
    uf.name              AS Freelancer_Name,
    f.hourly_rate,
    fr.score,
    fr.rank_position
FROM dbo.Freelancers f
INNER JOIN dbo.Users uf
    ON f.freelancer_id = uf.user_id
LEFT JOIN dbo.Freelancer_Rankings fr
    ON f.freelancer_id = fr.freelancer_id
ORDER BY fr.rank_position ASC;

--  All skills and their demand trends (NULL if no trend recorded)
SELECT
    s.skill_name,
    s.category,
    d.demand_score,
    d.month,
    d.growth_rate
FROM dbo.Skills s
LEFT JOIN dbo.Demand_Trends d
    ON s.skill_id = d.skill_id;

--  All contracts and their reviews (NULL if not yet reviewed)
SELECT
    c.contract_id,
    c.agreed_amount,
    r.rating,
    r.comment,
    r.is_flagged
FROM dbo.Contracts c
LEFT JOIN dbo.Reviews r
    ON c.contract_id = r.contract_id;



--  Classify freelancers by experience level
SELECT
    uf.name              AS Freelancer_Name,
    f.hourly_rate,
    f.experience_years,
    CASE
        WHEN f.experience_years <= 2  THEN 'Junior'
        WHEN f.experience_years <= 5  THEN 'Mid-Level'
        WHEN f.experience_years <= 8  THEN 'Senior'
        ELSE                               'Expert'
    END AS Experience_Level
FROM dbo.Freelancers f
INNER JOIN dbo.Users uf ON f.freelancer_id = uf.user_id
ORDER BY f.experience_years DESC;

--  Classify freelancers by hourly rate tier
SELECT
    uf.name              AS Freelancer_Name,
    f.hourly_rate,
    CASE
        WHEN f.hourly_rate < 30  THEN 'Budget Tier'
        WHEN f.hourly_rate < 50  THEN 'Standard Tier'
        WHEN f.hourly_rate < 70  THEN 'Premium Tier'
        ELSE                          'Elite Tier'
    END AS Rate_Category
FROM dbo.Freelancers f
INNER JOIN dbo.Users uf ON f.freelancer_id = uf.user_id
ORDER BY f.hourly_rate DESC;

-- Classify projects by budget size
SELECT
    title,
    budget,
    status,
    CASE
        WHEN budget < 5000   THEN 'Small Project'
        WHEN budget < 10000  THEN 'Medium Project'
        WHEN budget < 15000  THEN 'Large Project'
        ELSE                      'Enterprise Project'
    END AS Project_Size
FROM dbo.Projects
ORDER BY budget DESC;

--  Classify reviews by quality
SELECT
    r.review_id,
    r.rating,
    CASE
        WHEN r.rating >= 4.5  THEN 'Excellent'
        WHEN r.rating >= 4.0  THEN 'Good'
        WHEN r.rating >= 3.0  THEN 'Average'
        ELSE                       'Poor'
    END AS Review_Quality
FROM dbo.Reviews r
ORDER BY r.rating DESC;

--  Classify milestone payment status
SELECT
    m.title,
    m.amount,
    m.status,
    CASE
        WHEN m.status = 'Completed'   THEN 'Payment Released'
        WHEN m.status = 'Pending'     THEN 'Payment Awaiting'
        ELSE                               'Payment Cancelled'
    END AS Payment_Status
FROM dbo.Milestones m
ORDER BY m.amount DESC;

-- Classify clients by spending tier
SELECT
    uc.name              AS Client_Name,
    c.company_name,
    c.total_spent,
    CASE
        WHEN c.total_spent < 10000  THEN 'Small Client'
        WHEN c.total_spent < 20000  THEN 'Medium Client'
        WHEN c.total_spent < 30000  THEN 'Large Client'
        ELSE                             'Enterprise Client'
    END AS Client_Tier
FROM dbo.Clients c
INNER JOIN dbo.Users uc ON c.client_id = uc.user_id
ORDER BY c.total_spent DESC;

--  Freelancer availability label
SELECT
    uf.name,
    f.hourly_rate,
    CASE
        WHEN f.availability = 1 THEN 'Available for Hire'
        ELSE                         'Currently Unavailable'
    END AS Hire_Status
FROM dbo.Freelancers f
INNER JOIN dbo.Users uf ON f.freelancer_id = uf.user_id;

--            A query inside another query


-- Freelancers earning above the platform average hourly rate
--     Inner query: calculates average. Outer query: uses that result.
SELECT
    freelancer_id,
    hourly_rate,
    experience_years
FROM dbo.Freelancers
WHERE hourly_rate >
(
    SELECT AVG(hourly_rate)
    FROM dbo.Freelancers
);

-- Projects with budget above the platform average budget
SELECT
    project_id,
    title,
    budget,
    status
FROM dbo.Projects
WHERE budget >
(
    SELECT AVG(budget)
    FROM dbo.Projects
);

--  Freelancer with the single highest hourly rate
SELECT
    uf.name,
    f.hourly_rate
FROM dbo.Freelancers f
INNER JOIN dbo.Users uf ON f.freelancer_id = uf.user_id
WHERE f.hourly_rate =
(
    SELECT MAX(hourly_rate)
    FROM dbo.Freelancers
);

--  Freelancers who have at least one contract (EXISTS subquery)
SELECT
    uf.name,
    f.hourly_rate,
    f.experience_years
FROM dbo.Freelancers f
INNER JOIN dbo.Users uf ON f.freelancer_id = uf.user_id
WHERE EXISTS
(
    SELECT 1
    FROM dbo.Contracts c
    WHERE c.freelancer_id = f.freelancer_id
);

--  Freelancers who have NEVER placed a bid (NOT IN subquery)
SELECT
    freelancer_id,
    hourly_rate,
    experience_years
FROM dbo.Freelancers
WHERE freelancer_id NOT IN
(
    SELECT DISTINCT freelancer_id
    FROM dbo.Bids
);

--  Reviews with rating below the platform average
SELECT
    review_id,
    contract_id,
    rating,
    comment
FROM dbo.Reviews
WHERE rating <
(
    SELECT AVG(rating)
    FROM dbo.Reviews
);

--  Top 5 earning freelancers — using subquery to rank
SELECT TOP 5
    freelancer_id,
    SUM(total_earned) AS Lifetime_Earnings
FROM dbo.Earnings_Log
GROUP BY freelancer_id
ORDER BY Lifetime_Earnings DESC;

--  Clients spending more than the average client spend
SELECT
    uc.name,
    c.company_name,
    c.total_spent
FROM dbo.Clients c
INNER JOIN dbo.Users uc ON c.client_id = uc.user_id
WHERE c.total_spent >
(
    SELECT AVG(total_spent)
    FROM dbo.Clients
)
ORDER BY c.total_spent DESC;

--  Skills with above-average demand score
SELECT
    s.skill_name,
    s.category,
    AVG(d.demand_score) AS Avg_Demand
FROM dbo.Demand_Trends d
INNER JOIN dbo.Skills s ON d.skill_id = s.skill_id
GROUP BY s.skill_name, s.category
HAVING AVG(d.demand_score) >
(
    SELECT AVG(demand_score)
    FROM dbo.Demand_Trends
)
ORDER BY Avg_Demand DESC;


--            BEGIN TRANSACTION / COMMIT / ROLLBACK


--  COMMIT — permanently complete a milestone and create payment
--     This is a real business transaction: mark done, release money.
BEGIN TRANSACTION;

    UPDATE dbo.Milestones
    SET status       = 'Completed',
        completed_at = GETDATE()
    WHERE milestone_id = 82;   -- picks an existing Pending milestone

    -- If exactly 1 row updated, commit; otherwise roll back
    IF @@ROWCOUNT = 1
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'Milestone 82 completed and transaction committed.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'No rows updated — transaction rolled back.';
    END;
GO

--  ROLLBACK demo — make a change then undo it
BEGIN TRANSACTION;

    -- Temporarily delete a demand trend record
    DELETE FROM dbo.Demand_Trends
    WHERE trend_id = 1;

    -- We change our mind — roll back so the row is restored
    ROLLBACK TRANSACTION;
    PRINT 'DELETE rolled back. Row is safe.';
GO

--  Verify the rollback worked — should still show trend_id = 1
SELECT * FROM dbo.Demand_Trends WHERE trend_id = 1;
GO

--  Safe balance-transfer style transaction
--     Update two things atomically — both succeed or neither does
BEGIN TRANSACTION;

    UPDATE dbo.Freelancers
    SET hourly_rate = 92.00
    WHERE freelancer_id = 39;

    UPDATE dbo.Freelancer_Rankings
    SET score = 97.00, calculated_at = GETDATE()
    WHERE freelancer_id = 39;

    IF @@ERROR = 0
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'Both updates committed successfully.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'Error detected — both updates rolled back.';
    END;
GO



-- Create the top freelancers view
CREATE OR ALTER VIEW dbo.top_freelancers_view AS
SELECT
    uf.name              AS freelancer_name,
    f.hourly_rate,
    f.experience_years,
    fr.score,
    fr.rank_position
FROM dbo.Users uf
INNER JOIN dbo.Freelancers f
    ON uf.user_id = f.freelancer_id
INNER JOIN dbo.Freelancer_Rankings fr
    ON f.freelancer_id = fr.freelancer_id;
GO

--  Use the view — select from it like a table
SELECT *
FROM dbo.top_freelancers_view
ORDER BY rank_position ASC;

--  Create a view for the active project pipeline
CREATE OR ALTER VIEW dbo.active_projects_view AS
SELECT
    p.project_id,
    p.title,
    p.budget,
    p.deadline,
    p.status,
    uc.name              AS Client_Name,
    c.company_name
FROM dbo.Projects p
INNER JOIN dbo.Clients c
    ON p.client_id = c.client_id
INNER JOIN dbo.Users uc
    ON c.client_id = uc.user_id
WHERE p.status IN ('Open', 'In Progress');
GO

--  Use the active project pipeline view
SELECT * FROM dbo.active_projects_view ORDER BY budget DESC;

--  Create a fraud monitoring view
CREATE OR ALTER VIEW dbo.fraud_monitor_view AS
SELECT
    ff.flag_id,
    ff.reason,
    ff.confidence_score,
    ff.flagged_at,
    r.rating,
    r.comment,
    uf.name              AS Freelancer_Name
FROM dbo.Fraud_Flags ff
INNER JOIN dbo.Reviews r
    ON ff.review_id = r.review_id
INNER JOIN dbo.Contracts c
    ON r.contract_id = c.contract_id
INNER JOIN dbo.Freelancers f
    ON c.freelancer_id = f.freelancer_id
INNER JOIN dbo.Users uf
    ON f.freelancer_id = uf.user_id;
GO

-- Use the fraud monitoring view
SELECT * FROM dbo.fraud_monitor_view ORDER BY confidence_score DESC;
GO



--  match_freelancer — find top 5 freelancers for a given skill
CREATE OR ALTER PROCEDURE dbo.match_freelancer
    @SkillID INT
AS
BEGIN
    -- Given a skill ID, return the best matched freelancers
    -- sorted by their ranking score
    SELECT TOP 5
        uf.name              AS Freelancer_Name,
        f.hourly_rate,
        f.experience_years,
        s.skill_name,
        fs.proficiency_level,
        fr.score,
        fr.rank_position
    FROM dbo.Freelancer_Skills fs
    INNER JOIN dbo.Freelancers f
        ON fs.freelancer_id = f.freelancer_id
    INNER JOIN dbo.Users uf
        ON f.freelancer_id = uf.user_id
    INNER JOIN dbo.Skills s
        ON fs.skill_id = s.skill_id
    INNER JOIN dbo.Freelancer_Rankings fr
        ON f.freelancer_id = fr.freelancer_id
    WHERE fs.skill_id = @SkillID
    ORDER BY fr.score DESC;
END;
GO

--  Run match_freelancer for Web Development (skill_id = 1)
EXEC dbo.match_freelancer @SkillID = 1;

--  Run match_freelancer for Python (skill_id = 9)
EXEC dbo.match_freelancer @SkillID = 9;

--  monthly_report — earnings report for a given month
CREATE OR ALTER PROCEDURE dbo.monthly_report
    @Month DATE
AS
BEGIN
    -- Given a month date, show all freelancer earnings for that month
    -- sorted from highest to lowest
    SELECT
        uf.name              AS Freelancer_Name,
        e.month,
        e.total_earned,
        e.avg_rating,
        fr.rank_position
    FROM dbo.Earnings_Log e
    INNER JOIN dbo.Freelancers f
        ON e.freelancer_id = f.freelancer_id
    INNER JOIN dbo.Users uf
        ON f.freelancer_id = uf.user_id
    LEFT JOIN dbo.Freelancer_Rankings fr
        ON f.freelancer_id = fr.freelancer_id
    WHERE e.month = @Month
    ORDER BY e.total_earned DESC;
END;
GO

--  Run monthly_report for September 2026
EXEC dbo.monthly_report @Month = '2026-09-01';

--  Run monthly_report for August 2026
EXEC dbo.monthly_report @Month = '2026-08-01';
GO



--  Trigger: Auto-release payment when milestone is Completed
CREATE OR ALTER TRIGGER dbo.trg_AutoPayment
ON dbo.Milestones
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- When a milestone changes status TO Completed
    -- AND it does not already have a payment record
    -- insert a payment automatically
    INSERT INTO dbo.Payments
        (milestone_id, amount_pkr, amount_usd, exchange_rate)
    SELECT
        i.milestone_id,
        i.amount * 285,   -- convert USD to PKR at 285 rate
        i.amount,         -- amount in USD
        285               -- exchange rate
    FROM inserted i
    INNER JOIN deleted d
        ON i.milestone_id = d.milestone_id
    WHERE i.status = 'Completed'
      AND d.status <> 'Completed'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.Payments p
          WHERE p.milestone_id = i.milestone_id
      );
END;
GO

--  Test the Auto-Payment trigger
--     Update a Pending milestone to Completed
UPDATE dbo.Milestones
SET status       = 'Completed',
    completed_at = GETDATE()
WHERE milestone_id = 84;   -- a Pending milestone

--  Check that the payment was automatically created
SELECT *
FROM dbo.Payments
WHERE milestone_id = 84;
GO

--  Trigger: Flag suspicious low-rating reviews automatically
CREATE OR ALTER TRIGGER dbo.trg_FlagSuspiciousReview
ON dbo.Reviews
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- If a newly submitted review has rating <= 2.0
    -- automatically add a fraud flag record
    INSERT INTO dbo.Fraud_Flags
        (review_id, reason, confidence_score, flagged_at)
    SELECT
        review_id,
        'Very low rating — automatic fraud flag triggered.',
        80.00,
        GETDATE()
    FROM inserted
    WHERE rating <= 2.0;
END;
GO

--  Test the Fraud Flag trigger — insert a very low rating review
INSERT INTO dbo.Reviews (contract_id, rating, comment, is_flagged)
VALUES (1, 1.50, 'Very poor experience.', 0);

--  Verify that the fraud flag was automatically inserted
SELECT TOP 1 *
FROM dbo.Fraud_Flags
ORDER BY flag_id DESC;
GO

--  Trigger: Update freelancer ranking score after a new review
CREATE OR ALTER TRIGGER dbo.trg_UpdateRanking
ON dbo.Reviews
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Recalculate the average rating for each affected freelancer
    -- and update their ranking score (avg_rating * 20 as a simple formula)
    UPDATE fr
    SET
        fr.score         = x.new_score,
        fr.calculated_at = GETDATE()
    FROM dbo.Freelancer_Rankings fr
    INNER JOIN
    (
        SELECT
            c.freelancer_id,
            AVG(r.rating) * 20 AS new_score
        FROM dbo.Reviews r
        INNER JOIN dbo.Contracts c
            ON r.contract_id = c.contract_id
        WHERE c.freelancer_id IN
        (
            SELECT c2.freelancer_id
            FROM inserted i
            INNER JOIN dbo.Contracts c2
                ON i.contract_id = c2.contract_id
        )
        GROUP BY c.freelancer_id
    ) x
        ON fr.freelancer_id = x.freelancer_id;
END;
GO



--  Top freelancers by lifetime earnings and performance score
SELECT TOP 10
    uf.name              AS Freelancer_Name,
    f.hourly_rate,
    f.experience_years,
    fr.score             AS Ranking_Score,
    fr.rank_position,
    SUM(e.total_earned)  AS Lifetime_Earnings,
    AVG(e.avg_rating)    AS Career_Avg_Rating
FROM dbo.Freelancers f
INNER JOIN dbo.Users uf
    ON f.freelancer_id = uf.user_id
INNER JOIN dbo.Freelancer_Rankings fr
    ON f.freelancer_id = fr.freelancer_id
INNER JOIN dbo.Earnings_Log e
    ON f.freelancer_id = e.freelancer_id
GROUP BY uf.name, f.hourly_rate, f.experience_years, fr.score, fr.rank_position
ORDER BY Lifetime_Earnings DESC;

--  Project pipeline and total budget by status
SELECT
    status,
    COUNT(*)     AS Project_Count,
    SUM(budget)  AS Total_Budget,
    AVG(budget)  AS Avg_Budget,
    MIN(budget)  AS Smallest_Budget,
    MAX(budget)  AS Largest_Budget
FROM dbo.Projects
GROUP BY status
ORDER BY Total_Budget DESC;

--  Client project activity and spending
SELECT
    uc.name              AS Client_Name,
    c.company_name,
    c.industry,
    c.total_spent,
    COUNT(p.project_id)  AS Projects_Posted,
    SUM(p.budget)        AS Total_Budget_Posted
FROM dbo.Clients c
INNER JOIN dbo.Users uc
    ON c.client_id = uc.user_id
LEFT JOIN dbo.Projects p
    ON c.client_id = p.client_id
GROUP BY uc.name, c.company_name, c.industry, c.total_spent
ORDER BY c.total_spent DESC;

--  Bid comparison and contract conversion rate
SELECT
    p.project_id,
    p.title,
    p.budget,
    COUNT(b.bid_id)       AS Total_Bids,
    AVG(b.proposed_amount) AS Avg_Bid,
    MAX(b.proposed_amount) AS Highest_Bid,
    MIN(b.proposed_amount) AS Lowest_Bid,
    c.agreed_amount        AS Final_Contract_Value
FROM dbo.Projects p
LEFT JOIN dbo.Bids b
    ON p.project_id = b.project_id
LEFT JOIN dbo.Contracts c
    ON p.project_id = c.project_id
GROUP BY p.project_id, p.title, p.budget, c.agreed_amount
ORDER BY Total_Bids DESC;

--  Milestone completion and payment totals
SELECT
    COUNT(*)                                    AS Total_Milestones,
    SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END) AS Completed,
    SUM(CASE WHEN status='Pending'   THEN 1 ELSE 0 END) AS Pending,
    SUM(CASE WHEN status='Cancelled' THEN 1 ELSE 0 END) AS Cancelled,
    SUM(amount)                                 AS Total_Milestone_Value,
    SUM(CASE WHEN status='Completed' THEN amount ELSE 0 END) AS Released_Value,
    SUM(CASE WHEN status='Pending'   THEN amount ELSE 0 END) AS Pending_Value
FROM dbo.Milestones;

--  PKR/USD payment and exchange-rate analysis
SELECT
    COUNT(*)              AS Total_Payments,
    SUM(amount_usd)       AS Total_USD_Paid,
    AVG(amount_usd)       AS Avg_USD_Per_Payment,
    SUM(amount_pkr)       AS Total_PKR_Paid,
    AVG(amount_pkr)       AS Avg_PKR_Per_Payment,
    AVG(exchange_rate)    AS Avg_Exchange_Rate,
    MIN(exchange_rate)    AS Min_Exchange_Rate,
    MAX(exchange_rate)    AS Max_Exchange_Rate
FROM dbo.Payments;

--  Monthly freelancer earnings and average ratings
SELECT
    e.month,
    COUNT(DISTINCT e.freelancer_id)  AS Active_Freelancers,
    SUM(e.total_earned)              AS Monthly_Total_Earnings,
    AVG(e.total_earned)              AS Avg_Earnings_Per_Freelancer,
    AVG(e.avg_rating)                AS Platform_Avg_Rating
FROM dbo.Earnings_Log e
GROUP BY e.month
ORDER BY e.month ASC;

--  Skill demand and month-over-month growth
SELECT
    s.skill_name,
    s.category,
    MIN(d.demand_score)  AS Demand_Jan,
    MAX(d.demand_score)  AS Demand_Latest,
    MAX(d.demand_score) - MIN(d.demand_score) AS Total_Growth,
    AVG(d.growth_rate)   AS Avg_Monthly_Growth_Rate
FROM dbo.Demand_Trends d
INNER JOIN dbo.Skills s
    ON d.skill_id = s.skill_id
GROUP BY s.skill_name, s.category
ORDER BY Total_Growth DESC;

--  Freelancer matching by skill + ranking (stored procedure call)
EXEC dbo.match_freelancer @SkillID = 9;  -- Python

--  Fraud and risk monitoring summary
SELECT
    COUNT(*)              AS Total_Fraud_Flags,
    AVG(confidence_score) AS Avg_Confidence_Score,
    MAX(confidence_score) AS Highest_Confidence,
    MIN(confidence_score) AS Lowest_Confidence,
    (SELECT COUNT(*) FROM dbo.Reviews) AS Total_Reviews,
    CAST(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM dbo.Reviews)
        AS DECIMAL(5,2)
    )                     AS Fraud_Percentage
FROM dbo.Fraud_Flags;




 


--  COMPLETE PLATFORM DASHBOARD SUMMARY

SELECT
    'Platform Metrics'                              AS Category,
    CAST((SELECT COUNT(*) FROM dbo.Users)           AS NVARCHAR(20)) AS Value,
    'Total Users'                                   AS Description
UNION ALL
SELECT 'Platform Metrics',
    CAST((SELECT COUNT(*) FROM dbo.Freelancers)     AS NVARCHAR(20)),
    'Total Freelancers'
UNION ALL
SELECT 'Platform Metrics',
    CAST((SELECT COUNT(*) FROM dbo.Clients)         AS NVARCHAR(20)),
    'Total Clients'
UNION ALL
SELECT 'Project Pipeline',
    CAST((SELECT COUNT(*) FROM dbo.Projects WHERE status='Open') AS NVARCHAR(20)),
    'Open Projects'
UNION ALL
SELECT 'Project Pipeline',
    CAST((SELECT COUNT(*) FROM dbo.Projects WHERE status='In Progress') AS NVARCHAR(20)),
    'In Progress Projects'
UNION ALL
SELECT 'Project Pipeline',
    CAST((SELECT COUNT(*) FROM dbo.Projects WHERE status='Completed') AS NVARCHAR(20)),
    'Completed Projects'
UNION ALL
SELECT 'Financials',
    CAST(CAST(SUM(amount_usd) AS DECIMAL(15,2)) AS NVARCHAR(20)),
    'Total USD Paid'
FROM dbo.Payments
UNION ALL
SELECT 'Financials',
    CAST(CAST(AVG(total_earned) AS DECIMAL(10,2)) AS NVARCHAR(20)),
    'Avg Monthly Freelancer Earnings'
FROM dbo.Earnings_Log
UNION ALL
SELECT 'Quality',
    CAST(CAST(AVG(rating) AS DECIMAL(4,2)) AS NVARCHAR(20)),
    'Platform Average Review Rating'
FROM dbo.Reviews
UNION ALL
SELECT 'Safety',
    CAST(COUNT(*) AS NVARCHAR(20)),
    'Total Fraud Flags'
FROM dbo.Fraud_Flags;




-- [ VIEWS]


-- Top freelancers view
CREATE OR ALTER VIEW dbo.top_freelancers_view AS
SELECT uf.name AS freelancer_name, f.hourly_rate,
       f.experience_years, fr.score, fr.rank_position
FROM dbo.Users uf
INNER JOIN dbo.Freelancers f ON uf.user_id = f.freelancer_id
INNER JOIN dbo.Freelancer_Rankings fr ON f.freelancer_id = fr.freelancer_id;
GO

SELECT * FROM dbo.top_freelancers_view ORDER BY rank_position ASC;
GO

-- Active projects view
CREATE OR ALTER VIEW dbo.active_projects_view AS
SELECT p.project_id, p.title, p.budget, p.deadline, p.status,
       uc.name AS Client_Name, c.company_name
FROM dbo.Projects p
INNER JOIN dbo.Clients c ON p.client_id = c.client_id
INNER JOIN dbo.Users uc ON c.client_id = uc.user_id
WHERE p.status IN ('Open', 'In Progress');
GO

SELECT * FROM dbo.active_projects_view ORDER BY budget DESC;
GO

-- Fraud monitoring view
CREATE OR ALTER VIEW dbo.fraud_monitor_view AS
SELECT ff.flag_id, ff.reason, ff.confidence_score, ff.flagged_at,
       r.rating, r.comment, uf.name AS Freelancer_Name
FROM dbo.Fraud_Flags ff
INNER JOIN dbo.Reviews r ON ff.review_id = r.review_id
INNER JOIN dbo.Contracts c ON r.contract_id = c.contract_id
INNER JOIN dbo.Freelancers f ON c.freelancer_id = f.freelancer_id
INNER JOIN dbo.Users uf ON f.freelancer_id = uf.user_id;
GO

SELECT * FROM dbo.fraud_monitor_view ORDER BY confidence_score DESC;
GO



-- [STORED PROCEDURES]


-- match_freelancer: find top freelancers for a skill
CREATE OR ALTER PROCEDURE dbo.match_freelancer @SkillID INT
AS
BEGIN
    SELECT TOP 5
        uf.name AS Freelancer_Name, f.hourly_rate,
        f.experience_years, s.skill_name,
        fs.proficiency_level, fr.score, fr.rank_position
    FROM dbo.Freelancer_Skills fs
    INNER JOIN dbo.Freelancers f ON fs.freelancer_id = f.freelancer_id
    INNER JOIN dbo.Users uf ON f.freelancer_id = uf.user_id
    INNER JOIN dbo.Skills s ON fs.skill_id = s.skill_id
    INNER JOIN dbo.Freelancer_Rankings fr ON f.freelancer_id = fr.freelancer_id
    WHERE fs.skill_id = @SkillID
    ORDER BY fr.score DESC;
END;
GO

EXEC dbo.match_freelancer @SkillID = 1;   -- Web Development
EXEC dbo.match_freelancer @SkillID = 9;   -- Python
GO

-- monthly_report: earnings for a given month
CREATE OR ALTER PROCEDURE dbo.monthly_report @Month DATE
AS
BEGIN
    SELECT uf.name AS Freelancer_Name, e.month,
           e.total_earned, e.avg_rating, fr.rank_position
    FROM dbo.Earnings_Log e
    INNER JOIN dbo.Freelancers f ON e.freelancer_id = f.freelancer_id
    INNER JOIN dbo.Users uf ON f.freelancer_id = uf.user_id
    LEFT JOIN dbo.Freelancer_Rankings fr ON f.freelancer_id = fr.freelancer_id
    WHERE e.month = @Month
    ORDER BY e.total_earned DESC;
END;
GO

EXEC dbo.monthly_report @Month = '2026-09-01';
EXEC dbo.monthly_report @Month = '2026-08-01';
GO


-- [ TRIGGERS]

-- Trigger 1: Auto-release payment when milestone completed
CREATE OR ALTER TRIGGER dbo.trg_AutoPayment
ON dbo.Milestones AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Payments (milestone_id, amount_pkr, amount_usd, exchange_rate)
    SELECT i.milestone_id, i.amount * 285, i.amount, 285
    FROM inserted i
    INNER JOIN deleted d ON i.milestone_id = d.milestone_id
    WHERE i.status = 'Completed'
      AND d.status <> 'Completed'
      AND NOT EXISTS (SELECT 1 FROM dbo.Payments p WHERE p.milestone_id = i.milestone_id);
END;
GO

-- Test: complete a pending milestone
UPDATE dbo.Milestones
SET status = 'Completed', completed_at = GETDATE()
WHERE milestone_id = 84;

-- Check payment was auto-created
SELECT * FROM dbo.Payments WHERE milestone_id = 84;
GO

-- Trigger 2: Flag suspicious low-rating reviews
CREATE OR ALTER TRIGGER dbo.trg_FlagSuspiciousReview
ON dbo.Reviews AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Fraud_Flags (review_id, reason, confidence_score, flagged_at)
    SELECT review_id, 'Very low rating — auto flagged.', 80.00, GETDATE()
    FROM inserted
    WHERE rating <= 2.0;
END;
GO

-- Test: insert a very low rating
INSERT INTO dbo.Reviews (contract_id, rating, comment, is_flagged)
VALUES (1, 1.50, 'Very poor experience.', 0);

-- Check fraud flag was auto-created
SELECT TOP 1 * FROM dbo.Fraud_Flags ORDER BY flag_id DESC;
GO

-- Trigger 3: Update ranking score after new review
CREATE OR ALTER TRIGGER dbo.trg_UpdateRanking
ON dbo.Reviews AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE fr
    SET fr.score = x.new_score, fr.calculated_at = GETDATE()
    FROM dbo.Freelancer_Rankings fr
    INNER JOIN (
        SELECT c.freelancer_id, AVG(r.rating) * 20 AS new_score
        FROM dbo.Reviews r
        INNER JOIN dbo.Contracts c ON r.contract_id = c.contract_id
        WHERE c.freelancer_id IN (
            SELECT c2.freelancer_id FROM inserted i
            INNER JOIN dbo.Contracts c2 ON i.contract_id = c2.contract_id
        )
        GROUP BY c.freelancer_id
    ) x ON fr.freelancer_id = x.freelancer_id;
END;
GO



-- [ BUSINESS ANALYSIS]


-- Top 10 freelancers by lifetime earnings
SELECT TOP 10
    uf.name AS Freelancer_Name, f.hourly_rate,
    f.experience_years, fr.score, fr.rank_position,
    SUM(e.total_earned) AS Lifetime_Earnings,
    AVG(e.avg_rating) AS Career_Rating
FROM dbo.Freelancers f
INNER JOIN dbo.Users uf ON f.freelancer_id = uf.user_id
INNER JOIN dbo.Freelancer_Rankings fr ON f.freelancer_id = fr.freelancer_id
INNER JOIN dbo.Earnings_Log e ON f.freelancer_id = e.freelancer_id
GROUP BY uf.name, f.hourly_rate, f.experience_years, fr.score, fr.rank_position
ORDER BY Lifetime_Earnings DESC;

-- Project pipeline by status
SELECT status, COUNT(*) AS Count, SUM(budget) AS Total_Budget,
       AVG(budget) AS Avg_Budget, MIN(budget) AS Min, MAX(budget) AS Max
FROM dbo.Projects
GROUP BY status ORDER BY Total_Budget DESC;

-- Client activity and spending
SELECT uc.name AS Client_Name, c.company_name, c.industry,
       c.total_spent, COUNT(p.project_id) AS Projects_Posted,
       SUM(p.budget) AS Total_Budget_Posted
FROM dbo.Clients c
INNER JOIN dbo.Users uc ON c.client_id = uc.user_id
LEFT JOIN dbo.Projects p ON c.client_id = p.client_id
GROUP BY uc.name, c.company_name, c.industry, c.total_spent
ORDER BY c.total_spent DESC;

-- Bid comparison per project
SELECT p.project_id, p.title, p.budget,
       COUNT(b.bid_id) AS Total_Bids,
       AVG(b.proposed_amount) AS Avg_Bid,
       MAX(b.proposed_amount) AS Highest_Bid,
       MIN(b.proposed_amount) AS Lowest_Bid,
       c.agreed_amount AS Final_Contract_Value
FROM dbo.Projects p
LEFT JOIN dbo.Bids b ON p.project_id = b.project_id
LEFT JOIN dbo.Contracts c ON p.project_id = c.project_id
GROUP BY p.project_id, p.title, p.budget, c.agreed_amount
ORDER BY Total_Bids DESC;

-- Milestone completion summary
SELECT
    COUNT(*) AS Total_Milestones,
    SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END) AS Completed,
    SUM(CASE WHEN status='Pending'   THEN 1 ELSE 0 END) AS Pending,
    SUM(amount) AS Total_Value,
    SUM(CASE WHEN status='Completed' THEN amount ELSE 0 END) AS Released_Value,
    SUM(CASE WHEN status='Pending'   THEN amount ELSE 0 END) AS Pending_Value
FROM dbo.Milestones;

-- PKR/USD payment analysis
SELECT COUNT(*) AS Total_Payments,
       SUM(amount_usd) AS Total_USD, AVG(amount_usd) AS Avg_USD,
       SUM(amount_pkr) AS Total_PKR, AVG(amount_pkr) AS Avg_PKR,
       AVG(exchange_rate) AS Avg_Rate
FROM dbo.Payments;

-- Monthly earnings trend
SELECT e.month, COUNT(DISTINCT e.freelancer_id) AS Active_Freelancers,
       SUM(e.total_earned) AS Monthly_Total,
       AVG(e.total_earned) AS Avg_Per_Freelancer,
       AVG(e.avg_rating) AS Platform_Avg_Rating
FROM dbo.Earnings_Log e
GROUP BY e.month ORDER BY e.month ASC;

-- Skill demand growth
SELECT s.skill_name, s.category,
       MIN(d.demand_score) AS Start_Score,
       MAX(d.demand_score) AS Latest_Score,
       MAX(d.demand_score) - MIN(d.demand_score) AS Total_Growth,
       AVG(d.growth_rate) AS Avg_Growth_Rate
FROM dbo.Demand_Trends d
INNER JOIN dbo.Skills s ON d.skill_id = s.skill_id
GROUP BY s.skill_name, s.category
ORDER BY Total_Growth DESC;

-- Fraud monitoring summary
SELECT COUNT(*) AS Total_Flags,
       AVG(confidence_score) AS Avg_Confidence,
       MAX(confidence_score) AS Max_Confidence,
       MIN(confidence_score) AS Min_Confidence,
       (SELECT COUNT(*) FROM dbo.Reviews) AS Total_Reviews,
       CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.Reviews) AS DECIMAL(5,2)) AS Fraud_Pct
FROM dbo.Fraud_Flags;



-- [ AI RISK SCORING]
-- ============================================================

SELECT
    uf.name              AS Freelancer_Name,
    f.hourly_rate,
    f.experience_years,
    COALESCE(e.Career_Rating, 0) AS Career_Avg_Rating,
    COALESCE(e.Avg_Monthly, 0)   AS Avg_Monthly_Earning,
    COALESCE(fc.Flags, 0)        AS Fraud_Flags,
    fr.rank_position,
    -- Risk Score calculation
    (
        CASE WHEN COALESCE(e.Career_Rating,0) >= 4.5 THEN 30
             WHEN COALESCE(e.Career_Rating,0) >= 4.0 THEN 20
             ELSE 0 END
      + CASE WHEN f.experience_years >= 5 THEN 20 ELSE 0 END
      + CASE WHEN f.availability = 1 THEN 10 ELSE 0 END
      + CASE WHEN COALESCE(e.Avg_Monthly,0) >= 5000 THEN 10 ELSE 0 END
      - CASE WHEN COALESCE(fc.Flags,0) > 0 THEN 30 ELSE 0 END
    ) AS Risk_Score,
    -- Risk Level classification
    CASE
        WHEN (
            CASE WHEN COALESCE(e.Career_Rating,0) >= 4.5 THEN 30
                 WHEN COALESCE(e.Career_Rating,0) >= 4.0 THEN 20
                 ELSE 0 END
          + CASE WHEN f.experience_years >= 5 THEN 20 ELSE 0 END
          + CASE WHEN f.availability = 1 THEN 10 ELSE 0 END
          + CASE WHEN COALESCE(e.Avg_Monthly,0) >= 5000 THEN 10 ELSE 0 END
          - CASE WHEN COALESCE(fc.Flags,0) > 0 THEN 30 ELSE 0 END
        ) >= 50 THEN 'Low Risk'
        WHEN (
            CASE WHEN COALESCE(e.Career_Rating,0) >= 4.5 THEN 30
                 WHEN COALESCE(e.Career_Rating,0) >= 4.0 THEN 20
                 ELSE 0 END
          + CASE WHEN f.experience_years >= 5 THEN 20 ELSE 0 END
          + CASE WHEN f.availability = 1 THEN 10 ELSE 0 END
          + CASE WHEN COALESCE(e.Avg_Monthly,0) >= 5000 THEN 10 ELSE 0 END
          - CASE WHEN COALESCE(fc.Flags,0) > 0 THEN 30 ELSE 0 END
        ) >= 20 THEN 'Medium Risk'
        ELSE 'High Risk'
    END AS Risk_Level
FROM dbo.Freelancers f
INNER JOIN dbo.Users uf ON f.freelancer_id = uf.user_id
LEFT JOIN (
    SELECT freelancer_id, AVG(total_earned) AS Avg_Monthly, AVG(avg_rating) AS Career_Rating
    FROM dbo.Earnings_Log GROUP BY freelancer_id
) e ON f.freelancer_id = e.freelancer_id
LEFT JOIN (
    SELECT c.freelancer_id, COUNT(ff.flag_id) AS Flags
    FROM dbo.Contracts c
    INNER JOIN dbo.Reviews r ON c.contract_id = r.contract_id
    INNER JOIN dbo.Fraud_Flags ff ON r.review_id = ff.review_id
    GROUP BY c.freelancer_id
) fc ON f.freelancer_id = fc.freelancer_id
LEFT JOIN dbo.Freelancer_Rankings fr ON f.freelancer_id = fr.freelancer_id
ORDER BY Risk_Score DESC;



-- [ FINAL PLATFORM DASHBOARD SUMMARY]


SELECT 'Total Users'         AS Metric, CAST((SELECT COUNT(*) FROM dbo.Users) AS NVARCHAR) AS Value
UNION ALL SELECT 'Total Freelancers',   CAST((SELECT COUNT(*) FROM dbo.Freelancers) AS NVARCHAR)
UNION ALL SELECT 'Total Clients',       CAST((SELECT COUNT(*) FROM dbo.Clients) AS NVARCHAR)
UNION ALL SELECT 'Open Projects',       CAST((SELECT COUNT(*) FROM dbo.Projects WHERE status='Open') AS NVARCHAR)
UNION ALL SELECT 'In Progress',         CAST((SELECT COUNT(*) FROM dbo.Projects WHERE status='In Progress') AS NVARCHAR)
UNION ALL SELECT 'Completed Projects',  CAST((SELECT COUNT(*) FROM dbo.Projects WHERE status='Completed') AS NVARCHAR)
UNION ALL SELECT 'Total Payments',      CAST((SELECT COUNT(*) FROM dbo.Payments) AS NVARCHAR)
UNION ALL SELECT 'Total Reviews',       CAST((SELECT COUNT(*) FROM dbo.Reviews) AS NVARCHAR)
UNION ALL SELECT 'Fraud Flags',         CAST((SELECT COUNT(*) FROM dbo.Fraud_Flags) AS NVARCHAR)
UNION ALL SELECT 'Total Skills',        CAST((SELECT COUNT(*) FROM dbo.Skills) AS NVARCHAR);

