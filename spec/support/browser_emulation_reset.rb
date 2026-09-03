# Capybara reuses one browser across examples, and a CDP device metrics override outlives
# the example that set it. Specs that size the window with resize_to instead of an override
# are then silently ignored, because an active override wins over the window size — so a
# viewport spec running earlier makes a later one assert against the wrong width. The
# failure only appears at seeds that order them that way, which is what makes it costly.
RSpec.configure do |config|
  config.after(type: :system) do
    driver = Capybara.current_session.driver
    browser = driver.browser if driver.respond_to?(:browser)

    # Deliberately unrescued. A driver with no CDP is asked nothing, but a CDP call that
    # does fail leaves the override live for every later example — the corruption this hook
    # exists to prevent — and a blanket rescue would resurface it as a baffling width
    # failure in an unrelated spec instead of here.
    browser.execute_cdp("Emulation.clearDeviceMetricsOverride") if browser.respond_to?(:execute_cdp)
  end
end
