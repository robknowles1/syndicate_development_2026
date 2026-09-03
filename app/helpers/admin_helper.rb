module AdminHelper
  # Ordered destinations for the persistent admin nav bar. Kept here rather than inline
  # in the layout so the ordering is testable and a future admin section is added in
  # one place instead of being duplicated across the layout and the dashboard.
  def admin_nav_items
    [
      [ t("admin.layout.nav.dashboard"), admin_root_path ],
      [ t("admin.layout.nav.home"),      admin_home_page_content_path ],
      [ t("admin.layout.nav.about"),     admin_about_page_content_path ],
      [ t("admin.layout.nav.gallery"),   admin_gallery_photos_path ],
      [ t("admin.layout.nav.services"),  admin_services_page_path ],
      [ t("admin.layout.nav.social"),    admin_social_media_links_path ]
    ]
  end

  # Deliberately not current_page?, which matches only GET requests. A validation
  # failure re-renders the form in response to the original PATCH/POST, so current_page?
  # would drop the highlight exactly when the admin most needs to know where they are.
  def admin_nav_current?(path)
    if path == admin_root_path
      # Every admin path starts with /admin, so the dashboard needs an exact match.
      request.path == admin_root_path
    elsif path == admin_services_page_path
      # Service sections are edited on their own pages, which have no nav entry.
      request.path.start_with?(path, "/admin/service_sections")
    else
      request.path.start_with?(path)
    end
  end

  # Hover is not an affordance on touch, so the current page is marked with a solid fill.
  def admin_nav_link_class(path)
    base = "block py-3 px-3 text-sm font-bold rounded"

    if admin_nav_current?(path)
      "#{base} bg-red-600 text-white"
    else
      "#{base} text-gray-300 hover:text-white"
    end
  end
end
