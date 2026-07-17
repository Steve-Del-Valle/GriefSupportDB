-- =============================================================================
-- GriefSupportDB
-- A comprehensive SQL Server database architecture designed to modernize the
-- information system of a grief support nonprofit. Drawing on real-world
-- operational experience with a legacy system, the project reimagines how
-- clients, volunteers, facilitators, donors, staff, programs, and fundraising
-- activities can be managed within a flexible, scalable, and maintainable
-- relational database.
-- =============================================================================
-- Script 11: Views and Analytical Queries
-- Description: Reporting views (vw_ prefix) for day-to-day staff use, plus a
--              library of standalone analytical queries for board reporting,
--              grant reporting, and operational monitoring. Views cover the
--              "what is true right now" questions; the analytical queries at
--              the bottom cover the "how are we doing over time" questions
--              that don't belong permanently in the schema.
-- Version:     v5
-- Author:      Steve
-- Dependencies: 01 through 10 must be run first
-- =============================================================================

USE GriefSupportDB;
GO

-- =============================================================================
-- SECTION 1: CLIENT VIEWS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- VIEW: vw_ActiveClientRoster
-- Purpose: One row per active client with contact and demographic detail.
-- Excludes closed/deceased/inactive clients so front-line staff see only
-- the current active caseload by default.
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_ActiveClientRoster AS
SELECT
    cl.ClientID,
    c.ContactID,
    c.FirstName,
    c.LastName,
    c.Phone,
    c.Email,
    ct.TypeName          AS ClientType,
    cs.StatusName         AS ClientStatus,
    c.DateOfBirth,
    DATEDIFF(YEAR, c.DateOfBirth, GETDATE())
        - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, c.DateOfBirth, GETDATE()), c.DateOfBirth) > GETDATE()
               THEN 1 ELSE 0 END               AS Age,
    g.GenderName,
    ci.CityName,
    st.StateName,
    cl.InviteToGroups,
    cl.ExperiencedSuicideLoss,
    cl.ExperiencedHomicideLoss,
    cl.ClientContactDate,
    staff.JobTitle         AS AssignedStaffTitle,
    sc.FirstName + ' ' + sc.LastName            AS ClientContactStaffName,
    cl.CreatedDate
FROM ClientInformation cl
JOIN ContactInformation c   ON c.ContactID = cl.ContactID
JOIN ClientType ct          ON ct.TypeID = cl.ClientTypeID
JOIN ClientStatus cs        ON cs.StatusID = cl.ClientStatusID
LEFT JOIN Gender g          ON g.GenderID = c.GenderID
LEFT JOIN City ci           ON ci.CityID = c.CityID
LEFT JOIN State st          ON st.StateID = c.StateID
LEFT JOIN Staff staff       ON staff.StaffID = cl.ClientContactStaffID
LEFT JOIN ContactInformation sc ON sc.ContactID = staff.ContactID
WHERE cs.StatusName = 'Active';
GO

-- -----------------------------------------------------------------------------
-- VIEW: vw_ClientLossSummary
-- Purpose: One row per Loss record, joined out to the deceased and the
-- client, for grant reporting on loss type distribution across the caseload.
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_ClientLossSummary AS
SELECT
    l.LossID,
    cl.ClientID,
    c.FirstName + ' ' + c.LastName              AS ClientName,
    lt.TypeName            AS LossType,
    l.DeceasedRelationship,
    d.FirstName + ' ' +
        COALESCE(d.LastName, d.Species, '')     AS DeceasedName,
    dt.TypeName             AS DeceasedType,
    d.DateOfDeath,
    cod.TypeName             AS CauseOfDeath,
    l.LossDate,
    DATEDIFF(DAY, l.LossDate, GETDATE())        AS DaysSinceLoss
