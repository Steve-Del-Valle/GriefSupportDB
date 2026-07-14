# Known Limitations
*GriefSupportDB — a comprehensive SQL Server database architecture designed
to modernize the information system of a grief support nonprofit.*

This document is an honest account of the tradeoffs and fragility points
in the current implementation. Every item here was discovered by actually
building and running the project, not anticipated in advance. Documenting
them is part of the engineering record, not an afterthought.

---

## Seed data uses hardcoded identity values

`12_SeedData.sql` inserts records in dependency order and references
earlier rows by literal integer — `ContactID = 19` for a client,
`ContactID = 39` for a donor, and so on — rather than capturing
`SCOPE_IDENTITY()` and carrying it forward through variables.

**Why it was built this way:** speed of initial development, and it
works correctly as long as the script runs start to finish against a
genuinely empty database with no partial failures along the way.

**Why it's fragile:** SQL Server's `IDENTITY` seed advances on every
insert attempt, whether or not that attempt succeeds. If any section
fails partway through — as happened during development when a bad
lookup value caused a batch insert to roll back — and the script is
re-run without first dropping and recreating the database, every
hardcoded ID reference after that point silently points at the wrong
row, or at a row that doesn't exist yet. The failure mode is not an
error message; it's a foreign key violation several sections later
that looks unrelated to its actual cause.

**How this was handled in practice:** the rule adopted during
development was to treat any mid-script failure as a signal to drop
and recreate the database and start over, rather than patching forward
from a partial state. That rule is now stated explicitly in the header
comment of `12_SeedData.sql`.

**What a production version would do differently:** capture each
`SCOPE_IDENTITY()` into a variable immediately after insert and use the
variable in every subsequent reference, or stage the seed data in
temp tables keyed by a natural identifier (e.g., email or a synthetic
external ID) and resolve to the real `ContactID` via lookup at
insert time. Either approach removes the dependency on identity
values landing at a predictable number.

---

## Seed data was built and ordered by hand

There is no synthetic data generator. Every row in `12_SeedData.sql`
was written out explicitly, section by section, in an order chosen to
satisfy foreign key dependencies (staff and board members first,
clients before their loss records, donors before any encounter that
references them, and so on).

**Why it's fragile:** dependency ordering enforced by convention and
careful reading, not by the database. During development, two
donor-stewardship `Encounter` rows were placed in the clients-and-
volunteers section, four sections before the donor records they
referenced existed. Nothing in the schema caught this at write time —
only the FK violation on execution surfaced it. A larger seed script,
or one maintained by more than one person, would make this class of
mistake more likely, not less.

**What a production or larger-scale version would do differently:** a
script-driven or Python-based generator that resolves relationships
programmatically (query for a valid `ContactID` of a given role rather
than assuming a literal number) removes this entire category of bug at
the cost of more upfront tooling work.

---

## Lookup value IDs are easy to confuse across similarly named tables

`ProfileStatus` and `ClientStatus` are separate lookup tables with
overlapping-sounding values (`ProfileStatus` has Active, Inactive,
Deceased, Do Not Contact at IDs 1–4; `ClientStatus` has a different
set including its own Deceased at ID 7). A seed data row referenced
`ProfileStatusID = 7` assuming it meant Deceased, when that ID and
value pairing only exists in `ClientStatus`. The error message on
insert (a foreign key violation naming the constraint) did not by
itself make the mismatch between the two lookup tables obvious — that
took direct inspection of both tables' contents.

**What a production version would do differently:** naming the
lookup tables and their ID columns more distinctly (e.g.,
`ProfileLifecycleStatusID` vs. `ClientServiceStatusID`) would reduce
the chance of this specific confusion, at the cost of more verbose
column names throughout the schema.

---

## RAISERROR has non-obvious substitution parameter rules

Two stored procedures originally passed a `DECIMAL(10,2)` variable
directly into a `RAISERROR(...)` call using `%s` substitution. T-SQL
rejects this at execution time with a syntax error that does not
clearly explain the actual constraint (substitution arguments must be
literals or variables of specific accepted types — not `DECIMAL`, and
not the result of an inline function call like `CONVERT()`). Both
procedures required converting the value to `VARCHAR` and assigning it
to its own variable before the `RAISERROR` call would succeed.

**What a production version would do differently:** for anything more
than a handful of custom error messages, `THROW` with a pre-formatted
message string (built with `CONCAT` or `FORMATMESSAGE`) is more
predictable than `RAISERROR`'s substitution rules, and is Microsoft's
recommended direction going forward.

---

## No automated tests

Correctness of the schema, stored procedures, and seed data was
verified manually — running each script, reading the Messages pane,
and querying row counts after each stage. There is no tSQLt suite or
equivalent automated test harness confirming that a future change to
one procedure doesn't silently break another (for example, a change to
`OrgConfiguration` values silently changing which mailing preferences
`usp_ApplyMailingPreferencesFromPayment` applies).

**What a production version would do differently:** a tSQLt test suite
covering the stored procedures' business rules — allocation sum
validation, mailing preference triggers, scholarship balance
enforcement — so that schema or procedure changes have an automated
regression check rather than relying on rerunning the seed script and
eyeballing the results.

---

## Geographic and demographic data is simplified

City, State, and Country lookups cover only the values needed for the
seed data's fictional Ashland, Oregon-area organization. The schema
supports international addresses (`CountryID`, nullable `StateID`),
but the lookup tables themselves are not populated with a full
reference set of cities, states, or countries — that would need to be
sourced from a proper reference dataset before any real-world use.

---

## Security and access control are out of scope

This is a schema and data project, not a deployed application. There
is no row-level security, no application-layer authentication, and no
role-based access control implemented at the database level beyond
what SQL Server's own login/user model would provide if configured.
A real deployment serving actual client data would require this layer
before going anywhere near production use.
