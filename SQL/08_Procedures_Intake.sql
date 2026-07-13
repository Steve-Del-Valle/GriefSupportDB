-- =============================================================================
-- GriefSupportDB
-- A comprehensive SQL Server database architecture designed to modernize the
-- information system of a grief support nonprofit. Drawing on real-world
-- operational experience with a legacy system, the project reimagines how
-- clients, volunteers, facilitators, donors, staff, programs, and fundraising
-- activities can be managed within a flexible, scalable, and maintainable
-- relational database.
-- =============================================================================
-- Script 08: Stored Procedures — Intake and Contact Management
-- Description: Procedures for creating and managing contact records,
--              client intake, encounter logging, and loss recording.
--              These procedures enforce business rules at the database
--              level rather than relying on application code.
-- Version:     v5
-- Author:      Steve Del Valle
-- Dependencies: 01 through 07 must be run first
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- PROCEDURE 1: usp_SearchContact
-- Purpose:  Search ContactInformation before creating a new record.
--           Addresses the duplicate record problem documented in the
--           Line One Call workflow. Staff search first; this procedure
--           returns likely matches so the caller can confirm before
--           a new record is created.
-- Usage:    EXEC usp_SearchContact @LastName = 'Smith', @FirstName = 'John'
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_SearchContact
    @LastName       NVARCHAR(100)   = NULL,
    @FirstName      NVARCHAR(100)   = NULL,
    @Phone          NVARCHAR(20)    = NULL,
    @Email          NVARCHAR(255)   = NULL,
    @OrganizationName NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- At least one search parameter must be provided
    IF @LastName IS NULL AND @FirstName IS NULL
       AND @Phone IS NULL AND @Email IS NULL
       AND @OrganizationName IS NULL
    BEGIN
        RAISERROR('At least one search parameter must be provided.', 16, 1);
        RETURN;
    END

    SELECT
        c.ContactID,
        c.FirstName,
        c.LastName,
        c.OrganizationName,
        c.Phone,
        c.AlternatePhone,
        c.Email,
        ci.CityName                         AS City,
        s.StateName                         AS State,
        ps.StatusName                       AS ProfileStatus,
        pt.TypeName                         AS ProfileType,
        c.InitialContactDate,
        -- Show which roles this contact holds
        CASE WHEN st.StaffID IS NOT NULL
             THEN 'Yes' ELSE 'No' END       AS IsStaff,
        CASE WHEN bm.MemberID IS NOT NULL
             THEN 'Yes' ELSE 'No' END       AS IsBoardMember,
        CASE WHEN v.VolunteerID IS NOT NULL
             THEN 'Yes' ELSE 'No' END       AS IsVolunteer,
        CASE WHEN cl.ClientID IS NOT NULL
             THEN 'Yes' ELSE 'No' END       AS IsClient,
        CASE WHEN d.DonorID IS NOT NULL
             THEN 'Yes' ELSE 'No' END       AS IsDonor,
        CASE WHEN f.FacilitatorID IS NOT NULL
             THEN 'Yes' ELSE 'No' END       AS IsFacilitator
    FROM ContactInformation c
    LEFT JOIN City          ci  ON c.CityID         = ci.CityID
    LEFT JOIN State         s   ON c.StateID         = s.StateID
    LEFT JOIN ProfileStatus ps  ON c.ProfileStatusID = ps.StatusID
    LEFT JOIN ProfileType   pt  ON c.ProfileTypeID   = pt.TypeID
    LEFT JOIN Staff         st  ON c.ContactID       = st.ContactID
                                AND st.EndDate IS NULL
    LEFT JOIN BoardMember   bm  ON c.ContactID       = bm.ContactID
                                AND bm.EndDate IS NULL
    LEFT JOIN VolunteerInformation v
                                ON c.ContactID       = v.ContactID
                                AND v.EndDate IS NULL
    LEFT JOIN ClientInformation cl
                                ON c.ContactID       = cl.ContactID
    LEFT JOIN DonorInformation  d
                                ON c.ContactID       = d.ContactID
    LEFT JOIN Facilitator       f
                                ON c.ContactID       = f.ContactID
    WHERE
        -- Match on any provided parameter
        (
            (@LastName        IS NOT NULL AND c.LastName           LIKE '%' + @LastName + '%')
         OR (@FirstName       IS NOT NULL AND c.FirstName          LIKE '%' + @FirstName + '%')
         OR (@Phone           IS NOT NULL AND (c.Phone             LIKE '%' + @Phone + '%'
                                           OR  c.AlternatePhone    LIKE '%' + @Phone + '%'))
         OR (@Email           IS NOT NULL AND c.Email              LIKE '%' + @Email + '%')
         OR (@OrganizationName IS NOT NULL AND c.OrganizationName  LIKE '%' + @OrganizationName + '%')
        )
    ORDER BY
        c.LastName,
        c.FirstName;
