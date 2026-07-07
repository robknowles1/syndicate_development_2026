# ADR-004: Singleton Content Model Pattern and Publish Flag Placement

**Status:** Accepted
**Date:** 2026-07-07
**Deciders:** Architect agent


## Context

SPEC-006 introduces admin-editable copy for the home page: four named fields (`hero_tagline`, `mission_heading`, `mission_subheading`, `mission_body`) plus a `published` flag that gates whether the public page renders DB values or i18n fallback. The spec draft raises two questions that block implementation:

1. Should the `published` flag live as a column on the new `HomePageContent` model, or as a `SiteSetting` key-value row (consistent with the existing `services_page_published` key from SPEC-004)?
2. Should the singleton content model (`HomePageContent`, at most one row ever used) be implemented as a dedicated ActiveRecord table, or should all four fields be stored as individual `SiteSetting` rows?

Both choices establish a pattern that will recur: this site will likely need per-page content editing for About and Contact in future specs.

Existing precedents in this codebase:
- ADR-001 chose dedicated relational models (`service_sections`, `service_bullets`) over a key-value store for structured editable content on the Services page.
- SPEC-004 stores the Services page visibility toggle as a `SiteSetting` row (`services_page_published = "true"/"false"`). This flag controls whether the entire page is accessible; it is checked independently of any content model via a `before_action` redirect guard.


## Decision

**1. Use a dedicated `home_page_contents` table (singleton ActiveRecord model).** Do not store the four editable fields as `SiteSetting` rows.

**2. Put `published` as a boolean column on `HomePageContent`.** Do not create a `"home_page_content_published"` `SiteSetting` key.


## Rationale

### Singleton model over key-value store for the four content fields

The four fields are typed, individually validated content — not configuration flags. `hero_tagline` has a 50-character maximum; `mission_body` is a text column that preserves line breaks; each field has presence validation. These constraints are expressed cleanly as `validates` declarations on an ActiveRecord model and as column-type constraints in the migration. Storing them as `SiteSetting` rows would require:

- Coercing everything to strings (losing the `text` type for `mission_body`)
- Moving per-field validations out of the model and into the controller or a form object
- Fabricating a model-like object for form rendering and error display, since `form_with model:` expects an object with attribute accessors and an `errors` collection

ADR-001 rejected the key-value approach for `ServiceSection`/`ServiceBullet` for structurally similar reasons: structured content with individual constraints is a poor fit for flat `{ key, value }` storage. The same reasoning applies here. The KV store is the right home for scalar flags (`services_page_published`); it is the wrong home for multi-field content objects.

### `published` as a column on `HomePageContent`

The `services_page_published` SiteSetting is not a good precedent for this flag because the two flags have different semantics:

- `services_page_published` is a *page-access gate*: it controls whether the entire `/services` route is accessible. It is checked via a `before_action` redirect guard on `PagesController`, independently of any content model — there is no "ServicesPageContent" singleton. The flag is a site-level setting, appropriately stored in the site settings table.

- `HomePageContent#published` is a *content substitution switch*: it controls whether four specific fields on a page that always renders show DB values or i18n fallback. The home page is never redirected-away or blocked. This flag is semantically a property of the content record it gates — it answers "is this content object live?" — not a property of the site.

Placing `published` on the model rather than in a separate table has three practical benefits:

1. **Atomicity.** Updating content copy and flipping the publish flag is a single `update` call in one transaction. With a separate `SiteSetting.set` call, the two writes are independent; a partial failure leaves them inconsistent.

2. **Simpler controller.** `@home_page_content = HomePageContent.first_or_initialize` gives the controller and view everything they need — content and publish state — with one DB read. A SiteSetting approach requires a second lookup.

3. **No phantom inconsistency.** If the `home_page_contents` row does not exist, `published` is implicitly false (nil record → fallback). There is no scenario where a SiteSetting says "published: true" but no content row exists to serve.


## Alternatives Considered

| Option | Pros | Cons | Rejected Because |
|--------|------|------|-----------------|
| Store 4 fields as `SiteSetting` rows | No new table; consistent with existing SiteSetting usage | Loses column typing; per-field validations must move out of the model; form error display requires a fabricated form object; `mission_body` (text) becomes a string column | Structured typed content with individual validations is a poor fit for a flat KV store (same reasoning as ADR-001) |
| `published` as a `SiteSetting` key | Consistent with `services_page_published` | Two separate writes for one logical operation; extra DB read per request; risk of inconsistency between content row and setting; flag has different semantics from `services_page_published` | The `services_page_published` precedent is not analogous (page-access gate vs. field-level content switch); atomicity and co-location favor a column |


## Consequences

### Positive

- Standard Rails patterns throughout: one model, one migration, one `form_with model:`, one `update` call.
- Per-field validations, error messages, and re-render on failure work without any extra machinery.
- Reading publish state costs nothing extra — it's already loaded with the content object.
- Establishes a clear pattern for future page content editing specs: dedicated singleton model, `published` column co-located with the content it gates.

### Negative

- One new table (`home_page_contents`) rather than reusing the existing `site_settings` table. On a site this size this is irrelevant in practice.
- Future developers must know to use `first_or_initialize` (not `new`) to preserve the singleton contract. This is documented in R10 of the spec and enforced by application code, not a DB constraint.

### Risks

- **Second-row creation.** The singleton contract is enforced by application code (`first_or_initialize`), not a database unique constraint. A developer writing a direct `HomePageContent.create` call could break it. Mitigated by documenting R10 in the spec and in this ADR. A DB-level constraint (e.g. a unique index on a constant expression) is possible but is over-engineering for a single-admin site; application-level enforcement is sufficient.
- **Pattern drift on future specs.** If a future spec introduces page content editing and stores its publish flag in `SiteSetting` (reverting to the old pattern), the codebase will have two inconsistent approaches. Mitigated by this ADR being the explicit reference for the pattern going forward.


## Implementation Notes

1. The singleton is enforced by always reading and writing via `HomePageContent.first_or_initialize`. No second row must ever be created. The controller's `show` and `update` actions both use this pattern.
2. `published` is a `boolean not null default false` column. The `form` must include a hidden field with value `"false"` paired with the checkbox so that unchecking sends `"false"` rather than omitting the param entirely (standard Rails checkbox pattern).
3. The seed row (`db/seeds.rb`) must use `first_or_initialize` and call `save!` only if `new_record?` or if the record genuinely needs updating — running seeds twice must not raise or produce a second row.
4. `PagesController#home` loads `@home_page_content = HomePageContent.first` (may return nil). The view checks `@home_page_content&.published?` to decide between DB values and i18n fallback. A nil result is equivalent to unpublished. No nil-unsafe access anywhere in the view.
5. The `published` column accessor is `published?` (boolean predicate generated by ActiveRecord). Use `@home_page_content.published?` in view conditionals, not `== true`.
