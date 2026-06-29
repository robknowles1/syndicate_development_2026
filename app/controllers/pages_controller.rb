class PagesController < ApplicationController
  before_action :check_services_published, only: :services

  def home
  end

  def about
  end

  def gallery
    @images = Dir.glob(Rails.root.join("app/assets/images/gallery/*.jpg")).map do |path|
      "gallery/#{File.basename(path)}"
    end.sort
  end

  def services
    @sections = ServiceSection.includes(:service_bullets).all.order(:slug)
  end

  private

  def check_services_published
    redirect_to root_path unless SiteSetting.enabled?("services_page_published")
  end
end
