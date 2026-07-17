# Design Decisions
*GriefSupportDB — a comprehensive SQL Server database architecture designed
to modernize the information system of a grief support nonprofit.*

This document explains the reasoning behind the key architectural
choices in GriefSupportDB. Each decision was made in response to a
real problem observed in the systems that came before this one, or a
real operational need of the organization being modeled.

---

## ContactInformation as the universal center

**Decision:** Every person and organization in the database has exactly
one `ContactInformation` record. All roles — Client, Donor, Volunteer,
Staff, Board Member, Facilitator — are separate tables that link back
to `ContactInformation` via `ContactID`.

**Why:** The original systems were siloed. A donor who was also a
client existed in Giftworks and in the CDB as two completely separate
records with no connection between them. A volunteer who donated had
no linkage between their volunteer record and their giving history. A
board member who sought grief support services after a personal loss
had no clean way to exist in both capacities.

The single-profile model means a person is entered once. Every role
they hold, every encounter, every donation, every group attendance
record connects to that one record. The organization can see the whole
person, not a fragment of them determined by which system happened to
hold their data.

---

## Roles are separate tables, not a single role column

**Decision:** Each role has its own table (`Staff`, `BoardMember`,
`VolunteerInformation`, `ClientInformation`, `DonorInformation`,
`Facilitator`) rather than a single `Role` column on
`ContactInformation`.

**Why:** Each role has different attributes. A Staff record needs a job
title and employment dates. A Volunteer record needs BST registration
dates, background check status, and interview completion. A Client
record needs insurance, minor suitability, and suicide/homicide loss
flags. A Donor record needs prospect status and assigned board member.
Collapsing these into a single role column would either lose all of
that role-specific data or require a single table with dozens of
nullable columns that mean nothing outside their specific role context.

Separate tables keep each role's data clean, queryable, and meaningful.

---

## Roles are date-ranged

**Decision:** Every role table has `StartDate` and `EndDate`. A `NULL`
EndDate means the role is currently active.

**Why:** People's relationships with organizations change over time.
A staff member leaves and returns as a board member. A client becomes
a volunteer. A volunteer takes a leave of absence and returns. A board
member's term ends and they begin a new term in a different seat.

Without date ranges, recording a new role overwrites the history of
the previous one. With date ranges, the complete history is preserved.
Queries can filter for currently active roles (`EndDate IS NULL`) or
reconstruct what the organization looked like at any point in time.

---

## ReferralType and ReferralSource belong on Encounter, not Client

**Decision:** `ReferralTypeID` and `ReferralSourceID` are columns on
`Encounter`, not on `ClientInformation`.

**Why:** This was one of the most significant structural problems in
the original system. Storing referral information at the client level
implies a person can only have one referral type and one referral
source across their entire relationship with the organization. That is
not how people actually engage with grief support services.

A parent may call for their child on the first encounter — referral
type "For Child / Youth," referred by a school counselor. Six months
later the same parent calls for themselves — referral type "For Self,"
referred by a friend. Both encounters are real and both contexts matter.
A single field on the client record can only hold one of them and will
be wrong for the other.

Recording referral context at the Encounter level captures the reality
of each contact accurately without overwriting prior history.

---

## Encounter is the universal contact record

**Decision:** A single `Encounter` table with an expanded `EncounterType`
lookup and an `IsLightweight` flag replaces the original two-table
approach of Encounter + Interaction.

**Why:** Two separate tables for different levels of contact formality
creates a question every staff member has to answer before logging
anything: does this go in Encounter or Interaction? That question has
no clean answer when the boundaries are ambiguous, which they always
are in practice.

A single table with a flag removes the ambiguity. `IsLightweight = 0`
means full documentation is expected. `IsLightweight = 1` means this
is a quick touchpoint — a reminder call, an attendance confirmation —
that warrants a log entry but not a full encounter record. One table
also means one query to see a complete contact history for any person.

---

## Deceased persons are records, not text fields

**Decision:** A `Deceased` table with its own primary key, searchable
name fields, cause of death, and a `DeceasedType` that distinguishes
persons from pets.

**Why:** The original system stored the deceased person's name as a
plain text field on the client record. That approach loses two things:

First, searchability. If a staff member wants to find all clients who
lost someone named Robert Garcia, a text field search is fragile and
unreliable. A proper record with indexed name fields makes this query
clean and accurate.

Second, linkability. Two siblings who both lost the same parent are
two separate clients. In the original system, the parent exists as two
separate text strings in two separate records with no connection. In
GriefSupportDB, the parent exists as one `Deceased` record that both
client Loss records reference. The shared loss is visible in the data.

**On pet loss:** The organization serves people who have lost animal
companions. This is a recognized grief type with its own support group.
The `Deceased` table handles this through a `DeceasedTypeID` field
(Person or Pet / Animal Companion) and a nullable `Species` field.
The same table, same structure, no separate handling required.

---

## Payments are split, not summarized

**Decision:** A `Payment` table records the physical transaction. A
`PaymentAllocation` table splits that payment across one or more
purposes. `IsTaxDeductible` is tracked at the allocation level.

**Why:** The original system had no clean way to record a single check
that covered both a program fee and a donation. This was documented as
an unresolved problem in the organization's data entry conventions.
Staff had to choose which it was and lose the other, or find a
workaround that produced inconsistent data.

A payment of $200 that is half group fee and half donation produces:
one `Payment` record (the check) and two `PaymentAllocation` records
(the fee portion and the donation portion). The tax receipt covers
only the allocation where `IsTaxDeductible = 1`. The total of all
allocations is enforced to equal the payment total by stored procedure.

