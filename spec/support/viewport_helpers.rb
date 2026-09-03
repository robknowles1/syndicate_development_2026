# Headless Chrome enforces a minimum window width of roughly 500px, so
# `browser.manage.window.resize_to(375, 812)` silently produces a 500px viewport — wide
# enough to hide the layout breakage a real phone shows, while reading in the spec as
# though phone width were covered. A persistent admin nav shipped effectively unusable
# on a phone that way, past a spec that resized to "375".
#
# CDP's device metrics override sets the viewport directly and does reach phone widths.
# `mobile: true` covers the viewport meta tag, overlay scrollbars and text autosizing — not
# touch. Touch events need Emulation.setTouchEmulationEnabled, which nothing here calls, so
# `ontouchstart in window` stays false: never read a spec passing under emulate_viewport as
# evidence that a touch code path was exercised.
module ViewportHelpers
  # Chrome will not render below roughly 367px wide even under a device metrics
  # override; a narrower request is silently widened. Since a spec that believes it is
  # at 320px but is really at 367px is the exact failure this helper exists to prevent,
  # refuse the request rather than let it pass quietly.
  MINIMUM_EMULATED_WIDTH = 367

  # Capybara reuses one browser across examples, and a device metrics override outlives
  # the example that set it. Applying a second override on top of a live one yields a
  # viewport matching neither, so clear any previous override before setting this one.
  def emulate_viewport(width:, height: 844)
    if width < MINIMUM_EMULATED_WIDTH
      raise ArgumentError,
        "Chrome cannot render below #{MINIMUM_EMULATED_WIDTH}px; #{width}px would " \
        "silently become #{MINIMUM_EMULATED_WIDTH}px. Assert at #{MINIMUM_EMULATED_WIDTH}px or wider."
    end

    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: true)
  end

  # Reports the viewport the browser actually applied, so a spec can assert it got the
  # width it asked for instead of trusting the request silently succeeded.
  def actual_viewport_width
    page.evaluate_script("window.innerWidth")
  end
end

RSpec.configure do |config|
  config.include ViewportHelpers, type: :system
end
