-- =============================================================================
-- GriefSupportDB
-- Script 05: Facilitator Credentialing Tables
-- Description: The Facilitator credentialing pipeline. A Facilitator is a
--              distinct credentialed capacity that both Staff and Volunteers
--              can earn. The pipeline enforces: BST completion, background
--              check clearance, personal experience verification, interview
--              vetting, and Co-Facilitator experience before a person may
--              lead a group independently.
--              Includes: Facilitator, FacilitatorGroupTypeQualification,
--                        FacilitatorAvailability
-- Version:     v5
-- Author:      Steve Del Valle
-- Dependencies: 01_LookupTables.sql, 02_CoreProfile.sql, 03_RoleTables.sql
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- SECTION 1: FACILITATOR
-- A Facilitator record represents a person who has entered the facilitator
-- credentialing pipeline. Both Staff and Volunteers can be Facilitators,
-- tracked by FacilitatorTypeID.
--
-- Universal credentials (apply to all group types) are stored here:
--   - BST completion
--   - Background check
--   - Initial interview
--   - Qualified date (date approved for any facilitation)
--
-- Group-type-specific credentials are in FacilitatorGroupTypeQualification.
--
-- A Facilitator links directly to ContactInformation, not to
-- VolunteerInformation, because Staff can also facilitate groups and
-- their doing so is their job, not volunteer service.
-- =============================================================================

CREATE TABLE Facilitator (
    FacilitatorID           INT             NOT NULL IDENTITY(1,1),
    ContactID               INT             NOT NULL,
    FacilitatorTypeID       INT             NOT NULL,   -- Staff or Volunteer
    FacilitatorStatusID     INT             NOT NULL,

    -- Universal credential fields - must be complete before any
    -- group-type-specific vetting can begin
    BSTCompletedDate        DATE            NULL,       -- Bereavement Skills Training completion
    BackgroundCheckCleared  BIT             NOT NULL CONSTRAINT DF_Facilitator_BGCheckCleared DEFAULT 0,
    BackgroundCheckDate     DATE            NULL,

    -- Initial interview: conducted by Staff before any group assignment
    InterviewDate           DATE            NULL,
    InterviewedByStaffID    INT             NULL,
    InterviewNotes          NVARCHAR(MAX)   NULL,

    -- QualifiedDate: the date this person was approved for facilitation
    -- in at least one group type. Group-type-specific dates are on
    -- FacilitatorGroupTypeQualification.
    QualifiedDate           DATE            NULL,

    CONSTRAINT PK_Facilitator PRIMARY KEY (FacilitatorID),

    CONSTRAINT FK_Facilitator_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID),

    CONSTRAINT FK_Facilitator_FacilitatorType
        FOREIGN KEY (FacilitatorTypeID) REFERENCES FacilitatorType(TypeID),

    CONSTRAINT FK_Facilitator_FacilitatorStatus
        FOREIGN KEY (FacilitatorStatusID) REFERENCES FacilitatorStatus(StatusID),

    CONSTRAINT FK_Facilitator_InterviewedByStaff
        FOREIGN KEY (InterviewedByStaffID) REFERENCES Staff(StaffID),

    -- A person should only have one active Facilitator record
    CONSTRAINT UQ_Facilitator_ContactID UNIQUE (ContactID)
);
GO

CREATE NONCLUSTERED INDEX IX_Facilitator_ContactID
    ON Facilitator (ContactID);
GO

CREATE NONCLUSTERED INDEX IX_Facilitator_FacilitatorStatusID
    ON Facilitator (FacilitatorStatusID);
GO

-- =============================================================================
-- SECTION 2: FACILITATOR GROUP TYPE QUALIFICATION
-- Records grief-type-specific credentials for each Facilitator.
-- A Facilitator can be qualified for multiple group types, each requiring
-- independent vetting.
--
-- Example: A person who lost a child to suicide may qualify for both
-- the Suicide Loss group and the Child Loss group. Each qualification
-- has its own record with independent PersonalExperienceVerified,
-- vetting notes, and promotion dates.
--
-- Qualification pipeline per group type:
--   1. PersonalExperienceVerified - lived experience with this grief type
--      confirmed (can be auto-suggested from GroupAttendance history)
--   2. VettingDate / VettedByStaffID - interview and discussion completed
--   3. VettingOutcome: Approved, Deferred, or Declined
--   4. QualifiedForCoFacilitator + CoFacilitatorQualifiedDate
--   5. Minimum Co-Facilitator sessions (see OrgConfiguration)
--   6. QualifiedForFacilitator + FacilitatorQualifiedDate
-- =============================================================================