END
GO

-- =============================================================================
-- PROCEDURE 2: usp_CreateContact
-- Purpose:  Create a new ContactInformation record after confirming no
--           duplicate exists via usp_SearchContact. Returns the new
--           ContactID so the caller can immediately proceed to role
--           and encounter creation in the same workflow.
-- Usage:    EXEC usp_CreateContact
--               @FirstName = 'John', @LastName = 'Smith',
--               @Phone = '541-555-0100', @ProfileTypeID = 1,
--               @ProfileStatusID = 1, @CreatedByStaffID = 1
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_CreateContact
    @ProfileTypeID      INT,
    @ProfileStatusID    INT,
    @OrganizationName   NVARCHAR(255)   = NULL,
    @FirstName          NVARCHAR(100)   = NULL,
    @MiddleName         NVARCHAR(100)   = NULL,
    @LastName           NVARCHAR(100)   = NULL,
    @Phone              NVARCHAR(20)    = NULL,
    @AlternatePhone     NVARCHAR(20)    = NULL,
    @Email              NVARCHAR(255)   = NULL,
    @AddressLine1       NVARCHAR(255)   = NULL,
    @AddressLine2       NVARCHAR(255)   = NULL,
    @CityID             INT             = NULL,
    @StateID            INT             = NULL,
    @Zip                NVARCHAR(20)    = NULL,
    @CountryID          INT             = NULL,
    @DateOfBirth        DATE            = NULL,
    @GenderID           INT             = NULL,
    @EthnicityID        INT             = NULL,
    @InitialContactDate DATE            = NULL,
    @CreatedByStaffID   INT             = NULL,
    -- Output: returns the new ContactID to the caller
    @NewContactID       INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Apply data entry convention: use UNK for unknown names
    -- per the organization's documented data entry standards
    SET @FirstName  = NULLIF(LTRIM(RTRIM(@FirstName)),  '');
    SET @LastName   = NULLIF(LTRIM(RTRIM(@LastName)),   '');

    -- Default unknown phone per convention
    IF @Phone IS NULL OR LTRIM(RTRIM(@Phone)) = ''
        SET @Phone = '555-555-5555';

    -- Default initial contact date to today if not provided
    IF @InitialContactDate IS NULL
        SET @InitialContactDate = CAST(GETDATE() AS DATE);

    INSERT INTO ContactInformation (
        ProfileTypeID,
        ProfileStatusID,
        OrganizationName,
        FirstName,
        MiddleName,
        LastName,
        Phone,
        AlternatePhone,
        Email,
        AddressLine1,
        AddressLine2,
        CityID,
        StateID,
        Zip,
        CountryID,
        DateOfBirth,
        GenderID,
        EthnicityID,
        InitialContactDate,
        CreatedByStaffID,
        CreatedDate
    )
    VALUES (
        @ProfileTypeID,
        @ProfileStatusID,
        @OrganizationName,
        @FirstName,
        @MiddleName,
        @LastName,
        @Phone,
        @AlternatePhone,
        @Email,
        @AddressLine1,
        @AddressLine2,
        @CityID,
        @StateID,
        @Zip,
        @CountryID,
        @DateOfBirth,
        @GenderID,
        @EthnicityID,
        @InitialContactDate,
        @CreatedByStaffID,
        CAST(GETDATE() AS DATE)
    );

    SET @NewContactID = SCOPE_IDENTITY();
END
GO

