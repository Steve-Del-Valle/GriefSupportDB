-- =============================================================================
-- GriefSupportDB
-- A comprehensive SQL Server database architecture designed to modernize the
-- information system of a grief support nonprofit. Drawing on real-world
-- operational experience with a legacy system, the project reimagines how
-- clients, volunteers, facilitators, donors, staff, programs, and fundraising
-- activities can be managed within a flexible, scalable, and maintainable
-- relational database.
-- =============================================================================
-- Script 10: Stored Procedures — Facilitator and Group Management
-- Description: Procedures for managing the facilitator credentialing
--              pipeline, group assignments, meeting scheduling, attendance
--              recording, and finding qualified substitutes.
--              These procedures enforce the two-person rule, background
--              check requirements, and qualification gates that protect
--              the safety and integrity of grief support groups.
-- Version:     v5
-- Author:      Steve
-- Dependencies: 01 through 09 must be run first
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- PROCEDURE 1: usp_EnterFacilitatorPipeline
-- Purpose:  Register a person as a Facilitator candidate, beginning
--           the credentialing pipeline. The person must already have
--           a ContactInformation record. Creates the Facilitator record
--           with initial status 'In Training'.
-- Usage:    EXEC usp_EnterFacilitatorPipeline
--               @ContactID = 205, @FacilitatorTypeID = 2,
--               @BSTCompletedDate = '2024-01-15', @CreatedByStaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_EnterFacilitatorPipeline
    @ContactID          INT,
    @FacilitatorTypeID  INT,               -- 1=Staff, 2=Volunteer
    @BSTCompletedDate   DATE    = NULL,
    @CreatedByStaffID   INT     = NULL,
    @NewFacilitatorID   INT     OUTPUT
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

    -- Verify not already in pipeline
    IF EXISTS (
        SELECT 1 FROM Facilitator WHERE ContactID = @ContactID
    )
    BEGIN
        RAISERROR('ContactID %d already has a Facilitator record.', 16, 1, @ContactID);
        RETURN;
    END

    -- Get the 'In Training' status ID
    DECLARE @InTrainingStatusID INT;
    SELECT @InTrainingStatusID = StatusID
    FROM FacilitatorStatus
    WHERE StatusName = 'In Training';

    INSERT INTO Facilitator (
        ContactID,
        FacilitatorTypeID,
        FacilitatorStatusID,
        BSTCompletedDate,
        BackgroundCheckCleared
    )
    VALUES (
        @ContactID,
        @FacilitatorTypeID,
        @InTrainingStatusID,
        @BSTCompletedDate,
        0   -- Not yet cleared
    );

    SET @NewFacilitatorID = SCOPE_IDENTITY();
END
GO

-- =============================================================================
-- PROCEDURE 2: usp_RecordBackgroundCheckCleared
-- Purpose:  Record that a facilitator's background check has been
--           cleared. This gate must be passed before the person can
--           be assigned to any group in any capacity.
-- Usage:    EXEC usp_RecordBackgroundCheckCleared
--               @FacilitatorID = 12, @BackgroundCheckDate = '2024-02-01',
--               @ClearedByStaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_RecordBackgroundCheckCleared
    @FacilitatorID          INT,
    @BackgroundCheckDate    DATE    = NULL,
    @ClearedByStaffID       INT     = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM Facilitator WHERE FacilitatorID = @FacilitatorID
    )
    BEGIN
        RAISERROR('FacilitatorID %d does not exist.', 16, 1, @FacilitatorID);
        RETURN;
    END

    IF @BackgroundCheckDate IS NULL
        SET @BackgroundCheckDate = CAST(GETDATE() AS DATE);

    UPDATE Facilitator
    SET
        BackgroundCheckCleared  = 1,
        BackgroundCheckDate     = @BackgroundCheckDate
    WHERE FacilitatorID = @FacilitatorID;
END
GO

