-- =============================================================================
-- GriefSupportDB
-- Script 04: Transactional Tables
-- Description: Tables that record events, activities, and transactions over
--              time. These are the operational heart of the database.
--              Includes: Deceased, Loss, Encounter, Note, Outcome,
--                        Payment, PaymentAllocation, FeeSchedule,
--                        MailingPreference
-- Version:     v5 - Business Process Normalization
-- Changes:     - Interaction and InteractionType tables removed entirely.
--                Encounter is now the single universal contact record.
--              - Encounter gains IsLightweight BIT for quick touchpoints
--              - PaymentAllocation gains CampaignID and ScholarshipFundID
--                as deferred FKs (added in Script 07 after Campaign and
--                ScholarshipFund tables are created)
-- Author:      Steve Del Valle
-- Dependencies: 01_LookupTables.sql, 02_CoreProfile.sql, 03_RoleTables.sql
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- SECTION 1: DECEASED
-- Represents the person or animal companion whose death is the basis of a
-- client's grief. Stored as a separate searchable record so that:
--   - Multiple clients who share the same loss can be linked
--   - The organization can search by deceased name
--   - Pet / animal companion losses are handled alongside human losses
--
-- DeceasedType distinguishes Person from Pet / Animal Companion.
-- LastName and Species are mutually exclusive in practice:
--   Person:  FirstName + LastName populated, Species NULL
--   Pet:     FirstName (pet name) populated, LastName NULL, Species populated
-- =============================================================================

CREATE TABLE Deceased (
    DeceasedID          INT             NOT NULL IDENTITY(1,1),
    DeceasedTypeID      INT             NOT NULL,
    FirstName           NVARCHAR(100)   NULL,   -- Person first name or pet name
    LastName            NVARCHAR(100)   NULL,   -- Person only; NULL for pets
    Species             NVARCHAR(100)   NULL,   -- Pet only: Dog, Cat, Horse, etc.
    DateOfDeath         DATE            NULL,
    CauseOfDeathTypeID  INT             NULL,
    Notes               NVARCHAR(MAX)   NULL,

    CONSTRAINT PK_Deceased PRIMARY KEY (DeceasedID),

    CONSTRAINT FK_Deceased_DeceasedType
        FOREIGN KEY (DeceasedTypeID) REFERENCES DeceasedType(TypeID),

    CONSTRAINT FK_Deceased_CauseOfDeathType
        FOREIGN KEY (CauseOfDeathTypeID) REFERENCES CauseOfDeathType(TypeID)
);
GO

CREATE NONCLUSTERED INDEX IX_Deceased_LastName
    ON Deceased (LastName, FirstName);
GO

-- =============================================================================
-- SECTION 2: LOSS
-- Records each loss experience associated with a client.
-- A client can have multiple Loss records (e.g., lost a parent and later
-- lost a child - each is a separate Loss record).
-- DeceasedID links to the Deceased table for searchable deceased records.
-- EncounterID optionally records which encounter the loss was first disclosed.
-- DeceasedRelationship is the relationship of the deceased TO the client
-- (e.g., 'Mother', 'Spouse', 'Dog').
-- =============================================================================

