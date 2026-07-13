-- =============================================================================
-- GriefSupportDB
-- A comprehensive SQL Server database architecture designed to modernize the
-- information system of a grief support nonprofit. Drawing on real-world
-- operational experience with a legacy system, the project reimagines how
-- clients, volunteers, facilitators, donors, staff, programs, and fundraising
-- activities can be managed within a flexible, scalable, and maintainable
-- relational database.
-- =============================================================================
-- Script 09: Stored Procedures — Payment Processing
-- Description: Procedures for recording payments, allocating funds across
--              fees and donations, managing tax acknowledgements, and
--              automating mailing preferences based on giving history.
--              The payment model solves the split-payment problem
--              documented in the Credit Card Process workflow — a single
--              check covering both a fee and a donation now has a clean,
--              accurate home.
-- Version:     v5
-- Author:      Steve Del Valle
-- Dependencies: 01 through 08 must be run first
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- PROCEDURE 1: usp_RecordPayment
-- Purpose:  Record a physical payment transaction and one or more
--           allocations in a single atomic operation.
--           Enforces that the sum of all allocations equals the
--           payment total before committing.
--           Automatically sets mailing preferences based on donation
--           amounts per OrgConfiguration business rules.
--           Returns PaymentID and a list of AllocationIDs.
--
-- The @Allocations parameter uses a table-valued approach via a temp
-- table that the caller populates before executing. See usage example
-- below the procedure.
--
-- Usage example:
--   -- Step 1: Create the allocation temp table
--   CREATE TABLE #Allocations (
--       AllocationTypeID    INT,
--       FeeID               INT,
--       CampaignID          INT,
--       ScholarshipFundID   INT,
--       Amount              DECIMAL(10,2),
--       IsTaxDeductible     BIT,
--       IsScholarship       BIT,
--       ScholarshipAmount   DECIMAL(10,2),
--       DonorID             INT,
--       FeeDescription      NVARCHAR(255)
--   );
--
--   -- Step 2: Insert allocations
--   INSERT INTO #Allocations VALUES (4, 1, NULL, NULL, 40.00, 0, 0, NULL, NULL, 'Group Fee');
--   INSERT INTO #Allocations VALUES (1, NULL, NULL, NULL, 60.00, 1, 0, NULL, 7, 'General Donation');
--
--   -- Step 3: Execute
--   EXEC usp_RecordPayment
--       @ContactID = 101, @PaymentMethodTypeID = 2,
--       @PaymentDate = '2024-03-15', @TotalAmount = 100.00,
--       @CheckNumber = '1042', @ReceivedByStaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_RecordPayment
    @ContactID              INT,
    @PaymentMethodTypeID    INT,
    @PaymentDate            DATE            = NULL,
    @TotalAmount            DECIMAL(10,2),
    @CheckNumber            NVARCHAR(50)    = NULL,
    @ReceivedByStaffID      INT             = NULL,
    @CreatedByStaffID       INT             = NULL,
    @NewPaymentID           INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Verify contact exists
    IF NOT EXISTS (
        SELECT 1 FROM ContactInformation WHERE ContactID = @ContactID
    )
    BEGIN
        RAISERROR('ContactID %d does not exist.', 16, 1, @ContactID);
        RETURN;
    END

    -- Validate total amount
    IF @TotalAmount <= 0
    BEGIN
        RAISERROR('Payment TotalAmount must be greater than zero.', 16, 1);
        RETURN;
    END

    -- Verify allocation temp table exists and has rows
    IF OBJECT_ID('tempdb..#Allocations') IS NULL
    BEGIN
        RAISERROR('Temp table #Allocations must be created and populated before calling usp_RecordPayment.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM #Allocations)
    BEGIN
        RAISERROR('At least one allocation must be provided in #Allocations.', 16, 1);
        RETURN;
    END

    -- Verify allocations sum to total amount
    DECLARE @AllocationSum DECIMAL(10,2);
    SELECT @AllocationSum = SUM(Amount) FROM #Allocations;

    IF @AllocationSum <> @TotalAmount
    BEGIN
        DECLARE @AllocationSumStr VARCHAR(20) = CONVERT(VARCHAR(20), @AllocationSum);
        DECLARE @TotalAmountStr   VARCHAR(20) = CONVERT(VARCHAR(20), @TotalAmount);

        RAISERROR(
            'Allocation sum (%s) does not equal TotalAmount (%s). All funds must be allocated.',
            16, 1,
            @AllocationSumStr,
            @TotalAmountStr
        );
        RETURN;
    END

    IF @PaymentDate IS NULL
        SET @PaymentDate = CAST(GETDATE() AS DATE);

    BEGIN TRANSACTION;

    BEGIN TRY

        -- Create the Payment record
        INSERT INTO Payment (
            ContactID,
            PaymentMethodTypeID,
            PaymentDate,
            TotalAmount,
            CheckNumber,
            ReceivedByStaffID,
            AcknowledgementSent,
            CreatedByStaffID,
            CreatedDate
        )
        VALUES (
            @ContactID,
            @PaymentMethodTypeID,
            @PaymentDate,
            @TotalAmount,
            @CheckNumber,
            @ReceivedByStaffID,
            0,  -- AcknowledgementSent: false until sent
            @CreatedByStaffID,
            CAST(GETDATE() AS DATE)
        );

        SET @NewPaymentID = SCOPE_IDENTITY();

        -- Insert all allocations from temp table
        INSERT INTO PaymentAllocation (
            PaymentID,
            AllocationTypeID,
            FeeID,
            CampaignID,
            ScholarshipFundID,
            Amount,
            IsTaxDeductible,
            IsScholarship,
            ScholarshipAmount,
            DonorID,
            FeeDescription
        )
        SELECT
            @NewPaymentID,
            AllocationTypeID,
            FeeID,
            CampaignID,
            ScholarshipFundID,
            Amount,
            IsTaxDeductible,
            IsScholarship,
            ScholarshipAmount,
            DonorID,
            FeeDescription
        FROM #Allocations;

        -- Apply mailing preferences based on donation amounts
        -- Business rules are read from OrgConfiguration so they
        -- can be updated without changing this procedure
        EXEC usp_ApplyMailingPreferencesFromPayment
            @PaymentID          = @NewPaymentID,
            @ContactID          = @ContactID,
            @SetByStaffID       = @CreatedByStaffID;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================================================
-- PROCEDURE 2: usp_ApplyMailingPreferencesFromPayment
-- Purpose:  Automatically set mailing preferences based on payment
--           allocations and OrgConfiguration business rules.
--           Called internally by usp_RecordPayment but can also be
--           called manually to recalculate preferences.
--
--           Business rules implemented:
--           - Any donation → Newsletter, Annual Report, Holiday Ask, ILOF
--           - Donation >= MajorDonorThreshold → also Holiday Card
--           - Grant funder → Newsletter, Annual Report
--           - BST full fee → Newsletter, Annual Report, Holiday Ask, ILOF
--           - BST scholarship fee → Newsletter, Annual Report
--           - Group full fee → Newsletter, Annual Report, Holiday Ask, ILOF
--           - Group scholarship fee → Newsletter, Annual Report
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_ApplyMailingPreferencesFromPayment
    @PaymentID      INT,
    @ContactID      INT,
    @SetByStaffID   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Read thresholds from OrgConfiguration
    DECLARE @MajorDonorThreshold    DECIMAL(10,2);
    DECLARE @Today                  DATE = CAST(GETDATE() AS DATE);

    SELECT @MajorDonorThreshold = CAST(ConfigValue AS DECIMAL(10,2))
    FROM OrgConfiguration
    WHERE ConfigKey = 'MajorDonorThreshold';

    -- Get the total donation amount from this payment
    DECLARE @TotalDonationAmount DECIMAL(10,2) = 0;
    SELECT @TotalDonationAmount = ISNULL(SUM(Amount), 0)
    FROM PaymentAllocation
    WHERE PaymentID = @PaymentID
    AND IsTaxDeductible = 1;

    -- Get BST fee allocations
    DECLARE @BSTFullFee         DECIMAL(10,2) = 0;
    DECLARE @BSTScholarship     BIT = 0;

    SELECT
        @BSTFullFee     = ISNULL(SUM(CASE WHEN IsScholarship = 0 THEN Amount ELSE 0 END), 0),
        @BSTScholarship = CASE WHEN MAX(CAST(IsScholarship AS INT)) = 1 THEN 1 ELSE 0 END
    FROM PaymentAllocation pa
    JOIN AllocationType at ON pa.AllocationTypeID = at.TypeID
    WHERE pa.PaymentID = @PaymentID
    AND at.TypeName = 'BST Fee';

    -- Get Group fee allocations
    DECLARE @GroupFullFee       DECIMAL(10,2) = 0;
    DECLARE @GroupScholarship   BIT = 0;

    SELECT
        @GroupFullFee       = ISNULL(SUM(CASE WHEN IsScholarship = 0 THEN Amount ELSE 0 END), 0),
        @GroupScholarship   = CASE WHEN MAX(CAST(IsScholarship AS INT)) = 1 THEN 1 ELSE 0 END
    FROM PaymentAllocation pa
    JOIN AllocationType at ON pa.AllocationTypeID = at.TypeID
    WHERE pa.PaymentID = @PaymentID
    AND at.TypeName = 'Group Fee';

    -- Helper: set a mailing preference if not already set
    -- OptedIn = 1, records reason for audit trail
    DECLARE @Reason NVARCHAR(500);

    -- Any donation triggers: Newsletter, Annual Report, Holiday Ask
    IF @TotalDonationAmount > 0
    BEGIN
        SET @Reason = 'Donation received on ' + CAST(@Today AS NVARCHAR(20));

        EXEC usp_SetMailingPreference @ContactID, 'Newsletter',    1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Annual Report', 1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Holiday Ask',   1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Event Invitation', 1, @Reason, @SetByStaffID;
    END

    -- Major gift also triggers Holiday Card
    IF @TotalDonationAmount >= @MajorDonorThreshold
    BEGIN
        SET @Reason = 'Major gift of $' + CAST(@TotalDonationAmount AS NVARCHAR(20))
                    + ' received on ' + CAST(@Today AS NVARCHAR(20));
        EXEC usp_SetMailingPreference @ContactID, 'Holiday Card', 1, @Reason, @SetByStaffID;
    END

    -- BST full fee: Newsletter, Annual Report, Holiday Ask, Event Invitation
    IF @BSTFullFee > 0 AND @BSTScholarship = 0
    BEGIN
        SET @Reason = 'BST full fee received on ' + CAST(@Today AS NVARCHAR(20));
        EXEC usp_SetMailingPreference @ContactID, 'Newsletter',       1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Annual Report',    1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Holiday Ask',      1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Event Invitation', 1, @Reason, @SetByStaffID;
    END

    -- BST scholarship fee: Newsletter, Annual Report only
    IF @BSTScholarship = 1
    BEGIN
        SET @Reason = 'BST scholarship fee received on ' + CAST(@Today AS NVARCHAR(20));
        EXEC usp_SetMailingPreference @ContactID, 'Newsletter',    1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Annual Report', 1, @Reason, @SetByStaffID;
    END

    -- Group full fee: Newsletter, Annual Report, Holiday Ask, Event Invitation
    IF @GroupFullFee > 0 AND @GroupScholarship = 0
    BEGIN
        SET @Reason = 'Group full fee received on ' + CAST(@Today AS NVARCHAR(20));
        EXEC usp_SetMailingPreference @ContactID, 'Newsletter',       1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Annual Report',    1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Holiday Ask',      1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Event Invitation', 1, @Reason, @SetByStaffID;
    END

    -- Group scholarship fee: Newsletter, Annual Report only
    IF @GroupScholarship = 1
    BEGIN
        SET @Reason = 'Group scholarship fee received on ' + CAST(@Today AS NVARCHAR(20));
        EXEC usp_SetMailingPreference @ContactID, 'Newsletter',    1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Annual Report', 1, @Reason, @SetByStaffID;
    END

END
GO

-- =============================================================================
-- PROCEDURE 3: usp_SetMailingPreference
-- Purpose:  Set or update a single mailing preference for a contact.
--           Called internally by usp_ApplyMailingPreferencesFromPayment
--           but also available for manual preference management.
--           Uses MERGE to insert if not exists, update if exists.
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_SetMailingPreference
    @ContactID      INT,
    @MailingTypeName NVARCHAR(100),
    @OptedIn        BIT             = 1,
    @OptedInReason  NVARCHAR(500)   = NULL,
    @SetByStaffID   INT             = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MailingTypeID  INT;
    DECLARE @Today          DATE = CAST(GETDATE() AS DATE);

    SELECT @MailingTypeID = TypeID
    FROM MailingType
    WHERE TypeName = @MailingTypeName;

    IF @MailingTypeID IS NULL
    BEGIN
        RAISERROR('MailingType "%s" not found.', 16, 1, @MailingTypeName);
        RETURN;
    END

    MERGE MailingPreference AS target
    USING (
        SELECT @ContactID AS ContactID, @MailingTypeID AS MailingTypeID
    ) AS source
    ON target.ContactID     = source.ContactID
    AND target.MailingTypeID = source.MailingTypeID
    WHEN MATCHED THEN
        UPDATE SET
            OptedIn         = @OptedIn,
            OptedInDate     = @Today,
            OptedInReason   = @OptedInReason,
            SetByStaffID    = @SetByStaffID
    WHEN NOT MATCHED THEN
        INSERT (ContactID, MailingTypeID, OptedIn, OptedInDate, OptedInReason, SetByStaffID)
        VALUES (@ContactID, @MailingTypeID, @OptedIn, @Today, @OptedInReason, @SetByStaffID);
END
GO

-- =============================================================================
-- PROCEDURE 4: usp_SendAcknowledgement
-- Purpose:  Mark a payment acknowledgement as sent and record the date.
--           Tax acknowledgements must be sent for all tax-deductible
--           donations. This procedure provides the audit record that
--           the acknowledgement was issued.
-- Usage:    EXEC usp_SendAcknowledgement @PaymentID = 42, @StaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_SendAcknowledgement
    @PaymentID      INT,
    @StaffID        INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM Payment WHERE PaymentID = @PaymentID
    )
    BEGIN
        RAISERROR('PaymentID %d does not exist.', 16, 1, @PaymentID);
        RETURN;
    END

    -- Only update if not already acknowledged
    IF EXISTS (
        SELECT 1 FROM Payment
        WHERE PaymentID = @PaymentID
        AND AcknowledgementSent = 1
    )
    BEGIN
        RAISERROR('PaymentID %d has already been acknowledged.', 16, 1, @PaymentID);
        RETURN;
    END

    UPDATE Payment
    SET
        AcknowledgementSent = 1,
        AcknowledgementDate = CAST(GETDATE() AS DATE),
        ModifiedDate        = CAST(GETDATE() AS DATE),
        ModifiedByStaffID   = @StaffID
    WHERE PaymentID = @PaymentID;

