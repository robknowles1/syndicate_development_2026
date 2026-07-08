# Testing Rules

> Test structure, mocking, assertions, and test organization.
> Read when: writing or reviewing tests

## Test-First Development

All behavior changes require a failing test before implementation code. For bug fixes, start with a failing test that reproduces the bug before writing the fix. Write one test, watch it fail, write minimal code to pass, repeat.

### 3.1 Test Structure: AAA with Explicit Comments

Every test that has distinct setup, execution, and verification phases must use explicit AAA comments: `# Arrange`, `# Act`, `# Assert`.

**Ruby:**
```ruby
it 'returns the processed result' do
  # Arrange
  batch = create(:batch)
  instance = described_class.new(batch)

  # Act
  result = instance.call

  # Assert
  expect(result).to have_attributes(status: 'completed')
end
```

**TypeScript:**
```typescript
it("returns the created record", async () => {
  // Arrange
  const org = await prisma.organization.create({ data: { ... } });

  // Act
  const result = await createExportRequest(prisma, requestData);

  // Assert
  expect(result).toEqual(expect.objectContaining({ ... }));
});
```

One-liner declarative assertions are exempt:
```ruby
it { is_expected.to validate_presence_of(:name) }
```

### 3.2 No Global Variables in Tests

Tests must not declare or depend on global variables. All state is scoped to the individual test using inline variables.

### 3.3 Setup/Teardown Hooks Are Prohibited

`before`, `beforeEach`, `beforeAll`, `after`, `afterEach`, `afterAll` are prohibited for domain setup. All test setup belongs inline in each test case using the Arrange phase of AAA.

**The only acceptable uses of hooks:**
- Database cleaning strategy configuration
- `jest.restoreAllMocks()` in `afterEach` for TypeScript test suites

If setup is identical across tests, extract a helper method and call it explicitly in each test's Arrange phase.

### 3.4 Inline Variables Only — No Lazy Declarations

`let` and `let!` (Ruby) are prohibited. Always use inline variables within each test case.

**Required:**
```ruby
it 'processes the batch' do
  # Arrange
  batch = create(:batch, status: :pending)
  service = described_class.new(batch)

  # Act
  result = service.call

  # Assert
  expect(result).to have_attributes(status: 'completed')
end
```

**TypeScript:** Use `const` within each test function body. Do not declare shared `const` or `let` at `describe` scope.

### 3.5 Test Grouping Hierarchy

```
Top level: unit under test (class, module, component)
  Second level: method or behavior being tested
    Third level: scenario or precondition (prefixed with "when", "with", "without")
      Leaf level: expected outcome
```

Rules:
- The scenario level always starts with `when`, `with`, or `without`
- Nesting depth should not exceed 4 levels

### 3.6 Test Data Factories

Use a factory/builder library for creating test data.

Rules:
- Use `build` (in-memory) for objects that don't need persistence. Use `create` (persisted) only when needed.
- Use traits for test variations: `:admin`, `:with_tenant`
- Use sequences for unique values
- For TypeScript: use factory functions with `Partial<T>` for overrides

### 3.7 Mocking and Stubbing

#### 3.7.1 Stub in Arrange, Verify in Assert

All stubbing happens in the **Arrange** phase. All mock verification happens in the **Assert** phase. Never combine setup and verification in the same statement.

#### 3.7.2 Never Use Message Expectations (Ruby)

**Prohibited:** `expect(object).to receive(:method)`
**Required:** `allow(object).to receive(:method)` in Arrange + `expect(object).to have_received(:method)` in Assert

#### 3.7.3 Named Doubles

All test doubles must have a descriptive name: `double(:context, success?: true)`

#### 3.7.4 Type-Safe Doubles

Prefer `instance_double(ClassName)` (Ruby) or `Partial<T>` (TypeScript) over anonymous doubles.

#### 3.7.5 `spy` vs `double`

- **`spy`** (Ruby) / **`jest.fn()`** (TS): Use when you need to verify the object was called but don't care about configuring return values. Typical for loggers and message publishers.

  ```ruby
  logger = spy
  instance = described_class.new(batch, logger)
  ```

- **`double`** (Ruby) / **`jest.spyOn`** (TS): Use when you need to control the return value of a specific method.

#### 3.7.6 Complex Stubs: The `.tap` Pattern (Ruby)

When a double needs both configured behavior and to be returned from another stub, build it with `.tap`:

