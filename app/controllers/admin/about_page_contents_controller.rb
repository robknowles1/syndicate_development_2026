module Admin
  class AboutPageContentsController < BaseController
    def restore_defaults
      about_page_content = AboutPageContent.first_or_initialize
      about_page_content.assign_attributes(i18n_default_attributes)
      about_page_content.save!
      about_page_content.slideshow_image_1.purge if about_page_content.slideshow_image_1.attached?
      about_page_content.slideshow_image_2.purge if about_page_content.slideshow_image_2.attached?
      about_page_content.slideshow_image_3.purge if about_page_content.slideshow_image_3.attached?
      flash[:notice] = I18n.t("admin.about_page_content.flash.restored")
      redirect_to admin_about_page_content_path
    end

    def show
      @about_page_content = AboutPageContent.first_or_initialize
      @about_page_content.assign_attributes(i18n_default_attributes) if @about_page_content.new_record?
    end

    def update
      @about_page_content = AboutPageContent.first_or_initialize
      if @about_page_content.update(about_page_content_params)
        flash[:notice] = I18n.t("admin.about_page_content.update_notice")
        redirect_to admin_about_page_content_path
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def i18n_default_attributes
      {
        shop_heading:       I18n.t("pages.about.shop_heading"),
        shop_phone_label:   I18n.t("pages.about.shop_phone_label"),
        shop_phone_number:  I18n.t("pages.about.shop_phone_number"),
        shop_address_label: I18n.t("pages.about.shop_address_label"),
        shop_address:       I18n.t("pages.about.shop_address"),
        bio_heading:        I18n.t("pages.about.bio_heading"),
        bio_body:           I18n.t("pages.about.bio_body"),
        slideshow_alt_1:    I18n.t("pages.about.slideshow_alt_1"),
        slideshow_alt_2:    I18n.t("pages.about.slideshow_alt_2"),
        slideshow_alt_3:    I18n.t("pages.about.slideshow_alt_3")
      }
    end

    def about_page_content_params
      params.require(:about_page_content).permit(
        :shop_heading,
        :shop_phone_label,
        :shop_phone_number,
        :shop_address_label,
        :shop_address,
        :bio_heading,
        :bio_body,
        :slideshow_alt_1,
        :slideshow_alt_2,
        :slideshow_alt_3,
        :published,
        :slideshow_image_1,
        :slideshow_image_2,
        :slideshow_image_3
      )
    end
  end
end