END
GO

-- =============================================================================
-- PROCEDURE 5: usp_GetDonorLevel
-- Purpose:  Calculate the current donor level for a contact based on
--           actual giving history. Donor level is always calculated
--           from data — never stored as a field that could go stale.
--
--           Returns: DonorLevel, TotalGivingAllTime, TotalGivingThisYear,
--                    LargestSingleGift, LastGiftDate, LastGiftAmount
--
--           Thresholds are read from OrgConfiguration:
--             MajorDonorThreshold (default $500)
--             VIPDonorThreshold   (default $10,000)
-- Usage:    EXEC usp_GetDonorLevel @ContactID = 101
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_GetDonorLevel
    @ContactID  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MajorThreshold DECIMAL(10,2);
    DECLARE @VIPThreshold   DECIMAL(10,2);

    SELECT @MajorThreshold = CAST(ConfigValue AS DECIMAL(10,2))
    FROM OrgConfiguration WHERE ConfigKey = 'MajorDonorThreshold';

    SELECT @VIPThreshold = CAST(ConfigValue AS DECIMAL(10,2))
    FROM OrgConfiguration WHERE ConfigKey = 'VIPDonorThreshold';

    SELECT
        c.ContactID,
        c.FirstName,
        c.LastName,
        c.OrganizationName,
        -- Total giving all time (tax deductible allocations only)
        ISNULL(SUM(pa.Amount), 0)                               AS TotalGivingAllTime,
        -- Total giving this calendar year
        ISNULL(SUM(CASE
            WHEN YEAR(p.PaymentDate) = YEAR(GETDATE())
            THEN pa.Amount ELSE 0
        END), 0)                                                AS TotalGivingThisYear,
        -- Largest single gift
        ISNULL(MAX(pa.Amount), 0)                               AS LargestSingleGift,
        -- Most recent gift
        MAX(p.PaymentDate)                                      AS LastGiftDate,
        -- Amount of most recent gift
        (
            SELECT TOP 1 pa2.Amount
            FROM PaymentAllocation pa2
            JOIN Payment p2 ON pa2.PaymentID = p2.PaymentID
            JOIN DonorInformation d2 ON pa2.DonorID = d2.DonorID
            WHERE d2.ContactID = c.ContactID
            AND pa2.IsTaxDeductible = 1
            ORDER BY p2.PaymentDate DESC
        )                                                       AS LastGiftAmount,
        -- Calculated donor level based on largest single gift
        CASE
            WHEN ISNULL(MAX(pa.Amount), 0) >= @VIPThreshold
                THEN 'VIP Donor ($' + CAST(@VIPThreshold AS NVARCHAR) + '+)'
            WHEN ISNULL(MAX(pa.Amount), 0) >= @MajorThreshold
                THEN 'Major Donor ($' + CAST(@MajorThreshold AS NVARCHAR) + '+)'
            WHEN ISNULL(SUM(CASE
                    WHEN YEAR(p.PaymentDate) = YEAR(GETDATE())
                    THEN pa.Amount ELSE 0 END), 0) > 0
                THEN 'Annual Fund Donor'
            WHEN ISNULL(SUM(pa.Amount), 0) > 0
                THEN 'Lapsed Donor'
            ELSE 'Prospect / No Giving History'
        END                                                     AS DonorLevel
    FROM ContactInformation c
    LEFT JOIN DonorInformation  d   ON c.ContactID     = d.ContactID
    LEFT JOIN PaymentAllocation pa  ON d.DonorID       = pa.DonorID
                                    AND pa.IsTaxDeductible = 1
    LEFT JOIN Payment           p   ON pa.PaymentID    = p.PaymentID
    WHERE c.ContactID = @ContactID
    GROUP BY
        c.ContactID,
        c.FirstName,
        c.LastName,
        c.OrganizationName;