FROM Loss l
JOIN ClientInformation cl   ON cl.ClientID = l.ClientID
JOIN ContactInformation c   ON c.ContactID = cl.ContactID
JOIN LossType lt             ON lt.TypeID = l.LossTypeID
LEFT JOIN Deceased d         ON d.DeceasedID = l.DeceasedID
LEFT JOIN DeceasedType dt    ON dt.TypeID = d.DeceasedTypeID
LEFT JOIN CauseOfDeathType cod ON cod.TypeID = d.CauseOfDeathTypeID;
GO

-- -----------------------------------------------------------------------------
-- VIEW: vw_WellbeingFollowUpFlags
-- Purpose: Clients whose most recent recorded attendance was
-- 'Absent - No Contact' - a wellbeing signal that should trigger a staff
-- follow-up call, particularly relevant in a grief support context.
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_WellbeingFollowUpFlags AS
WITH LastAttendance AS (
    SELECT
        ga.ClientID,
        ga.AttendanceStatusID,
        ga.AttendanceDate,
        ROW_NUMBER() OVER (PARTITION BY ga.ClientID ORDER BY ga.AttendanceDate DESC) AS rn
    FROM GroupAttendance ga
)
SELECT
    cl.ClientID,
    c.FirstName + ' ' + c.LastName  AS ClientName,
    c.Phone,
    la.AttendanceDate                AS LastAttendanceDate,
    DATEDIFF(DAY, la.AttendanceDate, GETDATE()) AS DaysSinceLastContact
FROM LastAttendance la
JOIN ClientInformation cl  ON cl.ClientID = la.ClientID
JOIN ContactInformation c  ON c.ContactID = cl.ContactID
WHERE la.rn = 1
  AND la.AttendanceStatusID = (SELECT StatusID FROM AttendanceStatus WHERE StatusName = 'Absent - No Contact');
GO

-- =============================================================================
-- SECTION 2: FACILITATOR AND GROUP VIEWS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- VIEW: vw_FacilitatorRoster
-- Purpose: One row per Facilitator with contact info, pipeline status, and
-- a count of the group types they currently hold a qualification for.
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_FacilitatorRoster AS
SELECT
    f.FacilitatorID,
    c.ContactID,
    c.FirstName + ' ' + c.LastName    AS FacilitatorName,
    ft.TypeName                        AS FacilitatorType,
    fs.StatusName                      AS FacilitatorStatus,
    f.BSTCompletedDate,
    f.BackgroundCheckCleared,
    f.QualifiedDate,
    (SELECT COUNT(*) FROM FacilitatorGroupTypeQualification q
        WHERE q.FacilitatorID = f.FacilitatorID
          AND q.QualifiedForCoFacilitator = 1)   AS GroupTypesQualifiedCoFacilitator,
    (SELECT COUNT(*) FROM FacilitatorGroupTypeQualification q
        WHERE q.FacilitatorID = f.FacilitatorID
          AND q.QualifiedForFacilitator = 1)     AS GroupTypesQualifiedLead
FROM Facilitator f
JOIN ContactInformation c     ON c.ContactID = f.ContactID
JOIN FacilitatorType ft       ON ft.TypeID = f.FacilitatorTypeID
JOIN FacilitatorStatus fs     ON fs.StatusID = f.FacilitatorStatusID;
GO

-- -----------------------------------------------------------------------------
-- VIEW: vw_FacilitatorQualificationDetail
-- Purpose: One row per Facilitator per GroupType qualification, with names
-- resolved. Used to answer "who is qualified to lead a Suicide Loss group?"
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_FacilitatorQualificationDetail AS
SELECT
    q.QualificationID,
    f.FacilitatorID,
    c.FirstName + ' ' + c.LastName    AS FacilitatorName,
    pgt.TypeName                       AS GroupType,
    q.PersonalExperienceVerified,
    q.VettingOutcome,
    q.QualifiedForCoFacilitator,
    q.CoFacilitatorQualifiedDate,
    q.QualifiedForFacilitator,
    q.FacilitatorQualifiedDate
FROM FacilitatorGroupTypeQualification q
JOIN Facilitator f              ON f.FacilitatorID = q.FacilitatorID
JOIN ContactInformation c       ON c.ContactID = f.ContactID
JOIN PeerSupportGroupType pgt   ON pgt.TypeID = q.GroupTypeID;
GO

