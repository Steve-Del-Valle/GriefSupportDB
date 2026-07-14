-- =============================================================================
-- GriefSupportDB
-- Script 01: Lookup Tables
-- Description: All reference/lookup tables with seed data.
--              These must be created first as all other tables depend on them.
-- Version:     v5 - Business Process Normalization
-- Changes:     - Removed InteractionType (Interaction table eliminated)
--              - EncounterType expanded to cover all role contact types
--              - NoteType 'Clinical' replaced with 'Program'
--              - ReferralSource 'Doctor' replaced with 'Medical Professional'
--              - EnrollmentStatus 'Waitlisted' corrected to 'Waitlist'
--              - PeerSupportGroupType 'Theatre Troupe' replaced with
--                'Expressive Arts'
--              - MailingType ILOF comment corrected
--              - Added CampaignType lookup
--              - Added ProgramType table above PeerSupportGroupType
-- Author:      Steve Del Valle
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- SECTION 1: CORE PROFILE LOOKUPS
-- =============================================================================

CREATE TABLE ProfileType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_ProfileType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_ProfileType_TypeName UNIQUE (TypeName)
);

INSERT INTO ProfileType (TypeName) VALUES
    ('Personal'),
    ('Professional'),
    ('Organization');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE ProfileStatus (
    StatusID    INT             NOT NULL IDENTITY(1,1),
    StatusName  NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_ProfileStatus PRIMARY KEY (StatusID),
    CONSTRAINT UQ_ProfileStatus_StatusName UNIQUE (StatusName)
);

INSERT INTO ProfileStatus (StatusName) VALUES
    ('Active'),
    ('Inactive'),
    ('Deceased'),
    ('Do Not Contact');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE Gender (
    GenderID    INT             NOT NULL IDENTITY(1,1),
    GenderName  NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_Gender PRIMARY KEY (GenderID),
    CONSTRAINT UQ_Gender_GenderName UNIQUE (GenderName)
);