END
GO

-- =============================================================================
-- PROCEDURE 6: usp_GetUnacknowledgedPayments
-- Purpose:  Return all payments with tax-deductible allocations that
--           have not yet had acknowledgements sent. Used to drive the
--           acknowledgement workflow so no donor misses a tax receipt.
-- Usage:    EXEC usp_GetUnacknowledgedPayments
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_GetUnacknowledgedPayments
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.PaymentID,
        p.PaymentDate,
        p.TotalAmount,
        c.FirstName,
        c.LastName,
        c.OrganizationName,
        c.Email,
        c.Phone,
        pmt.TypeName                        AS PaymentMethod,
        p.CheckNumber,
        -- Total deductible amount for the tax receipt
        SUM(pa.Amount)                      AS TaxDeductibleAmount,
        -- Days since payment with no acknowledgement
        DATEDIFF(DAY, p.PaymentDate, GETDATE()) AS DaysSincePayment
    FROM Payment p
    JOIN ContactInformation c   ON p.ContactID          = c.ContactID
    JOIN PaymentMethodType  pmt ON p.PaymentMethodTypeID = pmt.TypeID
    JOIN PaymentAllocation  pa  ON p.PaymentID          = pa.PaymentID
                                AND pa.IsTaxDeductible   = 1
    WHERE p.AcknowledgementSent = 0
    GROUP BY
        p.PaymentID,
        p.PaymentDate,
        p.TotalAmount,
        c.FirstName,
        c.LastName,
        c.OrganizationName,
        c.Email,
        c.Phone,
        pmt.TypeName,
        p.CheckNumber
    ORDER BY
        p.PaymentDate ASC;  -- Oldest first — longest waiting acknowledgements first
