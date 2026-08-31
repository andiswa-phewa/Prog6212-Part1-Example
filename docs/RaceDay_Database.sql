/*
    RaceDay Event Management System
    Part 1 - Model SQL Server Database Script
    Purpose: Marking memorandum / exemplar solution

    This script is designed for Microsoft SQL Server.
    It creates the RaceDay database structure from a clean state,
    applies keys and constraints, and inserts realistic sample data.
*/

IF DB_ID('RaceDayDB') IS NULL
BEGIN
    CREATE DATABASE RaceDayDB;
END;
GO

USE RaceDayDB;
GO

/* Drop tables in dependency order so that the script can be re-run. */
DROP TABLE IF EXISTS dbo.Results;
DROP TABLE IF EXISTS dbo.Enrolments;
DROP TABLE IF EXISTS dbo.Categories;
DROP TABLE IF EXISTS dbo.Events;
DROP TABLE IF EXISTS dbo.Participants;
DROP TABLE IF EXISTS dbo.Organisers;
DROP TABLE IF EXISTS dbo.Users;
GO

/* ================================================================
   1. USERS
   Stores the common information for both Organisers and Participants.
   ================================================================ */
CREATE TABLE dbo.Users
(
    UserID          INT IDENTITY(1,1) PRIMARY KEY,
    FullName        NVARCHAR(120) NOT NULL,
    Email           NVARCHAR(150) NOT NULL,
    PasswordHash    NVARCHAR(255) NOT NULL,
    [Role]          NVARCHAR(20) NOT NULL,
    CreatedAt       DATETIME2(0) NOT NULL
        CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT CK_Users_Role CHECK ([Role] IN ('Organiser', 'Participant'))
);
GO

/* ================================================================
   2. ORGANISERS
   Role-specific information for users who create and manage events.
   OrganiserID is both the PK and an FK to Users.UserID.
   ================================================================ */
CREATE TABLE dbo.Organisers
(
    OrganiserID       INT PRIMARY KEY,
    OrganisationName  NVARCHAR(150) NOT NULL,
    ContactNumber     NVARCHAR(30) NOT NULL,

    CONSTRAINT FK_Organisers_Users
        FOREIGN KEY (OrganiserID) REFERENCES dbo.Users(UserID)
);
GO

/* ================================================================
   3. PARTICIPANTS
   Role-specific information for users who enter events.
   ParticipantID is both the PK and an FK to Users.UserID.
   ================================================================ */
CREATE TABLE dbo.Participants
(
    ParticipantID     INT PRIMARY KEY,
    DateOfBirth       DATE NOT NULL,
    EmergencyContact  NVARCHAR(120) NOT NULL,

    CONSTRAINT FK_Participants_Users
        FOREIGN KEY (ParticipantID) REFERENCES dbo.Users(UserID)
);
GO

/* ================================================================
   4. EVENTS
   Each Event is created by one Organiser.
   ================================================================ */
CREATE TABLE dbo.Events
(
    EventID          INT IDENTITY(1,1) PRIMARY KEY,
    EventName        NVARCHAR(150) NOT NULL,
    [Description]    NVARCHAR(500) NULL,
    EventDate        DATETIME2(0) NOT NULL,
    [Location]       NVARCHAR(180) NOT NULL,
    DistanceKm       DECIMAL(6,2) NOT NULL,
    EventType        NVARCHAR(30) NOT NULL,
    OrganiserID      INT NOT NULL,
    MaxParticipants  INT NOT NULL,
    [Status]         NVARCHAR(20) NOT NULL
        CONSTRAINT DF_Events_Status DEFAULT 'Open',

    CONSTRAINT FK_Events_Organisers
        FOREIGN KEY (OrganiserID) REFERENCES dbo.Organisers(OrganiserID),
    CONSTRAINT CK_Events_Distance CHECK (DistanceKm > 0),
    CONSTRAINT CK_Events_MaxParticipants CHECK (MaxParticipants > 0),
    CONSTRAINT CK_Events_Type CHECK (EventType IN ('Road Running', 'Walking', 'Cycling')),
    CONSTRAINT CK_Events_Status CHECK ([Status] IN ('Draft', 'Open', 'Closed', 'Completed', 'Cancelled'))
);
GO