INSERT INTO Gender (GenderName) VALUES
    ('Male'),
    ('Female'),
    ('Non-Binary'),
    ('Transgender Male'),
    ('Transgender Female'),
    ('Prefer Not to Say'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE Ethnicity (
    EthnicityID     INT             NOT NULL IDENTITY(1,1),
    EthnicityName   NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_Ethnicity PRIMARY KEY (EthnicityID),
    CONSTRAINT UQ_Ethnicity_EthnicityName UNIQUE (EthnicityName)
);

INSERT INTO Ethnicity (EthnicityName) VALUES
    ('American Indian or Alaska Native'),
    ('Asian'),
    ('Black or African American'),
    ('Hispanic or Latino'),
    ('Native Hawaiian or Other Pacific Islander'),
    ('White or Caucasian'),
    ('Two or More Races'),
    ('Prefer Not to Say'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE Country (
    CountryID   INT             NOT NULL IDENTITY(1,1),
    CountryName NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_Country PRIMARY KEY (CountryID),
    CONSTRAINT UQ_Country_CountryName UNIQUE (CountryName)
);

INSERT INTO Country (CountryName) VALUES
    ('United States'),
    ('Canada'),
    ('Mexico'),
    ('United Kingdom'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE State (
    StateID     INT             NOT NULL IDENTITY(1,1),
    StateName   NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_State PRIMARY KEY (StateID),
    CONSTRAINT UQ_State_StateName UNIQUE (StateName)
);

INSERT INTO State (StateName) VALUES
    ('Alabama'), ('Alaska'), ('Arizona'), ('Arkansas'), ('California'),
    ('Colorado'), ('Connecticut'), ('Delaware'), ('Florida'), ('Georgia'),
    ('Hawaii'), ('Idaho'), ('Illinois'), ('Indiana'), ('Iowa'),
    ('Kansas'), ('Kentucky'), ('Louisiana'), ('Maine'), ('Maryland'),
    ('Massachusetts'), ('Michigan'), ('Minnesota'), ('Mississippi'), ('Missouri'),
    ('Montana'), ('Nebraska'), ('Nevada'), ('New Hampshire'), ('New Jersey'),
    ('New Mexico'), ('New York'), ('North Carolina'), ('North Dakota'), ('Ohio'),
    ('Oklahoma'), ('Oregon'), ('Pennsylvania'), ('Rhode Island'), ('South Carolina'),
    ('South Dakota'), ('Tennessee'), ('Texas'), ('Utah'), ('Vermont'),
    ('Virginia'), ('Washington'), ('West Virginia'), ('Wisconsin'), ('Wyoming'),
    ('District of Columbia'),
    -- Canadian provinces for donors such as Benevity Community Impact Fund
    ('Alberta'), ('British Columbia'), ('Ontario'), ('Quebec');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE City (
    CityID      INT             NOT NULL IDENTITY(1,1),
    CityName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_City PRIMARY KEY (CityID)
);

INSERT INTO City (CityName) VALUES
    ('Ashland'),
    ('Medford'),
    ('Jacksonville'),
    ('Talent'),
    ('Phoenix'),
    ('Grants Pass'),
    ('Klamath Falls'),
    ('Other');
GO

-- =============================================================================
-- SECTION 2: RELATIONSHIP LOOKUPS
-- =============================================================================

CREATE TABLE RelationshipType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_RelationshipType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_RelationshipType_TypeName UNIQUE (TypeName)
);

INSERT INTO RelationshipType (TypeName) VALUES
    ('Spouse / Partner'),
    ('Parent'),
    ('Child'),
    ('Sibling'),
    ('Grandparent'),
    ('Grandchild'),
    ('Aunt / Uncle'),
    ('Niece / Nephew'),
    ('Friend'),
    ('Colleague'),
    ('Referred By'),
    ('Emergency Contact'),
    ('Other');
GO

-- =============================================================================
-- SECTION 3: ROLE-SPECIFIC LOOKUPS
-- =============================================================================

CREATE TABLE BoardRole (
    RoleID      INT             NOT NULL IDENTITY(1,1),
    RoleName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_BoardRole PRIMARY KEY (RoleID),
    CONSTRAINT UQ_BoardRole_RoleName UNIQUE (RoleName)
);

INSERT INTO BoardRole (RoleName) VALUES
    ('Chair'),
    ('Vice Chair'),
    ('Treasurer'),
    ('Secretary'),
    ('Member at Large');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE VolunteerStatus (
    StatusID    INT             NOT NULL IDENTITY(1,1),
    StatusName  NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_VolunteerStatus PRIMARY KEY (StatusID),
    CONSTRAINT UQ_VolunteerStatus_StatusName UNIQUE (StatusName)
);

INSERT INTO VolunteerStatus (StatusName) VALUES
    ('Interested'),          -- Has expressed interest, no training yet
    ('Training Registered'), -- Registered for BST
    ('Training Completed'),  -- Completed BST, pending background check
    ('Active'),              -- Cleared and serving
    ('Inactive'),
    ('On Leave');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE SupportSkill (
    SkillID     INT             NOT NULL IDENTITY(1,1),
    SkillName   NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_SupportSkill PRIMARY KEY (SkillID),
    CONSTRAINT UQ_SupportSkill_SkillName UNIQUE (SkillName)
);

INSERT INTO SupportSkill (SkillName) VALUES
    ('Active Listening'),
    ('Empathy'),
    ('Crisis Support'),
    ('Child and Youth Support'),
    ('Bilingual - Spanish'),
    ('Bilingual - Other'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE FacilitationSkill (
    SkillID     INT             NOT NULL IDENTITY(1,1),
    SkillName   NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_FacilitationSkill PRIMARY KEY (SkillID),
    CONSTRAINT UQ_FacilitationSkill_SkillName UNIQUE (SkillName)
);

INSERT INTO FacilitationSkill (SkillName) VALUES
    ('Group Dynamics'),
    ('Conflict Resolution'),
    ('Trauma-Informed Facilitation'),
    ('Child and Youth Group Facilitation'),
    ('Cross-Cultural Facilitation'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE ClientStatus (
    StatusID    INT             NOT NULL IDENTITY(1,1),
    StatusName  NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_ClientStatus PRIMARY KEY (StatusID),
    CONSTRAINT UQ_ClientStatus_StatusName UNIQUE (StatusName)
);

INSERT INTO ClientStatus (StatusName) VALUES
    ('Active'),
    ('Inactive'),
    ('Waitlisted'),
    ('Closed - Services Complete'),
    ('Closed - Does Not Fit Services'),
    ('Closed - No Response'),
    ('Deceased');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE ClientType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_ClientType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_ClientType_TypeName UNIQUE (TypeName)
);

INSERT INTO ClientType (TypeName) VALUES
    ('Individual Adult'),
    ('Individual Child / Youth'),
    ('Individual Teen'),
    ('Family'),
    ('Professional - Calling for Self'),
    ('Professional - Calling for Client'),
    ('School Staff'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE MinorsSuitableFor (
    SuitableForID   INT             NOT NULL IDENTITY(1,1),
    SuitableForName NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_MinorsSuitableFor PRIMARY KEY (SuitableForID),
    CONSTRAINT UQ_MinorsSuitableFor_Name UNIQUE (SuitableForName)
);

-- Describes what program type a minor client has been assessed as ready for
INSERT INTO MinorsSuitableFor (SuitableForName) VALUES
    ('Individual Support Only'),
    ('Pre-Program'),
    ('Peer Support Group'),
    ('Not Yet Assessed');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE SeekingServicesFor (
    SeekingID   INT             NOT NULL IDENTITY(1,1),
    SeekingName NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_SeekingServicesFor PRIMARY KEY (SeekingID),
    CONSTRAINT UQ_SeekingServicesFor_Name UNIQUE (SeekingName)
);

-- Recorded on each Encounter: who is this specific contact about?
INSERT INTO SeekingServicesFor (SeekingName) VALUES
    ('Self'),
    ('Child / Youth'),
    ('Teen'),
    ('Spouse / Partner'),
    ('Parent'),
    ('Sibling'),
    ('Other Family Member'),
    ('Client - Professional Referral'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE Insurance (
    InsuranceID     INT             NOT NULL IDENTITY(1,1),
    InsuranceName   NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_Insurance PRIMARY KEY (InsuranceID),
    CONSTRAINT UQ_Insurance_InsuranceName UNIQUE (InsuranceName)
);

INSERT INTO Insurance (InsuranceName) VALUES
    ('None'),
    ('Private'),
    ('Medicaid'),
    ('Medicare'),
    ('OHP - Oregon Health Plan'),
    ('Unknown'),
    ('Other');
GO

-- =============================================================================
-- SECTION 4: LOSS LOOKUPS
-- =============================================================================

CREATE TABLE LossType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_LossType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_LossType_TypeName UNIQUE (TypeName)
);

INSERT INTO LossType (TypeName) VALUES
    ('Spouse / Partner Loss'),
    ('Parent Loss - Mother'),
    ('Parent Loss - Father'),
    ('Sibling Loss'),
    ('Grandparent Loss'),
    ('Bereaved Parent'),
    ('Bereaved Grandparent'),
    ('Suicide Loss'),
    ('Homicide Loss'),
    ('Pet / Animal Companion Loss'),
    ('Anticipatory Grief'),
    ('Aging and Loss'),
    ('Divorce - Children and Families'),
    ('Divorce - Other'),
    ('Non-Death Loss'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE DeceasedType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_DeceasedType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_DeceasedType_TypeName UNIQUE (TypeName)
);

INSERT INTO DeceasedType (TypeName) VALUES
    ('Person'),
    ('Pet / Animal Companion');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE CauseOfDeathType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_CauseOfDeathType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_CauseOfDeathType_TypeName UNIQUE (TypeName)
);

-- Covers both human and animal causes of death
INSERT INTO CauseOfDeathType (TypeName) VALUES
    ('Natural Causes'),
    ('Illness / Disease'),
    ('Accident'),
    ('Suicide'),
    ('Homicide'),
    ('Euthanasia'),        -- Animal companion context
    ('Unknown'),
    ('Prefer Not to Say'),
    ('Other');
GO

-- =============================================================================
-- SECTION 5: DONOR AND PAYMENT LOOKUPS
-- =============================================================================

CREATE TABLE DonorStatus (
    StatusID    INT             NOT NULL IDENTITY(1,1),
    StatusName  NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_DonorStatus PRIMARY KEY (StatusID),
    CONSTRAINT UQ_DonorStatus_StatusName UNIQUE (StatusName)
);

INSERT INTO DonorStatus (StatusName) VALUES
    ('Prospect'),
    ('Active'),
    ('Lapsed'),            -- Has given before but not in current cycle
    ('Inactive'),
    ('Deceased');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE DonorType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_DonorType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_DonorType_TypeName UNIQUE (TypeName)
);

INSERT INTO DonorType (TypeName) VALUES
    ('Individual'),
    ('Corporate'),
    ('Foundation'),
    ('Grant Funder'),
    ('Community Fund'),    -- e.g. Benevity Community Impact Fund
    ('Service Club'),
    ('Faith Organization'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE PaymentMethodType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_PaymentMethodType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_PaymentMethodType_TypeName UNIQUE (TypeName)
);

INSERT INTO PaymentMethodType (TypeName) VALUES
    ('Cash'),
    ('Check'),
    ('Credit Card'),
    ('Electronic Funds Transfer'),
    ('Stock / Securities'),
    ('Planned Gift / Bequest'),
    ('In-Kind'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE AllocationType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_AllocationType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_AllocationType_TypeName UNIQUE (TypeName)
);

-- Used to split a single payment across multiple purposes.
-- CampaignID and ScholarshipFundID on PaymentAllocation provide the
-- specific designation; AllocationType captures the broad category.
INSERT INTO AllocationType (TypeName) VALUES
    ('Donation - General'),
    ('Donation - Campaign Designated'),
    ('Donation - Scholarship Fund'),
    ('Group Fee'),
    ('BST Fee'),
    ('Educational Session Fee'),
    ('Memorial Grove Fee'),
    ('Other Fee');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE FeeType (
    FeeTypeID   INT             NOT NULL IDENTITY(1,1),
    FeeTypeName NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_FeeType PRIMARY KEY (FeeTypeID),
    CONSTRAINT UQ_FeeType_FeeTypeName UNIQUE (FeeTypeName)
);

INSERT INTO FeeType (FeeTypeName) VALUES
    ('Group Fee'),
    ('BST Fee'),
    ('Educational Session Fee'),
    ('Memorial Grove Fee'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

-- v5: Campaign model replaces hardcoded ILOF as a mailing type.
-- ILOF (In Lieu Of Flowers) is now a Campaign record of type
-- 'In Lieu Of Flowers Fundraising Campaign'. All fundraising appeals
-- are modeled as Campaigns, keeping the system extensible.

CREATE TABLE CampaignType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_CampaignType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_CampaignType_TypeName UNIQUE (TypeName)
);

INSERT INTO CampaignType (TypeName) VALUES
    ('In Lieu Of Flowers'),   -- Memorial fundraising campaign
    ('Year End Appeal'),
    ('Giving Tuesday'),
    ('BST Scholarship Campaign'),
    ('Memorial Fund'),
    ('Capital Campaign'),
    ('General Appeal'),
    ('Other');
GO

-- =============================================================================
-- SECTION 6: MAILING LOOKUPS
-- =============================================================================

CREATE TABLE MailingType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_MailingType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_MailingType_TypeName UNIQUE (TypeName)
);

-- ILOF removed from mailing types in v5 - now modeled as a Campaign.
-- Based on mailing preference flags from the data entry conventions document.
INSERT INTO MailingType (TypeName) VALUES
    ('Newsletter'),
    ('Annual Report'),
    ('Holiday Ask'),
    ('Holiday Card'),
    ('Event Invitation'),
    ('Other');
GO

-- =============================================================================
-- SECTION 7: ENCOUNTER LOOKUPS
-- =============================================================================

-- v5: Interaction table eliminated. Encounter is now the single universal
-- record for all meaningful staff contacts regardless of role.
-- EncounterType covers intake calls, volunteer interviews, donor meetings,
-- facilitator vetting conversations, and lightweight touchpoints.
-- IsLightweight on the Encounter table flags quick touchpoints that do
-- not require full documentation.

CREATE TABLE EncounterType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_EncounterType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_EncounterType_TypeName UNIQUE (TypeName)
);