END
GO

-- =============================================================================
-- PROCEDURE 7: usp_RecordScholarshipAward
-- Purpose:  Record a scholarship award from a ScholarshipFund to a
--           recipient. Validates that the fund is active and that the
--           award amount does not exceed the available fund balance.
--           Fund balance is always calculated from actual records —
--           total donated minus total awarded — never stored as a
--           field that could become inaccurate.
-- Usage:    EXEC usp_RecordScholarshipAward
--               @ScholarshipFundID = 1, @ContactID = 205,
--               @FeeID = 2, @AwardAmount = 75.00,
--               @ApprovedByStaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_RecordScholarshipAward
    @ScholarshipFundID  INT,
    @ContactID          INT,
    @FeeID              INT,
    @AwardAmount        DECIMAL(10,2),
    @AwardDate          DATE            = NULL,
    @ApprovedByStaffID  INT             = NULL,
    @Notes              NVARCHAR(MAX)   = NULL,
    @NewAwardID         INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Verify fund is active
    IF NOT EXISTS (
        SELECT 1 FROM ScholarshipFund
        WHERE ScholarshipFundID = @ScholarshipFundID
        AND IsActive = 1
    )
    BEGIN
        RAISERROR('ScholarshipFundID %d does not exist or is not active.', 16, 1, @ScholarshipFundID);
        RETURN;
    END

    -- Calculate available fund balance
    -- Balance = total donations designated to fund minus total awards made
    DECLARE @TotalDonated   DECIMAL(10,2) = 0;
    DECLARE @TotalAwarded   DECIMAL(10,2) = 0;
    DECLARE @Balance        DECIMAL(10,2);

    SELECT @TotalDonated = ISNULL(SUM(pa.Amount), 0)
    FROM PaymentAllocation pa
    WHERE pa.ScholarshipFundID = @ScholarshipFundID;

    SELECT @TotalAwarded = ISNULL(SUM(AwardAmount), 0)
    FROM ScholarshipAward
    WHERE ScholarshipFundID = @ScholarshipFundID;

    SET @Balance = @TotalDonated - @TotalAwarded;

    IF @AwardAmount > @Balance
    BEGIN
        DECLARE @AwardAmountStr VARCHAR(20) = CONVERT(VARCHAR(20), @AwardAmount);
        DECLARE @BalanceStr     VARCHAR(20) = CONVERT(VARCHAR(20), @Balance);

        RAISERROR(
            'Award amount $%s exceeds available fund balance of $%s.',
            16, 1,
            @AwardAmountStr,
            @BalanceStr
        );
        RETURN;
    END

    IF @AwardDate IS NULL
        SET @AwardDate = CAST(GETDATE() AS DATE);

    INSERT INTO ScholarshipAward (
        ScholarshipFundID,
        ContactID,
        FeeID,
        AwardAmount,
        AwardDate,
        ApprovedByStaffID,
        Notes
    )
    VALUES (
        @ScholarshipFundID,
        @ContactID,
        @FeeID,
        @AwardAmount,
        @AwardDate,
        @ApprovedByStaffID,
        @Notes
    );

    SET @NewAwardID = SCOPE_IDENTITY();