CREATE TABLE Loss (
    LossID                  INT             NOT NULL IDENTITY(1,1),
    ClientID                INT             NOT NULL,
    DeceasedID              INT             NULL,       -- Links to Deceased record
    LossTypeID              INT             NOT NULL,
    EncounterID             INT             NULL,       -- Encounter where loss was disclosed
    LossDate                DATE            NULL,       -- Date of the loss event
    DeceasedRelationship    NVARCHAR(100)   NULL,       -- Relationship of deceased to client
    SupportReceived         NVARCHAR(MAX)   NULL,       -- Prior support client has received

    -- Audit fields
    CreatedDate             DATE            NOT NULL CONSTRAINT DF_Loss_CreatedDate DEFAULT GETDATE(),
    CreatedByStaffID        INT             NULL,
    ModifiedDate            DATE            NULL,
    ModifiedByStaffID       INT             NULL,

    CONSTRAINT PK_Loss PRIMARY KEY (LossID),

    CONSTRAINT FK_Loss_ClientInformation
        FOREIGN KEY (ClientID) REFERENCES ClientInformation(ClientID),

    CONSTRAINT FK_Loss_Deceased
        FOREIGN KEY (DeceasedID) REFERENCES Deceased(DeceasedID),

    CONSTRAINT FK_Loss_LossType
        FOREIGN KEY (LossTypeID) REFERENCES LossType(TypeID),

    CONSTRAINT FK_Loss_CreatedByStaff
        FOREIGN KEY (CreatedByStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT FK_Loss_ModifiedByStaff
        FOREIGN KEY (ModifiedByStaffID) REFERENCES Staff(StaffID)

    -- FK_Loss_Encounter added after Encounter table is created below
);
GO

CREATE NONCLUSTERED INDEX IX_Loss_ClientID
    ON Loss (ClientID);
GO

CREATE NONCLUSTERED INDEX IX_Loss_DeceasedID
    ON Loss (DeceasedID);
GO

-- =============================================================================
-- SECTION 3: ENCOUNTER
-- The single universal record for all meaningful staff contacts, regardless
-- of the person's role (client, volunteer, donor, board member, etc.).
--
-- v5 change: Interaction table eliminated. Encounter now covers everything
-- from formal intake calls to quick reminder touchpoints. IsLightweight
-- distinguishes quick touchpoints (no full documentation required) from
-- formal encounters that warrant complete notes and referral data.
--
-- ReferralType and ReferralSource live here (not on ClientInformation)
-- because a person can call for different reasons across encounters.
-- Example: First call for a child, later call for self = different
--          ReferralType per encounter.
--
-- SeekingServicesForID answers: who is this encounter about?
-- ClientTypeID reflects the type relevant to THIS encounter specifically.
-- =============================================================================

CREATE TABLE Encounter (
    EncounterID             INT             NOT NULL IDENTITY(1,1),
    ContactID               INT             NOT NULL,
    EncounterTypeID         INT             NOT NULL,
    StaffID                 INT             NULL,
    ClientTypeID            INT             NULL,       -- Type relevant to this encounter
    ReferralTypeID          INT             NULL,       -- Who is calling and why
    ReferralSourceID        INT             NULL,       -- How they heard about the org
    SeekingServicesForID    INT             NULL,       -- Who this encounter is about

    -- IsLightweight = 1 flags quick touchpoints (reminder calls, attendance
    -- confirmations, brief check-ins) that do not require full documentation.
    -- IsLightweight = 0 (default) = formal encounter requiring complete notes.
    IsLightweight           BIT             NOT NULL CONSTRAINT DF_Encounter_IsLightweight DEFAULT 0,

    EncounterDate           DATE            NOT NULL,
    EncounterNotes          NVARCHAR(MAX)   NULL,

    -- Audit fields
    CreatedDate             DATE            NOT NULL CONSTRAINT DF_Encounter_CreatedDate DEFAULT GETDATE(),
    CreatedByStaffID        INT             NULL,
    ModifiedDate            DATE            NULL,
    ModifiedByStaffID       INT             NULL,

    CONSTRAINT PK_Encounter PRIMARY KEY (EncounterID),

    CONSTRAINT FK_Encounter_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID),

    CONSTRAINT FK_Encounter_EncounterType
        FOREIGN KEY (EncounterTypeID) REFERENCES EncounterType(TypeID),

    CONSTRAINT FK_Encounter_Staff
        FOREIGN KEY (StaffID) REFERENCES Staff(StaffID),

    CONSTRAINT FK_Encounter_ClientType
        FOREIGN KEY (ClientTypeID) REFERENCES ClientType(TypeID),

    CONSTRAINT FK_Encounter_ReferralType
        FOREIGN KEY (ReferralTypeID) REFERENCES ReferralType(TypeID),

    CONSTRAINT FK_Encounter_ReferralSource
        FOREIGN KEY (ReferralSourceID) REFERENCES ReferralSource(SourceID),

    CONSTRAINT FK_Encounter_SeekingServicesFor
        FOREIGN KEY (SeekingServicesForID) REFERENCES SeekingServicesFor(SeekingID),

    CONSTRAINT FK_Encounter_CreatedByStaff
        FOREIGN KEY (CreatedByStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT FK_Encounter_ModifiedByStaff
        FOREIGN KEY (ModifiedByStaffID) REFERENCES Staff(StaffID)
);
GO

CREATE NONCLUSTERED INDEX IX_Encounter_ContactID
    ON Encounter (ContactID);
GO

CREATE NONCLUSTERED INDEX IX_Encounter_EncounterDate
    ON Encounter (EncounterDate);
GO

CREATE NONCLUSTERED INDEX IX_Encounter_IsLightweight
    ON Encounter (IsLightweight);
GO

-- Now that Encounter exists, add the FK from Loss to Encounter
ALTER TABLE Loss
    ADD CONSTRAINT FK_Loss_Encounter
        FOREIGN KEY (EncounterID) REFERENCES Encounter(EncounterID);
GO

-- =============================================================================
-- SECTION 4: NOTE
-- Free-form notes attached to any ContactInformation record.
-- NoteType categorizes the note (General, Program, Administrative, etc.).
-- Sensitive notes should use NoteType = 'Sensitive' so they can be
-- filtered by access level at the application layer.
--
-- v5: NoteType 'Clinical' removed - replaced with 'Program' in the
-- lookup table. The organization is not a clinical provider.
-- =============================================================================

CREATE TABLE Note (
    NoteID      INT             NOT NULL IDENTITY(1,1),
    ContactID   INT             NOT NULL,
    StaffID     INT             NULL,
    NoteTypeID  INT             NOT NULL,
    NoteDate    DATE            NOT NULL,
    NoteContent NVARCHAR(MAX)   NOT NULL,

    CONSTRAINT PK_Note PRIMARY KEY (NoteID),

    CONSTRAINT FK_Note_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID),

    CONSTRAINT FK_Note_Staff
        FOREIGN KEY (StaffID) REFERENCES Staff(StaffID),

    CONSTRAINT FK_Note_NoteType
        FOREIGN KEY (NoteTypeID) REFERENCES NoteType(TypeID)
);
GO