-- =============================================================================
-- PROCEDURE 3: usp_IntakeClient
-- Purpose:  Register an existing ContactInformation record as a Client.
--           Creates the ClientInformation record with InviteToGroups
--           defaulting to 1 (group-ready) per business rule.
--           Also creates the first ClientTypeHistory record.
--           Returns ClientID to caller.
-- Usage:    EXEC usp_IntakeClient
--               @ContactID = 101, @ClientTypeID = 1,
--               @ClientContactStaffID = 3, @CreatedByStaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_IntakeClient
    @ContactID              INT,
    @ClientTypeID           INT,
    @ClientStatusID         INT             = NULL,     -- Defaults to Active
    @ClientContactStaffID   INT             = NULL,
    @ClientContactDate      DATE            = NULL,
    @InsuranceID            INT             = NULL,
    @MinorsSuitableForID    INT             = NULL,
    @InviteToGroups         BIT             = 1,        -- Default: group-ready
    @CreatedByStaffID       INT             = NULL,
    @NewClientID            INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Verify the contact exists
    IF NOT EXISTS (
        SELECT 1 FROM ContactInformation WHERE ContactID = @ContactID
    )
    BEGIN
        RAISERROR('ContactID %d does not exist.', 16, 1, @ContactID);
        RETURN;
    END

    -- Verify the contact is not already a client
    IF EXISTS (
        SELECT 1 FROM ClientInformation WHERE ContactID = @ContactID
    )
    BEGIN
        RAISERROR('ContactID %d already has a ClientInformation record.', 16, 1, @ContactID);
        RETURN;
    END

    -- Default status to Active if not provided
    IF @ClientStatusID IS NULL
        SELECT @ClientStatusID = StatusID
        FROM ClientStatus
        WHERE StatusName = 'Active';

    -- Default contact date to today
    IF @ClientContactDate IS NULL
        SET @ClientContactDate = CAST(GETDATE() AS DATE);

    BEGIN TRANSACTION;

    BEGIN TRY

        -- Create the ClientInformation record
        INSERT INTO ClientInformation (
            ContactID,
            ClientStatusID,
            ClientTypeID,
            ClientContactStaffID,
            ClientContactDate,
            InsuranceID,
            MinorsSuitableForID,
            InviteToGroups,
            ExperiencedSuicideLoss,
            ExperiencedHomicideLoss,
            CreatedByStaffID,
            CreatedDate
        )
        VALUES (
            @ContactID,
            @ClientStatusID,
            @ClientTypeID,
            @ClientContactStaffID,
            @ClientContactDate,
            @InsuranceID,
            @MinorsSuitableForID,
            @InviteToGroups,
            0,  -- ExperiencedSuicideLoss: updated when Loss records are added
            0,  -- ExperiencedHomicideLoss: updated when Loss records are added
            @CreatedByStaffID,
            CAST(GETDATE() AS DATE)
        );

        SET @NewClientID = SCOPE_IDENTITY();

        -- Create the initial ClientTypeHistory record
        INSERT INTO ClientTypeHistory (
            ClientID,
            ClientTypeID,
            EffectiveDate,
            RecordedByStaffID,
            ChangeReason
        )
        VALUES (
            @NewClientID,
            @ClientTypeID,
            @ClientContactDate,
            @CreatedByStaffID,
            'Initial intake'
        );

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================================================
-- PROCEDURE 4: usp_LogEncounter
-- Purpose:  Log an Encounter for any contact. Handles both formal
--           encounters (intake calls, follow-ups, interviews) and
--           lightweight touchpoints (reminder calls, check-ins).
--           ReferralType, ReferralSource, and SeekingServicesFor are
--           captured at the Encounter level per design — not on the
--           client record — because context varies across contacts.
-- Usage:    EXEC usp_LogEncounter
--               @ContactID = 101, @EncounterTypeID = 1,
--               @StaffID = 3, @EncounterDate = '2024-03-15',
--               @IsLightweight = 0, @EncounterNotes = 'Initial intake call.'
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_LogEncounter
    @ContactID              INT,
    @EncounterTypeID        INT,
    @StaffID                INT             = NULL,
    @ClientTypeID           INT             = NULL,
    @ReferralTypeID         INT             = NULL,
    @ReferralSourceID       INT             = NULL,
    @SeekingServicesForID   INT             = NULL,
    @IsLightweight          BIT             = 0,
    @EncounterDate          DATE            = NULL,
    @EncounterNotes         NVARCHAR(MAX)   = NULL,
    @CreatedByStaffID       INT             = NULL,
    @NewEncounterID         INT             OUTPUT
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

    -- Default encounter date to today
    IF @EncounterDate IS NULL
        SET @EncounterDate = CAST(GETDATE() AS DATE);

    INSERT INTO Encounter (
        ContactID,
        EncounterTypeID,
        StaffID,
        ClientTypeID,
        ReferralTypeID,
        ReferralSourceID,
        SeekingServicesForID,
        IsLightweight,
        EncounterDate,
        EncounterNotes,
        CreatedByStaffID,
        CreatedDate
    )
    VALUES (
        @ContactID,
        @EncounterTypeID,
        @StaffID,
        @ClientTypeID,
        @ReferralTypeID,
        @ReferralSourceID,
        @SeekingServicesForID,
        @IsLightweight,
        @EncounterDate,
        @EncounterNotes,
        @CreatedByStaffID,
        CAST(GETDATE() AS DATE)
    );

    SET @NewEncounterID = SCOPE_IDENTITY();