-- -----------------------------------------------------------------------------
-- VIEW: vw_GroupRoster
-- Purpose: One row per active PeerSupportGroup with facilitator names and
-- a live enrolled-client count.
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_GroupRoster AS
SELECT
    pg.GroupID,
    pg.GroupName,
    pgt.TypeName                        AS GroupType,
    fc.FirstName + ' ' + fc.LastName    AS FacilitatorName,
    cofc.FirstName + ' ' + cofc.LastName AS CoFacilitatorName,
    pg.StartDate,
    pg.EndDate,
    (SELECT COUNT(*) FROM ClientGroup cg
        JOIN EnrollmentStatus es ON es.StatusID = cg.EnrollmentStatusID
        WHERE cg.GroupID = pg.GroupID AND es.StatusName = 'Enrolled')  AS CurrentlyEnrolled,
    (SELECT COUNT(*) FROM ClientGroup cg
        JOIN EnrollmentStatus es ON es.StatusID = cg.EnrollmentStatusID
        WHERE cg.GroupID = pg.GroupID AND es.StatusName = 'Waitlist')  AS CurrentlyWaitlisted
FROM PeerSupportGroup pg
JOIN PeerSupportGroupType pgt  ON pgt.TypeID = pg.GroupTypeID
JOIN Facilitator f             ON f.FacilitatorID = pg.FacilitatorID
JOIN ContactInformation fc     ON fc.ContactID = f.ContactID
JOIN Facilitator cf            ON cf.FacilitatorID = pg.CoFacilitatorID
JOIN ContactInformation cofc   ON cofc.ContactID = cf.ContactID
WHERE pg.EndDate IS NULL;
GO

-- -----------------------------------------------------------------------------
-- VIEW: vw_MeetingAttendanceSummary
-- Purpose: One row per Meeting with headcount, showing whether a substitute
-- covered either seat that session.
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_MeetingAttendanceSummary AS
SELECT
    m.MeetingID,
    pg.GroupName,
    m.MeetingDate,
    fc.FirstName + ' ' + fc.LastName     AS LedBy,
    m.SubstituteFacilitator,
    cofc.FirstName + ' ' + cofc.LastName AS CoLedBy,
    m.SubstituteCoFacilitator,
    (SELECT COUNT(*) FROM GroupAttendance ga
        JOIN AttendanceStatus a ON a.StatusID = ga.AttendanceStatusID
        WHERE ga.MeetingID = m.MeetingID AND a.StatusName = 'Present')            AS PresentCount,
    (SELECT COUNT(*) FROM GroupAttendance ga
        JOIN AttendanceStatus a ON a.StatusID = ga.AttendanceStatusID
        WHERE ga.MeetingID = m.MeetingID AND a.StatusName = 'Absent - Notified')  AS AbsentNotifiedCount,
    (SELECT COUNT(*) FROM GroupAttendance ga
        JOIN AttendanceStatus a ON a.StatusID = ga.AttendanceStatusID
        WHERE ga.MeetingID = m.MeetingID AND a.StatusName = 'Absent - No Contact') AS AbsentNoContactCount
FROM Meeting m
JOIN PeerSupportGroup pg      ON pg.GroupID = m.GroupID
JOIN Facilitator f            ON f.FacilitatorID = m.FacilitatorID
JOIN ContactInformation fc    ON fc.ContactID = f.ContactID
JOIN Facilitator cf           ON cf.FacilitatorID = m.CoFacilitatorID
JOIN ContactInformation cofc  ON cofc.ContactID = cf.ContactID;
GO

