# Naming Rules

> Naming conventions for services, queries, jobs, presenters, form objects, factories, and tests.
> Read when: naming anything in code or specs

### 1.1 General Rule: Descriptive, Unabbreviated Names

All names must be descriptive and self-explanatory. Abbreviations are not allowed. A reader should understand what something is or does without looking at its definition.

**Prohibited:**
```
proc_inv.rb           → process_invoice.rb
bp                    → basis_price
org                   → organization
amt                   → amount
cfg                   → configuration
data                  → (too vague — name what data it is: invoice_data, price_records)
```

**The only acceptable short names:**
- Single-letter block variables in trivial iterations where the type is obvious
- Widely understood idioms: `i` in a numeric loop, `e` in a rescue/catch
- `id` (not an abbreviation)

### 1.2 Service Objects

Named as verb phrases: `CreateOrganization`, `ProcessBatch`, `ImportPrices`

Namespaced by domain: `Admin::CreateOrganization`, `BatchActions::AttachCsvFile`

### 1.3 Query Objects

Named as noun phrases with `Query` suffix: `InvoiceQuery`, `ContractPositionsQueryObject`

Methods named `with_*` or `by_*`.

### 1.4 Background Jobs

Named with `Worker` or `Job` suffix: `ProcessBatchJob`, `LoadBatchJob`, `BasisPriceUpdateWorker`

### 1.5 Presenters

Named with `Presenter` suffix: `BasisPricePresenter`, `OpenInventoryPresenter`

### 1.6 Test Factories

Named after the domain model: `factory :user`, `factory :batch_transaction`

Traits describe the variation: `:admin`, `:with_tenant`, `:processable`

### 1.7 Integration/Feature Tests

File names describe the user action: `user_creates_a_new_bank_spec.rb`, `user_signs_in_spec.rb`

Scenario descriptions use third person: "they see the details", "they are signed in"

### 1.8 Test Helpers

Authentication helpers: `sign_in_as(user)` or `sign_in(user)`

### 1.9 Spec IDs

- Rules: `R1`, `R2`, `R3`, ...
- Edge cases: `E1`, `E2`, `E3`, ...
- Acceptance criteria: `AC-1`, `AC-2`, `AC-3`, ...
- Acceptance tests: `AT1`, `AT2`, `AT3`, ...
- Specs: `SPEC-001`, `SPEC-002`, ...