-- =============================================================================
-- PROCEDURE 3: usp_RecordFacilitatorInterview
-- Purpose:  Record the completion of a facilitator's initial interview.
--           The interview is a universal gate — must be completed before
--           any group-type-specific vetting can begin.
-- Usage:    EXEC usp_RecordFacilitatorInterview
--               @FacilitatorID = 12, @InterviewDate = '2024-02-15',
--               @InterviewedByStaffID = 3, @InterviewNotes = 'Strong...'
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_RecordFacilitatorInterview
    @FacilitatorID          INT,
    @InterviewDate          DATE            = NULL,
    @InterviewedByStaffID   INT             = NULL,
    @InterviewNotes         NVARCHAR(MAX)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM Facilitator WHERE FacilitatorID = @FacilitatorID
    )
    BEGIN
        RAISERROR('FacilitatorID %d does not exist.', 16, 1, @FacilitatorID);
        RETURN;
    END

    -- Background check must be cleared before interview is recorded
    IF NOT EXISTS (
        SELECT 1 FROM Facilitator
        WHERE FacilitatorID = @FacilitatorID
        AND BackgroundCheckCleared = 1
    )
    BEGIN
        RAISERROR(
            'FacilitatorID %d has not cleared the background check. Background check must be cleared before interview.',
            16, 1, @FacilitatorID
        );
        RETURN;
    END

    IF @InterviewDate IS NULL
        SET @InterviewDate = CAST(GETDATE() AS DATE);

    UPDATE Facilitator
    SET
        InterviewDate           = @InterviewDate,
        InterviewedByStaffID    = @InterviewedByStaffID,
        InterviewNotes          = @InterviewNotes
    WHERE FacilitatorID = @FacilitatorID;
END
GO

