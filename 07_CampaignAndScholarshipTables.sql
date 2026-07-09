-- =============================================================================
-- GriefSupportDB
-- Script 07: Campaign and Scholarship Tables
-- Description: Fundraising campaign tracking and BST scholarship fund
--              management. This script also adds the deferred FK constraints
--              to PaymentAllocation for CampaignID and ScholarshipFundID.
-- Version:     v5 - Business Process Normalization
-- Author:      Steve Del Valle
-- Dependencies: 01_LookupTables.sql, 02_CoreProfile.sql, 03_RoleTables.sql,
--               04_TransactionalTables.sql
--
-- Design principle: Model the underlying business process, not specific
-- program names. ILOF (In Lieu Of Flowers) is a Campaign, not a mailing type.
-- BST scholarships are a fund that can receive designated donations and
-- make awards to recipients. Future campaigns and funds fit without schema
-- changes.
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- SECTION 1: CAMPAIGN
-- Represents any fundraising campaign or appeal the organization runs.
-- Examples: In Lieu Of Flowers, Year End Appeal, Giving Tuesday,
--           BST Scholarship Campaign, Memorial Fund drive.
-- PaymentAllocation can optionally point to a Campaign so donations
-- are designated and reportable by campaign.
-- =============================================================================

CREATE TABLE Campaign (
    CampaignID          INT             NOT NULL IDENTITY(1,1),
    CampaignTypeID      INT             NOT NULL,
    CampaignName        NVARCHAR(255)   NOT NULL,
    Description         NVARCHAR(MAX)   NULL,
    StartDate           DATE            NULL,
    EndDate             DATE            NULL,
    IsActive            BIT             NOT NULL CONSTRAINT DF_Campaign_IsActive DEFAULT 1,
    CreatedByStaffID    INT             NULL,

    CONSTRAINT PK_Campaign PRIMARY KEY (CampaignID),

    CONSTRAINT FK_Campaign_CampaignType
        FOREIGN KEY (CampaignTypeID) REFERENCES CampaignType(TypeID),

    CONSTRAINT FK_Campaign_CreatedByStaff
        FOREIGN KEY (CreatedByStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT CK_Campaign_DateRange
        CHECK (EndDate IS NULL OR StartDate IS NULL OR EndDate >= StartDate)
);
GO

CREATE NONCLUSTERED INDEX IX_Campaign_CampaignTypeID
    ON Campaign (CampaignTypeID);
GO

CREATE NONCLUSTERED INDEX IX_Campaign_IsActive
    ON Campaign (IsActive);
GO

-- Seed with the organization's known standing campaigns
-- Dates left NULL until confirmed by organization
INSERT INTO Campaign (CampaignTypeID, CampaignName, Description, IsActive)
VALUES
    (1, 'In Lieu Of Flowers',
        'Annual memorial fundraising campaign. Families are invited to direct memorial gifts to the organization in lieu of flowers.',
        1),
    (4, 'BST Scholarship Campaign',
        'Ongoing campaign to fund Bereavement Skills Training scholarships for volunteers who cannot afford the full training fee.',
        1);
GO

-- =============================================================================
-- SECTION 2: SCHOLARSHIP FUND
-- A ScholarshipFund is a designated pool of money contributed by donors
-- for a specific scholarship purpose. It is optionally linked to a Campaign
-- that raised the funds.
--
-- Fund balance reporting (total donated vs. total awarded vs. remaining)
-- is handled by views and queries against PaymentAllocation and
-- ScholarshipAward rather than stored as a balance field, which would
-- become stale and inconsistent.
-- =============================================================================

CREATE TABLE ScholarshipFund (
    ScholarshipFundID   INT             NOT NULL IDENTITY(1,1),
    CampaignID          INT             NULL,       -- Optional: campaign that raised these funds
    FundName            NVARCHAR(255)   NOT NULL,
    Description         NVARCHAR(MAX)   NULL,
    IsActive            BIT             NOT NULL CONSTRAINT DF_ScholarshipFund_IsActive DEFAULT 1,
    CreatedByStaffID    INT             NULL,

    CONSTRAINT PK_ScholarshipFund PRIMARY KEY (ScholarshipFundID),

    CONSTRAINT FK_ScholarshipFund_Campaign
        FOREIGN KEY (CampaignID) REFERENCES Campaign(CampaignID),

    CONSTRAINT FK_ScholarshipFund_CreatedByStaff
        FOREIGN KEY (CreatedByStaffID) REFERENCES Staff(StaffID)
);
GO

-- Seed with the BST Scholarship Fund
INSERT INTO ScholarshipFund (CampaignID, FundName, Description, IsActive)
VALUES
    (2, 'BST Scholarship Fund',
        'Funds Bereavement Skills Training scholarships for volunteer facilitator candidates who cannot afford the full training fee. Donors may designate gifts to this fund.',
        1);
GO

-- =============================================================================
-- SECTION 3: SCHOLARSHIP AWARD
-- Records individual scholarship awards made from a ScholarshipFund to
-- a recipient. The recipient is identified by ContactID (linking to
-- ContactInformation) rather than VolunteerID because the award may
-- be made before the person has completed their volunteer onboarding.
-- FeeID links to FeeSchedule to record which fee the scholarship covers.
-- ApprovedByStaffID provides accountability for each award decision.
-- =============================================================================

CREATE TABLE ScholarshipAward (
    AwardID             INT             NOT NULL IDENTITY(1,1),
    ScholarshipFundID   INT             NOT NULL,
    ContactID           INT             NOT NULL,   -- Award recipient
    FeeID               INT             NOT NULL,   -- Which fee this covers
    AwardAmount         DECIMAL(10,2)   NOT NULL,
    AwardDate           DATE            NOT NULL,
    ApprovedByStaffID   INT             NULL,
    Notes               NVARCHAR(MAX)   NULL,

    CONSTRAINT PK_ScholarshipAward PRIMARY KEY (AwardID),

    CONSTRAINT FK_ScholarshipAward_ScholarshipFund
        FOREIGN KEY (ScholarshipFundID) REFERENCES ScholarshipFund(ScholarshipFundID),

    CONSTRAINT FK_ScholarshipAward_ContactInformation
        FOREIGN KEY (ContactID) REFERENCES ContactInformation(ContactID),

    CONSTRAINT FK_ScholarshipAward_FeeSchedule
        FOREIGN KEY (FeeID) REFERENCES FeeSchedule(FeeID),

    CONSTRAINT FK_ScholarshipAward_ApprovedByStaff
        FOREIGN KEY (ApprovedByStaffID) REFERENCES Staff(StaffID),

    CONSTRAINT CK_ScholarshipAward_Amount
        CHECK (AwardAmount > 0)
);
GO

CREATE NONCLUSTERED INDEX IX_ScholarshipAward_ScholarshipFundID
    ON ScholarshipAward (ScholarshipFundID);
GO

CREATE NONCLUSTERED INDEX IX_ScholarshipAward_ContactID
    ON ScholarshipAward (ContactID);
GO

-- =============================================================================
-- SECTION 4: DEFERRED FK CONSTRAINTS ON PAYMENTALLOCATION
-- Now that Campaign and ScholarshipFund exist, add the FK constraints
-- that were deferred in Script 04. This maintains correct dependency order
-- while keeping all PaymentAllocation columns defined together.
-- =============================================================================

ALTER TABLE PaymentAllocation
    ADD CONSTRAINT FK_PaymentAllocation_Campaign
        FOREIGN KEY (CampaignID) REFERENCES Campaign(CampaignID);
GO

ALTER TABLE PaymentAllocation
    ADD CONSTRAINT FK_PaymentAllocation_ScholarshipFund
        FOREIGN KEY (ScholarshipFundID) REFERENCES ScholarshipFund(ScholarshipFundID);
GO
