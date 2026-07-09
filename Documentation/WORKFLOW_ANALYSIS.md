# Workflow Analysis

This document analyzes two operational workflows from the Apricot
implementation that preceded GriefSupportDB. Both workflows are
preserved as PDFs in this folder.

These flowcharts are not presented as examples of bad work. They are
presented as evidence of what happens when a system does not match the
workflow it is supposed to support — and how the people operating that
system adapt to make it function anyway.

---

## Workflow 1: Line One Call
*File: Line_One_Call_Flowchart.pdf*

This flowchart documents the procedure staff followed when a call came
in on the organization's primary intake line. It was the most common
workflow in the building — every new client contact started here.

### What the workflow shows

A staff member receives a call, greets the caller, and asks for their
name and spelling. They search the database. From there the workflow
splits into three paths:

**New Client** — person is not in the database. Staff opens a new
profile, enters information following a separate written procedure,
saves the record, navigates to a second screen (the Encounter page),
enters encounter information, and saves again.

**Returning Client, single record** — person is in the database once.
Staff confirms and updates information, saves, navigates to the
Encounter page, enters encounter information, and saves again.

**Returning Client, multiple records** — person appears in the database
more than once. Staff makes a note to merge duplicates later, checks
the initial contact date on each record, chooses the oldest one as
the canonical record, confirms and updates information, saves,
navigates to the Encounter page, enters encounter information, and
saves again.

### What it reveals about the system

**Duplicate records were common enough to be a documented workflow
branch.** The "multiple records" path is not an edge case handled
by a footnote. It is a full branch of the primary intake flowchart
with four distinct steps. A system that prevents duplicate creation
through proper search-before-create design and unique constraints
eliminates this branch entirely.

**Two screens, two saves for one workflow.** Every path ends with the
same sequence: navigate away from the profile to a separate Encounter
screen, enter encounter information, save again. The profile and the
encounter were not part of a unified intake experience. Staff had to
remember to complete the second step or the encounter went unrecorded.

**"Make note to Merge Duplicates later"** is an instruction to defer
a data quality problem rather than prevent it. The merge task went
into someone's mental or physical to-do list, where it competed with
every other task in a busy nonprofit environment. Duplicates that were
not merged became permanent inconsistencies in the data.

**The workflow required staff to carry information in their head**
between the profile screen and the encounter screen. There was no
system-level continuity between the two. Staff who were interrupted
between saves — which happens constantly in a grief support
organization where calls are emotionally intensive — could lose context
and produce incomplete records.

### How GriefSupportDB addresses this

`ContactInformation` is the single record for every person. It is
indexed on last name and first name for fast, reliable search. A
stored procedure for new contact intake searches before creating,
reducing duplicate creation at the source rather than cleaning it up
afterward.

`Encounter` is a child record of `ContactInformation` — they are part
of the same data model and can be created in the same transaction.
There is no separate screen to remember to navigate to. The encounter
context — referral type, referral source, seeking services for whom,
encounter type, notes — is captured as part of the same workflow that
creates or confirms the contact record.

Date-ranged roles mean a returning client's history is always
accessible without navigating between systems or screens. The full
picture — every encounter, every loss record, every group enrollment,
every note — is connected to one record.

---

## Workflow 2: Credit Card Payment Processing
*File: Credit_Card_Process.pdf*

This flowchart documents the procedure for processing a credit card
payment received on a payment slip. It was designed and documented
by the author of this project — the only person at the organization
who performed this work — after inheriting a process that had no
written procedure and existed only as institutional knowledge.

The creation of this flowchart was itself an act of system analysis:
understanding a multi-step process well enough to map it, identify
its decision points, and document it clearly enough that another
person could follow it.

### What the workflow shows

A staff member receives a credit card payment slip. The workflow
immediately splits based on whether the slip contains complete billing
information.

**Complete billing information** — staff goes directly to Click and
Pledge (a third-party payment processor at a separate website), opens
the Virtual Terminal, enters a payment description, enters the amount,
enters patron information, enters the amount again, enters credit card
information, enters internal notes recording who the payment is for
and whether it is in memory or honor of someone, and processes the
payment. If the payment succeeds, the workflow continues to Apricot
for donation entry. If it fails, staff contacts program staff about
the issue.