-- =============================================================================
-- PROCEDURE 4: usp_VetFacilitatorForGroupType
-- Purpose:  Record the vetting decision for a Facilitator for a
--           specific grief group type. Creates or updates the
--           FacilitatorGroupTypeQualification record.
--           VettingOutcome must be: Approved, Deferred, or Declined.
--           On Approved, sets QualifiedForCoFacilitator = 1.
-- Usage:    EXEC usp_VetFacilitatorForGroupType
--               @FacilitatorID = 12, @GroupTypeID = 9,
--               @PersonalExperienceVerified = 1,
--               @VettingOutcome = 'Approved',
--               @VettedByStaffID = 3,
--               @VettingNotes = 'Has lived experience of suicide loss...'
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_VetFacilitatorForGroupType
    @FacilitatorID              INT,
    @GroupTypeID                INT,
    @PersonalExperienceVerified BIT             = 0,
    @PersonalExperienceNotes    NVARCHAR(MAX)   = NULL,
    @VettingDate                DATE            = NULL,
    @VettedByStaffID            INT             = NULL,
    @VettingMethod              NVARCHAR(100)   = NULL,
    @VettingNotes               NVARCHAR(MAX)   = NULL,
    @VettingOutcome             NVARCHAR(50),   -- 'Approved', 'Deferred', 'Declined'
    @DeferredReason             NVARCHAR(MAX)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate outcome value
    IF @VettingOutcome NOT IN ('Approved', 'Deferred', 'Declined')
    BEGIN
        RAISERROR(
            'VettingOutcome must be Approved, Deferred, or Declined. Received: %s',
            16, 1, @VettingOutcome
        );
        RETURN;
    END

    -- Verify facilitator has cleared the universal gates
    IF NOT EXISTS (
        SELECT 1 FROM Facilitator
        WHERE FacilitatorID = @FacilitatorID
        AND BackgroundCheckCleared = 1
        AND InterviewDate IS NOT NULL
    )
    BEGIN
        RAISERROR(
            'FacilitatorID %d has not completed the universal credential gates (background check and interview).',
            16, 1, @FacilitatorID
        );
        RETURN;
    END

    IF @VettingDate IS NULL
        SET @VettingDate = CAST(GETDATE() AS DATE);

    -- Determine Co-Facilitator qualification from outcome
    DECLARE @QualifiedForCoFac  BIT = 0;
    DECLARE @CoFacDate          DATE = NULL;

    IF @VettingOutcome = 'Approved'
    BEGIN
        SET @QualifiedForCoFac  = 1;
        SET @CoFacDate          = @VettingDate;
    END

    -- Upsert the qualification record
    MERGE FacilitatorGroupTypeQualification AS target
    USING (
        SELECT @FacilitatorID AS FacilitatorID, @GroupTypeID AS GroupTypeID
    ) AS source
    ON target.FacilitatorID = source.FacilitatorID
    AND target.GroupTypeID  = source.GroupTypeID
    WHEN MATCHED THEN
        UPDATE SET
            PersonalExperienceVerified  = @PersonalExperienceVerified,
            PersonalExperienceNotes     = @PersonalExperienceNotes,
            VettingDate                 = @VettingDate,
            VettedByStaffID             = @VettedByStaffID,
            VettingMethod               = @VettingMethod,
            VettingNotes                = @VettingNotes,
            VettingOutcome              = @VettingOutcome,
            DeferredReason              = @DeferredReason,
            QualifiedForCoFacilitator   = @QualifiedForCoFac,
            CoFacilitatorQualifiedDate  = @CoFacDate
    WHEN NOT MATCHED THEN
        INSERT (
            FacilitatorID, GroupTypeID,
            PersonalExperienceVerified, PersonalExperienceNotes,
            VettingDate, VettedByStaffID, VettingMethod,
            VettingNotes, VettingOutcome, DeferredReason,
            QualifiedForCoFacilitator, CoFacilitatorQualifiedDate,
            QualifiedForFacilitator
        )
        VALUES (
            @FacilitatorID, @GroupTypeID,
            @PersonalExperienceVerified, @PersonalExperienceNotes,
            @VettingDate, @VettedByStaffID, @VettingMethod,
            @VettingNotes, @VettingOutcome, @DeferredReason,
            @QualifiedForCoFac, @CoFacDate,
            0   -- Not yet qualified for lead
        );
END
GO

