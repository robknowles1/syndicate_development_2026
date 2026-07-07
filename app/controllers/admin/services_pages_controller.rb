module Admin
  class ServicesPagesController < BaseController
    def show
      @sections = ServiceSection.includes(:service_bullets).all.order(:position)
      @published = SiteSetting.enabled?("services_page_published")
    end

    def update
      SiteSetting.set("services_page_published", params[:published].presence || "false")
      flash[:notice] = I18n.t("admin.services_page.toggle_notice")
      redirect_to admin_services_page_path
    end
  end
end
