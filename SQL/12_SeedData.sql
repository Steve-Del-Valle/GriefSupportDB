-- =============================================================================
-- GriefSupportDB
-- A comprehensive SQL Server database architecture designed to modernize the
-- information system of a grief support nonprofit. Drawing on real-world
-- operational experience with a legacy system, the project reimagines how
-- clients, volunteers, facilitators, donors, staff, programs, and fundraising
-- activities can be managed within a flexible, scalable, and maintainable
-- relational database.
-- =============================================================================
-- Script 12: Seed Data
-- Description: Realistic synthetic data for demonstration and testing.
--              No real client, donor, volunteer, or staff data is used
--              anywhere in this script - all names, contact details, and
--              case details are fictional composites.
--
--              Inserted in dependency order against a freshly created,
--              empty database (Scripts 01-11 already run). IDENTITY values
--              are assumed to start at 1 and increment by 1 with no gaps.
--              IMPORTANT: this script must succeed in a single run against
--              a clean database. If any INSERT fails partway and is re-run,
--              SQL Server's IDENTITY seed will still have advanced, shifting
--              all subsequent hardcoded ID references out of alignment.
--              If that happens, DROP and recreate the database rather than
--              resuming mid-script.
--
--              ContactID map for reference while reading this script:
--                1-5    Staff
--                6-9    Board Members
--                10-15  Volunteer Facilitators
--                16-18  Support-only Volunteers (not Facilitators)
--                19-38  Clients
--                39-50  Donors
--
--              FacilitatorID 7 is ContactID 2 (Program Director), the one
--              staff member who is also a credentialed Facilitator.
-- Version:     v5
-- Author:      Steve Del Valle
-- Dependencies: 01 through 11 must be run first
--              
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- SECTION 1: STAFF (ContactID 1-5, StaffID 1-5)
-- =============================================================================

INSERT INTO ContactInformation
    (ProfileStatusID, ProfileTypeID, FirstName, LastName, Phone, Email,
     AddressLine1, CityID, StateID, Zip, CountryID, DateOfBirth, GenderID, EthnicityID, CreatedDate)
VALUES
    (1, 1, 'Maria',   'Delgado',   '541-555-0101', 'mdelgado@griefsupportorg.example',   '412 Siskiyou Blvd', 1, 37, '97520', 1, '1978-03-14', 2, 4, '2021-01-11'),
    (1, 1, 'James',   'Whitfield', '541-555-0102', 'jwhitfield@griefsupportorg.example', '890 Ashland St',    1, 37, '97520', 1, '1985-07-22', 1, 6, '2021-04-05'),
    (1, 1, 'Priya',   'Nair',      '541-555-0103', 'pnair@griefsupportorg.example',      '215 A St',          1, 37, '97520', 1, '1990-11-02', 2, 2, '2022-06-20'),
    (1, 1, 'Devon',   'Ashby',     '541-555-0104', 'dashby@griefsupportorg.example',     '77 N Main St',      1, 37, '97520', 1, '1993-02-18', 3, 6, '2022-09-01'),
    (1, 1, 'Carmen',  'Ruiz',      '541-555-0105', 'cruiz@griefsupportorg.example',      '330 Lithia Way',    1, 37, '97520', 1, '1988-05-30', 2, 4, '2023-03-15');
GO

INSERT INTO Staff (ContactID, JobTitle, StartDate) VALUES
    (1, 'Executive Director',                '2021-01-11'),
    (2, 'Program Director',                   '2021-04-05'),
    (3, 'Volunteer Coordinator',              '2022-06-20'),
    (4, 'Development & Fundraising Coordinator', '2022-09-01'),
    (5, 'Administrative Assistant',           '2023-03-15');
GO

-- Now that Staff exists, backfill CreatedByStaffID on the Staff records
-- themselves - the Executive Director is treated as the initial data steward.
UPDATE ContactInformation SET CreatedByStaffID = 1 WHERE ContactID BETWEEN 1 AND 5;
GO

-- Set a reasonable LastUpdatedByStaffID on OrgConfiguration now that Staff exists
UPDATE OrgConfiguration SET LastUpdatedByStaffID = 1, LastUpdatedDate = '2023-01-05';
GO

-- =============================================================================
-- SECTION 2: BOARD MEMBERS (ContactID 6-9)
-- =============================================================================

INSERT INTO ContactInformation
    (ProfileStatusID, ProfileTypeID, FirstName, LastName, Phone, Email,
     AddressLine1, CityID, StateID, Zip, CountryID, DateOfBirth, GenderID, EthnicityID, CreatedDate, CreatedByStaffID)
VALUES
    (1, 1, 'Harold',  'Bishop',    '541-555-0201', 'hbishop@example.com',   '55 Granite St',     1, 37, '97520', 1, '1962-09-09', 1, 6, '2021-02-01', 1),
    (1, 1, 'Linda',   'Cho',       '541-555-0202', 'lcho@example.com',      '19 Wimer St',       1, 37, '97520', 1, '1970-01-25', 2, 2, '2021-02-01', 1),
    (1, 1, 'Robert',  'Fenwick',   '541-555-0203', 'rfenwick@example.com',  '640 Iowa St',       2, 37, '97501', 1, '1958-06-11', 1, 6, '2022-01-10', 1),
    (1, 1, 'Aisha',   'Muhammad',  '541-555-0204', 'amuhammad@example.com', '212 Beach St',      1, 37, '97520', 1, '1975-12-03', 2, 3, '2023-01-09', 1);
GO

INSERT INTO BoardMember (ContactID, BoardRoleID, StartDate) VALUES
    (6, 1, '2021-02-01'),   -- Harold Bishop, Chair
    (7, 3, '2021-02-01'),   -- Linda Cho, Treasurer
    (8, 4, '2022-01-10'),   -- Robert Fenwick, Secretary
    (9, 5, '2023-01-09');   -- Aisha Muhammad, Member at Large
GO

-- =============================================================================
-- SECTION 3: DECEASED (DeceasedID 1-14)
-- Referenced by the Loss records seeded in Section 7.
-- =============================================================================

