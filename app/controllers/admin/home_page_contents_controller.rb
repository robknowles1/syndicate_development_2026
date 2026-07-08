module Admin
  class HomePageContentsController < BaseController
    def restore_defaults
      home_page_content = HomePageContent.first_or_initialize
      home_page_content.assign_attributes(
        hero_tagline:       I18n.t("pages.home.hero_tagline"),
        mission_heading:    I18n.t("pages.home.mission_heading"),
        mission_subheading: I18n.t("pages.home.mission_subheading"),
        mission_body:       I18n.t("pages.home.mission_body")
      )
      home_page_content.save!
      flash[:notice] = I18n.t("admin.home_page_content.flash.restored")
      redirect_to admin_home_page_content_path
    end

    def show
      @home_page_content = HomePageContent.first_or_initialize
    end

    def update
      @home_page_content = HomePageContent.first_or_initialize
      if @home_page_content.update(home_page_content_params)
        flash[:notice] = I18n.t("admin.home_page_content.update_notice")
        redirect_to admin_home_page_content_path
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def home_page_content_params
      params.require(:home_page_content).permit(
        :hero_tagline,
        :mission_heading,
        :mission_subheading,
        :mission_body,
        :published
      )
    end
  end
end