/* ================================================================
   5. CATEGORIES
   One Event can have many Categories.
   ================================================================ */
CREATE TABLE dbo.Categories
(
    CategoryID     INT IDENTITY(1,1) PRIMARY KEY,
    EventID        INT NOT NULL,
    CategoryName   NVARCHAR(100) NOT NULL,
    MinAge         INT NULL,
    MaxAge         INT NULL,
    Fee            DECIMAL(10,2) NOT NULL
        CONSTRAINT DF_Categories_Fee DEFAULT 0,

    CONSTRAINT FK_Categories_Events
        FOREIGN KEY (EventID) REFERENCES dbo.Events(EventID),
    CONSTRAINT UQ_Categories_Event_CategoryName
        UNIQUE (EventID, CategoryName),
    /* Supports the composite FK from Enrolments and guarantees
       that the selected Category belongs to the selected Event. */
    CONSTRAINT UQ_Categories_Event_CategoryID
        UNIQUE (EventID, CategoryID),
    CONSTRAINT CK_Categories_MinAge CHECK (MinAge IS NULL OR MinAge >= 0),
    CONSTRAINT CK_Categories_MaxAge CHECK (MaxAge IS NULL OR MaxAge >= 0),
    CONSTRAINT CK_Categories_AgeRange CHECK (MaxAge IS NULL OR MinAge IS NULL OR MaxAge >= MinAge),
    CONSTRAINT CK_Categories_Fee CHECK (Fee >= 0)
);
GO

/* ================================================================
   6. ENROLMENTS
   Resolves the many-to-many relationship between Participants and Events.
   A Participant chooses one Category when entering an Event.
   ================================================================ */
CREATE TABLE dbo.Enrolments
(
    EnrolmentID      INT IDENTITY(1,1) PRIMARY KEY,
    ParticipantID   INT NOT NULL,
    EventID         INT NOT NULL,
    CategoryID      INT NOT NULL,
    EnrolmentDate   DATETIME2(0) NOT NULL
        CONSTRAINT DF_Enrolments_EnrolmentDate DEFAULT SYSUTCDATETIME(),
    [Status]        NVARCHAR(20) NOT NULL
        CONSTRAINT DF_Enrolments_Status DEFAULT 'Confirmed',

    CONSTRAINT FK_Enrolments_Participants
        FOREIGN KEY (ParticipantID) REFERENCES dbo.Participants(ParticipantID),
    CONSTRAINT FK_Enrolments_Events
        FOREIGN KEY (EventID) REFERENCES dbo.Events(EventID),
    CONSTRAINT FK_Enrolments_EventCategory
        FOREIGN KEY (EventID, CategoryID)
        REFERENCES dbo.Categories(EventID, CategoryID),
    CONSTRAINT UQ_Enrolments_Participant_Event
        UNIQUE (ParticipantID, EventID),
    CONSTRAINT CK_Enrolments_Status
        CHECK ([Status] IN ('Confirmed', 'Cancelled', 'Completed'))
);
GO

/* ================================================================
   7. RESULTS
   An Enrolment can have at most one recorded Result.
   ================================================================ */
CREATE TABLE dbo.Results
(
    ResultID       INT IDENTITY(1,1) PRIMARY KEY,
    EnrolmentID    INT NOT NULL,
    FinishTime     TIME(0) NOT NULL,
    Position       INT NOT NULL,
    RecordedAt     DATETIME2(0) NOT NULL
        CONSTRAINT DF_Results_RecordedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_Results_Enrolments
        FOREIGN KEY (EnrolmentID) REFERENCES dbo.Enrolments(EnrolmentID),
    CONSTRAINT UQ_Results_Enrolment UNIQUE (EnrolmentID),
    CONSTRAINT CK_Results_Position CHECK (Position > 0)
);
GO

/* ================================================================
   SAMPLE DATA
   Minimum covered: 2 Organisers, 2 Participants, 3 Events,
   Categories for every Event, and sample Enrolments.
   ================================================================ */

