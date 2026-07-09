-- =============================================================================
-- GriefSupportDB
-- Script 03: Role Tables
-- Description: One table per role. Each links back to ContactInformation via
--              ContactID. A person can hold multiple roles simultaneously and
--              roles are date-ranged to preserve history.
--              Roles: Staff, BoardMember, VolunteerInformation,
--                     ClientInformation, DonorInformation
-- Author:      Steve Del Valle
-- Dependencies: 01_LookupTables.sql, 02_CoreProfile.sql
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- SECTION 1: STAFF
-- Paid employees of the organization. StartDate and EndDate allow a person
-- to leave and return in a new capacity without losing history.
-- JobTitle is free text to allow flexibility as roles evolve.
-- =============================================================================

CREATE TABLE Staff (
    StaffID     INT             NOT NULL IDENTITY(1,1),
    ContactID   INT             NOT NULL,
    JobTitle    NVARCHAR(150)   NULL,
    StartDate   DATE            NULL,
    EndDate     DATE            NULL,   -- NULL = currently active

    CONSTRAINT PK_Staff PRIMARY KEY (StaffID),

    CONSTRAINT FK_Staff_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID),

    -- End date must be after start date if both are present
    CONSTRAINT CK_Staff_DateRange
        CHECK (EndDate IS NULL OR StartDate IS NULL OR EndDate >= StartDate)
);
GO

CREATE NONCLUSTERED INDEX IX_Staff_ContactID
    ON Staff (ContactID);
GO

-- Now that Staff exists, add the FK references back to ContactInformation
-- for audit trail and initial contact staff fields

ALTER TABLE ContactInformation
    ADD CONSTRAINT FK_ContactInformation_InitialContactStaff
        FOREIGN KEY (InitialContactStaffID) REFERENCES Staff(StaffID);
GO

ALTER TABLE ContactInformation
    ADD CONSTRAINT FK_ContactInformation_CreatedByStaff
        FOREIGN KEY (CreatedByStaffID) REFERENCES Staff(StaffID);
GO

ALTER TABLE ContactInformation
    ADD CONSTRAINT FK_ContactInformation_ModifiedByStaff
        FOREIGN KEY (ModifiedByStaffID) REFERENCES Staff(StaffID);
GO

-- Add FK on OrgConfiguration now that Staff exists
ALTER TABLE OrgConfiguration
    ADD CONSTRAINT FK_OrgConfiguration_LastUpdatedByStaff
        FOREIGN KEY (LastUpdatedByStaffID) REFERENCES Staff(StaffID);
GO

-- =============================================================================
-- SECTION 2: BOARD MEMBER
-- Governing board members. BoardRoleID captures their seat (Chair, Treasurer,
-- etc.). A person can serve multiple terms recorded as separate rows.
-- =============================================================================

CREATE TABLE BoardMember (
    MemberID    INT     NOT NULL IDENTITY(1,1),
    ContactID   INT     NOT NULL,
    BoardRoleID INT     NOT NULL,
    StartDate   DATE    NULL,
    EndDate     DATE    NULL,   -- NULL = currently serving

    CONSTRAINT PK_BoardMember PRIMARY KEY (MemberID),

    CONSTRAINT FK_BoardMember_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID),

    CONSTRAINT FK_BoardMember_BoardRole
        FOREIGN KEY (BoardRoleID) REFERENCES BoardRole(RoleID),

    CONSTRAINT CK_BoardMember_DateRange
        CHECK (EndDate IS NULL OR StartDate IS NULL OR EndDate >= StartDate)
);
GO

CREATE NONCLUSTERED INDEX IX_BoardMember_ContactID
    ON BoardMember (ContactID);
GO

-- =============================================================================
-- SECTION 3: VOLUNTEER INFORMATION
-- Volunteers who support the organization. The credentialing pipeline is
-- tracked here at the general volunteer level. Facilitator-specific
-- credentialing is handled in the Facilitator and
-- FacilitatorGroupTypeQualification tables.
--
-- Pipeline order:
--   1. InterestedInTraining flag set by staff
--   2. BSTRegistrationDate - registered for Bereavement Skills Training
--   3. BSTCompletedDate    - completed BST
--   4. BackgroundCheckReleaseForm - form submitted
--   5. BackgroundCheckSubmitted   - submitted to screening agency
--   6. BackgroundCheckReport      - report reference number received
--   7. PersonalInterviewCompleted - interview done by staff
--   8. VolunteerStatus moves to 'Active'
-- =============================================================================

