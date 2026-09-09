module MetaTagsHelper
  def page_title
    content_for?(:title) ? content_for(:title) : t("application.title")
  end

  def page_meta_description
    content_for?(:meta_description) ? content_for(:meta_description) : t("application.meta_description")
  end

  def page_canonical_url
    content_for?(:canonical_url) ? content_for(:canonical_url) : request.base_url + request.path
  end

  def social_share_image_url
    @social_share_image_url ||= begin
      content = HomePageContent.first
      if content&.published? && content.hero_image.attached?
        rails_representation_url(content.social_share_variant)
      else
        image_url(StructuredDataHelper::BUSINESS_IMAGE)
      end
    end
  end
end
