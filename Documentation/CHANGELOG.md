# Changelog
*GriefSupportDB — a comprehensive SQL Server database architecture designed
to modernize the information system of a grief support nonprofit.*

All versions of the GriefSupportDB schema are documented here.
Each version reflects a distinct phase of design thinking, driven by
new questions, discovered gaps, or a clearer understanding of the
business process being modeled.

---

## Post-v5 — Relationships Are Recorded, Not Valued

**Theme:** *NULL should mean "unknown," never "a relationship this schema didn't think to honor."*

Reviewing how pet loss was represented turned up a real design flaw:
`DeceasedRelationship` was set to `NULL` for pet loss, on the reasoning
that a pet "doesn't get a human relationship value." That reasoning was
wrong, and worth correcting explicitly rather than quietly patching.

### What changed

**Pet loss now gets a real relationship value.**
`DeceasedRelationship` for `LossTypeID = 10` (Pet / Animal Companion
Loss) is now `'Pet / Animal Companion'` — a documented relationship,
not an absence of one. `LossTypeID` and `DeceasedRelationship` are now
chosen together rather than independently in both the seed data and
the Python generator, which also fixed a separate correctness bug: an
independently-random relationship could previously produce nonsensical
pairings like "Spouse / Partner Loss" recorded with "Daughter" as the
relationship.

**"Pregnancy Loss / Stillbirth" added to `LossType`.**
Added as `TypeID = 17`, appended at the end of the existing
`LossType` values to avoid renumbering the 16 already in use. Pairs
with the relationship value `'Unborn Child'`.

**Relationship vocabulary broadened.**
`Aunt` and `Uncle` added to the general relationship pool used by loss
types that don't imply a specific family role (Suicide Loss, Homicide
Loss, Divorce, Aging and Loss, and others). An aunt or uncle can be a
primary caregiver or a person's closest relationship; the schema
shouldn't imply otherwise by omission.

**New design principle documented.**
See DESIGN_DECISIONS.md, "Relationships are recorded, not valued" —
the database records what a relationship was; it never implies how
much that relationship mattered. That judgment belongs in the client's
narrative, captured in `Note` and `Encounter` records, not inferred
from a relationship code or a missing one.

### Design principle established
> *A database that goes quiet exactly where a relationship doesn't fit a conventional category repeats the failure it exists to correct.*

---



**Theme:** *The most recent loss and the loss someone needs help with right now are not always the same thing.*

Working through the seed data revealed a real gap: the schema could
record that a client had experienced a loss, but had no way to say
*which* loss — of possibly several, at very different points in time —
was the one actually driving their need for support today. A loss from
years ago can resurface as the active concern long after a more recent
loss has occurred. The schema needed to represent that directly rather
than leaving it to be inferred from context.

### What changed

**`Loss.IsPrimaryConcern` added.**
A `BIT` flag, default 0, marking which of a client's loss records is
currently their active concern. A filtered unique index
(`UQ_Loss_OnePrimaryPerClient`) enforces that at most one loss per
client can hold this flag at a time, structurally rather than by
convention. The flag is intentionally mutable — it can move from one
`Loss` record to another as a client's circumstances change, without
touching `LossDate` or any other historical fact about the loss itself.

**`Encounter.LossID` added.**
A nullable foreign key to `Loss`, identifying which specific loss a
given encounter concerned. Nullable because most encounter types —
a donor stewardship call, a volunteer inquiry — aren't about a loss at
all. This is deliberately the *reverse* relationship from the existing
`Loss.EncounterID` column: that column fixes the one encounter where a
loss was first disclosed, a fact that never changes. `Encounter.LossID`
lets any later encounter, however much time has passed, point back to
that same loss again if it resurfaces — or point at a different loss
entirely if that's what the conversation was actually about.

**Seed data now demonstrates the pattern explicitly.**
`12_SeedData.sql` Section 9 gives one client two losses at very
different times — a spouse's death in 2023 and a parent's death in
2019 — and marks the *older* one as the current primary concern.
Section 9b adds a new, recent `Encounter` whose `LossID` points at that
older loss, so the connection is explicit in the data rather than
something a reader has to piece together from dates. The Python
generator (`generate_griefsupportdb_seed.py`) implements the same
pattern programmatically: every client can now have 1-3 losses spread
across a 15-year window, and a dedicated step (Section 9b in the
generator) randomly selects one loss per client as their primary
concern — deliberately not always the most recent — and creates a
matching recent encounter referencing it.