END
GO
-- =============================================================================
-- GriefSupportDB
-- A comprehensive SQL Server database architecture designed to modernize the
-- information system of a grief support nonprofit. Drawing on real-world
-- operational experience with a legacy system, the project reimagines how
-- clients, volunteers, facilitators, donors, staff, programs, and fundraising
-- activities can be managed within a flexible, scalable, and maintainable
-- relational database.
-- =============================================================================
-- Script 09: Stored Procedures — Payment Processing
-- Description: Procedures for recording payments, allocating funds across
--              fees and donations, managing tax acknowledgements, and
--              automating mailing preferences based on giving history.
--              The payment model solves the split-payment problem
--              documented in the Credit Card Process workflow — a single
--              check covering both a fee and a donation now has a clean,
--              accurate home.
-- Version:     v5
-- Author:      Steve Del Valle
-- Dependencies: 01 through 08 must be run first
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- PROCEDURE 1: usp_RecordPayment
-- Purpose:  Record a physical payment transaction and one or more
--           allocations in a single atomic operation.
--           Enforces that the sum of all allocations equals the
--           payment total before committing.
--           Automatically sets mailing preferences based on donation
--           amounts per OrgConfiguration business rules.
--           Returns PaymentID and a list of AllocationIDs.
--
-- The @Allocations parameter uses a table-valued approach via a temp
-- table that the caller populates before executing. See usage example
-- below the procedure.
--
-- Usage example:
--   -- Step 1: Create the allocation temp table
--   CREATE TABLE #Allocations (
--       AllocationTypeID    INT,
--       FeeID               INT,
--       CampaignID          INT,
--       ScholarshipFundID   INT,
--       Amount              DECIMAL(10,2),
--       IsTaxDeductible     BIT,
--       IsScholarship       BIT,
--       ScholarshipAmount   DECIMAL(10,2),
--       DonorID             INT,
--       FeeDescription      NVARCHAR(255)
--   );
--
--   -- Step 2: Insert allocations
--   INSERT INTO #Allocations VALUES (4, 1, NULL, NULL, 40.00, 0, 0, NULL, NULL, 'Group Fee');
--   INSERT INTO #Allocations VALUES (1, NULL, NULL, NULL, 60.00, 1, 0, NULL, 7, 'General Donation');
--
--   -- Step 3: Execute
--   EXEC usp_RecordPayment
--       @ContactID = 101, @PaymentMethodTypeID = 2,
--       @PaymentDate = '2024-03-15', @TotalAmount = 100.00,
--       @CheckNumber = '1042', @ReceivedByStaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_RecordPayment
    @ContactID              INT,
    @PaymentMethodTypeID    INT,
    @PaymentDate            DATE            = NULL,
    @TotalAmount            DECIMAL(10,2),
    @CheckNumber            NVARCHAR(50)    = NULL,
    @ReceivedByStaffID      INT             = NULL,
    @CreatedByStaffID       INT             = NULL,
    @NewPaymentID           INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Verify contact exists
    IF NOT EXISTS (
        SELECT 1 FROM ContactInformation WHERE ContactID = @ContactID
    )
    BEGIN
        RAISERROR('ContactID %d does not exist.', 16, 1, @ContactID);
        RETURN;
    END

    -- Validate total amount
    IF @TotalAmount <= 0
    BEGIN
        RAISERROR('Payment TotalAmount must be greater than zero.', 16, 1);
        RETURN;
    END

    -- Verify allocation temp table exists and has rows
    IF OBJECT_ID('tempdb..#Allocations') IS NULL
    BEGIN
        RAISERROR('Temp table #Allocations must be created and populated before calling usp_RecordPayment.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM #Allocations)
    BEGIN
        RAISERROR('At least one allocation must be provided in #Allocations.', 16, 1);
        RETURN;
    END

    -- Verify allocations sum to total amount
    DECLARE @AllocationSum DECIMAL(10,2);
    SELECT @AllocationSum = SUM(Amount) FROM #Allocations;

    IF @AllocationSum <> @TotalAmount
    BEGIN
        DECLARE @AllocationSumStr VARCHAR(20) = CONVERT(VARCHAR(20), @AllocationSum);
        DECLARE @TotalAmountStr   VARCHAR(20) = CONVERT(VARCHAR(20), @TotalAmount);

        RAISERROR(
            'Allocation sum (%s) does not equal TotalAmount (%s). All funds must be allocated.',
            16, 1,
            @AllocationSumStr,
            @TotalAmountStr
        );
        RETURN;
    END

    IF @PaymentDate IS NULL
        SET @PaymentDate = CAST(GETDATE() AS DATE);

    BEGIN TRANSACTION;

    BEGIN TRY

        -- Create the Payment record
        INSERT INTO Payment (
            ContactID,
            PaymentMethodTypeID,
            PaymentDate,
            TotalAmount,
            CheckNumber,
            ReceivedByStaffID,
            AcknowledgementSent,
            CreatedByStaffID,
            CreatedDate
        )
        VALUES (
            @ContactID,
            @PaymentMethodTypeID,
            @PaymentDate,
            @TotalAmount,
            @CheckNumber,
            @ReceivedByStaffID,
            0,  -- AcknowledgementSent: false until sent
            @CreatedByStaffID,
            CAST(GETDATE() AS DATE)
        );

        SET @NewPaymentID = SCOPE_IDENTITY();

        -- Insert all allocations from temp table
        INSERT INTO PaymentAllocation (
            PaymentID,
            AllocationTypeID,
            FeeID,
            CampaignID,
            ScholarshipFundID,
            Amount,
            IsTaxDeductible,
            IsScholarship,
            ScholarshipAmount,
            DonorID,
            FeeDescription
        )
        SELECT
            @NewPaymentID,
            AllocationTypeID,
            FeeID,
            CampaignID,
            ScholarshipFundID,
            Amount,
            IsTaxDeductible,
            IsScholarship,
            ScholarshipAmount,
            DonorID,
            FeeDescription
        FROM #Allocations;

        -- Apply mailing preferences based on donation amounts
        -- Business rules are read from OrgConfiguration so they
        -- can be updated without changing this procedure
        EXEC usp_ApplyMailingPreferencesFromPayment
            @PaymentID          = @NewPaymentID,
            @ContactID          = @ContactID,
            @SetByStaffID       = @CreatedByStaffID;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================================================
-- PROCEDURE 2: usp_ApplyMailingPreferencesFromPayment
-- Purpose:  Automatically set mailing preferences based on payment
--           allocations and OrgConfiguration business rules.
--           Called internally by usp_RecordPayment but can also be
--           called manually to recalculate preferences.
--
--           Business rules implemented:
--           - Any donation → Newsletter, Annual Report, Holiday Ask, ILOF
--           - Donation >= MajorDonorThreshold → also Holiday Card
--           - Grant funder → Newsletter, Annual Report
--           - BST full fee → Newsletter, Annual Report, Holiday Ask, ILOF
--           - BST scholarship fee → Newsletter, Annual Report
--           - Group full fee → Newsletter, Annual Report, Holiday Ask, ILOF
--           - Group scholarship fee → Newsletter, Annual Report
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_ApplyMailingPreferencesFromPayment
    @PaymentID      INT,
    @ContactID      INT,
    @SetByStaffID   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Read thresholds from OrgConfiguration
    DECLARE @MajorDonorThreshold    DECIMAL(10,2);
    DECLARE @Today                  DATE = CAST(GETDATE() AS DATE);

    SELECT @MajorDonorThreshold = CAST(ConfigValue AS DECIMAL(10,2))
    FROM OrgConfiguration
    WHERE ConfigKey = 'MajorDonorThreshold';

    -- Get the total donation amount from this payment
    DECLARE @TotalDonationAmount DECIMAL(10,2) = 0;
    SELECT @TotalDonationAmount = ISNULL(SUM(Amount), 0)
    FROM PaymentAllocation
    WHERE PaymentID = @PaymentID
    AND IsTaxDeductible = 1;

    -- Get BST fee allocations
    DECLARE @BSTFullFee         DECIMAL(10,2) = 0;
    DECLARE @BSTScholarship     BIT = 0;

    SELECT
        @BSTFullFee     = ISNULL(SUM(CASE WHEN IsScholarship = 0 THEN Amount ELSE 0 END), 0),
        @BSTScholarship = CASE WHEN MAX(CAST(IsScholarship AS INT)) = 1 THEN 1 ELSE 0 END
    FROM PaymentAllocation pa
    JOIN AllocationType at ON pa.AllocationTypeID = at.TypeID
    WHERE pa.PaymentID = @PaymentID
    AND at.TypeName = 'BST Fee';

    -- Get Group fee allocations
    DECLARE @GroupFullFee       DECIMAL(10,2) = 0;
    DECLARE @GroupScholarship   BIT = 0;

    SELECT
        @GroupFullFee       = ISNULL(SUM(CASE WHEN IsScholarship = 0 THEN Amount ELSE 0 END), 0),
        @GroupScholarship   = CASE WHEN MAX(CAST(IsScholarship AS INT)) = 1 THEN 1 ELSE 0 END
    FROM PaymentAllocation pa
    JOIN AllocationType at ON pa.AllocationTypeID = at.TypeID
    WHERE pa.PaymentID = @PaymentID
    AND at.TypeName = 'Group Fee';

    -- Helper: set a mailing preference if not already set
    -- OptedIn = 1, records reason for audit trail
    DECLARE @Reason NVARCHAR(500);

    -- Any donation triggers: Newsletter, Annual Report, Holiday Ask
    IF @TotalDonationAmount > 0
    BEGIN
        SET @Reason = 'Donation received on ' + CAST(@Today AS NVARCHAR(20));

        EXEC usp_SetMailingPreference @ContactID, 'Newsletter',    1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Annual Report', 1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Holiday Ask',   1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Event Invitation', 1, @Reason, @SetByStaffID;
    END

    -- Major gift also triggers Holiday Card
    IF @TotalDonationAmount >= @MajorDonorThreshold
    BEGIN
        SET @Reason = 'Major gift of $' + CAST(@TotalDonationAmount AS NVARCHAR(20))
                    + ' received on ' + CAST(@Today AS NVARCHAR(20));
        EXEC usp_SetMailingPreference @ContactID, 'Holiday Card', 1, @Reason, @SetByStaffID;
    END

    -- BST full fee: Newsletter, Annual Report, Holiday Ask, Event Invitation
    IF @BSTFullFee > 0 AND @BSTScholarship = 0
    BEGIN
        SET @Reason = 'BST full fee received on ' + CAST(@Today AS NVARCHAR(20));
        EXEC usp_SetMailingPreference @ContactID, 'Newsletter',       1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Annual Report',    1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Holiday Ask',      1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Event Invitation', 1, @Reason, @SetByStaffID;
    END

    -- BST scholarship fee: Newsletter, Annual Report only
    IF @BSTScholarship = 1
    BEGIN
        SET @Reason = 'BST scholarship fee received on ' + CAST(@Today AS NVARCHAR(20));
        EXEC usp_SetMailingPreference @ContactID, 'Newsletter',    1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Annual Report', 1, @Reason, @SetByStaffID;
    END

    -- Group full fee: Newsletter, Annual Report, Holiday Ask, Event Invitation
    IF @GroupFullFee > 0 AND @GroupScholarship = 0
    BEGIN
        SET @Reason = 'Group full fee received on ' + CAST(@Today AS NVARCHAR(20));
        EXEC usp_SetMailingPreference @ContactID, 'Newsletter',       1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Annual Report',    1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Holiday Ask',      1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Event Invitation', 1, @Reason, @SetByStaffID;
    END

    -- Group scholarship fee: Newsletter, Annual Report only
    IF @GroupScholarship = 1
    BEGIN
        SET @Reason = 'Group scholarship fee received on ' + CAST(@Today AS NVARCHAR(20));
        EXEC usp_SetMailingPreference @ContactID, 'Newsletter',    1, @Reason, @SetByStaffID;
        EXEC usp_SetMailingPreference @ContactID, 'Annual Report', 1, @Reason, @SetByStaffID;
    END

END
GO

-- =============================================================================
-- PROCEDURE 3: usp_SetMailingPreference
-- Purpose:  Set or update a single mailing preference for a contact.
--           Called internally by usp_ApplyMailingPreferencesFromPayment
--           but also available for manual preference management.
--           Uses MERGE to insert if not exists, update if exists.
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_SetMailingPreference
    @ContactID      INT,
    @MailingTypeName NVARCHAR(100),
    @OptedIn        BIT             = 1,
    @OptedInReason  NVARCHAR(500)   = NULL,
    @SetByStaffID   INT             = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MailingTypeID  INT;
    DECLARE @Today          DATE = CAST(GETDATE() AS DATE);

    SELECT @MailingTypeID = TypeID
    FROM MailingType
    WHERE TypeName = @MailingTypeName;

    IF @MailingTypeID IS NULL
    BEGIN
        RAISERROR('MailingType "%s" not found.', 16, 1, @MailingTypeName);
        RETURN;
    END

    MERGE MailingPreference AS target
    USING (
        SELECT @ContactID AS ContactID, @MailingTypeID AS MailingTypeID
    ) AS source
    ON target.ContactID     = source.ContactID
    AND target.MailingTypeID = source.MailingTypeID
    WHEN MATCHED THEN
        UPDATE SET
            OptedIn         = @OptedIn,
            OptedInDate     = @Today,
            OptedInReason   = @OptedInReason,
            SetByStaffID    = @SetByStaffID
    WHEN NOT MATCHED THEN
        INSERT (ContactID, MailingTypeID, OptedIn, OptedInDate, OptedInReason, SetByStaffID)
        VALUES (@ContactID, @MailingTypeID, @OptedIn, @Today, @OptedInReason, @SetByStaffID);
END
GO

-- =============================================================================
-- PROCEDURE 4: usp_SendAcknowledgement
-- Purpose:  Mark a payment acknowledgement as sent and record the date.
--           Tax acknowledgements must be sent for all tax-deductible
--           donations. This procedure provides the audit record that
--           the acknowledgement was issued.
-- Usage:    EXEC usp_SendAcknowledgement @PaymentID = 42, @StaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_SendAcknowledgement
    @PaymentID      INT,
    @StaffID        INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM Payment WHERE PaymentID = @PaymentID
    )
    BEGIN
        RAISERROR('PaymentID %d does not exist.', 16, 1, @PaymentID);
        RETURN;
    END

    -- Only update if not already acknowledged
    IF EXISTS (
        SELECT 1 FROM Payment
        WHERE PaymentID = @PaymentID
        AND AcknowledgementSent = 1
    )
    BEGIN
        RAISERROR('PaymentID %d has already been acknowledged.', 16, 1, @PaymentID);
        RETURN;
    END

    UPDATE Payment
    SET
        AcknowledgementSent = 1,
        AcknowledgementDate = CAST(GETDATE() AS DATE),
        ModifiedDate        = CAST(GETDATE() AS DATE),
        ModifiedByStaffID   = @StaffID
    WHERE PaymentID = @PaymentID;

