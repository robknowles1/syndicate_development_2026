class PagesController < ApplicationController
  before_action :check_services_published, only: :services

  def home
    @home_page_content = HomePageContent.first
    @faqs = Faq.order(:position).load
  end

  def about
    @about_page_content = AboutPageContent
      .with_attached_slideshow_image_1
      .with_attached_slideshow_image_2
      .with_attached_slideshow_image_3
      .first
    @business_hours = BusinessHours.first
  end

  def gallery
    @photos = GalleryPhoto.with_attached_image.order(:position)
  end

  def services
    @sections = ServiceSection.includes(:service_bullets).all.order(:position)
  end

  private

  def check_services_published
    redirect_to root_path unless SiteSetting.enabled?("services_page_published")
  end
end
