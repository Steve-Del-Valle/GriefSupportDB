# Legacy System Analysis

This document describes the two systems GriefSupportDB was designed
to replace, the problems those systems created, and how each problem
informed a specific design decision in the new schema.

---

## The systems in place when this project began

When the author of this project began working at the organization, two
separate systems were in operation with no connection between them.

This was a grief support organization. The people in these systems
were not records — they were individuals who had lost someone. A
system failure, a missing record, an unresolved duplicate, an
unlogged encounter — the consequences were not inconveniences. They
were people who needed to be reached and weren't.

That context shaped every decision about what needed to be fixed,
what needed to be documented, and ultimately what needed to be built.

### Giftworks — Donor and Volunteer Management

Giftworks is a commercial off-the-shelf donor management application.
The organization used it to track donor giving history, volunteer
records, and mailing preferences.

As a packaged product, Giftworks was not designed for this
organization's specific needs. Its data model reflected generic donor
management assumptions rather than the operational reality of a grief
support organization where donors, volunteers, clients, and staff
overlap significantly — and where that overlap is meaningful. A donor
who was also a client, a volunteer who had been through the program,
a board member who was also a major donor — none of those connections
existed in Giftworks because Giftworks had no way to know about the
people in the other system.

### NEXiDU — Client Database (CDB)

The client database was universally called the **CDB** — short for
Client Database. Its actual product name was **NEXiDU**.

Nobody at the organization knew what NEXiDU meant. Investigation of
the application and its documentation eventually revealed the answer:
**Needle Exchange for Intravenous Drug Users**.

NEXiDU had been built by a nonprofit technology organization (NETCorps)
for harm reduction programs. It was repurposed for grief support client
tracking without being redesigned for it. The underlying data model —
built for tracking participants in a needle exchange program — was
adapted as-is for an entirely different population with entirely
different service needs.

NEXiDU was a Microsoft Access database. For small organizations with
low user counts and limited data volume, Access performs adequately.
As the organization grew, two problems emerged:

**Maintenance neglect.** Microsoft Access databases require periodic
maintenance — compacting and repairing — to remain stable. Nobody at
the organization understood this requirement. Over time, without
maintenance, the database began to corrupt. Strange characters appeared
in notes fields. Portions of records went missing. Data that staff had
carefully entered was degrading silently.

**Structural investigation.** When tasked with stabilizing the
database, investigation of the underlying structure revealed tables
that connected to nothing, fields that appeared to have been removed
without cleanup, and a schema that showed signs of having been hacked
apart informally over the years. The repurposing from needle exchange
to grief support had left artifacts of the original design throughout.

The database was kept running as long as possible while the case was
made for a more sustainable solution. Keeping it running was not a
small task — it meant understanding a corrupted, repurposed system
well enough to stabilize it, while continuing to serve an organization
whose clients were counting on it.

---

## The attempted solution — Social Solutions Apricot

The organization's executive director decided to consolidate Giftworks
and NEXiDU into a single platform — **Social Solutions Apricot**, a
cloud-based nonprofit case management system. This was the correct
strategic decision. Two siloed systems with no connection between
them was not a sustainable long-term solution, and Apricot was chosen
specifically to bring donor management, volunteer tracking, and client
services together in one place.

The intent was right. The execution was not.

A consultant was hired to design and build the implementation. He did
not conduct sufficient discovery. He did not ask enough questions about
how the organization actually worked, what problems the existing systems
were causing, or what staff needed to do their jobs effectively. He
did not use real operational scenarios to test whether the design
matched the workflow before building it. He built what he assumed the
answer was.

Apricot as a platform is capable. The problem was not the tool — it
was that the tool was configured by someone who did not understand
the domain it was being configured to serve.

The result inherited the right goal from the systems it was replacing
— consolidation into a single record per person — but reproduced many
of their structural problems in a new environment:

- Referral type and referral source were placed at the client level,
  making them one-and-only-one per client for life. This broke
  immediately for clients who called for different reasons across
  different encounters.
- There was no way to record that a single payment covered both a
  program fee and a donation. Staff had to choose one or lose the
  data.
- The data entry conventions document — a staff-written guide to using
  the system — was full of unresolved questions and workarounds,
  evidence that the system did not match the workflow it was supposed
  to support.
- Data from the migration was not cleaned before import. Duplicates,
  incorrect records, and inconsistencies from both original systems
  were carried forward. The most critical data — loss records — was
  particularly unreliable.
- Fields that were obviously needed were missing from the initial
  deployment and had to be added immediately after launch, evidence
  that the design process had not used real scenarios to validate
  the structure before building it.
- Because Apricot was configured rather than designed from the ground
  up, its data model reflected the platform's generic assumptions
  rather than the organization's specific operational reality.

The consolidation goal Apricot was meant to achieve is exactly what
GriefSupportDB is designed to deliver. The difference is that
GriefSupportDB was designed by someone who understood the operational
reality first — including the specific ways Apricot fell short of
meeting it.