INSERT INTO Deceased (DeceasedTypeID, FirstName, LastName, Species, DateOfDeath, CauseOfDeathTypeID, Notes) VALUES
    (1, 'Thomas',  'Alvarez',   NULL,     '2023-08-14', 2, 'Long illness; hospice involved in final weeks.'),
    (1, 'Nancy',   'Alvarez',   NULL,     '2019-04-02', 1, NULL),
    (1, 'Ethan',   'Park',      NULL,     '2024-01-30', 3, 'Motor vehicle accident.'),
    (1, 'Grace',   'Odom',      NULL,     '2022-11-19', 3, 'Family aware and processing openly in group.'),
    (1, 'Walter',  'Odom',      NULL,     '2020-07-07', 1, NULL),
    (1, 'Samuel',  'Iverson',   NULL,     '2023-03-25', 5, NULL),
    (1, 'Bethany', 'Marsh',     NULL,     '2024-05-11', 2, NULL),
    (1, 'Infant',  'Colston',   NULL,     '2024-02-02', 7, 'Neonatal loss; extremely sensitive - use NoteType Sensitive on all related notes.'),
    (2, 'Biscuit', NULL,       'Dog',     '2023-09-30', 6, NULL),
    (1, 'Louis',   'Trent',     NULL,     '2021-12-24', 1, NULL),
    (1, 'Patricia','Nakamura',  NULL,     '2024-06-18', 2, NULL),
    (1, 'Owen',    'Delacroix', NULL,     '2023-01-05', 4, 'Client is a first responder; loss occurred on duty.'),
    (2, 'Whiskers',NULL,       'Cat',     '2024-03-12', 1, NULL),
    (1, 'Diane',   'Whitmore',  NULL,     '2019-10-08', 2, NULL);
GO

-- =============================================================================
-- SECTION 4: VOLUNTEERS (ContactID 10-18)
-- 10-15 become Facilitators in Section 5. 16-18 remain support-only.
-- =============================================================================

INSERT INTO ContactInformation
    (ProfileStatusID, ProfileTypeID, FirstName, LastName, Phone, Email,
     AddressLine1, CityID, StateID, Zip, CountryID, DateOfBirth, GenderID, EthnicityID, CreatedDate, CreatedByStaffID)
VALUES
    (1, 1, 'Karen',   'Sussman',  '541-555-0301', 'ksussman@example.com',  '18 Nutley St',     1, 37, '97520', 1, '1965-03-19', 2, 6, '2022-02-14', 3),
    (1, 1, 'Marcus',  'Boyle',    '541-555-0302', 'mboyle@example.com',    '900 Clay St',      1, 37, '97520', 1, '1972-08-08', 1, 6, '2022-02-14', 3),
    (1, 1, 'Yuki',    'Tanaka',   '541-555-0303', 'ytanaka@example.com',   '44 Oak St',        1, 37, '97520', 1, '1980-10-27', 2, 2, '2022-05-01', 3),
    (1, 1, 'Isabel',  'Cortez',   '541-555-0304', 'icortez@example.com',   '76 Wightman St',   1, 37, '97520', 1, '1969-01-15', 2, 4, '2022-05-01', 3),
    (1, 1, 'Gregory', 'Falk',     '541-555-0305', 'gfalk@example.com',     '501 E Main St',    1, 37, '97520', 1, '1977-06-06', 1, 6, '2023-02-20', 3),
    (1, 1, 'Renee',   'Okafor',   '541-555-0306', 'rokafor@example.com',   '30 Church St',     1, 37, '97520', 1, '1995-09-12', 2, 3, '2024-01-08', 3),
    (1, 1, 'Bill',    'Harmon',   '541-555-0307', 'bharmon@example.com',   '210 Helman St',    1, 37, '97520', 1, '1958-04-21', 1, 6, '2022-11-03', 3),
    (1, 1, 'Susan',   'Zhou',     '541-555-0308', 'szhou@example.com',     '15 Pioneer St',    1, 37, '97520', 1, '1966-12-30', 2, 2, '2023-05-17', 3),
    (1, 1, 'Diego',   'Salcedo',  '541-555-0309', 'dsalcedo@example.com',  '620 B St',         1, 37, '97520', 1, '1991-07-19', 1, 4, '2024-03-02', 3);
GO

INSERT INTO VolunteerInformation
    (ContactID, VolunteerStatusID, VolunteerContactStaffID, VolunteerContactDate, StartDate,
     InterestedInTraining, BSTRegistrationDate, BSTCompletedDate,
     BackgroundCheckReleaseForm, BackgroundCheckSubmitted, BackgroundCheckReport, PersonalInterviewCompleted)
VALUES
    (10, 4, 3, '2022-02-14', '2022-05-01', 1, '2022-02-20', '2022-04-15', 1, '2022-04-16', 'BG-2022-0114', 1),
    (11, 4, 3, '2022-02-14', '2022-05-01', 1, '2022-02-20', '2022-04-15', 1, '2022-04-16', 'BG-2022-0115', 1),
    (12, 4, 3, '2022-05-01', '2022-08-01', 1, '2022-05-10', '2022-07-20', 1, '2022-07-21', 'BG-2022-0201', 1),
    (13, 4, 3, '2022-05-01', '2022-09-01', 1, '2022-05-10', '2022-07-20', 1, '2022-07-21', 'BG-2022-0202', 1),
    (14, 4, 3, '2023-02-20', '2023-06-01', 1, '2023-03-01', '2023-05-10', 1, '2023-05-11', 'BG-2023-0088', 1),
    (15, 2, 3, '2024-01-08', NULL,          1, '2024-01-15', NULL,        1, '2024-02-01', NULL,          0),
    (16, 4, 3, '2022-11-03', '2023-01-15', 0, NULL, NULL, 1, '2023-01-02', 'BG-2022-0410', 1),
    (17, 4, 3, '2023-05-17', '2023-07-01', 0, NULL, NULL, 1, '2023-06-15', 'BG-2023-0201', 1),
    (18, 1, 3, '2024-03-02', NULL,          0, NULL, NULL, 0, NULL, NULL, 0);
GO

INSERT INTO VolunteerSupportSkill (VolunteerID, SkillID) VALUES
    (1, 1), (1, 2),
    (2, 1), (2, 3),
    (3, 2), (3, 5),
    (7, 1), (7, 2),
    (8, 2), (8, 6);
GO

INSERT INTO VolunteerFacilitationSkill (VolunteerID, SkillID) VALUES
    (1, 1), (1, 3),
    (2, 1),
    (3, 3), (3, 5),
    (4, 1), (4, 2),
    (5, 1);
GO

-- =============================================================================
-- SECTION 5: FACILITATORS
-- FacilitatorID 1-6 = ContactID 10-15 (volunteers). FacilitatorID 7 = ContactID 2
-- (Program Director, staff facilitator).
-- =============================================================================

INSERT INTO Facilitator
    (ContactID, FacilitatorTypeID, FacilitatorStatusID, BSTCompletedDate,
     BackgroundCheckCleared, BackgroundCheckDate, InterviewDate, InterviewedByStaffID, QualifiedDate)
