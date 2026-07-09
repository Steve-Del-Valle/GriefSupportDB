-- =============================================================================
-- GriefSupportDB
-- Script 06: Group and Program Tables
-- Description: Peer support groups, meetings, attendance, client enrollment,
--              and outreach events.
-- Version:     v5
-- Author:      Steve Del Valle
-- Dependencies: 01_LookupTables.sql, 02_CoreProfile.sql, 03_RoleTables.sql,
--               05_FacilitatorTables.sql
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- SECTION 1: PEER SUPPORT GROUP
-- Represents an ongoing grief support group with a consistent Facilitator
-- and Co-Facilitator pairing assigned for the life of the group.
-- The permanent pairing is stored here for continuity and trust.
-- Session-level actual coverage (including substitutions) is recorded
-- on the Meeting table.
--
-- Business rules enforced here:
--   - Every group must have both a Facilitator and a Co-Facilitator (NOT NULL)
--   - The Facilitator and Co-Facilitator cannot be the same person
--   - Both must have appropriate FacilitatorGroupTypeQualification records
--     for the GroupTypeID (enforced by stored procedure)
-- =============================================================================

CREATE TABLE PeerSupportGroup (
    GroupID             INT             NOT NULL IDENTITY(1,1),
    GroupTypeID         INT             NOT NULL,
    FacilitatorID       INT             NOT NULL,   -- Primary lead; permanent assignment
    CoFacilitatorID     INT             NOT NULL,   -- Co-lead; permanent assignment
    GroupName           NVARCHAR(255)   NOT NULL,
    GroupDescription    NVARCHAR(MAX)   NULL,
    StartDate           DATE            NULL,
    EndDate             DATE            NULL,       -- NULL = group is currently active

    CONSTRAINT PK_PeerSupportGroup PRIMARY KEY (GroupID),

    CONSTRAINT FK_PeerSupportGroup_GroupType
        FOREIGN KEY (GroupTypeID) REFERENCES PeerSupportGroupType(TypeID),

    CONSTRAINT FK_PeerSupportGroup_Facilitator
        FOREIGN KEY (FacilitatorID) REFERENCES Facilitator(FacilitatorID),

    CONSTRAINT FK_PeerSupportGroup_CoFacilitator
        FOREIGN KEY (CoFacilitatorID) REFERENCES Facilitator(FacilitatorID),

    -- The Facilitator and Co-Facilitator must be different people
    CONSTRAINT CK_PeerSupportGroup_DifferentFacilitators
        CHECK (FacilitatorID <> CoFacilitatorID),

    CONSTRAINT CK_PeerSupportGroup_DateRange
        CHECK (EndDate IS NULL OR StartDate IS NULL OR EndDate >= StartDate)
);
GO

CREATE NONCLUSTERED INDEX IX_PeerSupportGroup_GroupTypeID
    ON PeerSupportGroup (GroupTypeID);
GO

CREATE NONCLUSTERED INDEX IX_PeerSupportGroup_FacilitatorID
    ON PeerSupportGroup (FacilitatorID);
GO

-- =============================================================================
-- SECTION 2: CLIENT GROUP
-- Enrollment bridge table between ClientInformation and PeerSupportGroup.
-- Represents a client's registration for a specific group.
-- This is distinct from GroupAttendance: enrollment = registered for the
-- group; attendance = showed up to a specific session.
--
-- EnrollmentStatus tracks: Waitlist → Enrolled → Completed / Withdrawn
-- WaitlistDate records when the client was placed on the waitlist.
-- ProgramCompleted and CompletionDate record explicit program completion
-- for grant reporting purposes.
-- =============================================================================