-- =============================================================================
-- PROCEDURE 5: usp_PromoteToLeadFacilitator
-- Purpose:  Promote a Co-Facilitator to lead Facilitator for a
--           specific group type. Validates the minimum session count
--           from OrgConfiguration before allowing promotion.
--           Records the approval and updates FacilitatorStatus.
-- Usage:    EXEC usp_PromoteToLeadFacilitator
--               @FacilitatorID = 12, @GroupTypeID = 9,
--               @QualifiedByStaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_PromoteToLeadFacilitator
    @FacilitatorID      INT,
    @GroupTypeID        INT,
    @QualifiedByStaffID INT     = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Read minimum session requirement from OrgConfiguration
    DECLARE @MinSessions INT;
    SELECT @MinSessions = CAST(ConfigValue AS INT)
    FROM OrgConfiguration
    WHERE ConfigKey = 'MinCoFacilitatorSessions';

    SET @MinSessions = ISNULL(@MinSessions, 6);  -- Default to 6 if not configured

    -- Verify Co-Facilitator qualification exists for this group type
    IF NOT EXISTS (
        SELECT 1 FROM FacilitatorGroupTypeQualification
        WHERE FacilitatorID         = @FacilitatorID
        AND GroupTypeID             = @GroupTypeID
        AND QualifiedForCoFacilitator = 1
    )
    BEGIN
        RAISERROR(
            'FacilitatorID %d is not qualified as Co-Facilitator for GroupTypeID %d.',
            16, 1, @FacilitatorID, @GroupTypeID
        );
        RETURN;
    END

    -- Count actual Co-Facilitator sessions served for this group type
    DECLARE @SessionsServed INT;

    SELECT @SessionsServed = COUNT(*)
    FROM Meeting m
    JOIN PeerSupportGroup g ON m.GroupID = g.GroupID
    WHERE m.CoFacilitatorID = @FacilitatorID
    AND g.GroupTypeID = @GroupTypeID;

    IF @SessionsServed < @MinSessions
    BEGIN
        RAISERROR(
            'FacilitatorID %d has served %d Co-Facilitator sessions for GroupTypeID %d. Minimum required: %d.',
            16, 1,
            @FacilitatorID, @SessionsServed, @GroupTypeID, @MinSessions
        );
        RETURN;
    END

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

    BEGIN TRANSACTION;

    BEGIN TRY

        -- Update the qualification record
        UPDATE FacilitatorGroupTypeQualification
        SET
            QualifiedForFacilitator = 1,
            FacilitatorQualifiedDate = @Today,
            QualifiedByStaffID      = @QualifiedByStaffID
        WHERE FacilitatorID = @FacilitatorID
        AND GroupTypeID     = @GroupTypeID;

        -- Update overall facilitator status to Qualified if not already
        UPDATE Facilitator
        SET
            FacilitatorStatusID = (
                SELECT StatusID FROM FacilitatorStatus WHERE StatusName = 'Qualified'
            ),
            QualifiedDate = ISNULL(QualifiedDate, @Today)
        WHERE FacilitatorID = @FacilitatorID
        AND FacilitatorStatusID = (
            SELECT StatusID FROM FacilitatorStatus WHERE StatusName = 'In Training'
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
-- PROCEDURE 6: usp_AssignGroupToFacilitators
-- Purpose:  Assign permanent Facilitator and Co-Facilitator to a
--           peer support group. Validates that both are qualified
--           for the group type and have cleared their background check.
--           Enforces the two-person rule and the no-same-person constraint.
-- Usage:    EXEC usp_AssignGroupToFacilitators
--               @GroupID = 5, @FacilitatorID = 12,
--               @CoFacilitatorID = 8, @AssignedByStaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_AssignGroupToFacilitators
    @GroupID            INT,
    @FacilitatorID      INT,
    @CoFacilitatorID    INT,
    @AssignedByStaffID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Verify group exists
    IF NOT EXISTS (SELECT 1 FROM PeerSupportGroup WHERE GroupID = @GroupID)
    BEGIN
        RAISERROR('GroupID %d does not exist.', 16, 1, @GroupID);
        RETURN;
    END

    -- Enforce two-person rule: different people in each seat
    IF @FacilitatorID = @CoFacilitatorID
    BEGIN
        RAISERROR(
            'FacilitatorID and CoFacilitatorID must be different people. Two distinct leads are required for every group.',
            16, 1
        );
        RETURN;
    END

    -- Get the group type for qualification check
    DECLARE @GroupTypeID INT;
    SELECT @GroupTypeID = GroupTypeID FROM PeerSupportGroup WHERE GroupID = @GroupID;

    -- Validate lead Facilitator: background check cleared AND qualified for lead
    IF NOT EXISTS (
        SELECT 1 FROM Facilitator f
        JOIN FacilitatorGroupTypeQualification q ON f.FacilitatorID = q.FacilitatorID
        WHERE f.FacilitatorID           = @FacilitatorID
        AND f.BackgroundCheckCleared    = 1
        AND q.GroupTypeID               = @GroupTypeID
        AND q.QualifiedForFacilitator   = 1
    )
    BEGIN
        RAISERROR(
            'FacilitatorID %d is not cleared or not qualified as lead Facilitator for this group type.',
            16, 1, @FacilitatorID
        );
        RETURN;
    END

    -- Validate Co-Facilitator: background check cleared AND qualified for co-lead or lead
    IF NOT EXISTS (
        SELECT 1 FROM Facilitator f
        JOIN FacilitatorGroupTypeQualification q ON f.FacilitatorID = q.FacilitatorID
        WHERE f.FacilitatorID               = @CoFacilitatorID
        AND f.BackgroundCheckCleared        = 1
        AND q.GroupTypeID                   = @GroupTypeID
        AND (q.QualifiedForCoFacilitator    = 1 OR q.QualifiedForFacilitator = 1)
    )
    BEGIN
        RAISERROR(
            'CoFacilitatorID %d is not cleared or not qualified as Co-Facilitator for this group type.',
            16, 1, @CoFacilitatorID
        );
        RETURN;
    END

    -- Assign the facilitators to the group
    UPDATE PeerSupportGroup
    SET
        FacilitatorID   = @FacilitatorID,
        CoFacilitatorID = @CoFacilitatorID
    WHERE GroupID = @GroupID;

    -- Update facilitator statuses to Active
    UPDATE Facilitator
    SET FacilitatorStatusID = (
        SELECT StatusID FROM FacilitatorStatus WHERE StatusName = 'Active'
    )
    WHERE FacilitatorID IN (@FacilitatorID, @CoFacilitatorID)
    AND FacilitatorStatusID = (
        SELECT StatusID FROM FacilitatorStatus WHERE StatusName = 'Qualified'
    );

END
GO

-- =============================================================================
-- PROCEDURE 7: usp_ScheduleMeeting
-- Purpose:  Schedule a meeting session for a group. Defaults to using
--           the group's permanent Facilitator and Co-Facilitator.
--           If either is unavailable, requires a substitute to be
--           specified explicitly. Validates background check clearance
--           for all assigned facilitators.
-- Usage:    Standard session:
--               EXEC usp_ScheduleMeeting @GroupID = 5,
--                   @MeetingDate = '2024-04-01'
--           With substitute:
--               EXEC usp_ScheduleMeeting @GroupID = 5,
--                   @MeetingDate = '2024-04-01',
--                   @SubstituteCoFacilitatorID = 14
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_ScheduleMeeting
    @GroupID                        INT,
    @MeetingDate                    DATE,
    @SubstituteFacilitatorID        INT     = NULL,
    @SubstituteCoFacilitatorID      INT     = NULL,
    @NewMeetingID                   INT     OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Get group's permanent facilitators
    DECLARE @PermFacilitatorID      INT;
    DECLARE @PermCoFacilitatorID    INT;

    SELECT
        @PermFacilitatorID      = FacilitatorID,
        @PermCoFacilitatorID    = CoFacilitatorID
    FROM PeerSupportGroup
    WHERE GroupID = @GroupID;

    IF @PermFacilitatorID IS NULL
    BEGIN
        RAISERROR('GroupID %d does not have facilitators assigned.', 16, 1, @GroupID);
        RETURN;
    END

    -- Determine who actually leads this session
    DECLARE @ActualFacilitatorID    INT = ISNULL(@SubstituteFacilitatorID, @PermFacilitatorID);
    DECLARE @ActualCoFacilitatorID  INT = ISNULL(@SubstituteCoFacilitatorID, @PermCoFacilitatorID);
    DECLARE @IsSubFac               BIT = CASE WHEN @SubstituteFacilitatorID IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @IsSubCoFac             BIT = CASE WHEN @SubstituteCoFacilitatorID IS NOT NULL THEN 1 ELSE 0 END;

    -- Enforce different people in each seat
    IF @ActualFacilitatorID = @ActualCoFacilitatorID
    BEGIN
        RAISERROR(
            'Facilitator and Co-Facilitator must be different people for every session.',
            16, 1
        );
        RETURN;
    END

    -- Verify background check clearance for both actual facilitators
    IF NOT EXISTS (
        SELECT 1 FROM Facilitator
        WHERE FacilitatorID = @ActualFacilitatorID
        AND BackgroundCheckCleared = 1
    )
    BEGIN
        RAISERROR(
            'FacilitatorID %d has not cleared the background check and cannot lead a group session.',
            16, 1, @ActualFacilitatorID
        );
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1 FROM Facilitator
        WHERE FacilitatorID = @ActualCoFacilitatorID
        AND BackgroundCheckCleared = 1
    )
    BEGIN
        RAISERROR(
            'CoFacilitatorID %d has not cleared the background check and cannot lead a group session.',
            16, 1, @ActualCoFacilitatorID
        );
        RETURN;
    END

    INSERT INTO Meeting (
        GroupID,
        FacilitatorID,
        CoFacilitatorID,
        SubstituteFacilitator,
        SubstituteCoFacilitator,
        MeetingDate
    )
    VALUES (
        @GroupID,
        @ActualFacilitatorID,
        @ActualCoFacilitatorID,
        @IsSubFac,
        @IsSubCoFac,
        @MeetingDate
    );

    SET @NewMeetingID = SCOPE_IDENTITY();