This model also handles scholarship fees cleanly. A scholarship
recipient pays a reduced fee. The allocation records the full fee
amount, the `IsScholarship` flag, and the actual amount paid. The
scholarship fund records the difference as an award.

---

## Facilitator credentialing is a pipeline

**Decision:** Facilitator qualification is modeled as a multi-gate
pipeline with separate credentials at the universal level (BST,
background check, initial interview) and the grief-type-specific
level (personal experience, vetting, Co-Facilitator experience,
promotion to lead).

**Why:** The organization has specific, well-defined requirements for
who can sit in the lead and co-lead seats of a grief support group.
Those requirements exist because putting an unqualified person in
front of grieving people in crisis can cause real harm.

Modeling this as a pipeline means the database enforces the
requirements structurally. A person cannot be assigned as a group
Facilitator without a `FacilitatorGroupTypeQualification` record
showing `QualifiedForFacilitator = 1`. A meeting cannot be scheduled
without both a Facilitator and Co-Facilitator in the record. Both
must have `BackgroundCheckCleared = 1`. A Co-Facilitator cannot be
promoted to lead without the minimum session count confirmed in
`OrgConfiguration`.

The credentialing pipeline also handles the case of a person qualifying
for multiple grief types independently. Someone who lost a child to
suicide may be qualified for both the Suicide Loss group and the Child
Loss group. Each qualification is its own record with its own vetting
history, because the personal experience and vetting for each type is
independently meaningful.

---

## Groups require two permanent leads

**Decision:** `PeerSupportGroup` has both `FacilitatorID` and
`CoFacilitatorID` as NOT NULL foreign keys with a CHECK constraint
preventing them from being the same person.

**Why:** The organization's operational standard is that every group
session has two people in a leadership role for safety and group
management. This is not optional. A group that only has one lead is
not running.

Modeling this as two required fields rather than one required and one
optional makes the business rule structural rather than procedural.
The database cannot hold a group record without both seats filled.

The permanent assignment lives on `PeerSupportGroup` for continuity
and trust — the same two people run the group for its duration. The
`Meeting` table records who actually led each session, including
substitutions, with `SubstituteFacilitator` and `SubstituteCoFacilitator`
flags signaling when a substitute was used.

---

## Configurable business rules

**Decision:** Business rules that may change over time are stored in
an `OrgConfiguration` key-value table rather than hardcoded in stored
procedures.

**Why:** Business rules change. The minimum number of Co-Facilitator
sessions before promotion, the major donor threshold, the fee amounts
— these are organizational policies, not technical constants. If they
are hardcoded in procedures, changing them requires a developer. If
they are stored in a configuration table, a staff member with the
right access can update them.

The `OrgConfiguration` table stores the key (e.g.,
`MinCoFacilitatorSessions`), the value (`6`), a plain-language
description of what the setting controls, and an audit trail of who
last changed it and when. Stored procedures read from this table rather
than containing hardcoded values.

---

## Relationships are recorded, not valued

**Decision:** `DeceasedRelationship` on `Loss` records the relationship
between the deceased and the client — spouse, parent, sibling, pet,
unborn child, aunt, uncle, colleague, friend — without any field or
logic implying how significant that relationship was to the client.
`NULL` is reserved exclusively for a relationship that is genuinely
unknown or not yet documented. It is never used as a stand-in for a
relationship the schema's author, or society more broadly, might be
tempted to treat as lesser.

**Why:** Early in this project, pet loss was handled by setting
`DeceasedRelationship` to `NULL` — the reasoning at the time was that a
pet "doesn't get a human relationship value." That was a mistake. A pet
can be someone's closest companion. An aunt or uncle can have been a
child's primary caregiver. The loss of a pregnancy or a stillbirth is
a real, often profoundly under-acknowledged grief. None of these
relationships are less real for falling outside a narrow definition of
immediate family, and a database that goes quiet exactly where a
relationship doesn't fit a conventional category is, in its own small
way, repeating the same failure to see the whole person that this
project exists to correct.

The fix was to treat every relationship the same way structurally:
`LossTypeID` and `DeceasedRelationship` are chosen together and
validated against each other (a "Spouse Loss" record can't end up
paired with "Daughter" as the relationship), pet loss and pregnancy
loss both get real, specific relationship values rather than an
absence of one, and the relationship vocabulary was broadened to
include aunt, uncle, and other roles that carry no less weight for
being outside the nuclear family.

The database's job is to record *what* the relationship was. It is
explicitly not the database's job to imply *how much it mattered* —
that judgment belongs to the client's own narrative, captured in
`Note` and `Encounter` records, not inferred from a relationship code.
An aunt who raised a child after a parent's death and a distant
acquaintance are both recorded the same way at the schema level:
as "Aunt." The difference between them is a story staff will learn
and document, not something a lookup table should presume to know
in advance.

---

## Model the business process, not the program name

**Decision:** All lookups and table names model the organizational
concept rather than a specific program or historical name.

**Why:** Programs change. The Theatre Troupe became a broader
Expressive Arts program that encompasses drama, art, music, movement,
and storytelling. If the database had a lookup value called "Theatre
Troupe," adding a visual art program would require either misusing an
existing value, adding a new one that partially overlaps, or changing
the schema.

"Expressive Arts" as a `PeerSupportGroupType` and a `ProgramType`
accommodates all of those modalities without change. New programs —
whatever they are called — fit into the existing structure by adding a
row to a lookup table, not by altering a table definition.

This principle applies throughout: ILOF (In Lieu Of Flowers) is a
Campaign, not a mailing type. A Campaign can have a name, a type, a
date range, and a designation target. Any future fundraising appeal —
Giving Tuesday, a capital campaign, a memorial fund — is modeled the
same way. The schema does not know or care what the campaigns are
called. It knows how campaigns work.