VALUES
    (10, 2, 3, '2022-04-15', 1, '2022-04-16', '2022-05-01', 3, '2022-08-15'),  -- Karen Sussman - Active
    (11, 2, 3, '2022-04-15', 1, '2022-04-16', '2022-05-01', 3, '2022-09-01'),  -- Marcus Boyle - Active
    (12, 2, 3, '2022-07-20', 1, '2022-07-21', '2022-08-01', 3, '2023-01-10'),  -- Yuki Tanaka - Active
    (13, 2, 3, '2022-07-20', 1, '2022-07-21', '2022-08-01', 3, '2023-02-01'),  -- Isabel Cortez - Active
    (14, 2, 3, '2023-05-10', 1, '2023-05-11', '2023-06-01', 2, '2023-11-01'),  -- Gregory Falk - Active
    (15, 2, 1, '2024-02-01', 1, '2024-02-01', NULL, NULL, NULL),               -- Renee Okafor - In Training
    (2,  1, 3, '2019-06-01', 1, '2019-06-02', '2019-06-15', 1, '2019-09-01');  -- James Whitfield (staff) - Active
GO

INSERT INTO FacilitatorGroupTypeQualification
    (FacilitatorID, GroupTypeID, PersonalExperienceVerified, PersonalExperienceNotes,
     VettingDate, VettedByStaffID, VettingMethod, VettingOutcome,
     QualifiedForCoFacilitator, CoFacilitatorQualifiedDate,
     QualifiedForFacilitator, FacilitatorQualifiedDate, QualifiedByStaffID)
VALUES
    (1, 1,  1, 'Lost spouse to illness in 2018.',       '2022-08-01', 3, 'Interview',            'Approved', 1, '2022-08-15', 0, NULL,         NULL),
    (2, 2,  1, 'Lost a child; completed own grief work five years prior.', '2022-08-20', 3, 'Interview and Panel', 'Approved', 1, '2022-09-01', 1, '2023-03-01', 2),
    (3, 2,  1, 'Sibling completed similar loss group as a client previously.', '2023-01-01', 3, 'Interview', 'Approved', 1, '2023-01-10', 0, NULL, NULL),
    (4, 14, 1, 'General facilitation background; broad lived-experience base.', '2023-01-20', 2, 'Interview', 'Approved', 1, '2023-02-01', 1, '2023-08-01', 2),
    (5, 14, 1, 'Lost a parent; strong group facilitation history from prior nonprofit work.', '2023-10-01', 2, 'Interview', 'Approved', 1, '2023-11-01', 0, NULL, NULL),
    (5, 12, 1, 'Extensive experience with teen bereavement from prior school counseling role.', '2023-10-15', 2, 'Interview and Panel', 'Approved', 1, '2023-11-01', 1, '2024-04-01', 2),
    (6, 12, 0, NULL, NULL, NULL, NULL, 'Deferred', 0, NULL, 0, NULL, NULL),
    (7, 1,  1, 'Professional background plus personal loss of a partner.', '2019-08-01', 1, 'Interview and Panel', 'Approved', 1, '2019-09-01', 1, '2019-09-01', 1),
    (7, 5,  1, 'Extensive clinical training in suicide postvention.',      '2020-01-10', 1, 'Interview and Panel', 'Approved', 1, '2020-02-01', 1, '2020-02-01', 1);
GO

INSERT INTO FacilitatorAvailability (FacilitatorID, DayOfWeek, IsAvailable, Notes) VALUES
    (1, 'Tuesday',   1, NULL),
    (2, 'Wednesday', 1, NULL),
    (3, 'Wednesday', 1, NULL),
    (4, 'Thursday',  1, NULL),
    (5, 'Thursday',  1, NULL),
    (5, 'Monday',    1, 'Available for the Teen group after school hours only.'),
    (6, 'Monday',    1, 'Still in training - co-facilitator seat only.'),
    (7, 'Tuesday',   1, NULL);
GO

-- =============================================================================
-- SECTION 6: PEER SUPPORT GROUPS (GroupID 1-4)
-- =============================================================================

INSERT INTO PeerSupportGroup
    (GroupTypeID, FacilitatorID, CoFacilitatorID, GroupName, GroupDescription, StartDate) VALUES
    (1,  7, 1, 'Spouse & Partner Loss - Tuesday Evening', 'Ongoing peer support for adults who have lost a spouse or partner.', '2022-09-06'),
    (2,  2, 3, 'Child Loss - Wednesday Afternoon',          'Ongoing peer support for bereaved parents who have lost a child.',    '2023-01-11'),
    (14, 4, 5, 'General Grief Support - Thursday Evening',  'Open grief support group for any loss type, drop-in format.',         '2023-02-16'),
    (12, 5, 6, 'Teen Grief Group - Monday After School',    'Peer support for teens processing the death of a family member.',     '2024-04-08');
GO

-- =============================================================================
-- SECTION 7: CLIENTS (ContactID 19-38)
-- =============================================================================

INSERT INTO ContactInformation
    (ProfileStatusID, ProfileTypeID, FirstName, LastName, Phone, Email,
     AddressLine1, CityID, StateID, Zip, CountryID, DateOfBirth, GenderID, EthnicityID,
     CreatedDate, CreatedByStaffID, InitialContactDate, InitialContactStaffID)
