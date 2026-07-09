-- =============================================================================
-- GriefSupportDB
-- Script 02: Core Profile Tables
-- Description: ContactInformation as the central entity, plus EmergencyContact
--              and Relationship tables. Every person or organization in the
--              database has exactly one ContactInformation record.
-- Author:      Steve Del Valle
-- Dependencies: 01_LookupTables.sql
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- SECTION 1: CONTACT INFORMATION
-- The core entity of the entire database. Every person, organization, donor,
-- client, volunteer, staff member, and board member has one record here.
-- Organization contacts use OrganizationName; individuals use First/Last name.
-- =============================================================================

CREATE TABLE ContactInformation (
    ContactID               INT             NOT NULL IDENTITY(1,1),

    -- Profile metadata
    InitialContactDate      DATE            NULL,
    InitialContactStaffID   INT             NULL,   -- FK to Staff (added post-Staff creation)
    ProfileStatusID         INT             NOT NULL,
    ProfileTypeID           INT             NOT NULL,

    -- Organization name: populated when ProfileType = 'Organization'
    OrganizationName        NVARCHAR(255)   NULL,

    -- Individual name fields
    FirstName               NVARCHAR(100)   NULL,   -- NULL allowed: use 'UNK' per data entry convention
    MiddleName              NVARCHAR(100)   NULL,
    LastName                NVARCHAR(100)   NULL,   -- NULL allowed: use 'UNK' per data entry convention

    -- Contact details
    Phone                   NVARCHAR(20)    NULL,   -- Use 555-555-5555 if unknown per convention
    AlternatePhone          NVARCHAR(20)    NULL,
    Email                   NVARCHAR(255)   NULL,

    -- Physical / primary address
    AddressLine1            NVARCHAR(255)   NULL,
    AddressLine2            NVARCHAR(255)   NULL,   -- For unit numbers or PO Box if same as mailing
    CityID                  INT             NULL,
    StateID                 INT             NULL,
    Zip                     NVARCHAR(20)    NULL,
    CountryID               INT             NULL,

    -- Mailing address: used when different from physical address
    -- UseMailingAddress drives whether this block is used for correspondence
    UseMailingAddress       BIT             NOT NULL CONSTRAINT DF_ContactInformation_UseMailingAddress DEFAULT 0,
    MailingAddressLine1     NVARCHAR(255)   NULL,
    MailingAddressLine2     NVARCHAR(255)   NULL,
    MailingCityID           INT             NULL,
    MailingStateID          INT             NULL,
    MailingZip              NVARCHAR(20)    NULL,
    MailingCountryID        INT             NULL,

    -- Demographics
    DateOfBirth             DATE            NULL,   -- Used for age calculations and grant reporting
    GenderID                INT             NULL,
    EthnicityID             INT             NULL,

    -- Audit fields
    CreatedDate             DATE            NOT NULL CONSTRAINT DF_ContactInformation_CreatedDate DEFAULT GETDATE(),
    CreatedByStaffID        INT             NULL,   -- FK added post-Staff creation
    ModifiedDate            DATE            NULL,
    ModifiedByStaffID       INT             NULL,   -- FK added post-Staff creation

    CONSTRAINT PK_ContactInformation PRIMARY KEY (ContactID),

    CONSTRAINT FK_ContactInformation_ProfileStatus
        FOREIGN KEY (ProfileStatusID) REFERENCES ProfileStatus(StatusID),

    CONSTRAINT FK_ContactInformation_ProfileType
        FOREIGN KEY (ProfileTypeID) REFERENCES ProfileType(TypeID),

    CONSTRAINT FK_ContactInformation_Gender
        FOREIGN KEY (GenderID) REFERENCES Gender(GenderID),

    CONSTRAINT FK_ContactInformation_Ethnicity
        FOREIGN KEY (EthnicityID) REFERENCES Ethnicity(EthnicityID),

    CONSTRAINT FK_ContactInformation_City
        FOREIGN KEY (CityID) REFERENCES City(CityID),

    CONSTRAINT FK_ContactInformation_State
        FOREIGN KEY (StateID) REFERENCES State(StateID),

    CONSTRAINT FK_ContactInformation_Country
        FOREIGN KEY (CountryID) REFERENCES Country(CountryID),

    CONSTRAINT FK_ContactInformation_MailingCity
        FOREIGN KEY (MailingCityID) REFERENCES City(CityID),

    CONSTRAINT FK_ContactInformation_MailingState
        FOREIGN KEY (MailingStateID) REFERENCES State(StateID),

    CONSTRAINT FK_ContactInformation_MailingCountry
        FOREIGN KEY (MailingCountryID) REFERENCES Country(CountryID)
);
GO