CREATE TABLE ClientGroup (
    ClientGroupID       INT             NOT NULL IDENTITY(1,1),
    GroupID             INT             NOT NULL,
    ClientID            INT             NOT NULL,
    EnrollmentStatusID  INT             NOT NULL,
    EnrollmentDate      DATE            NULL,
    WaitlistDate        DATE            NULL,       -- Date placed on waitlist
    CompletionDate      DATE            NULL,       -- Date program completed or closed
    ProgramCompleted    BIT             NOT NULL CONSTRAINT DF_ClientGroup_ProgramCompleted DEFAULT 0,
    CompletionNotes     NVARCHAR(MAX)   NULL,

    CONSTRAINT PK_ClientGroup PRIMARY KEY (ClientGroupID),

    CONSTRAINT FK_ClientGroup_PeerSupportGroup
        FOREIGN KEY (GroupID) REFERENCES PeerSupportGroup(GroupID),

    CONSTRAINT FK_ClientGroup_ClientInformation
        FOREIGN KEY (ClientID) REFERENCES ClientInformation(ClientID),

    CONSTRAINT FK_ClientGroup_EnrollmentStatus
        FOREIGN KEY (EnrollmentStatusID) REFERENCES EnrollmentStatus(StatusID),

    -- A client can only have one enrollment record per group
    CONSTRAINT UQ_ClientGroup_ClientGroup
        UNIQUE (GroupID, ClientID)
);
GO

CREATE NONCLUSTERED INDEX IX_ClientGroup_GroupID
    ON ClientGroup (GroupID);
GO

CREATE NONCLUSTERED INDEX IX_ClientGroup_ClientID
    ON ClientGroup (ClientID);
GO

-- =============================================================================
-- SECTION 3: MEETING
-- A single session of a PeerSupportGroup on a specific date.
-- Think of this as the equivalent of a class session in a school model:
--   PeerSupportGroup = Class (permanent teacher assignment)
--   Meeting          = Class Session (what actually happened that day)
--   GroupAttendance  = Roster (who showed up)
--
-- FacilitatorID and CoFacilitatorID record WHO ACTUALLY LED that session.
-- On normal sessions these match the PeerSupportGroup assignment.
-- When a substitute is used, SubstituteFacilitator or SubstituteCoFacilitator
-- is set to 1 and the substitute's FacilitatorID is recorded here.
--
-- Business rules enforced here:
--   - Both seats are required (NOT NULL)
--   - The two seats cannot be the same person
--   - Both must have BackgroundCheckCleared = 1 (enforced by procedure)
-- =============================================================================

CREATE TABLE Meeting (
    MeetingID               INT     NOT NULL IDENTITY(1,1),
    GroupID                 INT     NOT NULL,
    FacilitatorID           INT     NOT NULL,   -- Who actually led this session
    CoFacilitatorID         INT     NOT NULL,   -- Who actually co-led this session
    SubstituteFacilitator   BIT     NOT NULL CONSTRAINT DF_Meeting_SubFacilitator DEFAULT 0,
    SubstituteCoFacilitator BIT     NOT NULL CONSTRAINT DF_Meeting_SubCoFacilitator DEFAULT 0,
    MeetingDate             DATE    NOT NULL,

    CONSTRAINT PK_Meeting PRIMARY KEY (MeetingID),

    CONSTRAINT FK_Meeting_PeerSupportGroup
        FOREIGN KEY (GroupID) REFERENCES PeerSupportGroup(GroupID),

    CONSTRAINT FK_Meeting_Facilitator
        FOREIGN KEY (FacilitatorID) REFERENCES Facilitator(FacilitatorID),

    CONSTRAINT FK_Meeting_CoFacilitator
        FOREIGN KEY (CoFacilitatorID) REFERENCES Facilitator(FacilitatorID),

    -- The two seats must be different people in every session
    CONSTRAINT CK_Meeting_DifferentFacilitators
        CHECK (FacilitatorID <> CoFacilitatorID)
);
GO

CREATE NONCLUSTERED INDEX IX_Meeting_GroupID
    ON Meeting (GroupID);
GO

CREATE NONCLUSTERED INDEX IX_Meeting_MeetingDate
    ON Meeting (MeetingDate);
GO

-- =============================================================================
-- SECTION 4: GROUP ATTENDANCE
-- Records which clients attended a specific meeting session.
-- AttendanceStatus: Present, Absent - Notified, Absent - No Contact.
-- 'Absent - No Contact' is a wellbeing flag that should trigger a
-- staff follow-up, especially for vulnerable grief support clients.
-- 'Late' was intentionally excluded: in grief support, showing up
-- at all is meaningful. Marking lateness could feel judgmental.
-- =============================================================================

