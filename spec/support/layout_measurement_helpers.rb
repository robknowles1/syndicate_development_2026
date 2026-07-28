# Measures what the browser actually laid out, rather than what the Tailwind classes in
# the template imply. A utility class is no evidence of the rendered result once a flex
# parent, a long unbroken string, or a wrapped row has had its say.
module LayoutMeasurementHelpers
  def horizontal_overflow?
    page.evaluate_script("document.body.scrollWidth > window.innerWidth")
  end

  # Only the controls a thumb has to hit. Text inputs are excluded: they are sized for
  # reading rather than tapping, and hold no tap-target minimum.
  def smallest_tap_target_height
    page.evaluate_script(<<~JS)
      (() => {
        const controls = [...document.querySelectorAll('main a, main button, main input[type=submit]')]
          .filter(el => el.getBoundingClientRect().height > 0);
        if (controls.length === 0) return null;
        return Math.min(...controls.map(el => Math.round(el.getBoundingClientRect().height)));
      })()
    JS
  end

  def any_control_offscreen?
    page.evaluate_script(<<~JS)
      (() => {
        const controls = [...document.querySelectorAll('main a, main button, main input, main textarea')]
          .filter(el => el.getBoundingClientRect().height > 0);
        return controls.some(el => {
          const rect = el.getBoundingClientRect();
          return rect.right > window.innerWidth + 1 || rect.left < -1;
        });
      })()
    JS
  end
end

RSpec.configure do |config|
  config.include LayoutMeasurementHelpers, type: :system
end