INSERT INTO EncounterType (TypeName) VALUES
    -- Client contacts
    ('Client Intake'),
    ('Client Follow Up'),
    ('Client Check In'),
    ('Resource Referral'),
    -- Volunteer contacts
    ('Volunteer Inquiry'),
    ('Volunteer Interview'),
    ('Volunteer Training Discussion'),
    ('Facilitator Vetting'),
    ('Facilitator Development'),
    -- Donor contacts
    ('Donor Stewardship'),
    ('Donor Acknowledgement'),
    ('Grant Discussion'),
    -- Outreach and general
    ('Outreach Contact'),
    ('Walk In'),
    ('General Inquiry'),
    -- Lightweight touchpoints (use with IsLightweight = 1)
    ('Quick Touchpoint'),   -- Reminder call, attendance confirmation, etc.
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE NoteType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_NoteType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_NoteType_TypeName UNIQUE (TypeName)
);

-- v5: 'Clinical' replaced with 'Program' - the organization is not a
-- clinical provider and the terminology should remain neutral regarding
-- licensure. 'Program' captures service-related notes accurately.
INSERT INTO NoteType (TypeName) VALUES
    ('General'),
    ('Program'),            -- Service delivery and program participation notes
    ('Administrative'),
    ('Volunteer'),
    ('Facilitator Development'),
    ('Board'),
    ('Outreach'),
    ('Follow Up Required'),
    ('Sensitive'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE ReferralType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_ReferralType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_ReferralType_TypeName UNIQUE (TypeName)
);