-- =============================================================================
-- SECTION 3: DONOR AND FUNDRAISING VIEWS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- VIEW: vw_DonorGivingSummary
-- Purpose: Lifetime giving totals per donor, current giving-level threshold
-- lookup against OrgConfiguration, and most recent gift date. This is the
-- view usp_GetDonorLevel is built on top of for single-donor lookups; this
-- version is set-based for donor list reporting.
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_DonorGivingSummary AS
SELECT
    dn.DonorID,
    c.ContactID,
    COALESCE(c.OrganizationName, c.FirstName + ' ' + c.LastName)  AS DonorName,
    dt.TypeName                AS DonorType,
    ds.StatusName               AS DonorStatus,
    dn.IsProspect,
    COUNT(pa.AllocationID)      AS TotalGifts,
    SUM(pa.Amount)               AS LifetimeGiving,
    MAX(p.PaymentDate)           AS MostRecentGiftDate,
    MAX(pa.Amount)                AS LargestSingleGift,
    CASE
        WHEN SUM(pa.Amount) >= CAST((SELECT ConfigValue FROM OrgConfiguration WHERE ConfigKey = 'VIPDonorThreshold') AS DECIMAL(10,2))
            THEN 'VIP'
        WHEN SUM(pa.Amount) >= CAST((SELECT ConfigValue FROM OrgConfiguration WHERE ConfigKey = 'MajorDonorThreshold') AS DECIMAL(10,2))
            THEN 'Major Donor'
        ELSE 'Standard'
    END                           AS DonorLevel
FROM DonorInformation dn
JOIN ContactInformation c    ON c.ContactID = dn.ContactID
JOIN DonorType dt             ON dt.TypeID = dn.DonorTypeID
JOIN DonorStatus ds           ON ds.StatusID = dn.DonorStatusID
LEFT JOIN PaymentAllocation pa ON pa.DonorID = dn.DonorID
LEFT JOIN Payment p            ON p.PaymentID = pa.PaymentID
GROUP BY
    dn.DonorID, c.ContactID, c.OrganizationName, c.FirstName, c.LastName,
    dt.TypeName, ds.StatusName, dn.IsProspect;
GO

-- -----------------------------------------------------------------------------
-- VIEW: vw_PaymentAllocationDetail
-- Purpose: Flattened, human-readable view of every PaymentAllocation with
-- payer, allocation type, campaign, and scholarship fund names resolved.
-- The natural source for the tax-acknowledgement and general ledger export.
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_PaymentAllocationDetail AS
SELECT
    pa.AllocationID,
    p.PaymentID,
    p.PaymentDate,
    COALESCE(c.OrganizationName, c.FirstName + ' ' + c.LastName)  AS PayerName,
    pmt.TypeName          AS PaymentMethod,
    at.TypeName            AS AllocationType,
    pa.Amount,
    pa.IsTaxDeductible,
    pa.IsScholarship,
    pa.ScholarshipAmount,
    camp.CampaignName,
    sf.FundName             AS ScholarshipFund,
    fs.FeeName,
    p.AcknowledgementSent,
    p.AcknowledgementDate
FROM PaymentAllocation pa
JOIN Payment p                ON p.PaymentID = pa.PaymentID
JOIN ContactInformation c     ON c.ContactID = p.ContactID
JOIN PaymentMethodType pmt    ON pmt.TypeID = p.PaymentMethodTypeID
JOIN AllocationType at        ON at.TypeID = pa.AllocationTypeID
LEFT JOIN Campaign camp        ON camp.CampaignID = pa.CampaignID
LEFT JOIN ScholarshipFund sf   ON sf.ScholarshipFundID = pa.ScholarshipFundID
LEFT JOIN FeeSchedule fs       ON fs.FeeID = pa.FeeID;
GO

