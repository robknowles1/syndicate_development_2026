class SitemapsController < ApplicationController
  def show
    @page_urls = [ root_url, about_url, gallery_url ]
    @page_urls << services_url if SiteSetting.enabled?("services_page_published")
  end
end