INSERT INTO ReferralType (TypeName) VALUES
    ('For Self'),
    ('For Child / Youth'),
    ('For Teen'),
    ('For Spouse / Partner'),
    ('For Parent'),
    ('For Other Family Member'),
    ('Professional - For Client'),
    ('Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE ReferralSource (
    SourceID    INT             NOT NULL IDENTITY(1,1),
    SourceName  NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_ReferralSource PRIMARY KEY (SourceID),
    CONSTRAINT UQ_ReferralSource_SourceName UNIQUE (SourceName)
);

-- v5: 'Doctor' replaced with 'Medical Professional' to include dentists,
-- nurses, PAs, social workers, resource specialists, and all other
-- healthcare providers who may refer clients.
-- Based on TbLkpReferralSource from legacy system with corrections.
INSERT INTO ReferralSource (SourceName) VALUES
    ('Agency'),
    ('Medical Professional'),  -- Replaces 'Doctor' - includes all healthcare providers
    ('Mental Health Professional'),
    ('Hospice'),
    ('Hospital Staff'),
    ('School Counselor'),
    ('Social Worker'),
    ('Funeral Home'),
    ('Faith Community'),
    ('Former Client'),
    ('Friend'),
    ('Relative'),
    ('Internet'),
    ('Newspaper / Media'),
    ('WinterSpring Outreach Event'),
    ('Other');