VALUES
    (1, 1, 'Angela',   'Alvarez',   '541-555-1001', 'aalvarez@example.com',   '5 Terrace St',     1, 37, '97520', 1, '1980-02-11', 2, 4, '2023-08-20', 1, '2023-08-20', 1),
    (1, 1, 'Ben',      'Park',      '541-555-1002', 'bpark@example.com',      '810 Elkader St',   2, 37, '97501', 1, '1975-05-30', 1, 2, '2024-02-05', 1, '2024-02-05', 1),
    (1, 1, 'Ji-woo',   'Park',      '541-555-1003', 'jpark@example.com',      '810 Elkader St',   2, 37, '97501', 1, '2010-09-14', 3, 2, '2024-02-05', 1, '2024-02-05', 1),
    (1, 1, 'Farah',    'Odom',      '541-555-1004', 'fodom@example.com',      '340 Vista St',     1, 37, '97520', 1, '1955-01-01', 2, 6, '2020-08-01', 1, '2020-08-01', 1),
    (1, 1, 'Nathan',   'Iverson',   '541-555-1005', 'niverson@example.com',   '92 Palm Ave',      4, 37, '97540', 1, '1990-03-08', 1, 6, '2023-04-02', 1, '2023-04-02', 1),
    (1, 1, 'Colleen',  'Marsh',     '541-555-1006', 'cmarsh@example.com',     '61 Manzanita St',  1, 37, '97520', 1, '1982-07-19', 2, 6, '2024-05-20', 1, '2024-05-20', 1),
    (1, 1, 'Priscilla','Colston',   '541-555-1007', 'pcolston@example.com',   '14 Fern Valley Rd',1, 37, '97520', 1, '1996-04-25', 2, 3, '2024-02-10', 1, '2024-02-10', 1),
    (1, 1, 'Marco',    'Colston',   '541-555-1008', 'macolston@example.com',  '14 Fern Valley Rd',1, 37, '97520', 1, '1994-11-11', 1, 4, '2024-02-10', 1, '2024-02-10', 1),
    (1, 1, 'Tanya',    'Reyes',     '541-555-1009', 'treyes@example.com',     '203 Water St',     1, 37, '97520', 1, '2011-06-06', 2, 4, '2023-10-14', 1, '2023-10-14', 1),
    (1, 1, 'Louise',   'Trent',     '541-555-1010', 'ltrent@example.com',     '48 Morton St',     1, 37, '97520', 1, '1950-09-27', 2, 6, '2022-01-05', 1, '2022-01-05', 1),
    (1, 1, 'Hana',     'Nakamura',  '541-555-1011', 'hnakamura@example.com',  '705 Mountain Ave', 1, 37, '97520', 1, '1968-12-19', 2, 2, '2024-06-25', 1, '2024-06-25', 1),
    (1, 1, 'Ray',      'Delacroix', '541-555-1012', 'rdelacroix@example.com', '19 Winburn Way',   1, 37, '97520', 1, '1985-08-02', 1, 6, '2023-01-08', 2, '2023-01-08', 2),
    (1, 1, 'Chelsea',  'Whitmore',  '541-555-1013', 'cwhitmore@example.com',  '360 Clark Ave',    1, 37, '97520', 1, '1972-10-30', 2, 6, '2020-01-15', 1, '2020-01-15', 1),
    (1, 1, 'Omar',     'Siddiqui',  '541-555-1014', 'osiddiqui@example.com',  '80 Hersey St',     1, 37, '97520', 1, '1998-01-17', 1, 3, '2024-07-01', 1, '2024-07-01', 1),
    (2, 1, 'Patrick',  'Doyle',     '541-555-1015', 'pdoyle@example.com',     '221 Iowa St',      2, 37, '97501', 1, '1963-03-03', 1, 6, '2021-05-11', 1, '2021-05-11', 1),
    (1, 1, 'Sonia',    'Grewal',    '541-555-1016', 'sgrewal@example.com',    '5 Ray Ln',         1, 37, '97520', 1, '1979-06-21', 2, 2, '2024-03-19', 2, '2024-03-19', 2),
    (1, 1, 'Tyler',    'Combs',     '541-555-1017', 'tcombs@example.com',     '410 N Laurel St',  1, 37, '97520', 1, '2009-02-14', 1, 6, '2024-05-02', 1, '2024-05-02', 1),
    (1, 1, 'Wendy',    'Falk',      '541-555-1018', 'wfalk2@example.com',     '15 Almeda Dr',     6, 37, '97526', 1, '1991-09-09', 2, 6, '2024-08-14', 2, '2024-08-14', 2),
    (1, 1, 'Craig',    'Bell',      '541-555-1019', 'cbell@example.com',      '600 Crowson Rd',   1, 37, '97520', 1, '1988-04-04', 1, 6, '2024-09-05', 1, '2024-09-05', 1),
    (3, 1, 'Diane',    'Whitmore-Ellis', '541-555-1020', NULL, '360 Clark Ave', 1, 37, '97520', 1, '1948-11-11', 2, 6, '2019-10-15', 1, '2019-10-15', 1);
GO

INSERT INTO ClientInformation
    (ContactID, ClientStatusID, ClientTypeID, ClientContactStaffID, ClientContactDate,
     InsuranceID, MinorsSuitableForID, InviteToGroups, ExperiencedSuicideLoss, ExperiencedHomicideLoss,
     CreatedByStaffID)
VALUES
    (19, 1, 1, 1, '2023-08-20', 2, NULL, 1, 0, 0, 1),   -- Angela Alvarez
    (20, 1, 1, 1, '2024-02-05', 5, NULL, 1, 0, 0, 1),   -- Ben Park
    (21, 1, 2, 1, '2024-02-05', 5, 3,    1, 0, 0, 1),   -- Ji-woo Park (child, sibling loss)
    (22, 1, 1, 1, '2020-08-01', 6, NULL, 1, 0, 0, 1),   -- Farah Odom
    (23, 1, 1, 1, '2023-04-02', 2, NULL, 1, 0, 1, 1),   -- Nathan Iverson (homicide loss)
    (24, 1, 1, 1, '2024-05-20', 1, NULL, 1, 0, 0, 1),   -- Colleen Marsh
    (25, 1, 1, 1, '2024-02-10', 5, NULL, 0, 0, 0, 1),   -- Priscilla Colston
    (26, 1, 1, 1, '2024-02-10', 5, NULL, 0, 0, 0, 1),   -- Marco Colston
    (27, 1, 3, 1, '2023-10-14', 5, 3,    1, 0, 0, 1),   -- Tanya Reyes (teen)
    (28, 1, 1, 1, '2022-01-05', 6, NULL, 1, 0, 0, 1),   -- Louise Trent
    (29, 1, 1, 1, '2024-06-25', 2, NULL, 1, 0, 0, 1),   -- Hana Nakamura
    (30, 1, 1, 2, '2023-01-08', 5, NULL, 1, 1, 0, 2),   -- Ray Delacroix (suicide loss)
    (31, 4, 1, 1, '2020-01-15', 2, NULL, 1, 0, 0, 1),   -- Chelsea Whitmore (Closed - Complete)
    (32, 1, 1, 1, '2024-07-01', 6, NULL, 1, 0, 0, 1),   -- Omar Siddiqui
    (33, 2, 1, 1, '2021-05-11', 1, NULL, 0, 0, 0, 1),   -- Patrick Doyle (Inactive)
    (34, 1, 1, 2, '2024-03-19', 2, NULL, 1, 0, 0, 2),   -- Sonia Grewal
    (35, 1, 2, 1, '2024-05-02', 5, 3,    1, 0, 0, 1),   -- Tyler Combs (child)
    (36, 1, 1, 2, '2024-08-14', 6, NULL, 1, 0, 0, 2),   -- Wendy Falk
    (37, 1, 1, 1, '2024-09-05', 6, NULL, 1, 0, 0, 1),   -- Craig Bell
    (38, 7, 1, 1, '2019-10-15', 2, NULL, 0, 0, 0, 1);   -- Diane Whitmore-Ellis (Deceased)
GO