CREATE NONCLUSTERED INDEX IX_Note_ContactID
    ON Note (ContactID);
GO

-- =============================================================================
-- SECTION 5: OUTCOME
-- Records what action the organization took in response to a client's needs.
-- Based on TbLkpOutcome from the legacy system.
-- Outcome is tied to the client record rather than a specific encounter
-- as outcomes sometimes emerge over multiple contacts.
-- =============================================================================

CREATE TABLE Outcome (
    OutcomeID           INT             NOT NULL IDENTITY(1,1),
    ClientID            INT             NOT NULL,
    OutcomeTypeID       INT             NOT NULL,
    OutcomeDate         DATE            NOT NULL,
    OutcomeDescription  NVARCHAR(MAX)   NULL,

    CONSTRAINT PK_Outcome PRIMARY KEY (OutcomeID),

    CONSTRAINT FK_Outcome_ClientInformation
        FOREIGN KEY (ClientID) REFERENCES ClientInformation(ClientID),

    CONSTRAINT FK_Outcome_OutcomeType
        FOREIGN KEY (OutcomeTypeID) REFERENCES OutcomeType(TypeID)
);
GO

CREATE NONCLUSTERED INDEX IX_Outcome_ClientID
    ON Outcome (ClientID);
GO

-- =============================================================================
-- SECTION 6: FEE SCHEDULE
-- Stores the organization's current and historical fee amounts.
-- EffectiveDate and EndDate allow fees to change over time without
-- losing history. PaymentAllocation references FeeID to record which
-- fee rate applied at the time of payment.
-- ScholarshipAmount is the reduced fee for clients who qualify.
-- =============================================================================