GO

-- =============================================================================
-- SECTION 8: OUTCOME LOOKUPS
-- =============================================================================

CREATE TABLE OutcomeType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_OutcomeType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_OutcomeType_TypeName UNIQUE (TypeName)
);

-- Based on TbLkpOutcome from legacy system
INSERT INTO OutcomeType (TypeName) VALUES
    ('1-on-1 Referral'),
    ('Custom Referral List Sent'),
    ('Group Referral'),
    ('Literature Sent'),
    ('Online Literature Referral'),
    ('Other Agency Referral'),
    ('Other');
GO

-- =============================================================================
-- SECTION 9: FACILITATOR LOOKUPS
-- =============================================================================

CREATE TABLE FacilitatorType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_FacilitatorType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_FacilitatorType_TypeName UNIQUE (TypeName)
);

-- Whether this facilitator is serving in a Staff or Volunteer capacity
INSERT INTO FacilitatorType (TypeName) VALUES
    ('Staff'),
    ('Volunteer');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE FacilitatorStatus (
    StatusID    INT             NOT NULL IDENTITY(1,1),
    StatusName  NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_FacilitatorStatus PRIMARY KEY (StatusID),
    CONSTRAINT UQ_FacilitatorStatus_StatusName UNIQUE (StatusName)
);