-- Index on name fields for fast search
CREATE NONCLUSTERED INDEX IX_ContactInformation_LastName
    ON ContactInformation (LastName, FirstName);
GO

-- Index on organization name for fast search
CREATE NONCLUSTERED INDEX IX_ContactInformation_OrganizationName
    ON ContactInformation (OrganizationName);
GO

-- =============================================================================
-- SECTION 2: EMERGENCY CONTACT
-- Each ContactInformation record can have one or more emergency contacts.
-- IsPrimary flags the preferred first-contact person.
-- Emergency contacts are not full ContactInformation records - they are
-- lightweight contact details only.
-- =============================================================================

CREATE TABLE EmergencyContact (
    EmergencyContactID  INT             NOT NULL IDENTITY(1,1),
    ContactID           INT             NOT NULL,
    FirstName           NVARCHAR(100)   NOT NULL,
    LastName            NVARCHAR(100)   NOT NULL,
    Phone               NVARCHAR(20)    NOT NULL,
    AlternatePhone      NVARCHAR(20)    NULL,
    Relationship        NVARCHAR(100)   NULL,   -- Plain text: e.g. 'Sister', 'Friend'
    IsPrimary           BIT             NOT NULL CONSTRAINT DF_EmergencyContact_IsPrimary DEFAULT 0,

    CONSTRAINT PK_EmergencyContact PRIMARY KEY (EmergencyContactID),

    CONSTRAINT FK_EmergencyContact_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID)
);
GO

CREATE NONCLUSTERED INDEX IX_EmergencyContact_ContactID
    ON EmergencyContact (ContactID);
GO

-- =============================================================================
-- SECTION 3: RELATIONSHIP
-- Records relationships between two ContactInformation records.
-- ContactID_A and ContactID_B are both FKs to ContactInformation.
-- The relationship is directional: ContactID_A [RelationshipType] ContactID_B.
-- Example: ContactID_A (John) is the 'Parent' of ContactID_B (Jane).
-- StartDate and EndDate allow historical relationships to be preserved.
-- Important use case: deceased loved ones may have their own ContactInformation
-- record so that multiple clients who share a loss can be linked.
-- =============================================================================

CREATE TABLE Relationship (
    RelationshipID      INT     NOT NULL IDENTITY(1,1),
    ContactID_A         INT     NOT NULL,   -- The subject of the relationship
    ContactID_B         INT     NOT NULL,   -- The object of the relationship
    RelationshipTypeID  INT     NOT NULL,
    StartDate           DATE    NULL,
    EndDate             DATE    NULL,       -- NULL = relationship is current

    CONSTRAINT PK_Relationship PRIMARY KEY (RelationshipID),

    CONSTRAINT FK_Relationship_ContactA
        FOREIGN KEY (ContactID_A) REFERENCES ContactInformation(ContactID),

    CONSTRAINT FK_Relationship_ContactB
        FOREIGN KEY (ContactID_B) REFERENCES ContactInformation(ContactID),

    CONSTRAINT FK_Relationship_RelationshipType
        FOREIGN KEY (RelationshipTypeID) REFERENCES RelationshipType(TypeID),

    -- A contact cannot have a relationship with themselves
    CONSTRAINT CK_Relationship_NoSelfRelationship
        CHECK (ContactID_A <> ContactID_B)
);
GO

CREATE NONCLUSTERED INDEX IX_Relationship_ContactID_A
    ON Relationship (ContactID_A);
GO

CREATE NONCLUSTERED INDEX IX_Relationship_ContactID_B
    ON Relationship (ContactID_B);
GO
