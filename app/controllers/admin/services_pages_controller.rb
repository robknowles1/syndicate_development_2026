module Admin
  class ServicesPagesController < BaseController
    def show
      @sections = ServiceSection.includes(:service_bullets).all.order(:slug)
      @published = SiteSetting.enabled?("services_page_published")
    end

    def update
      if params[:published].present?
        SiteSetting.set("services_page_published", params[:published])
        flash[:notice] = I18n.t("admin.services_page.toggle_notice")
        redirect_to admin_services_page_path
      elsif params[:service_sections].present?
        update_service_sections
      else
        redirect_to admin_services_page_path
      end
    end

    private

    def update_service_sections
      success = true
      errors = []

      params[:service_sections].each do |slug, section_params|
        section = ServiceSection.includes(:service_bullets).find_by(slug: slug)
        next unless section

        attributes = section_params.to_unsafe_h
        unless section.update(service_section_update_params(attributes))
          success = false
          errors.concat(section.errors.full_messages)
        end
      end

      if success
        flash[:notice] = I18n.t("admin.services_page.content_notice")
        redirect_to admin_services_page_path
      else
        flash.now[:alert] = errors.join(", ")
        @sections = ServiceSection.includes(:service_bullets).all.order(:slug)
        @published = SiteSetting.enabled?("services_page_published")
        render :show, status: :unprocessable_entity
      end
    end

    def service_section_update_params(attrs)
      permitted = { heading: attrs["heading"] }
      if attrs["service_bullets_attributes"].present?
        bullets_attrs = attrs["service_bullets_attributes"].map do |_key, bullet|
          bullet.slice("id", "body", "position", "_destroy")
        end
        permitted[:service_bullets_attributes] = bullets_attrs
      end
      permitted
    end
  end
end