-- =============================================================================
-- SECTION 8: ENCOUNTERS
-- Intake-type encounters for a representative subset of clients and
-- volunteers, driving the referral-source analytics in Script 11.
-- =============================================================================

INSERT INTO Encounter
    (ContactID, EncounterTypeID, StaffID, ClientTypeID, ReferralTypeID, ReferralSourceID,
     SeekingServicesForID, IsLightweight, EncounterDate, EncounterNotes, CreatedByStaffID)
VALUES
    (19, 1, 1, 1, 1, 4, 1, 0, '2023-08-20', 'Initial intake call following spouse loss; hospice referred.', 1),
    (20, 1, 1, 1, 5, 12, 5, 0, '2024-02-05', 'Father called on behalf of self and daughter after son''s accident.', 1),
    (21, 1, 1, 2, 2, 12, 2, 0, '2024-02-05', 'Intake covers Ji-woo specifically; sibling loss.', 1),
    (22, 1, 1, 1, 1, 8, 1, 0, '2020-08-01', 'Referred by funeral home after spouse''s passing.', 1),
    (23, 1, 1, 1, 1, 1, 1, 0, '2023-04-02', 'Referred by victim services agency after homicide loss.', 1),
    (24, 1, 1, 1, 1, 13, 1, 0, '2024-05-20', 'Found the organization through online search.', 1),
    (25, 1, 1, 1, 1, 4, 1, 0, '2024-02-10', 'Extremely sensitive intake - neonatal loss. Use care in all future contact.', 1),
    (27, 1, 1, 3, 3, 6, 3, 0, '2023-10-14', 'School counselor referred after loss of sibling.', 1),
    (28, 1, 1, 1, 1, 11, 1, 0, '2022-01-05', 'Referred by a friend who is a former client.', 1),
    (30, 1, 2, 1, 1, 3, 1, 0, '2023-01-08', 'Referred by therapist following on-duty loss of colleague; suicide.', 2),
    (10, 5, 3, NULL, NULL, 11, NULL, 0, '2022-02-14', 'Initial volunteer inquiry call; interested in BST.', 3),
    (15, 5, 3, NULL, NULL, 13, NULL, 0, '2024-01-08', 'Found volunteer opportunity through website.', 3);
GO

-- =============================================================================
-- SECTION 9: LOSS RECORDS
-- Links clients to Deceased records seeded in Section 3.
-- =============================================================================

INSERT INTO Loss (ClientID, DeceasedID, LossTypeID, LossDate, DeceasedRelationship, CreatedByStaffID) VALUES
    (1,  1, 1,  '2023-08-14', 'Husband',  1),   -- Angela Alvarez / Thomas Alvarez, spouse loss
    (2,  3, 6,  '2024-01-30', 'Son',      1),   -- Ben Park / Ethan Park, bereaved parent
    (3,  3, 4,  '2024-01-30', 'Brother',  1),   -- Ji-woo Park / Ethan Park, sibling loss
    (4,  5, 1,  '2020-07-07', 'Husband',  1),   -- Farah Odom / Walter Odom, spouse loss
    (5,  6, 9,  '2023-03-25', 'Brother',  1),   -- Nathan Iverson / Samuel Iverson, homicide loss
    (6,  7, 1,  '2024-05-11', 'Wife',     1),   -- Colleen Marsh / Bethany Marsh, spouse loss
    (7,  8, 6,  '2024-02-02', 'Daughter', 1),   -- Priscilla Colston / Infant Colston, bereaved parent
    (8,  8, 6,  '2024-02-02', 'Daughter', 1),   -- Marco Colston / Infant Colston, bereaved parent
    (9,  4, 4,  '2022-11-19', 'Sister',   1),   -- Tanya Reyes / Grace Odom, sibling loss
    (10, 10, 1, '2021-12-24', 'Husband',  1),   -- Louise Trent / Louis Trent, spouse loss
    (11, 11, 6, '2024-06-18', 'Daughter', 1),   -- Hana Nakamura / Patricia Nakamura, bereaved parent
    (12, 12, 8, '2023-01-05', 'Colleague',1),   -- Ray Delacroix / Owen Delacroix, suicide loss
    (13, 14, 2, '2019-10-08', 'Mother',   1),   -- Chelsea Whitmore / Diane Whitmore, parent loss (mother)
    (14, 9,  10,'2023-09-30', 'Dog',      1);   -- Omar Siddiqui / Biscuit, pet loss
GO
    
-- =============================================================================
-- SECTION 10: CLIENT GROUP ENROLLMENT
-- =============================================================================

INSERT INTO ClientGroup
    (GroupID, ClientID, EnrollmentStatusID, EnrollmentDate, WaitlistDate, CompletionDate, ProgramCompleted) VALUES
    (1, 1,  2, '2023-09-05', NULL, NULL, 0),   -- Angela Alvarez - Spouse Loss group, Enrolled
    (1, 6,  2, '2024-06-01', NULL, NULL, 0),   -- Colleen Marsh - Enrolled
    (1, 10, 3, '2022-01-15', NULL, '2022-12-20', 1),  -- Louise Trent - Completed
    (1, 12, 2, '2023-02-01', NULL, NULL, 0),   -- Ray Delacroix - Enrolled
    (2, 2,  2, '2024-02-20', NULL, NULL, 0),   -- Ben Park - Child Loss group, Enrolled
    (2, 4,  1, NULL, '2024-06-15', NULL, 0),   -- Farah Odom - Waitlist
    (2, 11, 2, '2024-07-10', NULL, NULL, 0),   -- Hana Nakamura - Enrolled
    (3, 5,  2, '2023-04-15', NULL, NULL, 0),   -- Nathan Iverson - General Grief group, Enrolled
    (3, 14, 2, '2024-07-15', NULL, NULL, 0),   -- Omar Siddiqui - Enrolled
    (3, 13, 3, '2020-02-01', NULL, '2020-11-30', 1),  -- Chelsea Whitmore - Completed
    (3, 16, 2, '2024-08-20', NULL, NULL, 0),   -- Wendy Falk - Enrolled
    (4, 9,  2, '2024-04-08', NULL, NULL, 0),   -- Tanya Reyes - Teen Grief group, Enrolled
    (4, 17, 2, '2024-05-10', NULL, NULL, 0),   -- Tyler Combs - Enrolled
    (4, 3,  1, NULL, '2024-08-01', NULL, 0);   -- Ji-woo Park - Waitlist
GO

-- =============================================================================
-- SECTION 11: MEETINGS AND ATTENDANCE
-- Three sessions per group; attendance recorded for each enrolled client.
-- =============================================================================

