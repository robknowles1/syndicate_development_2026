module ApplicationHelper
  include TablerIconsRuby::Helper

  # Icons that are not yet bundled in the installed tabler_icons_ruby gem version
  # (e.g. icons added to the upstream Tabler Icons project after the gem's last release).
  # Each value is a complete <svg> string with a CSS class placeholder that service_icon
  # replaces with the caller-supplied size classes at render time.
  # SVG path data sourced verbatim from https://github.com/tabler/tabler-icons (MIT licensed).
  VENDORED_ICON_SVGS = {
    "car-suspension" => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon icon-tabler icons-tabler-outline icon-tabler-car-suspension ICON_CSS_CLASS_PLACEHOLDER"><path d="M12 22a3 3 0 1 1 0 -6a3 3 0 0 1 0 6" /><path d="M12 16v-12" /><path d="M13 2h-2v2h2v-2" /><path d="M9 11l6 -1" /><path d="M9 14l6 -1" /><path d="M9 8l6 -1" /></svg>'
  }.freeze

  # Renders a Tabler icon by key. Falls back to VENDORED_ICON_SVGS for icons not yet
  # bundled in the installed gem version (e.g. car-suspension). Both paths return
  # html_safe SVG markup and produce visually consistent output.
  def service_icon(icon_key, css_class:)
    if (svg = VENDORED_ICON_SVGS[icon_key])
      svg.gsub("ICON_CSS_CLASS_PLACEHOLDER", css_class).html_safe
    else
      tabler_icon(icon_key, class: css_class)
    end
  end
end