**Incomplete billing information** — staff goes first to Apricot to
look up the person. They search in Donor records. If the donor is
found, they proceed to Click and Pledge. If not found in Donor, they
search in Client records. If found as a Client, they proceed to Click
and Pledge. If not found in either, they contact program staff.

### What it reveals about the system

**A single payment transaction required navigating three separate
systems.** Apricot held the person's record. Click and Pledge
processed the payment. Then Apricot again for donation entry. Staff
were manually carrying information between two websites to complete
one transaction. There was no integration, no automatic record
creation, no unified view of the payment and the person.

**The amount was entered twice in Click and Pledge** — once before
patron information and once after. This is noted explicitly in the
flowchart. Redundant data entry is a data quality risk. Two entries
that should be identical can diverge through error.

**"In memory / honor" context was stored as unstructured text in a
payment processor's internal notes field.** This is ILOF (In Lieu Of
Flowers) donation context — information about who a memorial gift
honors — being captured in a free-text field in a third-party system
rather than as structured data in the organization's own database.
It could not be queried, reported on, or linked to the deceased
person or the donor record in any meaningful way.

**A failed payment routed to "Contact Program Staff about Issue"**
with no defined resolution path. The workflow ends there. What program
staff did with that contact, how the issue was resolved, and whether
the payment was eventually collected are not captured in the workflow
or the system.

**The search sequence — Donor first, then Client — reveals the siloed
data model.** A person who was both a donor and a client existed in
two separate places. Staff had to know to search both. A person who
was a client making a donation for the first time might not be found
in the Donor search at all, leading to the "contact program staff"
dead end even though the person was in the database.

**There was no scholarship or split payment handling in this workflow.**
A check that covered both a program fee and a donation had no
documented procedure. Staff improvised, producing inconsistent records.

### The significance of this workflow being designed by hand

The Credit Card Process flowchart did not come with the Apricot
implementation. It was created by the author of this project after
observing that the process existed only as unwritten institutional
knowledge held by one person. If that person had been unavailable,
the process would have been lost or reconstructed incorrectly.

Creating this flowchart required understanding the process well enough
to map every decision point, every path, and every failure state.
That understanding — of where the process worked, where it was fragile,
and where information fell through the gaps between systems — is
directly reflected in GriefSupportDB's payment model.

### How GriefSupportDB addresses this

The `Payment` and `PaymentAllocation` model replaces the three-system
workflow with a single unified transaction record. There is no third-
party system to navigate to separately — payment method, amount,
allocation, and acknowledgement status all live in the database.

`PaymentAllocation` with `IsTaxDeductible` at the allocation level
handles the fee-versus-donation split that had no home in the original
workflow. A single check covering a group fee and a donation produces
one `Payment` record and two `PaymentAllocation` records — one for
each purpose, each correctly classified for tax purposes.

The `Campaign` model with `PaymentAllocation.CampaignID` replaces the
unstructured "in memory / honor" note in Click and Pledge. An ILOF
designation is a `Campaign` record of type "In Lieu Of Flowers." A
donation designated to that campaign is a `PaymentAllocation` with the
`CampaignID` set. The designation is structured, queryable, and linked
to the donor record.

`ContactInformation` as the single center means a person who is both
a client and a donor has one record. There is no Donor search followed
by a Client search. There is one search, one record, and all of their
history — service, giving, group participation — in one place.

The `ScholarshipFund` and `ScholarshipAward` model handles reduced fee
payments that the original workflow had no procedure for at all.

---

## Summary: What these workflows tell the story of

Both flowcharts are evidence of the same underlying problem: the
systems being used did not match the work being done. Staff adapted
— they wrote procedures, they made notes to merge duplicates later,
they navigated between websites, they entered amounts twice — because
that is what capable people do when their tools fall short. They make
it work.

GriefSupportDB is what it looks like when the tools are built to match
the work instead.

The line one call workflow becomes: search, find or create, record the
encounter. One screen. One save.

The credit card workflow becomes: find the contact, record the payment,
allocate it. One system. One transaction.

The institutional knowledge that lived in one person's head — the
procedure that existed only because someone took the time to map it —
becomes structural. The database enforces the workflow rather than
depending on staff to remember it.

That is the difference between a system that was repurposed and a
system that was designed.
