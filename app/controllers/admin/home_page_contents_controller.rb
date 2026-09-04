module Admin
  class HomePageContentsController < BaseController
    def restore_defaults
      home_page_content = HomePageContent.first_or_initialize
      home_page_content.assign_attributes(i18n_default_attributes)
      home_page_content.save!
      home_page_content.hero_image.purge if home_page_content.hero_image.attached?
      home_page_content.cta_image.purge if home_page_content.cta_image.attached?
      flash[:notice] = I18n.t("admin.home_page_content.flash.restored")
      redirect_to admin_home_page_content_path
    end

    def show
      @home_page_content = HomePageContent.first_or_initialize
      @home_page_content.assign_attributes(i18n_default_attributes) if @home_page_content.new_record?
    end

    def update
      @home_page_content = HomePageContent.first_or_initialize
      purge_slots_marked_for_removal

      if @home_page_content.update(home_page_content_params)
        process_newly_attached_variants
        flash[:notice] = I18n.t("admin.home_page_content.update_notice")
        redirect_to admin_home_page_content_path
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def i18n_default_attributes
      {
        hero_tagline:       I18n.t("pages.home.hero_tagline"),
        mission_heading:    I18n.t("pages.home.mission_heading"),
        mission_subheading: I18n.t("pages.home.mission_subheading"),
        mission_body:       I18n.t("pages.home.mission_body")
      }
    end

    def new_file_submitted?(slot)
      params.dig(:home_page_content, slot).respond_to?(:tempfile)
    end

    def removal_requested?(slot)
      ActiveModel::Type::Boolean.new.cast(params.dig(:home_page_content, "remove_#{slot}"))
    end

    def process_newly_attached_variants
      if new_file_submitted?(:hero_image)
        @home_page_content.hero_display_variant.processed
        @home_page_content.social_share_variant.processed
      end
      @home_page_content.cta_display_variant.processed if new_file_submitted?(:cta_image)
    end

    def purge_slots_marked_for_removal
      %i[hero_image cta_image].each do |slot|
        next unless removal_requested?(slot) && !new_file_submitted?(slot)

        attachment = @home_page_content.public_send(slot)
        attachment.purge if attachment.attached?
      end
    end

    def home_page_content_params
      params.require(:home_page_content).permit(
        :hero_tagline,
        :mission_heading,
        :mission_subheading,
        :mission_body,
        :published,
        :hero_image,
        :cta_image,
        :remove_hero_image,
        :remove_cta_image
      )
    end
  end
end
