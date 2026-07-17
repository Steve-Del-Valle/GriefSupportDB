# GriefSupportDB

GriefSupportDB — a comprehensive SQL Server database architecture designed
to modernize the information system of a grief support nonprofit.
Drawing on real-world operational experience with a legacy system, the
project reimagines how clients, volunteers, facilitators, donors,
staff, programs, and fundraising activities can be managed within a
flexible, scalable, and maintainable relational database.

Built from the ground up after years of working with the systems that
came before it.

---

## Executive Summary

GriefSupportDB is a modern SQL Server database architecture designed for grief support organizations. It replaces fragmented legacy systems with a unified relational model capable of managing clients, volunteers, facilitators, donors, programs, fundraising, and operational workflows in a single integrated platform.

The project demonstrates:

- Relational database architecture
- Requirements analysis
- Domain-driven data modeling
- Stored procedures and analytical views
- Synthetic data generation
- Technical documentation
- Legacy system modernization

---

## Key Features

- 72-table normalized SQL Server schema
- Purpose-built for grief support organizations
- Versioned fee schedules
- Split payment allocations
- Date-ranged role history
- Encounter-centric workflow
- Searchable deceased records
- Facilitator credentialing pipeline
- Synthetic data generator
- Analytical views and stored procedures

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

The implementation highlighted a common systems development challenge: software can only reflect the quality of its requirements gathering and domain understanding. Although the chosen platform was capable for the most part, the resulting configuration did not fully capture the organization's operational workflows, leading to manual workarounds and post-deployment redesign.

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

GriefSupportDB began as a vision for a unified, purpose-built information
system that could replace the disconnected legacy applications used by
the organization. Giftworks and NEXiDU each solved part of the problem,
but neither provided a complete operational picture. Staff were forced
to move between systems, duplicate information, and rely on manual
workarounds to bridge gaps in functionality.

This project was conceived as a response to those limitations. Rather
than adapting software designed for another purpose, GriefSupportDB was
designed from the ground up around the actual workflows of a grief
support organization. Every major architectural decision was informed by
years of operational experience, direct observation of staff workflows,
and lessons learned from maintaining and extending the legacy systems.

GriefSupportDB is the realization of that vision—a modern relational
database architecture built to unify client services, volunteer
management, facilitator credentialing, fundraising, outreach, and
organizational operations within a single coherent data model.

Every design decision in this schema traces back to something that
actually broke, created unnecessary work, or failed to meet the needs of
staff serving real grieving people.

This project exists to demonstrate what that solution looks like when
someone takes the time to understand the problem before designing the
system and asks the right questions first.

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

The database contains 72 tables. Approximate breakdown by logical group:

| Group | Purpose |
|---|---|
| Core Profile | ContactInformation and related lookups |
| Roles | Staff, BoardMember, Volunteer, Client, Donor |
| Facilitator Credentialing | Facilitator pipeline and availability |
| Programs and Groups | Peer support groups, meetings, attendance |
| Transactional | Encounters, notes, outcomes, loss records |
| Payments | Payment, allocation, fee schedule |
| Campaigns and Scholarships | Fundraising campaigns, scholarship awards |
| Outreach | Events and attendance |
| Mailing | Preferences and types |
| Configuration | Configurable business rules |

*(A precise per-group table count is pending a recount against the
current schema — the total of 72 is confirmed directly against the
live database.)*

---

## Entity Relationship Diagram

*ERD in progress — see `/erd` folder once published.*

---

## Evolution of the design

This database was not designed in one sitting. It evolved through
several documented phases, each driven by new questions, discovered
gaps, or a clearer understanding of the business process being
modeled — including a full validation pass where the seed data and
stored procedures were run end to end against a clean database, the
defects that surfaced were fixed at the source, and a Python generator
was built to replace hand-written, hardcoded-ID seed data with one that
captures every real generated key at insert time and threads it forward.