-- -----------------------------------------------------------------------------
-- VIEW: vw_ScholarshipFundBalance
-- Purpose: Raised vs. awarded vs. remaining balance per ScholarshipFund.
-- Deliberately computed rather than stored, per the design note in Script 07 -
-- a stored balance column would drift out of sync with the transactions.
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_ScholarshipFundBalance AS
SELECT
    sf.ScholarshipFundID,
    sf.FundName,
    sf.IsActive,
    COALESCE((SELECT SUM(pa.Amount) FROM PaymentAllocation pa
                WHERE pa.ScholarshipFundID = sf.ScholarshipFundID), 0)  AS TotalRaised,
    COALESCE((SELECT SUM(sa.AwardAmount) FROM ScholarshipAward sa
                WHERE sa.ScholarshipFundID = sf.ScholarshipFundID), 0)  AS TotalAwarded,
    COALESCE((SELECT SUM(pa.Amount) FROM PaymentAllocation pa
                WHERE pa.ScholarshipFundID = sf.ScholarshipFundID), 0)
        - COALESCE((SELECT SUM(sa.AwardAmount) FROM ScholarshipAward sa
                WHERE sa.ScholarshipFundID = sf.ScholarshipFundID), 0)  AS RemainingBalance,
    (SELECT COUNT(*) FROM ScholarshipAward sa
        WHERE sa.ScholarshipFundID = sf.ScholarshipFundID)               AS AwardsMade
FROM ScholarshipFund sf;
GO

-- =============================================================================
-- SECTION 4: VOLUNTEER AND OUTREACH VIEWS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- VIEW: vw_VolunteerPipelineStatus
-- Purpose: One row per volunteer showing where they sit in the credentialing
-- pipeline. Used by the Volunteer Coordinator to see who is stalled and where.
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_VolunteerPipelineStatus AS
SELECT
    v.VolunteerID,
    c.ContactID,
    c.FirstName + ' ' + c.LastName    AS VolunteerName,
    vs.StatusName                      AS VolunteerStatus,
    v.InterestedInTraining,
    v.BSTRegistrationDate,
    v.BSTCompletedDate,
    v.BackgroundCheckReleaseForm,
    v.BackgroundCheckSubmitted,
    v.BackgroundCheckReport,
    v.PersonalInterviewCompleted,
    CASE
        WHEN v.PersonalInterviewCompleted = 1 THEN 'Interview Complete'
        WHEN v.BackgroundCheckReport IS NOT NULL THEN 'Background Check Received'
        WHEN v.BackgroundCheckSubmitted IS NOT NULL THEN 'Background Check Submitted'
        WHEN v.BackgroundCheckReleaseForm = 1 THEN 'Background Check Release Signed'
        WHEN v.BSTCompletedDate IS NOT NULL THEN 'BST Completed'
        WHEN v.BSTRegistrationDate IS NOT NULL THEN 'BST Registered'
        WHEN v.InterestedInTraining = 1 THEN 'Interested - Not Yet Registered'
        ELSE 'Inquiry Only'
    END                                  AS PipelineStage
FROM VolunteerInformation v
JOIN ContactInformation c   ON c.ContactID = v.ContactID
JOIN VolunteerStatus vs     ON vs.StatusID = v.VolunteerStatusID;
GO

-- -----------------------------------------------------------------------------
-- VIEW: vw_OutreachEventSummary
-- Purpose: Event-level summary with type name and both attendance measures
-- (headcount estimate vs. individually tracked attendees) side by side.
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_OutreachEventSummary AS
SELECT
    e.EventID,
    e.EventName,
    et.TypeName              AS EventType,
    e.EventDate,
    e.Location,
    s.FirstName + ' ' + s.LastName   AS OrganizedBy,
    e.AttendeeCount           AS EstimatedHeadcount,
    (SELECT COUNT(*) FROM OutreachEventAttendance a
        WHERE a.EventID = e.EventID)  AS TrackedAttendeeCount
FROM OutreachEvent e
JOIN OutreachEventType et    ON et.TypeID = e.EventTypeID
LEFT JOIN Staff st            ON st.StaffID = e.OrganizedByStaffID
LEFT JOIN ContactInformation s ON s.ContactID = st.ContactID;
GO

-- =============================================================================
-- SECTION 5: ANALYTICAL QUERIES
-- Standalone SELECT statements for board packets, grant reports, and
-- operational monitoring. These are intentionally NOT views - they represent
-- point-in-time analysis someone runs and reads, not a live pass-through
-- staff would query filtered/joined further. Copy the block you need into
-- SSMS or a scheduled reporting job.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- QUERY 1: Unduplicated clients served, by loss type
-- Grant-report style: counts each client once per loss type they carry,
-- for a given reporting period, based on when the Loss was disclosed.
-- -----------------------------------------------------------------------------
SELECT
    lt.TypeName                        AS LossType,
    COUNT(DISTINCT cl.ClientID)         AS UnduplicatedClients