CREATE TABLE GroupAttendance (
    AttendanceID        INT     NOT NULL IDENTITY(1,1),
    MeetingID           INT     NOT NULL,
    ClientID            INT     NOT NULL,
    AttendanceStatusID  INT     NOT NULL,
    AttendanceDate      DATE    NOT NULL,

    CONSTRAINT PK_GroupAttendance PRIMARY KEY (AttendanceID),

    CONSTRAINT FK_GroupAttendance_Meeting
        FOREIGN KEY (MeetingID) REFERENCES Meeting(MeetingID),

    CONSTRAINT FK_GroupAttendance_ClientInformation
        FOREIGN KEY (ClientID) REFERENCES ClientInformation(ClientID),

    CONSTRAINT FK_GroupAttendance_AttendanceStatus
        FOREIGN KEY (AttendanceStatusID) REFERENCES AttendanceStatus(StatusID),

    -- A client can only have one attendance record per meeting
    CONSTRAINT UQ_GroupAttendance_MeetingClient
        UNIQUE (MeetingID, ClientID)
);
GO

CREATE NONCLUSTERED INDEX IX_GroupAttendance_MeetingID
    ON GroupAttendance (MeetingID);
GO

CREATE NONCLUSTERED INDEX IX_GroupAttendance_ClientID
    ON GroupAttendance (ClientID);
GO

-- =============================================================================
-- SECTION 5: OUTREACH EVENT
-- Community-facing events organized by the organization that are distinct
-- from ongoing peer support groups.
-- Examples: community presentations, school presentations, health fairs,
--           expressive arts performances, memorial events, volunteer
--           recruitment events.
-- AttendeeCount is a summary field for events where individual attendance
-- is not tracked (e.g., a public presentation to a general audience).
-- OutreachEventAttendance tracks individual contact-level attendance
-- where known.
-- =============================================================================

CREATE TABLE OutreachEvent (
    EventID                 INT             NOT NULL IDENTITY(1,1),
    EventTypeID             INT             NOT NULL,
    EventName               NVARCHAR(255)   NOT NULL,
    EventDescription        NVARCHAR(MAX)   NULL,
    EventDate               DATE            NOT NULL,
    Location                NVARCHAR(255)   NULL,
    OrganizedByStaffID      INT             NULL,
    -- AttendeeCount: total headcount for public events where individual
    -- tracking is not practical
    AttendeeCount           INT             NULL,

    CONSTRAINT PK_OutreachEvent PRIMARY KEY (EventID),

    CONSTRAINT FK_OutreachEvent_OutreachEventType
        FOREIGN KEY (EventTypeID) REFERENCES OutreachEventType(TypeID),

    CONSTRAINT FK_OutreachEvent_OrganizedByStaff
        FOREIGN KEY (OrganizedByStaffID) REFERENCES Staff(StaffID)
);
GO

CREATE NONCLUSTERED INDEX IX_OutreachEvent_EventDate
    ON OutreachEvent (EventDate);
GO

-- =============================================================================
-- SECTION 6: OUTREACH EVENT ATTENDANCE
-- Individual attendance records for outreach events where specific
-- contacts are tracked (e.g., a volunteer recruitment event where
-- attendees sign in and become leads in the database).
-- =============================================================================

CREATE TABLE OutreachEventAttendance (
    AttendanceID    INT     NOT NULL IDENTITY(1,1),
    EventID         INT     NOT NULL,
    ContactID       INT     NOT NULL,
    AttendanceDate  DATE    NOT NULL,

    CONSTRAINT PK_OutreachEventAttendance PRIMARY KEY (AttendanceID),

    CONSTRAINT FK_OutreachEventAttendance_OutreachEvent
        FOREIGN KEY (EventID) REFERENCES OutreachEvent(EventID),

    CONSTRAINT FK_OutreachEventAttendance_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID),

    -- A contact can only have one attendance record per event
    CONSTRAINT UQ_OutreachEventAttendance_EventContact
        UNIQUE (EventID, ContactID)
);
GO

CREATE NONCLUSTERED INDEX IX_OutreachEventAttendance_EventID
    ON OutreachEventAttendance (EventID);
GO

CREATE NONCLUSTERED INDEX IX_OutreachEventAttendance_ContactID
    ON OutreachEventAttendance (ContactID);
GO