To populate a fresh database, run `sql/01` through `sql/11` in order,
then run `python/generate_griefsupportdb_seed.py` (recommended) or
`sql/12_SeedData.sql` (the original hand-written reference version,
documented in [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md)).

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

See [DESIGN_DECISIONS.md](DESIGN_DECISIONS.md) for the reasoning behind
the key architectural choices.

See [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) for an honest account
of the tradeoffs and fragility points in the current implementation —
including what broke during seed data validation and what a production
version would do differently.

---

## Repository structure

```
GriefSupportDB/
│
├── README.md                   This file
├── CHANGELOG.md                Version history and what changed in each iteration
├── DESIGN_DECISIONS.md         Reasoning behind key architectural choices
│
├── sql/                        Full build, run in order against a fresh database
│   ├── 01_LookupTables.sql
│   ├── 02_CoreProfile.sql
│   ├── 03_RoleTables.sql
│   ├── 04_TransactionalTables.sql
│   ├── 05_FacilitatorTables.sql
│   ├── 06_GroupAndProgramTables.sql
│   ├── 07_CampaignAndScholarshipTables.sql
│   ├── 08_Procedures_Intake.sql
│   ├── 09_Procedures_Payments.sql
│   ├── 10_Procedures_FacilitatorAndGroups.sql
│   ├── 11_Views_AnalyticalQueries.sql
│   └── 12_SeedData.sql         Hand-written reference seed data (see KNOWN_LIMITATIONS.md)
│
├── python/                     Synthetic data generator — recommended way to
│   │                           populate a fresh database (see below)
│   └── generate_griefsupportdb_seed.py
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

## Architecture picture

Legacy Systems

## Project Architecture

Giftworks        NEXiDU
      \          /
       \        /
    Legacy Systems
            │
            ▼
  Operational Analysis
            │
            ▼
     GriefSupportDB
            │
            ▼
     Future Evolution
   ├── REST API
   ├── Web Application
   ├── Mobile Application
   ├── Dashboards
   └── AI Assistant
---

## Technical details

**Database platform:** Microsoft SQL Server
**Design tool:** dbdiagram.io (drafting) / Draw.io (final ERD)
**Language:** T-SQL
**Status:** Schema, stored procedures, views, and seed data complete.
Scripts `01` through `12` run in sequence against a freshly created,
empty database with zero errors, populating all 72 tables with a
realistic synthetic dataset.

---

## Why SQL Server?

This project demonstrates SQL Server features that influenced the design:

The project demonstrates:

- Identity columns
- Stored procedures
- Views
- Foreign key constraints
- CHECK constraints
- Transactions
- `OUTPUT INSERTED`
- Window functions
- Common Table Expressions (CTEs)

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

## Future Roadmap / Planned Evolution
### Version 1.1

- ✅ Additional stored procedures
- ✅ Expanded synthetic data scenarios

### Version 2

- ⬜ REST API
- ⬜ Responsive Web application
- ⬜ Mobile application for facilitators and outreach staf

### Version 3

- ⬜ Operational dashboards
- ⬜ Executive reporting
- ⬜ Power BI integration

### Version 4

- ⬜ AI-assisted search
- ⬜ AI-assisted encounter summaries
- ⬜ Decision support AI-supported reporting

---

## What I learned

Building GriefSupportDB reinforced that successful information systems are driven by operational workflow rather than technology. Many of the project's most important architectural decisions came from observing how staff actually worked, identifying where legacy systems introduced friction, and redesigning the data model to better reflect real organizational processes.

---

## About this project

This is a portfolio project demonstrating database design, requirements
analysis, domain modeling, and technical documentation skills.

The organization this database was designed for is real. The operational
problems it addresses are real. The design decisions were made by
someone who spent years inside those problems before sitting down to
solve them.

---

## About the Author

This project reflects years of experience designing operational workflows, maintaining legacy information systems, documenting business processes, and translating real-world organizational needs into scalable technical solutions. It represents both a technical database project and a case study in requirements analysis, systems thinking, and software architecture.
