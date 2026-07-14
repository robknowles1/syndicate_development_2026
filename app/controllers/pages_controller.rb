class PagesController < ApplicationController
  before_action :check_services_published, only: :services

  def home
    @home_page_content = HomePageContent.first
  end

  def about
    @about_page_content = AboutPageContent.first
  end

  def gallery
    @photos = GalleryPhoto.order(:position)
  end

  def services
    @sections = ServiceSection.includes(:service_bullets).all.order(:position)
  end

  private

  def check_services_published
    redirect_to root_path unless SiteSetting.enabled?("services_page_published")
  end
end