INSERT INTO Meeting (GroupID, FacilitatorID, CoFacilitatorID, SubstituteFacilitator, SubstituteCoFacilitator, MeetingDate) VALUES
    (1, 7, 1, 0, 0, '2024-09-03'),
    (1, 7, 1, 0, 0, '2024-09-10'),
    (1, 1, 7, 1, 0, '2024-09-17'),   -- Facilitator 1 and Facilitator 7 swapped seats this session (substitute lead)
    (2, 2, 3, 0, 0, '2024-09-04'),
    (2, 2, 3, 0, 0, '2024-09-11'),
    (2, 2, 3, 0, 0, '2024-09-18'),
    (3, 4, 5, 0, 0, '2024-09-05'),
    (3, 4, 5, 0, 0, '2024-09-12'),
    (3, 4, 6, 0, 1, '2024-09-19'),   -- Facilitator 6 (in-training) covered co-facilitator seat
    (4, 5, 6, 0, 0, '2024-09-09'),
    (4, 5, 6, 0, 0, '2024-09-16'),
    (4, 5, 6, 0, 0, '2024-09-23');
GO

INSERT INTO GroupAttendance (MeetingID, ClientID, AttendanceStatusID, AttendanceDate) VALUES
    -- Group 1 (Meetings 1-3): Angela(1), Colleen(6), Louise(10) completed before Sept - only Angela/Colleen/Ray current
    (1, 1, 1, '2024-09-03'), (1, 6, 1, '2024-09-03'), (1, 12, 2, '2024-09-03'),
    (2, 1, 1, '2024-09-10'), (2, 6, 3, '2024-09-10'), (2, 12, 1, '2024-09-10'),
    (3, 1, 1, '2024-09-17'), (3, 6, 1, '2024-09-17'), (3, 12, 1, '2024-09-17'),
    -- Group 2 (Meetings 4-6): Ben(2), Hana(11)
    (4, 2, 1, '2024-09-04'), (4, 11, 1, '2024-09-04'),
    (5, 2, 1, '2024-09-11'), (5, 11, 2, '2024-09-11'),
    (6, 2, 1, '2024-09-18'), (6, 11, 1, '2024-09-18'),
    -- Group 3 (Meetings 7-9): Nathan(5), Omar(14), Wendy(16)
    (7, 5, 1, '2024-09-05'), (7, 14, 1, '2024-09-05'), (7, 16, 1, '2024-09-05'),
    (8, 5, 1, '2024-09-12'), (8, 14, 3, '2024-09-12'), (8, 16, 1, '2024-09-12'),
    (9, 5, 1, '2024-09-19'), (9, 14, 1, '2024-09-19'), (9, 16, 2, '2024-09-19'),
    -- Group 4 (Meetings 10-12): Tanya(9), Tyler(17)
    (10, 9, 1, '2024-09-09'), (10, 17, 1, '2024-09-09'),
    (11, 9, 1, '2024-09-16'), (11, 17, 1, '2024-09-16'),
    (12, 9, 2, '2024-09-23'), (12, 17, 1, '2024-09-23');
GO

-- =============================================================================
-- SECTION 12: DONORS (ContactID 39-50)
-- Mix of individual, corporate, and foundation donors. Corporate/Foundation
-- donors use OrganizationName and ProfileTypeID = 3.
-- =============================================================================

INSERT INTO ContactInformation
    (ProfileStatusID, ProfileTypeID, OrganizationName, FirstName, LastName, Phone, Email,
     AddressLine1, CityID, StateID, Zip, CountryID, CreatedDate, CreatedByStaffID)
VALUES
    (1, 1, NULL, 'Ellen',   'Marsh',      '541-555-2001', 'emarsh.donor@example.com',   '77 Beach St',       1, 37, '97520', 1, '2021-03-01', 1),
    (1, 1, NULL, 'Frank',   'Nguyen',     '541-555-2002', 'fnguyen.donor@example.com',  '900 Siskiyou Blvd', 1, 37, '97520', 1, '2021-03-01', 1),
    (1, 1, NULL, 'Grace',   'Papadakis',  '541-555-2003', 'gpapadakis@example.com',     '22 Vista St',       1, 37, '97520', 1, '2022-01-15', 1),
    (1, 1, NULL, 'Harold',  'Bishop',     NULL, NULL,      '55 Granite St',              1, 37, '97520', 1, '2021-02-01', 1),
    (1, 1, NULL, 'Linda',   'Cho',        NULL, NULL,      '19 Wimer St',                1, 37, '97520', 1, '2021-02-01', 1),
    (1, 1, NULL, 'Miriam',  'Solberg',    '541-555-2006', 'msolberg@example.com',       '410 Oak Knoll Dr',  1, 37, '97520', 1, '2023-04-10', 1),
    (1, 3, 'Rogue Valley Community Foundation', NULL, NULL, '541-555-2100', 'grants@rvcf.example.org', '100 E Main St', 2, 37, '97501', 1, '2021-06-01', 1),
    (1, 3, 'Ashland Rotary Club',               NULL, NULL, '541-555-2101', 'giving@ashlandrotary.example.org', '5 Winburn Way', 1, 37, '97520', 1, '2022-02-01', 1),
    (1, 3, 'Siskiyou Outdoor Supply Co.',       NULL, NULL, '541-555-2102', 'community@siskiyousupply.example.com', '212 4th St', 1, 37, '97520', 1, '2023-09-01', 1),
    (1, 1, NULL, 'Peter',   'Guzman',     '541-555-2007', 'pguzman@example.com',        '33 Scenic Dr',      1, 37, '97520', 1, '2024-01-20', 1),
    (1, 3, 'Benevity Community Impact Fund',    NULL, NULL, NULL, 'noreply@benevity.example.com', NULL, NULL, 53, NULL, 2, '2022-08-01', 1),
    (2, 1, NULL, 'Ruth',    'Callahan',   '541-555-2008', 'rcallahan@example.com',      '88 Fork St',        1, 37, '97520', 1, '2019-05-01', 1);
GO

INSERT INTO DonorInformation
    (ContactID, DonorStatusID, DonorTypeID, DonorContactStaffID, AssignedBoardMemberID, DonorContactDate, IsProspect)
