# System tests run the app in a real browser via Puma in a separate thread.
# The Puma thread cannot see data inside an open transaction from the test thread.
# Solution: use :deletion strategy (not :truncation to avoid FK issues) for system specs,
# which commits data so the browser can read it, and deletes records after each example.
RSpec.configure do |config|
  config.around(:each, type: :system) do |example|
    # Disable transactional test wrapping for this example so Puma can see DB writes
    self.class.use_transactional_tests = false

    # The example may write records; they are visible to the browser since no transaction wraps them.
    example.run

    # Clean up committed records after the example
    [ ServiceBullet, ServiceSection, SiteSetting, AdminUser ].each do |model|
      model.delete_all
    end

    # Restore transactional mode for subsequent non-system specs
    self.class.use_transactional_tests = true
  end
end