### Design principle reinforced
> *Model what actually happens, not just what happened most recently.*

---



**Theme:** *A schema is only proven once real data flows through it.*

With the schema, stored procedures, and views complete, the next test
was building realistic seed data and confirming the full script set
(`01` through `12`) runs cleanly against a freshly created, empty
database in a single pass. This phase surfaced three genuine defects
that schema review alone would not have caught — the kind of bugs that
only appear when a design is actually executed end to end.

### What was found and fixed

**RAISERROR cannot take a DECIMAL or a function call as a substitution
parameter.**
Two stored procedures (`usp_RecordPayment`, `usp_RecordScholarshipAward`)
raised custom error messages using `%s` substitution with `DECIMAL(10,2)`
variables passed directly. T-SQL rejects this — `RAISERROR` substitution
arguments must be a literal or a variable of an accepted type, not a
`DECIMAL` and not an inline `CONVERT()` expression. The fix: convert the
decimal to a `VARCHAR` and assign it to its own variable first, then pass
that variable to `RAISERROR`. A small syntax rule with no obvious error
message pointing to the actual cause.

**A lookup value that didn't exist.**
Seed data for one client record referenced `ProfileStatusID = 7`,
assuming a "Deceased" status existed in `ProfileStatus` at that ID.
It didn't — `ProfileStatus` only defines Active, Inactive, Deceased,
and Do Not Contact at IDs 1 through 4. (Confusingly, `ClientStatus` — a
separate lookup — does have a Deceased status at ID 7, which is likely
where the mismatch originated.) The single bad row caused the entire
20-row `ContactInformation` batch insert for Section 7 to fail as one
transaction, cascading into missing `ClientInformation` records and a
chain of foreign key errors in every downstream section that referenced
those clients.

**Seed data section ordering violated its own foreign key dependencies.**
Section 8 (Encounters) included two stewardship-call records referencing
donor `ContactID`s that don't exist until Section 12 (Donors) runs.
Encounters for donors were seeded four sections too early. Fixed by
moving those two rows to a new section immediately following Donor
creation.

### Why this matters

None of these three bugs were visible from reading the schema or the
stored procedure code in isolation. They only surfaced by actually
running the full script set against a clean database and reading the
error messages that came back — the same discipline required in
production: build it, run it, trust the error, fix the root cause,
run it again from a clean state until it's provably correct.

The seed data script (`12_SeedData.sql`) now runs start to finish
against a freshly created, empty database with zero errors, populating
all 72 tables with a fictional but operationally realistic dataset:
50 contacts across every role, 20 clients with loss records and group
enrollments, a full facilitator credentialing pipeline, split payment
allocations, scholarship awards, and outreach event attendance.

---

## v5 — Business Process Normalization

**Theme:** *Model the business process, not the program name.*

This version introduced the most significant architectural shift in the
project. After reviewing operational notes and thinking through how the
schema would hold up as the organization evolved, several structural
changes were made to ensure the database models what the organization
*does* rather than what it *currently calls things*.

### What changed

**Interaction table eliminated.**
The separate Interaction table was removed. Encounter now serves as the
single universal record for all meaningful staff contacts, regardless
of the person's role. An `IsLightweight` flag distinguishes quick
touchpoints (reminder calls, attendance confirmations) from formal
encounters requiring full documentation. One table, one query, complete
contact history.

**Campaign model introduced.**
ILOF (In Lieu Of Flowers) was previously modeled as a mailing type,
which was incorrect — it is a fundraising campaign. A new `Campaign`
table with `CampaignType` lookup handles ILOF, Year End Appeal, Giving
Tuesday, and any future campaigns without schema changes. Donations can
now be designated to a specific campaign through `PaymentAllocation`.

**Scholarship tracking added.**
`ScholarshipFund` links a designated fund to a Campaign. `ScholarshipAward`
records individual awards to recipients with amount, date, fee reference,
and staff approval. Donors can explicitly designate gifts to the BST
Scholarship Fund. The fund balance is always calculated from actual
donation and award records rather than stored as a field that would go stale.

**ProgramType hierarchy added.**
`ProgramType` now sits above `PeerSupportGroupType`, making group types
subtypes of broader program categories. Peer Support Groups, BST
Training, Children's Programs, Expressive Arts, Workshops, Memorial
Events, and Community Outreach are all distinct program types. Future
programs fit without schema changes.

**Lookup value corrections.**
- `NoteType` 'Clinical' replaced with 'Program' — the organization is
  not a clinical provider and clinical terminology implies a licensure
  model that does not apply.