END
GO

-- =============================================================================
-- PROCEDURE 5: usp_GetDonorLevel
-- Purpose:  Calculate the current donor level for a contact based on
--           actual giving history. Donor level is always calculated
--           from data — never stored as a field that could go stale.
--
--           Returns: DonorLevel, TotalGivingAllTime, TotalGivingThisYear,
--                    LargestSingleGift, LastGiftDate, LastGiftAmount
--
--           Thresholds are read from OrgConfiguration:
--             MajorDonorThreshold (default $500)
--             VIPDonorThreshold   (default $10,000)
-- Usage:    EXEC usp_GetDonorLevel @ContactID = 101
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_GetDonorLevel
    @ContactID  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MajorThreshold DECIMAL(10,2);
    DECLARE @VIPThreshold   DECIMAL(10,2);

    SELECT @MajorThreshold = CAST(ConfigValue AS DECIMAL(10,2))
    FROM OrgConfiguration WHERE ConfigKey = 'MajorDonorThreshold';

    SELECT @VIPThreshold = CAST(ConfigValue AS DECIMAL(10,2))
    FROM OrgConfiguration WHERE ConfigKey = 'VIPDonorThreshold';

    SELECT
        c.ContactID,
        c.FirstName,
        c.LastName,
        c.OrganizationName,
        -- Total giving all time (tax deductible allocations only)
        ISNULL(SUM(pa.Amount), 0)                               AS TotalGivingAllTime,
        -- Total giving this calendar year
        ISNULL(SUM(CASE
            WHEN YEAR(p.PaymentDate) = YEAR(GETDATE())
            THEN pa.Amount ELSE 0
        END), 0)                                                AS TotalGivingThisYear,
        -- Largest single gift
        ISNULL(MAX(pa.Amount), 0)                               AS LargestSingleGift,
        -- Most recent gift
        MAX(p.PaymentDate)                                      AS LastGiftDate,
        -- Amount of most recent gift
        (
            SELECT TOP 1 pa2.Amount
            FROM PaymentAllocation pa2
            JOIN Payment p2 ON pa2.PaymentID = p2.PaymentID
            JOIN DonorInformation d2 ON pa2.DonorID = d2.DonorID
            WHERE d2.ContactID = c.ContactID
            AND pa2.IsTaxDeductible = 1
            ORDER BY p2.PaymentDate DESC
        )                                                       AS LastGiftAmount,
        -- Calculated donor level based on largest single gift
        CASE
            WHEN ISNULL(MAX(pa.Amount), 0) >= @VIPThreshold
                THEN 'VIP Donor ($' + CAST(@VIPThreshold AS NVARCHAR) + '+)'
            WHEN ISNULL(MAX(pa.Amount), 0) >= @MajorThreshold
                THEN 'Major Donor ($' + CAST(@MajorThreshold AS NVARCHAR) + '+)'
            WHEN ISNULL(SUM(CASE
                    WHEN YEAR(p.PaymentDate) = YEAR(GETDATE())
                    THEN pa.Amount ELSE 0 END), 0) > 0
                THEN 'Annual Fund Donor'
            WHEN ISNULL(SUM(pa.Amount), 0) > 0
                THEN 'Lapsed Donor'
            ELSE 'Prospect / No Giving History'
        END                                                     AS DonorLevel
    FROM ContactInformation c
    LEFT JOIN DonorInformation  d   ON c.ContactID     = d.ContactID
    LEFT JOIN PaymentAllocation pa  ON d.DonorID       = pa.DonorID
                                    AND pa.IsTaxDeductible = 1
    LEFT JOIN Payment           p   ON pa.PaymentID    = p.PaymentID
    WHERE c.ContactID = @ContactID
    GROUP BY
        c.ContactID,
        c.FirstName,
        c.LastName,
        c.OrganizationName;