VALUES
    (39, 2, 1, 4, NULL, '2021-03-01', 0),   -- Ellen Marsh
    (40, 2, 1, 4, 1,    '2021-03-01', 0),   -- Frank Nguyen, stewarded by Board Chair
    (41, 2, 1, 4, NULL, '2022-01-15', 0),   -- Grace Papadakis
    (42, 2, 1, 4, NULL, '2021-02-01', 0),   -- Harold Bishop (also Board Chair - donors and board members can overlap)
    (43, 2, 1, 4, NULL, '2021-02-01', 0),   -- Linda Cho (also Board Treasurer)
    (44, 2, 1, 4, 2,    '2023-04-10', 0),   -- Miriam Solberg, VIP-level, stewarded by Treasurer
    (45, 2, 4, 4, NULL, '2021-06-01', 0),   -- Rogue Valley Community Foundation
    (46, 2, 6, 4, NULL, '2022-02-01', 0),   -- Ashland Rotary Club
    (47, 2, 2, 4, NULL, '2023-09-01', 0),   -- Siskiyou Outdoor Supply Co.
    (48, 1, 1, 4, NULL, '2024-01-20', 1),   -- Peter Guzman - Prospect, no gift yet
    (49, 2, 5, 4, NULL, '2022-08-01', 0),   -- Benevity Community Impact Fund
    (50, 3, 1, 4, NULL, '2019-05-01', 0);   -- Ruth Callahan - Lapsed
GO

-- =============================================================================
-- SECTION 12b: DONOR STEWARDSHIP ENCOUNTERS
-- Deferred from Section 8 - these reference ContactIDs 39/44 which don't
-- exist until Section 12 (Donors) has run.
-- =============================================================================

INSERT INTO Encounter
    (ContactID, EncounterTypeID, StaffID, ClientTypeID, ReferralTypeID, ReferralSourceID,
     SeekingServicesForID, IsLightweight, EncounterDate, EncounterNotes, CreatedByStaffID)
VALUES
    (39, 10, 4, NULL, NULL, NULL, NULL, 1, '2023-11-01', 'Brief stewardship check-in call.', 4),
    (44, 10, 4, NULL, NULL, NULL, NULL, 1, '2024-06-10', 'Thank-you call following major gift.', 4);
GO

-- =============================================================================
-- SECTION 13: PAYMENTS AND PAYMENT ALLOCATIONS
-- A mix of donations (general, campaign-designated, scholarship-designated)
-- and program fees (group fee, BST fee with and without scholarship).
-- =============================================================================

INSERT INTO Payment
    (ContactID, PaymentMethodTypeID, PaymentDate, TotalAmount, CheckNumber, ReceivedByStaffID,
     AcknowledgementSent, AcknowledgementDate, CreatedByStaffID)
VALUES
    (39, 2, '2024-11-15', 250.00,  '1042', 5, 1, '2024-11-20', 5),   -- Ellen Marsh - Year End Appeal
    (40, 2, '2024-12-01', 15000.00,'2210', 5, 1, '2024-12-05', 5),   -- Frank Nguyen - VIP gift
    (41, 3, '2024-06-10', 500.00,  NULL,   5, 1, '2024-06-11', 5),   -- Grace Papadakis - Major donor, credit card
    (44, 6, '2024-03-01', 25000.00,NULL,   1, 1, '2024-03-10', 1),   -- Miriam Solberg - Planned gift, VIP
    (45, 2, '2024-01-15', 5000.00, '90211',5, 1, '2024-01-22', 5),   -- RVCF grant, designated to BST Scholarship
    (46, 2, '2024-05-01', 1200.00, '551',  5, 1, '2024-05-05', 5),   -- Ashland Rotary - designated to In Lieu Of Flowers... actually general
    (47, 2, '2023-11-20', 800.00,  '77',   5, 1, '2023-11-28', 5),   -- Siskiyou Outdoor Supply - Giving Tuesday
    (49, 4, '2024-02-01', 150.00,  NULL,   5, 1, '2024-02-03', 5),   -- Benevity - general donation
    (1,  2, '2024-09-01', 40.00,   '1188', 5, 0, NULL, 5),           -- Angela Alvarez - Group Fee
    (2,  1, '2024-02-20', 40.00,   NULL,   3, 0, NULL, 3),           -- Ben Park - Group Fee, cash
    (10, 2, '2022-04-20', 150.00,  '640',  3, 1, '2022-04-25', 3),   -- Karen Sussman - full BST Fee
    (15, 2, '2024-02-05', 75.00,   '812',  3, 1, '2024-02-08', 3),   -- Renee Okafor - scholarship-reduced BST Fee
    (39, 2, '2024-06-01', 100.00,  '1055', 5, 1, '2024-06-03', 5);   -- Ellen Marsh - second gift, designated to ILOF campaign
GO

INSERT INTO PaymentAllocation
    (PaymentID, AllocationTypeID, FeeID, CampaignID, Amount, IsTaxDeductible, IsScholarship, ScholarshipAmount, DonorID, FeeDescription)
VALUES
    (1,  1, NULL, NULL, 250.00,   1, 0, NULL, 1,  'Year End Appeal general donation'),
    (2,  1, NULL, NULL, 15000.00, 1, 0, NULL, 2,  'VIP-level unrestricted gift'),
    (3,  1, NULL, NULL, 500.00,   1, 0, NULL, 3,  'Major donor gift'),
    (4,  1, NULL, NULL, 25000.00, 1, 0, NULL, 6,  'Planned gift / bequest installment'),
    (5,  3, NULL, NULL, 5000.00,  1, 0, NULL, 7,  'Grant designated to BST Scholarship Fund'),
    (6,  1, NULL, NULL, 1200.00,  1, 0, NULL, 8,  'Service club annual gift'),
    (7,  1, NULL, NULL, 800.00,   1, 0, NULL, 9,  'Giving Tuesday campaign gift'),
    (8,  1, NULL, NULL, 150.00,   1, 0, NULL, 11, 'Benevity-matched employee gift'),
    (9,  4, 1,    NULL, 40.00,    0, 0, NULL, NULL, 'Peer Support Group session fee - Angela Alvarez'),
    (10, 4, 1,    NULL, 40.00,    0, 0, NULL, NULL, 'Peer Support Group session fee - Ben Park'),
    (11, 5, 2,    NULL, 150.00,   0, 0, NULL, NULL, 'BST full fee - Karen Sussman'),
    (12, 5, 2,    NULL, 75.00,    0, 1, 75.00, NULL, 'BST scholarship-reduced fee - Renee Okafor'),
    (13, 2, NULL, NULL, 100.00,   1, 0, NULL, 1,    'In Lieu Of Flowers campaign gift');
GO

-- Point PaymentAllocation #5 and #12's scholarship designation at the fund
-- (CampaignID for #5 designates the fund's originating campaign; here we
-- also tag the ScholarshipFund directly since it is a fund-designated gift).
UPDATE PaymentAllocation SET CampaignID = 2, ScholarshipFundID = 1 WHERE AllocationID = 5;
UPDATE PaymentAllocation SET CampaignID = 1 WHERE AllocationID = 13;
GO

-- =============================================================================
-- SECTION 14: MAILING PREFERENCES
-- =============================================================================