- `ReferralSource` 'Doctor' replaced with 'Medical Professional' —
  nurses, PAs, dentists, resource specialists, and all other healthcare
  providers refer clients, not just physicians.
- `EnrollmentStatus` 'Waitlisted' corrected to 'Waitlist' — status
  names are nouns describing a state, not past-tense verbs.
- `PeerSupportGroupType` 'Theatre Troupe' replaced with 'Expressive
  Arts' — the database models the program type, not a specific
  historical program name. Drama, art, music, movement, and
  storytelling all fit without future changes.
- ILOF removed from `MailingType` — it is now a Campaign record.

### Design principle established
> *Don't model today's program names. Model the underlying business process.*

---

## v4 — Deceased Type and Default Corrections

**Theme:** Edge cases matter, especially in grief support.

### What changed

**Deceased table made flexible for pet loss.**
`DeceasedPerson` was renamed `Deceased` and given a `DeceasedTypeID`
foreign key linking to a new `DeceasedType` lookup (Person, Pet /
Animal Companion). A `Species` field was added, nullable, populated
only for animal losses. Pet loss is a grief type the organization
serves explicitly, and the database now models it cleanly alongside
human losses.

**InviteToGroups default documented.**
`InviteToGroups` on `ClientInformation` was confirmed as `BIT` with
`DEFAULT 1`. The business rule: a client is always assumed group-ready
until staff explicitly sets this to 0. N/A is not a valid state — this
is a YES or NO decision only. The default enforces this without
requiring staff action for every new record.

**CauseOfDeathType expanded.**
Values were added to cover both human and animal causes of death,
including Euthanasia for pet loss context.

---

## v3 — Completeness Pass

**Theme:** What's missing that the organization actually needs?

This version addressed gaps identified by reviewing operational
documents, data entry conventions, and real-world scenarios from
the organization's history.

### What changed

**Deceased persons became searchable records.**
The `Deceased` table (originally `DeceasedPerson`) replaced plain text
fields for deceased name. Multiple clients who share the same loss —
siblings who both lost a parent, for example — can now be linked to
the same Deceased record. Losses can be searched by the deceased
person's name.

**Emergency contact added.**
`EmergencyContact` as a dedicated table linked to `ContactInformation`.
For a grief support organization serving vulnerable people, knowing
who to contact in a crisis is operationally essential.

**Mailing address separated from physical address.**
A complete second address block added to `ContactInformation` with a
`UseMailingAddress` flag. The original system's single address field
broke for donors like Benevity Community Impact Fund (a Canadian
organization whose address did not fit the US address structure).

**International address support.**
`CountryID` added to both address blocks. `StateID` made nullable for
non-US addresses. Canadian provinces added to the State lookup.

**Staff job title and board member role added.**
`Staff` gained `JobTitle`. `BoardMember` gained `BoardRoleID` linking
to a `BoardRole` lookup (Chair, Vice Chair, Treasurer, Secretary,
Member at Large). Both were meaningful organizational data that the
schema was missing.

**Fee schedule and scholarship tracking introduced.**
`FeeSchedule` with versioned fee amounts replaced hardcoded values.
`IsScholarship` and `ScholarshipAmount` added to `PaymentAllocation`.
The data entry conventions document distinguished between full fee and
scholarship fee for both BST and group participation, with different
mailing preference rules for each.

**Program completion tracking added.**
`ClientGroup` gained `ProgramCompleted`, `CompletionDate`, and
`CompletionNotes`. Grant funders require reporting on program
completion, not just attendance.

**Waitlist status added.**
`EnrollmentStatus` expanded to include Waitlist. Grief support groups
are sometimes full, and the waitlist is an operational reality that
needed a home in the schema.

**Outreach events added.**
`OutreachEvent` and `OutreachEventAttendance` added for community
presentations, school visits, health fairs, and expressive arts
performances — events that are organizationally distinct from ongoing
peer support groups.

**Audit fields added to key tables.**
`CreatedDate`, `CreatedByStaffID`, `ModifiedDate`, `ModifiedByStaffID`
added to `ContactInformation`, `ClientInformation`,
`VolunteerInformation`, `Loss`, `Encounter`, and `Payment`. For a
database handling sensitive grief and personal data, knowing who
changed what and when is essential.

**NoteTypeID correction.**
`Note` was missing `NoteTypeID` as a foreign key despite having a
`NoteType` lookup table. Corrected.

---

## v2 — Operational Depth