END
GO

-- =============================================================================
-- PROCEDURE 5: usp_RecordLoss
-- Purpose:  Record a loss experience for a client. Creates or links
--           a Deceased record. Updates the quick-reference flags on
--           ClientInformation (ExperiencedSuicideLoss,
--           ExperiencedHomicideLoss) automatically based on LossType.
--           This keeps the denormalized flags accurate without
--           requiring manual updates.
-- Usage:    EXEC usp_RecordLoss
--               @ClientID = 42, @LossTypeID = 9,
--               @DeceasedFirstName = 'Robert', @DeceasedLastName = 'Garcia',
--               @DeceasedTypeID = 1, @LossDate = '2023-11-15',
--               @DeceasedRelationship = 'Father', @CreatedByStaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_RecordLoss
    @ClientID               INT,
    @LossTypeID             INT,
    -- Deceased information
    @DeceasedID             INT             = NULL,     -- Link to existing Deceased record
    @DeceasedTypeID         INT             = NULL,     -- Required if creating new Deceased
    @DeceasedFirstName      NVARCHAR(100)   = NULL,
    @DeceasedLastName       NVARCHAR(100)   = NULL,
    @DeceasedSpecies        NVARCHAR(100)   = NULL,     -- For pet losses
    @DeceasedDateOfDeath    DATE            = NULL,
    @CauseOfDeathTypeID     INT             = NULL,
    @DeceasedNotes          NVARCHAR(MAX)   = NULL,
    -- Loss details
    @EncounterID            INT             = NULL,
    @LossDate               DATE            = NULL,
    @DeceasedRelationship   NVARCHAR(100)   = NULL,
    @SupportReceived        NVARCHAR(MAX)   = NULL,
    @CreatedByStaffID       INT             = NULL,
    @NewLossID              INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Verify client exists
    IF NOT EXISTS (
        SELECT 1 FROM ClientInformation WHERE ClientID = @ClientID
    )
    BEGIN
        RAISERROR('ClientID %d does not exist.', 16, 1, @ClientID);
        RETURN;
    END

    BEGIN TRANSACTION;

    BEGIN TRY

        -- Create a new Deceased record if one was not provided
        IF @DeceasedID IS NULL AND @DeceasedTypeID IS NOT NULL
        BEGIN
            INSERT INTO Deceased (
                DeceasedTypeID,
                FirstName,
                LastName,
                Species,
                DateOfDeath,
                CauseOfDeathTypeID,
                Notes
            )
            VALUES (
                @DeceasedTypeID,
                @DeceasedFirstName,
                @DeceasedLastName,
                @DeceasedSpecies,
                @DeceasedDateOfDeath,
                @CauseOfDeathTypeID,
                @DeceasedNotes
            );

            SET @DeceasedID = SCOPE_IDENTITY();
        END

        -- Create the Loss record
        INSERT INTO Loss (
            ClientID,
            DeceasedID,
            LossTypeID,
            EncounterID,
            LossDate,
            DeceasedRelationship,
            SupportReceived,
            CreatedByStaffID,
            CreatedDate
        )
        VALUES (
            @ClientID,
            @DeceasedID,
            @LossTypeID,
            @EncounterID,
            @LossDate,
            @DeceasedRelationship,
            @SupportReceived,
            @CreatedByStaffID,
            CAST(GETDATE() AS DATE)
        );

        SET @NewLossID = SCOPE_IDENTITY();

        -- Update the quick-reference flags on ClientInformation
        -- based on the LossType recorded.
        -- These flags allow fast reporting without joining to Loss every time.
        UPDATE ClientInformation
        SET
            ExperiencedSuicideLoss = CASE
                WHEN EXISTS (
                    SELECT 1 FROM Loss l
                    JOIN LossType lt ON l.LossTypeID = lt.TypeID
                    WHERE l.ClientID = @ClientID
                    AND lt.TypeName = 'Suicide Loss'
                ) THEN 1 ELSE ExperiencedSuicideLoss
            END,
            ExperiencedHomicideLoss = CASE
                WHEN EXISTS (
                    SELECT 1 FROM Loss l
                    JOIN LossType lt ON l.LossTypeID = lt.TypeID
                    WHERE l.ClientID = @ClientID
                    AND lt.TypeName = 'Homicide Loss'
                ) THEN 1 ELSE ExperiencedHomicideLoss
            END,
            ModifiedDate        = CAST(GETDATE() AS DATE),
            ModifiedByStaffID   = @CreatedByStaffID
        WHERE ClientID = @ClientID;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================================================