FROM Loss l
JOIN ClientInformation cl ON cl.ClientID = l.ClientID
JOIN LossType lt           ON lt.TypeID = l.LossTypeID
WHERE l.CreatedDate >= DATEADD(YEAR, -1, GETDATE())
GROUP BY lt.TypeName
ORDER BY UnduplicatedClients DESC;
GO

-- -----------------------------------------------------------------------------
-- QUERY 2: Group attendance rate by group type, trailing 12 months
-- Present rate = Present / (Present + both Absent categories).
-- -----------------------------------------------------------------------------
SELECT
    pgt.TypeName                                            AS GroupType,
    COUNT(*)                                                  AS TotalAttendanceRecords,
    SUM(CASE WHEN a.StatusName = 'Present' THEN 1 ELSE 0 END) AS PresentCount,
    SUM(CASE WHEN a.StatusName <> 'Present' THEN 1 ELSE 0 END) AS AbsentCount,
    CAST(SUM(CASE WHEN a.StatusName = 'Present' THEN 1 ELSE 0 END) AS DECIMAL(10,2))
        / NULLIF(COUNT(*), 0) * 100                            AS AttendanceRatePct
FROM GroupAttendance ga
JOIN Meeting m               ON m.MeetingID = ga.MeetingID
JOIN PeerSupportGroup pg     ON pg.GroupID = m.GroupID
JOIN PeerSupportGroupType pgt ON pgt.TypeID = pg.GroupTypeID
JOIN AttendanceStatus a       ON a.StatusID = ga.AttendanceStatusID
WHERE ga.AttendanceDate >= DATEADD(YEAR, -1, GETDATE())
GROUP BY pgt.TypeName
ORDER BY AttendanceRatePct DESC;
GO

-- -----------------------------------------------------------------------------
-- QUERY 3: Facilitator session leaderboard, trailing 12 months
-- Counts sessions led (as either seat) per facilitator, including substitute
-- coverage, to support volunteer recognition and workload balancing.
-- -----------------------------------------------------------------------------
SELECT
    c.FirstName + ' ' + c.LastName   AS FacilitatorName,
    ft.TypeName                       AS FacilitatorType,
    COUNT(*)                           AS SessionsLed,
    SUM(CASE WHEN m.SubstituteFacilitator = 1 OR m.SubstituteCoFacilitator = 1
             THEN 1 ELSE 0 END)         AS SessionsAsSubstitute
FROM (
    SELECT MeetingID, FacilitatorID, SubstituteFacilitator, SubstituteCoFacilitator, MeetingDate FROM Meeting
    UNION ALL
    SELECT MeetingID, CoFacilitatorID, SubstituteFacilitator, SubstituteCoFacilitator, MeetingDate FROM Meeting
) m
JOIN Facilitator f          ON f.FacilitatorID = m.FacilitatorID
JOIN ContactInformation c   ON c.ContactID = f.ContactID
JOIN FacilitatorType ft     ON ft.TypeID = f.FacilitatorTypeID
WHERE m.MeetingDate >= DATEADD(YEAR, -1, GETDATE())
GROUP BY c.FirstName, c.LastName, ft.TypeName
ORDER BY SessionsLed DESC;
GO