CREATE TABLE FeeSchedule (
    FeeID               INT             NOT NULL IDENTITY(1,1),
    FeeTypeID           INT             NOT NULL,
    FeeName             NVARCHAR(150)   NOT NULL,
    FullAmount          DECIMAL(10,2)   NOT NULL,
    ScholarshipAmount   DECIMAL(10,2)   NULL,
    EffectiveDate       DATE            NOT NULL,
    EndDate             DATE            NULL,        -- NULL = currently in effect
    CreatedByStaffID    INT             NULL,

    CONSTRAINT PK_FeeSchedule PRIMARY KEY (FeeID),

    CONSTRAINT FK_FeeSchedule_FeeType
        FOREIGN KEY (FeeTypeID) REFERENCES FeeType(FeeTypeID),

    CONSTRAINT FK_FeeSchedule_CreatedByStaff
        FOREIGN KEY (CreatedByStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT CK_FeeSchedule_Amounts
        CHECK (FullAmount >= 0 AND (ScholarshipAmount IS NULL OR ScholarshipAmount >= 0)),

    CONSTRAINT CK_FeeSchedule_DateRange
        CHECK (EndDate IS NULL OR EndDate >= EffectiveDate)
);
GO

-- Seed initial fee schedule based on OrgConfiguration values
INSERT INTO FeeSchedule (FeeTypeID, FeeName, FullAmount, ScholarshipAmount, EffectiveDate)
VALUES
    (1, 'Peer Support Group Fee',           40.00,  NULL,  GETDATE()),
    (2, 'Bereavement Skills Training Fee',  150.00, 75.00, GETDATE());
GO

-- =============================================================================
-- SECTION 7: PAYMENT
-- Records the physical transaction - one record per check, cash payment,
-- or electronic transfer received. A single payment can be split across
-- multiple purposes via PaymentAllocation.
--
-- AcknowledgementSent and AcknowledgementDate track tax receipt delivery.
-- CheckNumber is only populated when PaymentMethodType = 'Check'.
-- =============================================================================

CREATE TABLE Payment (
    PaymentID               INT             NOT NULL IDENTITY(1,1),
    ContactID               INT             NOT NULL,
    PaymentMethodTypeID     INT             NOT NULL,
    PaymentDate             DATE            NOT NULL,
    TotalAmount             DECIMAL(10,2)   NOT NULL,
    CheckNumber             NVARCHAR(50)    NULL,
    ReceivedByStaffID       INT             NULL,
    AcknowledgementSent     BIT             NOT NULL CONSTRAINT DF_Payment_AcknowledgementSent DEFAULT 0,
    AcknowledgementDate     DATE            NULL,

    -- Audit fields
    CreatedDate             DATE            NOT NULL CONSTRAINT DF_Payment_CreatedDate DEFAULT GETDATE(),
    CreatedByStaffID        INT             NULL,
    ModifiedDate            DATE            NULL,
    ModifiedByStaffID       INT             NULL,

    CONSTRAINT PK_Payment PRIMARY KEY (PaymentID),

    CONSTRAINT FK_Payment_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID),

    CONSTRAINT FK_Payment_PaymentMethodType
        FOREIGN KEY (PaymentMethodTypeID) REFERENCES PaymentMethodType(TypeID),

    CONSTRAINT FK_Payment_ReceivedByStaff
        FOREIGN KEY (ReceivedByStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT FK_Payment_CreatedByStaff
        FOREIGN KEY (CreatedByStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT FK_Payment_ModifiedByStaff
        FOREIGN KEY (ModifiedByStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT CK_Payment_TotalAmount
        CHECK (TotalAmount > 0)
);
GO

CREATE NONCLUSTERED INDEX IX_Payment_ContactID
    ON Payment (ContactID);
GO

CREATE NONCLUSTERED INDEX IX_Payment_PaymentDate
    ON Payment (PaymentDate);
GO

-- =============================================================================
-- SECTION 8: PAYMENT ALLOCATION
-- Splits a Payment across one or more purposes.
-- Example: A $200 check where $100 is a group fee and $100 is a donation
-- produces one Payment record and two PaymentAllocation records.
--
-- IsTaxDeductible drives tax receipt generation.
--   Donation allocations = tax deductible.
--   Fee allocations = not tax deductible.
-- IsScholarship flags that a reduced fee was applied.
-- DonorID populated only when AllocationType is a Donation type.
-- FeeID references FeeSchedule to record which rate applied.
--
-- v5: CampaignID and ScholarshipFundID columns added here as nullable.
--     Their FK constraints are added in Script 07 after those tables exist.
--     This preserves correct dependency order while keeping all allocation
--     fields together in one table.
--
-- Business rule: sum of all allocation Amounts must equal Payment.TotalAmount.
-- This is enforced by stored procedure, not a table constraint, because
-- SQL Server does not support subquery-based CHECK constraints.
-- =============================================================================

CREATE TABLE PaymentAllocation (
    AllocationID        INT             NOT NULL IDENTITY(1,1),
    PaymentID           INT             NOT NULL,
    AllocationTypeID    INT             NOT NULL,
    FeeID               INT             NULL,       -- FK to FeeSchedule; fee allocations only
    CampaignID          INT             NULL,       -- FK added in Script 07; campaign donations
    ScholarshipFundID   INT             NULL,       -- FK added in Script 07; scholarship donations
    Amount              DECIMAL(10,2)   NOT NULL,
    IsTaxDeductible     BIT             NOT NULL CONSTRAINT DF_PaymentAllocation_TaxDeductible DEFAULT 0,
    IsScholarship       BIT             NOT NULL CONSTRAINT DF_PaymentAllocation_IsScholarship DEFAULT 0,
    ScholarshipAmount   DECIMAL(10,2)   NULL,       -- Actual scholarship reduction amount
    DonorID             INT             NULL,       -- FK to DonorInformation; donation allocations only
    FeeDescription      NVARCHAR(255)   NULL,

    CONSTRAINT PK_PaymentAllocation PRIMARY KEY (AllocationID),

    CONSTRAINT FK_PaymentAllocation_Payment
        FOREIGN KEY (PaymentID) REFERENCES Payment(PaymentID),

    CONSTRAINT FK_PaymentAllocation_AllocationType
        FOREIGN KEY (AllocationTypeID) REFERENCES AllocationType(TypeID),

    CONSTRAINT FK_PaymentAllocation_FeeSchedule
        FOREIGN KEY (FeeID) REFERENCES FeeSchedule(FeeID),

    CONSTRAINT FK_PaymentAllocation_DonorInformation
        FOREIGN KEY (DonorID) REFERENCES DonorInformation(DonorID),

    CONSTRAINT CK_PaymentAllocation_Amount
        CHECK (Amount > 0)
);
GO

CREATE NONCLUSTERED INDEX IX_PaymentAllocation_PaymentID
    ON PaymentAllocation (PaymentID);
GO

CREATE NONCLUSTERED INDEX IX_PaymentAllocation_DonorID
    ON PaymentAllocation (DonorID);
GO

-- =============================================================================
-- SECTION 9: MAILING PREFERENCE
-- Bridge table between ContactInformation and MailingType.
-- One record per contact per mailing type they are opted into.
-- OptedInReason documents WHY the preference was set.
--
-- v5: ILOF removed from MailingType - it is now a Campaign.
-- Mailing preferences are set by stored procedures based on business
-- rules in OrgConfiguration and can be overridden manually by staff.
-- =============================================================================

CREATE TABLE MailingPreference (
    PreferenceID    INT             NOT NULL IDENTITY(1,1),
    ContactID       INT             NOT NULL,
    MailingTypeID   INT             NOT NULL,
    OptedIn         BIT             NOT NULL CONSTRAINT DF_MailingPreference_OptedIn DEFAULT 1,
    OptedInDate     DATE            NULL,
    OptedInReason   NVARCHAR(500)   NULL,
    SetByStaffID    INT             NULL,

    CONSTRAINT PK_MailingPreference PRIMARY KEY (PreferenceID),

    CONSTRAINT FK_MailingPreference_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID),

    CONSTRAINT FK_MailingPreference_MailingType
        FOREIGN KEY (MailingTypeID) REFERENCES MailingType(TypeID),

    CONSTRAINT FK_MailingPreference_SetByStaff
        FOREIGN KEY (SetByStaffID) REFERENCES Staff(StaffID),

    -- A contact can only have one preference record per mailing type
    CONSTRAINT UQ_MailingPreference_ContactMailingType
        UNIQUE (ContactID, MailingTypeID)
);
GO

CREATE NONCLUSTERED INDEX IX_MailingPreference_ContactID
    ON MailingPreference (ContactID);
GO