CREATE TABLE VolunteerInformation (
    VolunteerID                 INT             NOT NULL IDENTITY(1,1),
    ContactID                   INT             NOT NULL,
    VolunteerStatusID           INT             NOT NULL,
    VolunteerContactStaffID     INT             NULL,
    VolunteerContactDate        DATE            NULL,
    StartDate                   DATE            NULL,
    EndDate                     DATE            NULL,   -- NULL = currently active
    InterestedInTraining        BIT             NOT NULL CONSTRAINT DF_Volunteer_InterestedInTraining DEFAULT 0,
    BSTRegistrationDate         DATE            NULL,
    BSTCompletedDate            DATE            NULL,
    BackgroundCheckReleaseForm  BIT             NOT NULL CONSTRAINT DF_Volunteer_BGCheckForm DEFAULT 0,
    BackgroundCheckSubmitted    DATE            NULL,
    BackgroundCheckReport       NVARCHAR(255)   NULL,   -- Reference number from screening agency
    PersonalInterviewCompleted  BIT             NOT NULL CONSTRAINT DF_Volunteer_Interview DEFAULT 0,

    -- Audit fields
    CreatedDate                 DATE            NOT NULL CONSTRAINT DF_VolunteerInformation_CreatedDate DEFAULT GETDATE(),
    CreatedByStaffID            INT             NULL,
    ModifiedDate                DATE            NULL,
    ModifiedByStaffID           INT             NULL,

    CONSTRAINT PK_VolunteerInformation PRIMARY KEY (VolunteerID),

    CONSTRAINT FK_VolunteerInformation_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID),

    CONSTRAINT FK_VolunteerInformation_VolunteerStatus
        FOREIGN KEY (VolunteerStatusID) REFERENCES VolunteerStatus(StatusID),

    CONSTRAINT FK_VolunteerInformation_ContactStaff
        FOREIGN KEY (VolunteerContactStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT FK_VolunteerInformation_CreatedByStaff
        FOREIGN KEY (CreatedByStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT FK_VolunteerInformation_ModifiedByStaff
        FOREIGN KEY (ModifiedByStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT CK_VolunteerInformation_DateRange
        CHECK (EndDate IS NULL OR StartDate IS NULL OR EndDate >= StartDate)
);
GO

CREATE NONCLUSTERED INDEX IX_VolunteerInformation_ContactID
    ON VolunteerInformation (ContactID);
GO

-- -----------------------------------------------------------------------------
-- Volunteer Skills Bridge Tables
-- Many-to-many: one volunteer can have many skills; one skill can belong to
-- many volunteers.
-- -----------------------------------------------------------------------------

CREATE TABLE VolunteerSupportSkill (
    ID          INT     NOT NULL IDENTITY(1,1),
    VolunteerID INT     NOT NULL,
    SkillID     INT     NOT NULL,

    CONSTRAINT PK_VolunteerSupportSkill PRIMARY KEY (ID),

    CONSTRAINT FK_VolunteerSupportSkill_Volunteer
        FOREIGN KEY (VolunteerID) REFERENCES VolunteerInformation(VolunteerID),

    CONSTRAINT FK_VolunteerSupportSkill_Skill
        FOREIGN KEY (SkillID) REFERENCES SupportSkill(SkillID),

    -- A volunteer cannot have the same support skill listed twice
    CONSTRAINT UQ_VolunteerSupportSkill
        UNIQUE (VolunteerID, SkillID)
);
GO

CREATE TABLE VolunteerFacilitationSkill (
    ID          INT     NOT NULL IDENTITY(1,1),
    VolunteerID INT     NOT NULL,
    SkillID     INT     NOT NULL,

    CONSTRAINT PK_VolunteerFacilitationSkill PRIMARY KEY (ID),

    CONSTRAINT FK_VolunteerFacilitationSkill_Volunteer
        FOREIGN KEY (VolunteerID) REFERENCES VolunteerInformation(VolunteerID),

    CONSTRAINT FK_VolunteerFacilitationSkill_Skill
        FOREIGN KEY (SkillID) REFERENCES FacilitationSkill(SkillID),

    CONSTRAINT UQ_VolunteerFacilitationSkill
        UNIQUE (VolunteerID, SkillID)
);
GO

-- =============================================================================
-- SECTION 4: CLIENT INFORMATION
-- People who have contacted the organization seeking support services.
-- ClientTypeID here is the PRIMARY type established at intake.
-- Additional types per encounter are tracked in Encounter.ClientTypeID.
-- Type changes over time are tracked in ClientTypeHistory.
--
-- InviteToGroups defaults to 1 (YES) per business rule:
--   A client is assumed group-ready until staff explicitly sets this to 0.
--   N/A is not a valid value - this is a YES/NO decision only.
-- =============================================================================

CREATE TABLE ClientInformation (
    ClientID                INT     NOT NULL IDENTITY(1,1),
    ContactID               INT     NOT NULL,
    ClientStatusID          INT     NOT NULL,
    ClientTypeID            INT     NOT NULL,   -- Primary type set at intake
    ClientContactStaffID    INT     NULL,
    ClientContactDate       DATE    NULL,
    InsuranceID             INT     NULL,
    MinorsSuitableForID     INT     NULL,       -- Populated only when client is a minor

    -- InviteToGroups: DEFAULT 1 = Yes, group-ready
    -- Staff sets to 0 only when client is assessed as not suitable for groups
    InviteToGroups          BIT     NOT NULL CONSTRAINT DF_ClientInformation_InviteToGroups DEFAULT 1,

    -- Quick-reference flags derived from Loss records
    -- These are denormalized for reporting speed; Loss table holds full detail
    ExperiencedSuicideLoss  BIT     NOT NULL CONSTRAINT DF_ClientInformation_SuicideLoss DEFAULT 0,
    ExperiencedHomicideLoss BIT     NOT NULL CONSTRAINT DF_ClientInformation_HomicideLoss DEFAULT 0,

    -- Audit fields
    CreatedDate             DATE    NOT NULL CONSTRAINT DF_ClientInformation_CreatedDate DEFAULT GETDATE(),
    CreatedByStaffID        INT     NULL,
    ModifiedDate            DATE    NULL,
    ModifiedByStaffID       INT     NULL,

    CONSTRAINT PK_ClientInformation PRIMARY KEY (ClientID),

    CONSTRAINT FK_ClientInformation_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID),

    CONSTRAINT FK_ClientInformation_ClientStatus
        FOREIGN KEY (ClientStatusID) REFERENCES ClientStatus(StatusID),

    CONSTRAINT FK_ClientInformation_ClientType
        FOREIGN KEY (ClientTypeID) REFERENCES ClientType(TypeID),

    CONSTRAINT FK_ClientInformation_ClientContactStaff
        FOREIGN KEY (ClientContactStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT FK_ClientInformation_Insurance
        FOREIGN KEY (InsuranceID) REFERENCES Insurance(InsuranceID),

    CONSTRAINT FK_ClientInformation_MinorsSuitableFor
        FOREIGN KEY (MinorsSuitableForID) REFERENCES MinorsSuitableFor(SuitableForID),

    CONSTRAINT FK_ClientInformation_CreatedByStaff
        FOREIGN KEY (CreatedByStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT FK_ClientInformation_ModifiedByStaff
        FOREIGN KEY (ModifiedByStaffID) REFERENCES Staff(StaffID)
);
GO

CREATE NONCLUSTERED INDEX IX_ClientInformation_ContactID
    ON ClientInformation (ContactID);
GO

CREATE NONCLUSTERED INDEX IX_ClientInformation_ClientStatusID
    ON ClientInformation (ClientStatusID);
GO

-- -----------------------------------------------------------------------------
-- Client Type History
-- Tracks changes to a client's type over time at the client level.
-- Encounter-level type is recorded separately on the Encounter table.
-- -----------------------------------------------------------------------------

CREATE TABLE ClientTypeHistory (
    HistoryID           INT             NOT NULL IDENTITY(1,1),
    ClientID            INT             NOT NULL,
    ClientTypeID        INT             NOT NULL,
    EffectiveDate       DATE            NOT NULL,
    RecordedByStaffID   INT             NULL,
    ChangeReason        NVARCHAR(500)   NULL,

    CONSTRAINT PK_ClientTypeHistory PRIMARY KEY (HistoryID),

    CONSTRAINT FK_ClientTypeHistory_ClientInformation
        FOREIGN KEY (ClientID) REFERENCES ClientInformation(ClientID),

    CONSTRAINT FK_ClientTypeHistory_ClientType
        FOREIGN KEY (ClientTypeID) REFERENCES ClientType(TypeID),

    CONSTRAINT FK_ClientTypeHistory_RecordedByStaff
        FOREIGN KEY (RecordedByStaffID) REFERENCES Staff(StaffID)
);
GO

CREATE NONCLUSTERED INDEX IX_ClientTypeHistory_ClientID
    ON ClientTypeHistory (ClientID);
GO

-- =============================================================================
-- SECTION 5: DONOR INFORMATION
-- People and organizations who have donated or are being cultivated as donors.
-- A Donor Prospect is someone identified as a potential donor before any gift
-- has been received. IsProspect = 1 flags this state.
-- AssignedBoardMemberID: board members are often assigned to steward donors.
-- =============================================================================

CREATE TABLE DonorInformation (
    DonorID                 INT     NOT NULL IDENTITY(1,1),
    ContactID               INT     NOT NULL,
    DonorStatusID           INT     NOT NULL,
    DonorTypeID             INT     NOT NULL,
    DonorContactStaffID     INT     NULL,
    AssignedBoardMemberID   INT     NULL,   -- FK to BoardMember
    DonorContactDate        DATE    NULL,
    IsProspect              BIT     NOT NULL CONSTRAINT DF_DonorInformation_IsProspect DEFAULT 0,

    CONSTRAINT PK_DonorInformation PRIMARY KEY (DonorID),

    CONSTRAINT FK_DonorInformation_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID),

    CONSTRAINT FK_DonorInformation_DonorStatus
        FOREIGN KEY (DonorStatusID) REFERENCES DonorStatus(StatusID),

    CONSTRAINT FK_DonorInformation_DonorType
        FOREIGN KEY (DonorTypeID) REFERENCES DonorType(TypeID),

    CONSTRAINT FK_DonorInformation_DonorContactStaff
        FOREIGN KEY (DonorContactStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT FK_DonorInformation_AssignedBoardMember
        FOREIGN KEY (AssignedBoardMemberID) REFERENCES BoardMember(MemberID)
);
GO

CREATE NONCLUSTERED INDEX IX_DonorInformation_ContactID
    ON DonorInformation (ContactID);
GO

CREATE NONCLUSTERED INDEX IX_DonorInformation_DonorStatusID
    ON DonorInformation (DonorStatusID);
GO