END
GO

-- =============================================================================
-- PROCEDURE 6: usp_GetUnacknowledgedPayments
-- Purpose:  Return all payments with tax-deductible allocations that
--           have not yet had acknowledgements sent. Used to drive the
--           acknowledgement workflow so no donor misses a tax receipt.
-- Usage:    EXEC usp_GetUnacknowledgedPayments
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_GetUnacknowledgedPayments
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.PaymentID,
        p.PaymentDate,
        p.TotalAmount,
        c.FirstName,
        c.LastName,
        c.OrganizationName,
        c.Email,
        c.Phone,
        pmt.TypeName                        AS PaymentMethod,
        p.CheckNumber,
        -- Total deductible amount for the tax receipt
        SUM(pa.Amount)                      AS TaxDeductibleAmount,
        -- Days since payment with no acknowledgement
        DATEDIFF(DAY, p.PaymentDate, GETDATE()) AS DaysSincePayment
    FROM Payment p
    JOIN ContactInformation c   ON p.ContactID          = c.ContactID
    JOIN PaymentMethodType  pmt ON p.PaymentMethodTypeID = pmt.TypeID
    JOIN PaymentAllocation  pa  ON p.PaymentID          = pa.PaymentID
                                AND pa.IsTaxDeductible   = 1
    WHERE p.AcknowledgementSent = 0
    GROUP BY
        p.PaymentID,
        p.PaymentDate,
        p.TotalAmount,
        c.FirstName,
        c.LastName,
        c.OrganizationName,
        c.Email,
        c.Phone,
        pmt.TypeName,
        p.CheckNumber
    ORDER BY
        p.PaymentDate ASC;  -- Oldest first — longest waiting acknowledgements first