-- PROCEDURE 6: usp_FullClientIntake
-- Purpose:  Complete end-to-end intake procedure combining contact
--           creation or lookup, client registration, first encounter
--           logging, and optional loss recording in a single
--           transaction. This is the procedure that maps directly to
--           the Line One Call workflow — one call, one procedure,
--           one complete record.
--
--           If @ContactID is provided, uses the existing contact.
--           If @ContactID is NULL, creates a new contact first.
--           Returns ContactID, ClientID, and EncounterID to caller.
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_FullClientIntake
    -- Contact fields (used if creating new contact)
    @ContactID              INT             = NULL,     -- Provide if contact exists
    @ProfileTypeID          INT             = 1,        -- Default: Personal
    @FirstName              NVARCHAR(100)   = NULL,
    @MiddleName             NVARCHAR(100)   = NULL,
    @LastName               NVARCHAR(100)   = NULL,
    @Phone                  NVARCHAR(20)    = NULL,
    @Email                  NVARCHAR(255)   = NULL,
    @DateOfBirth            DATE            = NULL,
    @GenderID               INT             = NULL,
    @EthnicityID            INT             = NULL,
    -- Client fields
    @ClientTypeID           INT,
    @InsuranceID            INT             = NULL,
    @MinorsSuitableForID    INT             = NULL,
    -- Encounter fields
    @EncounterTypeID        INT,
    @ReferralTypeID         INT             = NULL,
    @ReferralSourceID       INT             = NULL,
    @SeekingServicesForID   INT             = NULL,
    @EncounterNotes         NVARCHAR(MAX)   = NULL,
    -- Staff
    @StaffID                INT             = NULL,
    -- Output
    @OutContactID           INT             OUTPUT,
    @OutClientID            INT             OUTPUT,
    @OutEncounterID         INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

    BEGIN TRANSACTION;

    BEGIN TRY

        -- Step 1: Create contact if not provided
        IF @ContactID IS NULL
        BEGIN
            EXEC usp_CreateContact
                @ProfileTypeID      = @ProfileTypeID,
                @ProfileStatusID    = 1,            -- Active
                @FirstName          = @FirstName,
                @MiddleName         = @MiddleName,
                @LastName           = @LastName,
                @Phone              = @Phone,
                @Email              = @Email,
                @DateOfBirth        = @DateOfBirth,
                @GenderID           = @GenderID,
                @EthnicityID        = @EthnicityID,
                @InitialContactDate = @Today,
                @CreatedByStaffID   = @StaffID,
                @NewContactID       = @ContactID OUTPUT;
        END

        SET @OutContactID = @ContactID;

        -- Step 2: Register as client (only if not already a client)
        IF NOT EXISTS (
            SELECT 1 FROM ClientInformation WHERE ContactID = @ContactID
        )
        BEGIN
            EXEC usp_IntakeClient
                @ContactID              = @ContactID,
                @ClientTypeID           = @ClientTypeID,
                @ClientContactStaffID   = @StaffID,
                @ClientContactDate      = @Today,
                @InsuranceID            = @InsuranceID,
                @MinorsSuitableForID    = @MinorsSuitableForID,
                @InviteToGroups         = 1,
                @CreatedByStaffID       = @StaffID,
                @NewClientID            = @OutClientID OUTPUT;
        END
        ELSE
        BEGIN
            SELECT @OutClientID = ClientID
            FROM ClientInformation
            WHERE ContactID = @ContactID;
        END

        -- Step 3: Log the intake encounter
        EXEC usp_LogEncounter
            @ContactID              = @ContactID,
            @EncounterTypeID        = @EncounterTypeID,
            @StaffID                = @StaffID,
            @ClientTypeID           = @ClientTypeID,
            @ReferralTypeID         = @ReferralTypeID,
            @ReferralSourceID       = @ReferralSourceID,
            @SeekingServicesForID   = @SeekingServicesForID,
            @IsLightweight          = 0,
            @EncounterDate          = @Today,
            @EncounterNotes         = @EncounterNotes,
            @CreatedByStaffID       = @StaffID,
            @NewEncounterID         = @OutEncounterID OUTPUT;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================================================