-- -----------------------------------------------------------------------------
-- QUERY 4: Donor retention, this year vs. last year
-- A donor "retains" if they gave in both the prior 12-month window and the
-- current 12-month window. Classic year-over-year fundraising metric.
-- -----------------------------------------------------------------------------
WITH CurrentYearDonors AS (
    SELECT DISTINCT pa.DonorID
    FROM PaymentAllocation pa
    JOIN Payment p ON p.PaymentID = pa.PaymentID
    WHERE pa.DonorID IS NOT NULL
      AND p.PaymentDate >= DATEADD(YEAR, -1, GETDATE())
),
PriorYearDonors AS (
    SELECT DISTINCT pa.DonorID
    FROM PaymentAllocation pa
    JOIN Payment p ON p.PaymentID = pa.PaymentID
    WHERE pa.DonorID IS NOT NULL
      AND p.PaymentDate >= DATEADD(YEAR, -2, GETDATE())
      AND p.PaymentDate <  DATEADD(YEAR, -1, GETDATE())
)
SELECT
    (SELECT COUNT(*) FROM PriorYearDonors)                                            AS PriorYearDonorCount,
    (SELECT COUNT(*) FROM CurrentYearDonors)                                          AS CurrentYearDonorCount,
    (SELECT COUNT(*) FROM CurrentYearDonors cy
        WHERE cy.DonorID IN (SELECT DonorID FROM PriorYearDonors))                    AS RetainedDonorCount,
    CAST((SELECT COUNT(*) FROM CurrentYearDonors cy
            WHERE cy.DonorID IN (SELECT DonorID FROM PriorYearDonors)) AS DECIMAL(10,2))
        / NULLIF((SELECT COUNT(*) FROM PriorYearDonors), 0) * 100                     AS RetentionRatePct;
GO

-- -----------------------------------------------------------------------------
-- QUERY 5: Waitlist aging report
-- How long has each currently-waitlisted client been waiting? Flags anyone
-- over 30 days for staff prioritization.
-- -----------------------------------------------------------------------------
SELECT
    c.FirstName + ' ' + c.LastName   AS ClientName,
    pg.GroupName,
    pgt.TypeName                      AS GroupType,
    cg.WaitlistDate,
    DATEDIFF(DAY, cg.WaitlistDate, GETDATE())  AS DaysOnWaitlist,
    CASE WHEN DATEDIFF(DAY, cg.WaitlistDate, GETDATE()) > 30
         THEN 'Needs Follow Up' ELSE 'Within Normal Range' END AS Flag
FROM ClientGroup cg
JOIN EnrollmentStatus es    ON es.StatusID = cg.EnrollmentStatusID
JOIN ClientInformation cl   ON cl.ClientID = cg.ClientID
JOIN ContactInformation c   ON c.ContactID = cl.ContactID
JOIN PeerSupportGroup pg    ON pg.GroupID = cg.GroupID
JOIN PeerSupportGroupType pgt ON pgt.TypeID = pg.GroupTypeID
WHERE es.StatusName = 'Waitlist'
ORDER BY DaysOnWaitlist DESC;
GO

-- -----------------------------------------------------------------------------
-- QUERY 6: Referral source effectiveness
-- For each ReferralSource, how many encounters resulted in an eventual
-- 'Enrolled' or 'Completed' ClientGroup record? A crude but useful funnel.
-- -----------------------------------------------------------------------------
SELECT
    rs.SourceName                                                    AS ReferralSource,
    COUNT(DISTINCT e.ContactID)                                       AS ContactsReferred,
    COUNT(DISTINCT CASE WHEN es.StatusName IN ('Enrolled','Completed')
                         THEN cl.ClientID END)                        AS ClientsEnrolledOrCompleted,
    CAST(COUNT(DISTINCT CASE WHEN es.StatusName IN ('Enrolled','Completed')
                         THEN cl.ClientID END) AS DECIMAL(10,2))
        / NULLIF(COUNT(DISTINCT e.ContactID), 0) * 100                 AS ConversionRatePct
FROM Encounter e
JOIN ReferralSource rs      ON rs.SourceID = e.ReferralSourceID
LEFT JOIN ClientInformation cl  ON cl.ContactID = e.ContactID
LEFT JOIN ClientGroup cg        ON cg.ClientID = cl.ClientID
LEFT JOIN EnrollmentStatus es   ON es.StatusID = cg.EnrollmentStatusID
GROUP BY rs.SourceName
ORDER BY ConversionRatePct DESC;
GO

