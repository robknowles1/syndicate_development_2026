# Capybara reuses one browser across examples, and a CDP device metrics override outlives
# the example that set it. Specs that size the window with resize_to instead of an override
# are then silently ignored, because an active override wins over the window size — so a
# viewport spec running earlier makes a later one assert against the wrong width. The
# failure only appears at seeds that order them that way, which is what makes it costly.
RSpec.configure do |config|
  config.after(type: :system) do
    Capybara.current_session.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  rescue StandardError
    # No browser, or a driver without CDP: nothing to reset.
    nil
  end
end