The aftermath of the Apricot implementation was left to staff to
manage. Workarounds had to be created for what the system could not
do — not because workarounds were acceptable, but because the
alternative was failing the people the organization existed to serve.
Grieving people were counting on the organization to answer the phone,
find their record, and follow up. The system not working was not an
option. So it was made to work, through documentation, workarounds,
cleanup, and the kind of institutional knowledge that only comes from
being the person who refused to let it fail.

The person who created those workarounds, cleaned up the data, built
all the procedures and workflows from scratch, kept NEXiDU running
past its natural life, and understood better than anyone what the
organization actually needed — is the same person who designed
GriefSupportDB.

---

## Problems in the original systems and how GriefSupportDB addresses them

### Siloed data with no person-level connection

**Original problem:** A donor who was also a client existed in two
separate databases — Giftworks and the CDB — as two separate records
with no link between them. There was no way to see the complete picture
of a person's relationship with the organization.

**GriefSupportDB solution:** `ContactInformation` as the universal
center. Every person has one record. All roles — Client, Donor,
Volunteer, Staff, Board Member, Facilitator — link back to that record.
The complete relationship is always visible from one place.

---

### Referral context captured at the wrong level

**Original problem:** Referral type and referral source were stored on
the client record, implying a single value that applied to the entire
relationship. A parent who called for their child on the first contact
and for themselves six months later was forced into one referral type
that was wrong for at least one of those contacts.

**GriefSupportDB solution:** `ReferralTypeID` and `ReferralSourceID`
on `Encounter`. Each contact records its own referral context
independently. The complete referral history across all encounters is
preserved.

---

### No way to split a payment across fee and donation

**Original problem:** A check that covered both a program fee and a
donation had no clean home. Documented as an unresolved problem in
the organization's data entry conventions.

**GriefSupportDB solution:** `Payment` and `PaymentAllocation`.
One payment, multiple allocations. Tax deductibility tracked at the
allocation level. The sum of allocations is enforced to equal the
payment total.

---

### Deceased persons stored as text fields

**Original problem:** The name of the deceased person was a plain text
field. It could not be searched reliably, could not be linked across
multiple clients who shared the same loss, and provided no structured
information about the death.

**GriefSupportDB solution:** `Deceased` as a proper table with
searchable name fields, cause of death, and a type flag distinguishing
human from pet losses. Multiple clients can reference the same Deceased
record when they share a loss.

---

### No facilitator credentialing pipeline

**Original problem:** The organization had clear, specific requirements
for who could facilitate a grief support group — BST completion,
background check, lived experience with the relevant grief type,
vetting interview, Co-Facilitator experience. None of this was
modeled in any of the original systems. Tracking it was informal and
dependent on individual staff knowledge.

**GriefSupportDB solution:** `Facilitator`,
`FacilitatorGroupTypeQualification`, and `FacilitatorAvailability`
model the complete credentialing pipeline structurally. Each gate is
recorded. Qualifications are tracked per grief type independently.
The substitute pool is queryable by availability, group type
qualification, and clearance status.

---

### No role history

**Original problem:** When a person's role changed — a staff member
became a board member, a volunteer took a leave of absence — there was
no clean way to record the change without losing the prior state.

**GriefSupportDB solution:** Every role table has `StartDate` and
`EndDate`. Role history is preserved. A person who was staff from 2018
to 2021 and returned as a board member in 2024 has two dated records
with no data loss.

---

### Data was not cleaned before migration

**Original problem:** The Apricot migration imported data from the
original systems without cleaning it first. Duplicates, incorrect
records, and incomplete loss records were carried forward. The data
was inconsistent at the point of migration and remained inconsistent
afterward.

**GriefSupportDB design response:** Audit fields (`CreatedDate`,
`CreatedByStaffID`, `ModifiedDate`, `ModifiedByStaffID`) on all key
tables. A clean seed data process rather than a raw migration. The
design documentation specifies data entry conventions including
standard values for unknown fields (e.g., `UNK` for unknown names,
`555-555-5555` for unknown phone numbers) that ensure consistency
from the first record forward.

---

### Lookup values that conflated multiple concepts

**Original problem:** The `TbLkpContactReason` field in the original
CDB was doing the work of five different concepts simultaneously —
loss type, group type, volunteer status, contact reason, and
administrative status — all collapsed into a single lookup. Values
like "Vol. Training Has Been Taken," "Reactivated," "Deactivated,"
and "Newsletter" appeared alongside grief types like "Suicide" and
"Spouse Loss" in the same dropdown.

**GriefSupportDB solution:** Each concept has its own table.
`LossType`, `PeerSupportGroupType`, `VolunteerStatus`,
`EncounterType`, and `ProfileStatus` are separate lookups with values
appropriate to each context. Staff see the right options for the right
field. Reporting queries filter on the correct table rather than
parsing a single overloaded field.

---

*The `/legacy` folder contains the original table schemas from the
NEXiDU CDB and Giftworks systems. Actual data is not included.
Structure only, in keeping with the privacy of the individuals those
systems served.*