CREATE TABLE FacilitatorGroupTypeQualification (
    QualificationID             INT             NOT NULL IDENTITY(1,1),
    FacilitatorID               INT             NOT NULL,
    GroupTypeID                 INT             NOT NULL,   -- FK to PeerSupportGroupType

    -- Personal experience with this grief type
    -- Can be auto-populated from GroupAttendance history as a suggestion;
    -- staff must confirm or override.
    PersonalExperienceVerified  BIT             NOT NULL CONSTRAINT DF_FGTQ_PersonalExp DEFAULT 0,
    PersonalExperienceNotes     NVARCHAR(MAX)   NULL,

    -- Vetting process for this group type
    VettingDate                 DATE            NULL,
    VettedByStaffID             INT             NULL,
    -- VettingMethod: 'Interview', 'Panel Discussion', or 'Interview and Panel'
    VettingMethod               NVARCHAR(100)   NULL,
    VettingNotes                NVARCHAR(MAX)   NULL,
    -- VettingOutcome: 'Approved', 'Deferred', 'Declined'
    VettingOutcome              NVARCHAR(50)    NULL,
    -- DeferredReason: what needs to change before re-evaluation
    DeferredReason              NVARCHAR(MAX)   NULL,

    -- Co-Facilitator qualification
    QualifiedForCoFacilitator   BIT             NOT NULL CONSTRAINT DF_FGTQ_CoFac DEFAULT 0,
    CoFacilitatorQualifiedDate  DATE            NULL,

    -- Lead Facilitator qualification
    -- Requires minimum Co-Facilitator sessions per OrgConfiguration
    -- ('MinCoFacilitatorSessions') plus staff approval
    QualifiedForFacilitator     BIT             NOT NULL CONSTRAINT DF_FGTQ_Fac DEFAULT 0,
    FacilitatorQualifiedDate    DATE            NULL,
    QualifiedByStaffID          INT             NULL,   -- Staff who approved promotion to lead

    CONSTRAINT PK_FacilitatorGroupTypeQualification PRIMARY KEY (QualificationID),

    CONSTRAINT FK_FGTQ_Facilitator
        FOREIGN KEY (FacilitatorID) REFERENCES Facilitator(FacilitatorID),

    CONSTRAINT FK_FGTQ_PeerSupportGroupType
        FOREIGN KEY (GroupTypeID) REFERENCES PeerSupportGroupType(TypeID),

    CONSTRAINT FK_FGTQ_VettedByStaff
        FOREIGN KEY (VettedByStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT FK_FGTQ_QualifiedByStaff
        FOREIGN KEY (QualifiedByStaffID) REFERENCES Staff(StaffID),

    -- A facilitator can only have one qualification record per group type
    CONSTRAINT UQ_FGTQ_FacilitatorGroupType
        UNIQUE (FacilitatorID, GroupTypeID),

    -- Cannot be qualified as lead Facilitator without first qualifying as Co-Facilitator
    CONSTRAINT CK_FGTQ_CoFacBeforeFac
        CHECK (QualifiedForFacilitator = 0 OR QualifiedForCoFacilitator = 1),

    -- VettingOutcome must be a known value if populated
    CONSTRAINT CK_FGTQ_VettingOutcome
        CHECK (VettingOutcome IS NULL OR
               VettingOutcome IN ('Approved', 'Deferred', 'Declined'))
);
GO

CREATE NONCLUSTERED INDEX IX_FGTQ_FacilitatorID
    ON FacilitatorGroupTypeQualification (FacilitatorID);
GO

CREATE NONCLUSTERED INDEX IX_FGTQ_GroupTypeID
    ON FacilitatorGroupTypeQualification (GroupTypeID);
GO

-- =============================================================================
-- SECTION 3: FACILITATOR AVAILABILITY
-- Records standing and specific-date availability for the substitute pool.
-- Used to find qualified substitutes when a regular Facilitator or
-- Co-Facilitator is unavailable.
--
-- Substitution query logic (implemented as stored procedure):
--   Find Facilitators who:
--     1. Are available on the meeting date (IsAvailable = 1)
--     2. Have BackgroundCheckCleared = 1
--     3. Have a FacilitatorGroupTypeQualification record for the group type
--        with QualifiedForCoFacilitator = 1 or QualifiedForFacilitator = 1
--
-- DayOfWeek records standing weekly availability.
-- AvailableDate + IsAvailable = 0 allows marking someone unavailable
--   on a day they would normally be free (e.g., vacation override).
-- =============================================================================

CREATE TABLE FacilitatorAvailability (
    AvailabilityID  INT             NOT NULL IDENTITY(1,1),
    FacilitatorID   INT             NOT NULL,
    -- DayOfWeek: 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    --            'Friday', 'Saturday', 'Sunday'
    DayOfWeek       NVARCHAR(20)    NULL,
    -- AvailableDate: for specific date overrides
    AvailableDate   DATE            NULL,
    IsAvailable     BIT             NOT NULL CONSTRAINT DF_FacilitatorAvailability_IsAvailable DEFAULT 1,
    Notes           NVARCHAR(MAX)   NULL,

    CONSTRAINT PK_FacilitatorAvailability PRIMARY KEY (AvailabilityID),

    CONSTRAINT FK_FacilitatorAvailability_Facilitator
        FOREIGN KEY (FacilitatorID) REFERENCES Facilitator(FacilitatorID),

    -- Must have either DayOfWeek or AvailableDate, not neither
    CONSTRAINT CK_FacilitatorAvailability_HasDate
        CHECK (DayOfWeek IS NOT NULL OR AvailableDate IS NOT NULL),

    CONSTRAINT CK_FacilitatorAvailability_DayOfWeek
        CHECK (DayOfWeek IS NULL OR DayOfWeek IN
               ('Monday','Tuesday','Wednesday','Thursday',
                'Friday','Saturday','Sunday'))
);
GO

CREATE NONCLUSTERED INDEX IX_FacilitatorAvailability_FacilitatorID
    ON FacilitatorAvailability (FacilitatorID);
GO

CREATE NONCLUSTERED INDEX IX_FacilitatorAvailability_AvailableDate
    ON FacilitatorAvailability (AvailableDate);
GO
