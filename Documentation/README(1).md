# GriefSupportDB

GriefSupportDB is a comprehensive MySQL database architecture designed
to modernize the information system of a grief support nonprofit.
Drawing on real-world operational experience with a legacy system, the
project reimagines how clients, volunteers, facilitators, donors,
staff, programs, and fundraising activities can be managed within a
flexible, scalable, and maintainable relational database.

Built from the ground up after years of working with the systems that
came before it.

---

## Background

### Where this started

When I began working at the organization, they were running two
separate, siloed systems. Donor and volunteer data lived in
**Giftworks**, a commercial off-the-shelf product. Client data lived
in a system everyone called the **CDB** — short for Client Database —
whose actual name was **NEXiDU**.

This was a grief support organization. People calling in had just lost
a spouse, a child, a parent. They were in crisis. The systems the
organization depended on to serve them had to work.

Nobody knew what NEXiDU meant. I eventually found out: it stood for
**Needle Exchange for Intravenous Drug Users**. It had been built by a
nonprofit technology organization and repurposed for grief support
without being redesigned for it. The data model underneath was built
for harm reduction, not bereavement services. It worked well enough
while the organization was small. As the organization grew, the cracks
started showing.

NEXiDU was a Microsoft Access database. Over time — without the routine
maintenance and compiling that Access requires — it began to corrupt.
Strange characters appeared in notes fields. Pieces of records went
missing. I was tasked with fixing it. Investigating the structure, I
found tables that connected to nothing, fields that had been hacked
away without cleanup, and a foundation that was never designed for what
the organization actually needed.

I kept it running for as long as I could while making the case that
two siloed systems with a repurposed foundation was not a sustainable
path forward. The stakes of a system failure were not abstract — they
were the people who called and needed to be reached back.

### Building operational standards from nothing

Alongside the database work, there was a parallel problem: nothing was
documented. No written procedures for any operational process. No
standardization. Every staff member handled tasks differently — intake
calls, payment processing, data entry, group management — based on
whatever they had been told informally or worked out themselves. When
someone new joined the organization, there was nothing to hand them.

Every workflow, procedure, and process document the organization had
was created from scratch. That meant observing how things were actually
done, mapping the decision points, identifying where processes broke
down or diverged between staff members, and producing documentation
clear enough that anyone could follow it consistently.

The Credit Card Process flowchart — preserved in the `/legacy/workflows`
folder — is one example. It was designed and executed exclusively by
the author of this project. The procedure for processing a credit card
payment that touched three separate systems had existed only as
knowledge held by one person. The flowchart made it transferable.

The Line One Call flowchart — also in `/legacy/workflows` — documents
the client intake procedure that every staff member followed differently
before it was standardized.

These workflows are part of the record of this project because they
show what the system required staff to do — and because their
complexity and fragility are part of what made the case for building
something better.

### The attempted solution — and why it still wasn't enough

The executive director decided to replace Giftworks and NEXiDU with
a single platform — **Social Solutions Apricot**. This was the right
instinct. Two siloed systems with no connection between them was not
sustainable, and Apricot was chosen specifically to bring donor
management, volunteer tracking, and client services together in one
place.

The intent was correct. The implementation was not.

A consultant was hired to build it. He did not ask enough questions.
He did not understand the domain. He did not use real operational
scenarios to validate the design before building it. He built what
he assumed the answer was rather than what the organization actually
needed.

The problems Apricot introduced did not exist in a vacuum. This was
a grief support organization. When the system had gaps, staff had
to fill them manually — and the people waiting on the other end of
those gaps were in crisis. Workarounds were not optional. They had
to be created and maintained to keep services running because the
alternative was failing the people the organization existed to serve.

That burden fell on the same person who had already kept NEXiDU
running past its natural life — the same person who had built all
the workflows and procedures from scratch. Cleaning up after the
implementation, creating workarounds for what Apricot could not do,
and keeping the organization operational was not a separate project.
It was the continuation of the same one.

Apricot is a capable platform. The problem was not the tool — it was
that the tool was configured by someone who did not understand the
work it was being configured to support. The result inherited the
right idea from the systems it replaced — consolidation — but
reproduced many of their structural problems in a new environment:

- Referral type and referral source placed at the client level,
  making them one-and-only-one per client for life
- No way to record that a single payment covered both a program fee
  and a donation
- No support for clients who called about multiple people across
  different encounters
- Data migrated without cleaning — duplicates, incorrect records,
  and missing loss data carried forward from the original systems
- Fields that were obviously needed missing from the initial
  deployment, requiring immediate additions after launch
- A data entry conventions document full of unresolved questions
  that staff were left to figure out on their own

The consolidation goal that Apricot was meant to achieve — one system,
one record per person, complete operational picture — is exactly what
GriefSupportDB is designed to deliver. The difference is that
GriefSupportDB was designed by someone who spent years inside the
operational reality those systems were supposed to serve, and who
understood the cost of getting it wrong.

### Why this database exists

The working name for this project was **GriefSupportDB** — Adaptive Intelligent Data
Understanding System. The name was a deliberate response to the
two siloed systems it was designed to replace. Giftworks and NEXiDU
were the opposite of unified. GriefSupportDB was the vision of what a single,
purpose-built system could be.

GriefSupportDB is the realization of that vision — a ground-up
relational database design built from years of domain knowledge,
direct operational observation, and careful analysis of what the
previous systems could not do. Every design decision in this schema
traces back to something that actually broke or failed in a real system
serving real grieving people.

This project exists to demonstrate what that solution looks like when
someone asks the right questions first.

---

## What this database does

GriefSupportDB is a purpose-built relational database for a grief
support organization. It manages the full operational picture of the
organization in a single integrated system:

