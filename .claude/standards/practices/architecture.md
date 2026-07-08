# Architecture Rules

> Layering rules, service objects, query objects, presenters, background jobs, and request handler patterns.
> Read when: writing or reviewing application code

### 1.1 Layered Structure

Every project must organize code into explicit layers. Request handlers never contain business logic.

Required layers:

| Layer            | Purpose                                                      | Ruby example                   | TypeScript example             |
| ---------------- | ------------------------------------------------------------ | ------------------------------ | ------------------------------ |
| Request Handlers | HTTP routing, parameter extraction, response formatting only | `app/controllers/`             | `src/routers/`, `src/routes/`  |
| Services         | Business logic, orchestration, command execution             | `app/services/`                | `src/services/`                |
| Domain Models    | Persistence, validations, associations, domain rules         | `app/models/`                  | Prisma models, `src/models/`   |
| Background Jobs  | Async boundaries, background processing                      | `app/workers/`, `app/sidekiq/` | BullMQ workers, `src/workers/` |

Optional layers (add when the project needs them):

| Layer                        | Purpose                                                                       |
| ---------------------------- | ----------------------------------------------------------------------------- |
| Query Objects                | Complex read operations, chainable filters, query composition                 |
| Input Objects / Form Objects | Multi-field input validation, request shaping, create/update param separation |
| Presenters / Formatters      | Display logic: currency, date, unit formatting                                |
| Policies                     | Authorization rules, permission checks                                        |
| Interactors                  | Multi-step command orchestration with rollback semantics                      |

### 1.2 Service Object Contract

All service objects expose a single public execution method (`.call`) as the entry point.

Rules:
- **One public method**: `.call`. All other methods are non-public.
- **Constructor injection**: Services receive dependencies through the constructor, not global state.
- **Transaction safety**: Services wrap multi-step mutations in database transactions.
- **Typed returns**: Services return domain objects or structured result types, never raw hashes.

**Ruby reference:**
```ruby
class CreateOrganization
  def initialize(attributes)
    @attributes = attributes
  end

  def call
    Organization.transaction do
      # business logic
    end
    @organization
  end
end
```

**TypeScript reference:**
```typescript
type Result<T> = { success: boolean; data: T; errors?: string[] };

export const createExportRequest = async (
  prisma: PrismaClient,
  data: RequestData,
): Promise<ExportRequest> => {
  // business logic
};
```

### 1.3 Thin Request Handlers

Request handlers handle only: authentication checks, parameter extraction, service delegation, and response formatting.

Rules:
- Handler actions are 2-8 lines of meaningful code.
- No business logic.
- Authorization checks happen at the handler layer, before service delegation.
- Use localized message keys for user-facing feedback, not hardcoded strings.

### 1.4 Query Object Pattern

Complex reads go in dedicated query objects, not in models or request handlers.

Rules:
- Query objects wrap a base query and return `self` for chaining.
- Methods use descriptive `with_*` or `by_*` naming.

### 1.5 Background Job Pattern

Background jobs are thin wrappers. They fetch the record, delegate to a service, and handle error reporting.

Rules:
- Jobs receive only serializable identifiers (IDs, keys), never complex objects.
- Business logic never lives in a job.
- Error handling: catch, report to error tracker, re-raise for framework retry.

### 1.6 Presenter/Decorator Pattern

Display logic belongs in presenter objects, not in domain models or templates.

Rules:
- Presenters wrap a domain object and a formatting context.
- Use the Null Object pattern when the wrapped object may be nil.
- Memoize expensive computations.

### 1.7 Input/Form Object Pattern

When a request collects input that does not map 1:1 to a domain model, use an input object.

Rules:
- Input objects include validation logic.
- Separate output methods for different operations: `create_params` vs `update_params`.

### 1.8 Request Handler Action Order

When a request handler defines multiple CRUD actions, order them alphabetically:
```
create, destroy, edit, index, new, show, update
```