END
GO

-- =============================================================================
-- PROCEDURE 8: usp_RecordAttendance
-- Purpose:  Record client attendance for a meeting session.
--           AttendanceStatus: Present, Absent - Notified, Absent - No Contact.
--           'Absent - No Contact' creates a follow-up flag — a client
--           who stops coming without contact is a wellbeing concern
--           in a grief support context.
-- Usage:    EXEC usp_RecordAttendance
--               @MeetingID = 101, @ClientID = 42,
--               @AttendanceStatusName = 'Present'
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_RecordAttendance
    @MeetingID              INT,
    @ClientID               INT,
    @AttendanceStatusName   NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AttendanceStatusID INT;
    SELECT @AttendanceStatusID = StatusID
    FROM AttendanceStatus
    WHERE StatusName = @AttendanceStatusName;

    IF @AttendanceStatusID IS NULL
    BEGIN
        RAISERROR(
            'AttendanceStatus "%s" not found. Valid values: Present, Absent - Notified, Absent - No Contact.',
            16, 1, @AttendanceStatusName
        );
        RETURN;
    END

    MERGE GroupAttendance AS target
    USING (
        SELECT @MeetingID AS MeetingID, @ClientID AS ClientID
    ) AS source
    ON target.MeetingID = source.MeetingID
    AND target.ClientID = source.ClientID
    WHEN MATCHED THEN
        UPDATE SET AttendanceStatusID = @AttendanceStatusID
    WHEN NOT MATCHED THEN
        INSERT (MeetingID, ClientID, AttendanceStatusID, AttendanceDate)
        VALUES (@MeetingID, @ClientID, @AttendanceStatusID, CAST(GETDATE() AS DATE));