- **People** — clients, donors, volunteers, staff, board members, and
  facilitators, all connected through a single core profile
- **Services** — peer support groups, facilitator credentialing,
  session attendance, program enrollment and completion
- **Fundraising** — donations, split payments, tax acknowledgements,
  campaign tracking, and scholarship fund management
- **Outreach** — community events, presentations, and organizational
  relationship tracking
- **History** — role changes over time, loss records linked to
  searchable deceased records, encounter history across all contact types

---

## Design principles

### Model the business process, not the program name

The original systems modeled specific program names. When programs
changed, the data model broke. GriefSupportDB models the underlying
business concept — a Facilitator earns qualifications, a Campaign
raises funds, an Encounter records a contact — so that new programs
fit without schema changes.

### Every role is date-ranged

A staff member who left and returned as a board member has two
date-ranged role records. A volunteer who also becomes a client has
both records simultaneously. No history is overwritten.

### Encounter-level context, not client-level

Referral type, referral source, and seeking services for whom are
recorded on the Encounter, not the client. A person who calls for their
child on one encounter and for themselves on another has the right
context recorded for each contact, not a single value that goes stale.

### Payments are split, not summarized

A single check covering both a program fee and a donation produces one
Payment record and two PaymentAllocation records. Tax deductibility is
tracked at the allocation level. The fee schedule is versioned so
historical payment records always reference the rate that applied at
the time.

### Deceased persons are records, not text fields

The previous system stored the deceased person's name as a plain text
field. GriefSupportDB stores a Deceased record that can be searched,
linked across multiple clients who share the same loss, and
distinguished between human losses and pet or animal companion losses —
a grief type the organization serves.

### Facilitator credentialing is a pipeline, not a checkbox

Becoming a group facilitator requires: completing Bereavement Skills
Training, passing a background check, demonstrating personal experience
with the relevant grief type, completing a staff vetting interview, and
serving as Co-Facilitator for a minimum number of sessions. Each gate
is tracked in the database. A group cannot be scheduled without both a
qualified Facilitator and Co-Facilitator in the lead seats.

---

## Schema overview

The database contains 67 tables organized into logical groups:

| Group | Tables | Purpose |
|---|---|---|
| Core Profile | 10 | ContactInformation and related lookups |
| Roles | 9 | Staff, BoardMember, Volunteer, Client, Donor |
| Facilitator Credentialing | 3 | Facilitator pipeline and availability |
| Programs and Groups | 6 | Peer support groups, meetings, attendance |
| Transactional | 7 | Encounters, notes, outcomes, loss records |
| Payments | 4 | Payment, allocation, fee schedule |
| Campaigns and Scholarships | 3 | Fundraising campaigns, scholarship awards |
| Outreach | 2 | Events and attendance |
| Mailing | 2 | Preferences and types |
| Configuration | 1 | Configurable business rules |

---

## Entity Relationship Diagram

![GriefSupportDB ERD v5](erd/GriefSupportDB_ERD_v5.png)

The `/erd` folder contains diagrams for each version of the schema,
showing how the design evolved from the initial concept through five
iterations.

---

## Evolution of the design

This database was not designed in one sitting. It evolved through five
documented versions, each driven by new questions, discovered gaps, or
a clearer understanding of the business process being modeled.

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

See [DESIGN_DECISIONS.md](DESIGN_DECISIONS.md) for the reasoning behind
the key architectural choices.

---

## Repository structure

```
GriefSupportDB/
│
├── README.md                   This file
├── CHANGELOG.md                Version history and what changed in each iteration
├── DESIGN_DECISIONS.md         Reasoning behind key architectural choices
│
├── sql/                        CREATE TABLE scripts in dependency order
│   ├── 01_LookupTables.sql
│   ├── 02_CoreProfile.sql
│   ├── 03_RoleTables.sql
│   ├── 04_TransactionalTables.sql
│   ├── 05_FacilitatorTables.sql
│   ├── 06_GroupAndProgramTables.sql
│   └── 07_CampaignAndScholarshipTables.sql
│
├── seed/                       Realistic synthetic data for testing and demonstration
│   └── (coming soon)
│
├── procedures/                 Stored procedures for key business workflows
│   └── (coming soon)
│
├── views/                      Reporting views
│   └── (coming soon)
│
├── queries/                    Sample analytical queries
│   └── (coming soon)
│
├── erd/                        Entity relationship diagrams for each version
│   └── (coming soon)
│
└── legacy/                     Original system schemas and analysis
    ├── LEGACY_ANALYSIS.md
    ├── workflows/
    │   ├── WORKFLOW_ANALYSIS.md
    │   ├── Line_One_Call_Flowchart.pdf
    │   └── Credit_Card_Process.pdf
    ├── NEXiDU_CDB/
    └── Giftworks/
```

---

## Technical details

**Database platform:** Microsoft SQL Server  
**Design tool:** dbdiagram.io (drafting) / Draw.io (final ERD)  
**Language:** T-SQL  
**Status:** Schema complete — seed data, stored procedures, views,
and queries in progress

---

## Legacy systems

The `/legacy` folder contains the schemas of the two original systems
this database was designed to replace — the NEXiDU Client Database
(Microsoft Access) and the relevant Giftworks tables — along with an
analysis of their limitations.

Actual data from those systems is not included. This repository
contains structure only, in keeping with the privacy of the individuals
those systems served.

See [legacy/LEGACY_ANALYSIS.md](legacy/LEGACY_ANALYSIS.md) for the
full analysis.

---

## About this project

This is a portfolio project demonstrating database design, requirements
analysis, domain modeling, and technical documentation skills.

The organization this database was designed for is real. The operational
problems it addresses are real. The design decisions were made by
someone who spent years inside those problems before sitting down to
solve them.


