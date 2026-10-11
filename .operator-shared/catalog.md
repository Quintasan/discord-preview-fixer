# Shared Partition Catalog

## Tree

- `operator.md`
  - Description: Shared Operator Instructions — workflow, rules, and style doctrine for this repo.
  - Read If: Auto-injected.
- `catalog.md`
  - Description: This catalog.
  - Read If: Auto-injected.
- `README.md`
  - Description: Operator Memory install boilerplate; not project knowledge.
  - Read If: Installing or learning Operator Memory.
- `specs/link-fixing.md`
  - Description: Contract for link detection, host rewriting, and the fixed-reply reply/edit/delete lifecycle.
  - Read If: Changing link detection, adding a `Service` subclass, or touching message handling.
- `specs/runtime.md`
  - Description: Runtime contract for the health endpoint, storage retention, and container expectations.
  - Read If: Changing `main.rb` wiring, `HealthServer`, the messages table, or deployment.
- `guides/discordrb.md`
  - Description: Discordrb 3.8 event and API notes for message events, edits, and bot filtering.
  - Read If: Adding or changing Discord event handling.