END
GO

-- =============================================================================
-- PROCEDURE 9: usp_FindAvailableSubstitutes
-- Purpose:  Find qualified substitutes for a group session on a given
--           date. Returns facilitators who are:
--             1. Available on that date or day of week
--             2. Background check cleared
--             3. Qualified for the group's grief type
--             4. Not already assigned as the other seat for this session
--           This procedure operationalizes the substitute pool concept
--           and makes finding a substitute a query rather than a
--           series of phone calls.
-- Usage:    EXEC usp_FindAvailableSubstitutes
--               @GroupID = 5, @SessionDate = '2024-04-01',
--               @NeedSubstituteFor = 'Facilitator'
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_FindAvailableSubstitutes
    @GroupID            INT,
    @SessionDate        DATE,
    @NeedSubstituteFor  NVARCHAR(20)    -- 'Facilitator' or 'CoFacilitator'
AS
BEGIN
    SET NOCOUNT ON;

    -- Get group type and current permanent assignments
    DECLARE @GroupTypeID            INT;
    DECLARE @PermFacilitatorID      INT;
    DECLARE @PermCoFacilitatorID    INT;

    SELECT
        @GroupTypeID            = GroupTypeID,
        @PermFacilitatorID      = FacilitatorID,
        @PermCoFacilitatorID    = CoFacilitatorID
    FROM PeerSupportGroup
    WHERE GroupID = @GroupID;

    -- Get day of week for availability check
    DECLARE @DayOfWeek NVARCHAR(20) =
        DATENAME(WEEKDAY, @SessionDate);

    -- Minimum qualification required based on which seat needs filling
    DECLARE @NeedLeadQualification BIT =
        CASE WHEN @NeedSubstituteFor = 'Facilitator' THEN 1 ELSE 0 END;

    -- The person currently in the other seat (cannot sub into both)
    DECLARE @OtherSeatFacilitatorID INT =
        CASE
            WHEN @NeedSubstituteFor = 'Facilitator'
            THEN @PermCoFacilitatorID
            ELSE @PermFacilitatorID
        END;

    SELECT
        f.FacilitatorID,
        c.FirstName,
        c.LastName,
        c.Phone,
        c.Email,
        ft.TypeName                             AS FacilitatorType,
        fs.StatusName                           AS FacilitatorStatus,
        q.QualifiedForFacilitator,
        q.QualifiedForCoFacilitator,
        fa.Notes                                AS AvailabilityNotes
    FROM Facilitator f
    JOIN ContactInformation             c   ON f.ContactID          = c.ContactID
    JOIN FacilitatorType                ft  ON f.FacilitatorTypeID  = ft.TypeID
    JOIN FacilitatorStatus              fs  ON f.FacilitatorStatusID = fs.StatusID
    JOIN FacilitatorGroupTypeQualification q ON f.FacilitatorID     = q.FacilitatorID
                                            AND q.GroupTypeID        = @GroupTypeID
    -- Availability: available on this specific date OR standing day availability
    JOIN FacilitatorAvailability        fa  ON f.FacilitatorID      = fa.FacilitatorID
                                            AND fa.IsAvailable       = 1
                                            AND (
                                                fa.AvailableDate = @SessionDate
                                                OR fa.DayOfWeek  = @DayOfWeek
                                            )
    WHERE
        -- Must have background check cleared
        f.BackgroundCheckCleared = 1
        -- Must meet qualification level for the seat needing filling
        AND (
            @NeedLeadQualification = 0
            OR q.QualifiedForFacilitator = 1
        )
        AND (
            @NeedLeadQualification = 1
            OR q.QualifiedForCoFacilitator = 1
        )
        -- Cannot be the same person as the other seat
        AND f.FacilitatorID <> @OtherSeatFacilitatorID
        -- Cannot be the permanent person for this seat (they're unavailable)
        AND f.FacilitatorID <> (
            CASE
                WHEN @NeedSubstituteFor = 'Facilitator'
                THEN @PermFacilitatorID
                ELSE @PermCoFacilitatorID
            END
        )
        -- Not marked unavailable on this specific date
        AND NOT EXISTS (
            SELECT 1 FROM FacilitatorAvailability fa2
            WHERE fa2.FacilitatorID = f.FacilitatorID
            AND fa2.AvailableDate   = @SessionDate
            AND fa2.IsAvailable     = 0
        )
    ORDER BY
        -- Prefer more experienced facilitators at top of list
        q.QualifiedForFacilitator DESC,
        c.LastName,
        c.FirstName;
END
GO

-- =============================================================================
-- PROCEDURE 10: usp_EnrollClientInGroup
-- Purpose:  Enroll a client in a peer support group or place them on
--           the waitlist. Checks InviteToGroups flag before enrolling.
--           If the group already has the client enrolled, reports the
--           current status rather than creating a duplicate.
-- Usage:    EXEC usp_EnrollClientInGroup
--               @ClientID = 42, @GroupID = 5,
--               @EnrollmentStatusName = 'Enrolled'
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_EnrollClientInGroup
    @ClientID               INT,
    @GroupID                INT,
    @EnrollmentStatusName   NVARCHAR(100)   = 'Enrolled',
    @EnrolledByStaffID      INT             = NULL,
    @NewClientGroupID       INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Verify client is flagged as group-ready
    IF NOT EXISTS (
        SELECT 1 FROM ClientInformation
        WHERE ClientID = @ClientID
        AND InviteToGroups = 1
    )
    BEGIN
        RAISERROR(
            'ClientID %d is not currently flagged as group-ready (InviteToGroups = 0). Review with program staff before enrolling.',
            16, 1, @ClientID
        );
        RETURN;
    END

    -- Check for existing enrollment
    IF EXISTS (
        SELECT 1 FROM ClientGroup
        WHERE ClientID = @ClientID AND GroupID = @GroupID
    )
    BEGIN
        DECLARE @CurrentStatus NVARCHAR(100);
        SELECT @CurrentStatus = es.StatusName
        FROM ClientGroup cg
        JOIN EnrollmentStatus es ON cg.EnrollmentStatusID = es.StatusID
        WHERE cg.ClientID = @ClientID AND cg.GroupID = @GroupID;

        RAISERROR(
            'ClientID %d already has a record for GroupID %d with status: %s',
            16, 1, @ClientID, @GroupID, @CurrentStatus
        );
        RETURN;
    END

    DECLARE @EnrollmentStatusID INT;
    SELECT @EnrollmentStatusID = StatusID
    FROM EnrollmentStatus
    WHERE StatusName = @EnrollmentStatusName;

    IF @EnrollmentStatusID IS NULL
    BEGIN
        RAISERROR('EnrollmentStatus "%s" not found.', 16, 1, @EnrollmentStatusName);
        RETURN;
    END

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

    INSERT INTO ClientGroup (
        GroupID,
        ClientID,
        EnrollmentStatusID,
        EnrollmentDate,
        WaitlistDate,
        ProgramCompleted
    )
    VALUES (
        @GroupID,
        @ClientID,
        @EnrollmentStatusID,
        CASE WHEN @EnrollmentStatusName = 'Enrolled'  THEN @Today ELSE NULL END,
        CASE WHEN @EnrollmentStatusName = 'Waitlist'  THEN @Today ELSE NULL END,
        0
    );

    SET @NewClientGroupID = SCOPE_IDENTITY();
END
GO

-- =============================================================================
-- PROCEDURE 11: usp_CompleteProgram
-- Purpose:  Mark a client's participation in a group as complete.
--           Records the completion date and any staff notes.
--           Program completion is tracked explicitly for grant
--           reporting — funders require this data separately from
--           attendance records.
-- Usage:    EXEC usp_CompleteProgram
--               @ClientGroupID = 87, @CompletionNotes = 'Client...',
--               @RecordedByStaffID = 3
-- =============================================================================

CREATE OR ALTER PROCEDURE usp_CompleteProgram
    @ClientGroupID      INT,
    @CompletionNotes    NVARCHAR(MAX)   = NULL,
    @CompletionDate     DATE            = NULL,
    @RecordedByStaffID  INT             = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM ClientGroup WHERE ClientGroupID = @ClientGroupID
    )
    BEGIN
        RAISERROR('ClientGroupID %d does not exist.', 16, 1, @ClientGroupID);
        RETURN;
    END

    IF @CompletionDate IS NULL
        SET @CompletionDate = CAST(GETDATE() AS DATE);

    -- Get Completed status ID
    DECLARE @CompletedStatusID INT;
    SELECT @CompletedStatusID = StatusID
    FROM EnrollmentStatus
    WHERE StatusName = 'Completed';

    UPDATE ClientGroup
    SET
        EnrollmentStatusID  = @CompletedStatusID,
        CompletionDate      = @CompletionDate,
        ProgramCompleted    = 1,
        CompletionNotes     = @CompletionNotes
    WHERE ClientGroupID = @ClientGroupID;
END
GO