**Theme:** The schema needs to reflect how the organization actually works.

This version added the operational machinery that transforms a
conceptual model into a working system.

### What changed

**Payment model redesigned for split payments.**
The simple `Donation` table was replaced with a `Payment` /
`PaymentAllocation` model. A single check covering both a program fee
and a donation produces one `Payment` record and two `PaymentAllocation`
records. `IsTaxDeductible` is tracked at the allocation level for
accurate tax receipt generation. This solved a real problem documented
in the organization's data entry conventions.

**Facilitator credentialing pipeline added.**
`Facilitator` became its own role directly off `ContactInformation`,
separate from `VolunteerInformation`, because both Staff and Volunteers
can facilitate groups. A full credentialing pipeline was modeled:
BST completion, background check, personal experience verification,
vetting interview, and Co-Facilitator experience before independent
facilitation. `FacilitatorGroupTypeQualification` records grief-type-
specific qualifications independently — a person may be qualified for
suicide loss groups but still in training for child loss groups.

**Group structure formalized.**
Every `PeerSupportGroup` requires both a Facilitator and a
Co-Facilitator assigned as permanent leads (the two-person rule for
group safety). `Meeting` records what actually happened each session,
including substitutions. `GroupAttendance` tracks client attendance
with a three-value status: Present, Absent - Notified, Absent - No
Contact. The third status is a wellbeing flag requiring staff follow-up.

**Substitute facilitator pool added.**
`FacilitatorAvailability` enables finding qualified substitutes when
a regular facilitator is unavailable. Substitution queries match on
availability date, group type qualification, and background check
status.

**ClientGroup enrollment added.**
`ClientGroup` as a distinct enrollment record separated from session
attendance. Enrollment = registered for the group. Attendance = showed
up to a specific session.

**ReferralType and ReferralSource moved to Encounter.**
Confirmed by operational scenario analysis: a person can call for their
child on one encounter and for themselves on another. These fields
belong on the Encounter, not the client record. This was one of the
most significant corrections from the original system.

**ClientType added to Encounter.**
Similarly, the type relevant to a specific encounter may differ from
the primary type established at intake. `Encounter` gained `ClientTypeID`.
`ClientTypeHistory` tracks changes at the client level over time.

**SeekingServicesFor added to Encounter.**
A new field answering: who is this specific encounter about? Self,
Child / Youth, Teen, Spouse / Partner, Other Family Member, etc. This
solved the John Smith scenario — one caller touching multiple encounter
types in a single contact.

**Volunteer skills bridge tables added.**
`VolunteerSupportSkill` and `VolunteerFacilitationSkill` replaced
single FK fields with proper many-to-many bridge tables.

**Mailing preferences redesigned as bridge table.**
`MailingPreference` as a bridge table between `ContactInformation` and
`MailingType` replaced the earlier approach. Adding a new mailing type
is now a new row in a lookup table rather than a schema change.

**OrgConfiguration added.**
A key-value configuration table stores business rules that should be
data, not code: minimum Co-Facilitator sessions, major donor threshold,
VIP donor threshold, default fee amounts. Policy changes happen in the
data, not in stored procedures.

---

## v1 — Initial Schema

**Theme:** Establish the core structure and get the fundamentals right.

### What was established

**ContactInformation as the central entity.**
Every person and organization in the database has exactly one
`ContactInformation` record. All roles radiate from this center.
This solved the fundamental problem of the original siloed systems —
a donor who was also a client existed in two separate databases with
no connection between them.

**Five roles as separate tables.**
`Staff`, `BoardMember`, `VolunteerInformation`, `ClientInformation`,
and `DonorInformation` each as their own table with role-specific
fields. A person can hold multiple roles simultaneously. Each role has
`StartDate` and `EndDate` to preserve history without overwriting.

**Relationship table.**
`Relationship` as a bridge between two `ContactInformation` records
with a `RelationshipType` lookup. Critical for a grief support
organization where family connections, referral chains, and shared
losses are central to understanding the people being served.

**Loss linked to Client.**
`Loss` as a child table of `ClientInformation`, allowing a client to
have multiple loss records. `LossType` as a lookup covering the grief
types the organization serves.

**Organization profiles.**
`ProfileType` extended to include Organization, allowing corporate
donors and grant funders to have profiles without requiring a separate
company table. An organization's primary contact can optionally link to
their own individual profile.

**Lookup-first architecture.**
All categorical fields reference lookup tables rather than using
free-text or CHECK constraints. Lookup values can be added by
authorized staff without schema changes.