INSERT INTO dbo.Users (FullName, Email, PasswordHash, [Role])
VALUES
('Nomsa Dlamini', 'nomsa.dlamini@raceday.example', 'HASHED_PASSWORD_1', 'Organiser'),
('Thabo Molefe', 'thabo.molefe@raceday.example', 'HASHED_PASSWORD_2', 'Organiser'),
('Lindiwe Khumalo', 'lindiwe.khumalo@raceday.example', 'HASHED_PASSWORD_3', 'Participant'),
('Sipho Naidoo', 'sipho.naidoo@raceday.example', 'HASHED_PASSWORD_4', 'Participant');
GO

INSERT INTO dbo.Organisers (OrganiserID, OrganisationName, ContactNumber)
VALUES
(1, 'Coastal Striders Events', '0825550101'),
(2, 'Urban Endurance SA', '0835550102');
GO

INSERT INTO dbo.Participants (ParticipantID, DateOfBirth, EmergencyContact)
VALUES
(3, '1998-04-12', 'Zanele Khumalo - 0845550201'),
(4, '1994-11-03', 'Priya Naidoo - 0845550202');
GO

INSERT INTO dbo.Events
    (EventName, [Description], EventDate, [Location], DistanceKm, EventType,
     OrganiserID, MaxParticipants, [Status])
VALUES
('Cape Town Winter Run',
 'A scenic road-running event along the Atlantic Seaboard.',
 '2026-07-18T07:00:00', 'Sea Point Promenade, Cape Town', 10.00,
 'Road Running', 1, 1200, 'Completed'),

('Durban Spring Walk',
 'A social beachfront walking event for recreational and competitive walkers.',
 '2026-09-05T06:30:00', 'Golden Mile, Durban', 8.00,
 'Walking', 1, 900, 'Open'),

('Joburg Heritage Cycle',
 'An urban cycling challenge through selected Johannesburg heritage routes.',
 '2026-09-24T06:00:00', 'Newtown, Johannesburg', 42.00,
 'Cycling', 2, 1500, 'Open');
GO

INSERT INTO dbo.Categories (EventID, CategoryName, MinAge, MaxAge, Fee)
VALUES
(1, 'Open 18-39', 18, 39, 250.00),
(1, 'Veteran 40+', 40, NULL, 250.00),
(2, 'Open Walker', 16, NULL, 150.00),
(2, 'Junior Walker', 12, 17, 100.00),
(3, 'Open Cyclist', 18, NULL, 400.00),
(3, 'Veteran Cyclist 40+', 40, NULL, 400.00);
GO

INSERT INTO dbo.Enrolments (ParticipantID, EventID, CategoryID, EnrolmentDate, [Status])
VALUES
(3, 1, 1, '2026-06-10T09:00:00', 'Completed'),
(4, 1, 1, '2026-06-12T10:30:00', 'Completed'),
(3, 2, 3, '2026-08-02T14:15:00', 'Confirmed'),
(4, 3, 5, '2026-08-05T11:45:00', 'Confirmed');
GO

INSERT INTO dbo.Results (EnrolmentID, FinishTime, Position, RecordedAt)
VALUES
(1, '00:52:18', 34, '2026-07-18T10:00:00'),
(2, '00:48:42', 21, '2026-07-18T10:00:00');
GO

/* ================================================================
   VERIFICATION QUERIES
   These are not required for the schema, but help the marker/student
   verify that the seed data and relationships work correctly.
   ================================================================ */

SELECT * FROM dbo.Users;
SELECT * FROM dbo.Organisers;
SELECT * FROM dbo.Participants;
SELECT * FROM dbo.Events;
SELECT * FROM dbo.Categories;
SELECT * FROM dbo.Enrolments;
SELECT * FROM dbo.Results;
GO

/* Human-readable enrolment check */
SELECT
    e.EnrolmentID,
    u.FullName AS Participant,
    ev.EventName,
    c.CategoryName,
    e.[Status] AS EnrolmentStatus,
    r.FinishTime,
    r.Position
FROM dbo.Enrolments e
INNER JOIN dbo.Participants p ON p.ParticipantID = e.ParticipantID
INNER JOIN dbo.Users u ON u.UserID = p.ParticipantID
INNER JOIN dbo.Events ev ON ev.EventID = e.EventID
INNER JOIN dbo.Categories c ON c.CategoryID = e.CategoryID
LEFT JOIN dbo.Results r ON r.EnrolmentID = e.EnrolmentID
ORDER BY e.EnrolmentID;
GO