INSERT INTO FacilitatorStatus (StatusName) VALUES
    ('In Training'),      -- Serving as Co-Facilitator, building toward lead
    ('Qualified'),        -- Cleared for both seats
    ('Active'),           -- Currently assigned to a group
    ('Inactive'),
    ('On Leave');
GO

-- =============================================================================
-- SECTION 10: PROGRAM AND GROUP LOOKUPS
-- =============================================================================

-- v5: ProgramType sits above PeerSupportGroupType, making group types
-- subtypes of broader program categories. This accommodates future growth
-- (BST Training, Children's Programs, Workshops, Memorial Events) without
-- schema changes.

CREATE TABLE ProgramType (
    ProgramTypeID   INT             NOT NULL IDENTITY(1,1),
    ProgramTypeName NVARCHAR(150)   NOT NULL,
    Description     NVARCHAR(MAX)   NULL,
    CONSTRAINT PK_ProgramType PRIMARY KEY (ProgramTypeID),
    CONSTRAINT UQ_ProgramType_ProgramTypeName UNIQUE (ProgramTypeName)
);

INSERT INTO ProgramType (ProgramTypeName, Description) VALUES
    ('Peer Support Group',      'Ongoing grief support groups facilitated by trained staff or volunteers'),
    ('BST Training',            'Bereavement Skills Training for volunteer facilitators'),
    ('Childrens Program',       'Programs specifically designed for child and youth grief support'),
    ('Expressive Arts',         'Programs using creative modalities such as drama, art, music, writing, movement, and storytelling'),
    ('Workshop',                'Single or multi-session educational or skill-building events'),
    ('Memorial Event',          'Events honoring those who have died, including ILOF'),
    ('Community Outreach',      'Presentations and outreach to schools, faith communities, and other organizations'),
    ('Other',                   NULL);
GO

-- -----------------------------------------------------------------------------

CREATE TABLE PeerSupportGroupType (
    TypeID          INT             NOT NULL IDENTITY(1,1),
    ProgramTypeID   INT             NOT NULL,   -- FK to ProgramType
    TypeName        NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_PeerSupportGroupType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_PeerSupportGroupType_TypeName UNIQUE (TypeName),
    CONSTRAINT FK_PeerSupportGroupType_ProgramType
        FOREIGN KEY (ProgramTypeID) REFERENCES ProgramType(ProgramTypeID)
);

-- v5: 'Theatre Troupe' replaced with 'Expressive Arts' to model the
-- underlying business concept rather than a specific historical program.
-- Future programs (drama, art, music, movement, storytelling) fit naturally
-- without schema changes.
INSERT INTO PeerSupportGroupType (ProgramTypeID, TypeName) VALUES
    (1, 'Spouse / Partner Loss'),
    (1, 'Child Loss'),
    (1, 'Parent Loss'),
    (1, 'Sibling Loss'),
    (1, 'Suicide Loss'),
    (1, 'Homicide Loss'),
    (1, 'Pet / Animal Companion Loss'),
    (1, 'Bereaved Parent'),
    (1, 'Bereaved Grandparent'),
    (1, 'Anticipatory Grief'),
    (1, 'Aging and Loss'),
    (1, 'Teen Grief'),
    (1, 'Child / Youth Grief'),
    (1, 'General Grief'),
    (4, 'Expressive Arts'),   -- ProgramType 4 = Expressive Arts
    (1, 'Other');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE EnrollmentStatus (
    StatusID    INT             NOT NULL IDENTITY(1,1),
    StatusName  NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_EnrollmentStatus PRIMARY KEY (StatusID),
    CONSTRAINT UQ_EnrollmentStatus_StatusName UNIQUE (StatusName)
);

-- v5: 'Waitlisted' corrected to 'Waitlist' for consistent noun-based
-- status naming convention throughout the schema.
INSERT INTO EnrollmentStatus (StatusName) VALUES
    ('Waitlist'),
    ('Enrolled'),
    ('Completed'),
    ('Withdrawn'),
    ('Removed');
GO

-- -----------------------------------------------------------------------------

CREATE TABLE AttendanceStatus (
    StatusID    INT             NOT NULL IDENTITY(1,1),
    StatusName  NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_AttendanceStatus PRIMARY KEY (StatusID),
    CONSTRAINT UQ_AttendanceStatus_StatusName UNIQUE (StatusName)
);

-- 'Late' omitted per design decision: showing up is what matters
-- in a grief support context. Late could feel judgmental in this setting.
INSERT INTO AttendanceStatus (StatusName) VALUES
    ('Present'),
    ('Absent - Notified'),
    ('Absent - No Contact');
GO

-- =============================================================================
-- SECTION 11: OUTREACH LOOKUPS
-- =============================================================================

CREATE TABLE OutreachEventType (
    TypeID      INT             NOT NULL IDENTITY(1,1),
    TypeName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_OutreachEventType PRIMARY KEY (TypeID),
    CONSTRAINT UQ_OutreachEventType_TypeName UNIQUE (TypeName)
);

INSERT INTO OutreachEventType (TypeName) VALUES
    ('Community Presentation'),
    ('Church / Faith Organization'),
    ('School Presentation'),
    ('Memorial Event'),
    ('Expressive Arts Performance'),
    ('Health Fair'),
    ('Volunteer Recruitment'),
    ('Other');
GO

-- =============================================================================
-- SECTION 12: CONFIGURATION
-- =============================================================================

CREATE TABLE OrgConfiguration (
    ConfigID                INT             NOT NULL IDENTITY(1,1),
    ConfigKey               NVARCHAR(100)   NOT NULL,
    ConfigValue             NVARCHAR(255)   NOT NULL,
    Description             NVARCHAR(MAX)   NULL,
    LastUpdatedByStaffID    INT             NULL,   -- FK added after Staff table is created
    LastUpdatedDate         DATE            NULL,
    CONSTRAINT PK_OrgConfiguration PRIMARY KEY (ConfigID),
    CONSTRAINT UQ_OrgConfiguration_ConfigKey UNIQUE (ConfigKey)
);

-- Seed with initial business rules.
-- Values should be reviewed and confirmed by the organization.
INSERT INTO OrgConfiguration (ConfigKey, ConfigValue, Description) VALUES
    ('MinCoFacilitatorSessions',    '6',    'Minimum sessions as Co-Facilitator before consideration for lead Facilitator role'),
    ('MajorDonorThreshold',         '500',  'Minimum single donation in dollars qualifying as a major gift - triggers Holiday Card mailing preference'),
    ('VIPDonorThreshold',           '10000','Minimum single donation in dollars qualifying as a VIP donor gift'),
    ('DefaultInviteToGroups',       '1',    'Default for InviteToGroups on new ClientInformation records. 1 = group-ready unless staff sets to 0'),
    ('BackgroundCheckRequiredDays', '0',    'Days after background check submission before facilitator may be cleared. 0 = cleared upon report receipt'),
    ('GroupFeeFullAmount',          '40',   'Standard full fee per group session in dollars'),
    ('BSTFeeFullAmount',            '150',  'Standard full Bereavement Skills Training fee in dollars'),
    ('BSTFeeScholarshipAmount',     '75',   'Scholarship Bereavement Skills Training fee in dollars');
GO