END
GO

-- =============================================================================
-- PROCEDURE 7: usp_RecordScholarshipAward
-- Purpose:  Record a scholarship award from a ScholarshipFund to a
--           recipient. Validates that the fund is active and that the
--           award amount does not exceed the available fund balance.
--           Fund balance is always calculated from actual records —
--           total donated minus total awarded — never stored as a
--           field that could become inaccurate.
-- Usage:    EXEC usp_RecordScholarshipAward
--               @ScholarshipFundID = 1, @ContactID = 205,
--               @FeeID = 2, @AwardAmount = 75.00,
--               @ApprovedByStaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_RecordScholarshipAward
    @ScholarshipFundID  INT,
    @ContactID          INT,
    @FeeID              INT,
    @AwardAmount        DECIMAL(10,2),
    @AwardDate          DATE            = NULL,
    @ApprovedByStaffID  INT             = NULL,
    @Notes              NVARCHAR(MAX)   = NULL,
    @NewAwardID         INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Verify fund is active
    IF NOT EXISTS (
        SELECT 1 FROM ScholarshipFund
        WHERE ScholarshipFundID = @ScholarshipFundID
        AND IsActive = 1
    )
    BEGIN
        RAISERROR('ScholarshipFundID %d does not exist or is not active.', 16, 1, @ScholarshipFundID);
        RETURN;
    END

    -- Calculate available fund balance
    -- Balance = total donations designated to fund minus total awards made
    DECLARE @TotalDonated   DECIMAL(10,2) = 0;
    DECLARE @TotalAwarded   DECIMAL(10,2) = 0;
    DECLARE @Balance        DECIMAL(10,2);

    SELECT @TotalDonated = ISNULL(SUM(pa.Amount), 0)
    FROM PaymentAllocation pa
    WHERE pa.ScholarshipFundID = @ScholarshipFundID;

    SELECT @TotalAwarded = ISNULL(SUM(AwardAmount), 0)
    FROM ScholarshipAward
    WHERE ScholarshipFundID = @ScholarshipFundID;

    SET @Balance = @TotalDonated - @TotalAwarded;

    IF @AwardAmount > @Balance
    BEGIN
        DECLARE @AwardAmountStr VARCHAR(20) = CONVERT(VARCHAR(20), @AwardAmount);
        DECLARE @BalanceStr     VARCHAR(20) = CONVERT(VARCHAR(20), @Balance);

        RAISERROR(
            'Award amount $%s exceeds available fund balance of $%s.',
            16, 1,
            @AwardAmountStr,
            @BalanceStr
        );
        RETURN;
    END

    IF @AwardDate IS NULL
        SET @AwardDate = CAST(GETDATE() AS DATE);

    INSERT INTO ScholarshipAward (
        ScholarshipFundID,
        ContactID,
        FeeID,
        AwardAmount,
        AwardDate,
        ApprovedByStaffID,
        Notes
    )
    VALUES (
        @ScholarshipFundID,
        @ContactID,
        @FeeID,
        @AwardAmount,
        @AwardDate,
        @ApprovedByStaffID,
        @Notes
    );

    SET @NewAwardID = SCOPE_IDENTITY();
END
GO