-- PROCEDURE 7: usp_AddNote
-- Purpose:  Add a note to any contact record. Simple but important —
--           notes are the primary free-text record of what happened
--           in any interaction with the organization.
-- Usage:    EXEC usp_AddNote
--               @ContactID = 101, @StaffID = 3,
--               @NoteTypeID = 1, @NoteContent = 'Client called...'
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_AddNote
    @ContactID      INT,
    @StaffID        INT             = NULL,
    @NoteTypeID     INT,
    @NoteDate       DATE            = NULL,
    @NoteContent    NVARCHAR(MAX),
    @NewNoteID      INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM ContactInformation WHERE ContactID = @ContactID
    )
    BEGIN
        RAISERROR('ContactID %d does not exist.', 16, 1, @ContactID);
        RETURN;
    END

    IF @NoteDate IS NULL
        SET @NoteDate = CAST(GETDATE() AS DATE);

    INSERT INTO Note (
        ContactID,
        StaffID,
        NoteTypeID,
        NoteDate,
        NoteContent
    )
    VALUES (
        @ContactID,
        @StaffID,
        @NoteTypeID,
        @NoteDate,
        @NoteContent
    );

    SET @NewNoteID = SCOPE_IDENTITY();
END
GO

-- =============================================================================
-- PROCEDURE 8: usp_UpdateClientType
-- Purpose:  Update a client's primary ClientType and record the change
--           in ClientTypeHistory. Ensures the history trail is never
--           broken when a client's circumstances change.
-- Usage:    EXEC usp_UpdateClientType
--               @ClientID = 42, @NewClientTypeID = 3,
--               @ChangeReason = 'Client now seeking services for self',
--               @RecordedByStaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_UpdateClientType
    @ClientID               INT,
    @NewClientTypeID        INT,
    @ChangeReason           NVARCHAR(500)   = NULL,
    @RecordedByStaffID      INT             = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM ClientInformation WHERE ClientID = @ClientID
    )
    BEGIN
        RAISERROR('ClientID %d does not exist.', 16, 1, @ClientID);
        RETURN;
    END

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

    BEGIN TRANSACTION;

    BEGIN TRY

        -- Update the primary type on ClientInformation
        UPDATE ClientInformation
        SET
            ClientTypeID        = @NewClientTypeID,
            ModifiedDate        = @Today,
            ModifiedByStaffID   = @RecordedByStaffID
        WHERE ClientID = @ClientID;

        -- Record the change in history
        INSERT INTO ClientTypeHistory (
            ClientID,
            ClientTypeID,
            EffectiveDate,
            RecordedByStaffID,
            ChangeReason
        )
        VALUES (
            @ClientID,
            @NewClientTypeID,
            @Today,
            @RecordedByStaffID,
            @ChangeReason
        );

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