INSERT INTO MailingPreference (ContactID, MailingTypeID, OptedIn, OptedInDate, OptedInReason, SetByStaffID) VALUES
    (39, 1, 1, '2021-03-01', 'Opted in at first gift.', 5),
    (39, 4, 1, '2021-03-01', 'Major-adjacent donor; holiday card preference default.', 5),
    (40, 1, 1, '2021-03-01', 'Opted in at first gift.', 5),
    (40, 4, 1, '2024-12-05', 'VIP threshold met - holiday card triggered per business rule.', 5),
    (44, 4, 1, '2024-03-10', 'VIP threshold met - holiday card triggered per business rule.', 5),
    (44, 2, 1, '2024-03-10', 'Annual report requested by donor directly.', 5),
    (1,  1, 1, '2023-08-20', 'Opted in at intake.', 1),
    (10, 1, 1, '2022-02-14', 'Opted in as volunteer.', 3),
    (10, 5, 1, '2022-02-14', 'Wants event invitations as an active facilitator.', 3);
GO

-- =============================================================================
-- SECTION 15: SCHOLARSHIP AWARDS
-- =============================================================================

INSERT INTO ScholarshipAward (ScholarshipFundID, ContactID, FeeID, AwardAmount, AwardDate, ApprovedByStaffID, Notes) VALUES
    (1, 15, 2, 75.00, '2024-02-05', 3, 'Awarded to Renee Okafor for BST Fee balance not covered by reduced-fee payment.');
GO

-- =============================================================================
-- SECTION 16: OUTREACH EVENTS AND ATTENDANCE
-- =============================================================================

INSERT INTO OutreachEvent (EventTypeID, EventName, EventDescription, EventDate, Location, OrganizedByStaffID, AttendeeCount) VALUES
    (1, 'Coping with Grief During the Holidays', 'Community presentation on healthy grief coping strategies during the holiday season.', '2024-12-05', 'Ashland Public Library', 3, 42),
    (3, 'Ashland High School Grief Awareness Assembly', 'School presentation introducing grief support resources to students and staff.', '2024-10-18', 'Ashland High School', 3, 210),
    (7, 'Volunteer Facilitator Info Session', 'Recruitment event for prospective BST trainees.', '2024-01-20', 'Organization Office', 3, 18),
    (4, 'Annual Remembrance Gathering', 'Memorial event honoring those who have died, open to the community.', '2024-09-21', 'Lithia Park', 1, 85);
GO

INSERT INTO OutreachEventAttendance (EventID, ContactID, AttendanceDate) VALUES
    (3, 15, '2024-01-20'),
    (3, 18, '2024-01-20'),
    (4, 1,  '2024-09-21'),
    (4, 48, '2024-09-21');   -- Peter Guzman attended
GO

-- =============================================================================
-- SECTION 17: NOTES
-- =============================================================================

INSERT INTO Note (ContactID, StaffID, NoteTypeID, NoteDate, NoteContent) VALUES
    (1,  1, 2, '2023-08-22', 'Client is processing early grief; connected with Spouse & Partner Loss group starting September cohort.'),
    (7,  1, 9, '2024-02-11', 'Sensitive case - neonatal loss. Family has requested no mailings referencing children''s programs. Flagged in system.'),
    (10, 3, 4, '2022-08-16', 'Approved as Co-Facilitator for Spouse & Partner Loss group following successful vetting interview.'),
    (30, 2, 8, '2023-01-10', 'Follow-up required: client missed second scheduled intake call, reschedule needed.'),
    (44, 1, 6, '2024-03-11', 'Planned gift documentation filed with Development Coordinator; board notified at March meeting.');
GO

-- =============================================================================
-- SECTION 18: OUTCOMES
-- =============================================================================

INSERT INTO Outcome (ClientID, OutcomeTypeID, OutcomeDate, OutcomeDescription) VALUES
    (13, 3, '2020-02-01', 'Referred and enrolled into General Grief Support group; completed program successfully in Nov 2020.'),
    (10, 3, '2022-01-15', 'Referred and enrolled into Spouse & Partner Loss group; completed program successfully.'),
    (7,  1, '2024-02-12', 'Provided one-on-one referral to a specialized perinatal loss counselor given the sensitivity of the case.'),
    (15, 6, '2021-05-15', 'Client needs exceeded scope of services; referred to an outside counseling agency.');
GO

-- =============================================================================
-- END OF SEED DATA
-- Sanity-check row counts across every table populated by this script.
-- =============================================================================

SELECT 'ContactInformation' AS TableName, COUNT(*) AS RecordCount FROM ContactInformation
UNION ALL SELECT 'Staff', COUNT(*) FROM Staff
UNION ALL SELECT 'BoardMember', COUNT(*) FROM BoardMember
UNION ALL SELECT 'VolunteerInformation', COUNT(*) FROM VolunteerInformation
UNION ALL SELECT 'ClientInformation', COUNT(*) FROM ClientInformation
UNION ALL SELECT 'DonorInformation', COUNT(*) FROM DonorInformation
UNION ALL SELECT 'Deceased', COUNT(*) FROM Deceased
UNION ALL SELECT 'Loss', COUNT(*) FROM Loss
UNION ALL SELECT 'Facilitator', COUNT(*) FROM Facilitator
UNION ALL SELECT 'FacilitatorGroupTypeQualification', COUNT(*) FROM FacilitatorGroupTypeQualification
UNION ALL SELECT 'FacilitatorAvailability', COUNT(*) FROM FacilitatorAvailability
UNION ALL SELECT 'PeerSupportGroup', COUNT(*) FROM PeerSupportGroup
UNION ALL SELECT 'ClientGroup', COUNT(*) FROM ClientGroup
UNION ALL SELECT 'Meeting', COUNT(*) FROM Meeting
UNION ALL SELECT 'GroupAttendance', COUNT(*) FROM GroupAttendance
UNION ALL SELECT 'Encounter', COUNT(*) FROM Encounter
UNION ALL SELECT 'Note', COUNT(*) FROM Note
UNION ALL SELECT 'Outcome', COUNT(*) FROM Outcome
UNION ALL SELECT 'Payment', COUNT(*) FROM Payment
UNION ALL SELECT 'PaymentAllocation', COUNT(*) FROM PaymentAllocation
UNION ALL SELECT 'MailingPreference', COUNT(*) FROM MailingPreference
UNION ALL SELECT 'ScholarshipAward', COUNT(*) FROM ScholarshipAward
UNION ALL SELECT 'OutreachEvent', COUNT(*) FROM OutreachEvent
UNION ALL SELECT 'OutreachEventAttendance', COUNT(*) FROM OutreachEventAttendance;
GO