```ruby
service = double.tap do |stub|
  allow(stub).to receive(:call)
end
allow(Admin::SendWelcomeEmail).to receive(:new).and_return(service)
```

This pattern avoids multi-line `let` blocks and keeps the stub self-contained.

**TypeScript equivalent:** Use helper functions or inline chaining:

```typescript
const spy = jest.spyOn(global, "fetch");
mockRequests(spy, mockedRequests); // helper encapsulates complex mock setup
```

#### 3.7.7 Dependency Injection Over Patching

Doubles are passed as constructor arguments. Never use `allow_any_instance_of`.

#### 3.7.8 Mock Restoration (TypeScript)

Every TypeScript test suite using `jest.spyOn` must restore mocks after each test:
```typescript
afterEach(() => {
  jest.restoreAllMocks();
});
```

#### 3.7.9 HTTP Mocking

External HTTP calls are stubbed inline in the Arrange phase, never in shared setup.

**Ruby (WebMock):**

```ruby
stub_request(:get, "#{api_url}/v1/ap/checks_issued?#{filter_hash.to_query}")
  .with(headers:)
  .to_return(body: { data: [check_data] }.to_json, headers: response_headers)
```

**TypeScript (jest.spyOn on fetch):**

```typescript
const mockFetch = jest.spyOn(global, "fetch");
mockFetch.mockResolvedValueOnce({
  json: async () => ({ status: "SUCCESS" }),
} as any);
```

#### 3.7.10 Never Mock the Database

Tests use real database operations through factories and ORM calls, not database mocks. The database cleaning strategy (3.12) handles isolation.

### 3.8 Assert Behavior, Not Implementation

Tests verify observable outcomes — return values, side effects, HTTP responses — not which private methods were called.

### 3.9 Assertion Patterns

Use structured matchers, not manual field-by-field comparisons.

**Ruby reference matchers:** `have_attributes`, `contain_exactly`, `include`, `be_empty`, `raise_error`
**TypeScript reference matchers:** `toEqual(expect.objectContaining(...))`, `toMatchObject`, `toHaveBeenCalledWith`, `rejects.toThrow`

### 3.10 Integration/Feature Test Patterns

- Use **page objects** to encapsulate DOM traversal and UI interaction
- Provide an authentication helper (`sign_in_as(user)`) that abstracts the auth mechanism
- Assert UI content using localization keys, not hardcoded strings

### 3.11 Test Configuration Standards

Every project must configure:
- Randomized test order with a reproducible seed
- Verified/type-safe mocks
- Database isolation: transaction-based cleanup by default, truncation for integration tests
- Coverage reporting enabled

### 3.12 Database Cleanup Strategy

Projects with a database must use a cleaning strategy that:

- **Default**: wraps each test in a transaction that rolls back (fast).
- **Integration/browser tests**: truncates tables (required when test and app run in separate threads or processes).
- **Suite start**: truncates once before all tests to start clean.

### 3.13 Linter Relaxations for Test Files

- Test length limits: disabled
- Multiple assertions per test: allowed
- Block/function length: excluded for test files
- Named subject requirements: disabled. Not all tests benefit from named subjects.

### 3.14 Mutating Methods Must Return Evaluable State

Mutating methods in our own code should return the mutated state so callers and tests can evaluate the result directly. Do not force tests to re-query to verify the outcome — that's a sign the method's interface isn't testable.

Reserve re-querying for legacy code or vendor libraries where you don't control the return value.

### 3.15 Test File Organization

Test directory structure mirrors the source directory structure:

```
tests/                          # or spec/
├── factories/                  # Test data factories
├── features/ or integration/   # End-to-end / acceptance tests
├── models/                     # Domain model unit tests
├── services/                   # Service object unit tests
├── controllers/ or routes/     # Request handler tests
├── workers/ or jobs/           # Background job tests
├── form_objects/               # Input/form object tests
├── presenters/                 # Presenter tests
├── lib/                        # Library/utility tests
└── support/
    ├── database cleanup config
    ├── factory/fixture config
    ├── browser driver config
    ├── auth helper
    ├── http mock config
    ├── matchers/               # Custom assertion matchers
    ├── page_objects/           # Page objects for feature tests
    ├── value_objects/          # Value objects for test data
    └── helpers/                # Domain-specific test helpers
```

Stack-specific test rules (e.g. Rails request-spec policy, `reload!` prohibition) live in `agents/stacks/<stack>/` overlays, not here.