-- -----------------------------------------------------------------------------
-- QUERY 7: Volunteer pipeline funnel
-- Counts volunteers currently sitting at each pipeline stage, using the
-- same stage logic as vw_VolunteerPipelineStatus, to visualize drop-off.
-- -----------------------------------------------------------------------------
SELECT
    PipelineStage,
    COUNT(*) AS VolunteerCount
FROM vw_VolunteerPipelineStatus
GROUP BY PipelineStage
ORDER BY
    CASE PipelineStage
        WHEN 'Inquiry Only'                        THEN 1
        WHEN 'Interested - Not Yet Registered'      THEN 2
        WHEN 'BST Registered'                       THEN 3
        WHEN 'BST Completed'                        THEN 4
        WHEN 'Background Check Release Signed'      THEN 5
        WHEN 'Background Check Submitted'           THEN 6
        WHEN 'Background Check Received'            THEN 7
        WHEN 'Interview Complete'                   THEN 8
        ELSE 9
    END;
GO

-- -----------------------------------------------------------------------------
-- QUERY 8: Scholarship fund utilization
-- Wraps vw_ScholarshipFundBalance with a utilization percentage, useful for
-- deciding whether a fund needs another appeal or is sitting underused.
-- -----------------------------------------------------------------------------
SELECT
    FundName,
    TotalRaised,
    TotalAwarded,
    RemainingBalance,
    AwardsMade,
    CAST(TotalAwarded AS DECIMAL(10,2)) / NULLIF(TotalRaised, 0) * 100  AS UtilizationRatePct
FROM vw_ScholarshipFundBalance
WHERE IsActive = 1
ORDER BY UtilizationRatePct DESC;
GO

-- -----------------------------------------------------------------------------
-- QUERY 9: Mailing preference opt-in distribution
-- Simple census of how many active contacts are opted into each mailing
-- type, to size print runs and estimate postage/appeal reach.
-- -----------------------------------------------------------------------------
SELECT
    mt.TypeName        AS MailingType,
    COUNT(*)            AS OptedInContacts
FROM MailingPreference mp
JOIN MailingType mt     ON mt.TypeID = mp.MailingTypeID
JOIN ContactInformation c ON c.ContactID = mp.ContactID
JOIN ProfileStatus ps   ON ps.StatusID = c.ProfileStatusID
WHERE mp.OptedIn = 1
  AND ps.StatusName = 'Active'
GROUP BY mt.TypeName
ORDER BY OptedInContacts DESC;
GO

-- -----------------------------------------------------------------------------
-- QUERY 10: Board-ready snapshot
-- A single results grid combining the handful of numbers a board packet
-- opens with: active caseload, active groups, active facilitators, YTD
-- giving, and open waitlist count.
-- -----------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM ClientInformation cl
        JOIN ClientStatus cs ON cs.StatusID = cl.ClientStatusID
        WHERE cs.StatusName = 'Active')                                    AS ActiveClients,
    (SELECT COUNT(*) FROM PeerSupportGroup WHERE EndDate IS NULL)          AS ActiveGroups,
    (SELECT COUNT(*) FROM Facilitator f
        JOIN FacilitatorStatus fs ON fs.StatusID = f.FacilitatorStatusID
        WHERE fs.StatusName = 'Active')                                    AS ActiveFacilitators,
    (SELECT SUM(pa.Amount) FROM PaymentAllocation pa
        JOIN Payment p ON p.PaymentID = pa.PaymentID
        JOIN AllocationType at ON at.TypeID = pa.AllocationTypeID
        WHERE at.TypeName LIKE 'Donation%'
          AND p.PaymentDate >= DATEFROMPARTS(YEAR(GETDATE()), 1, 1))       AS YTDDonations,
    (SELECT COUNT(*) FROM ClientGroup cg
        JOIN EnrollmentStatus es ON es.StatusID = cg.EnrollmentStatusID
        WHERE es.StatusName = 'Waitlist')                                   AS WaitlistTotal;
GO
