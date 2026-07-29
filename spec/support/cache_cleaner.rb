# The test environment uses a real cache store so rate limiting can be exercised, which
# means rate-limit counters survive between examples unless cleared. Without this, an
# example that exhausts the login throttle would cause unrelated later examples to be
# rejected, and the failure would depend on ordering.
RSpec.configure do |config|
  config.before(:each) { Rails.cache.clear }
end
