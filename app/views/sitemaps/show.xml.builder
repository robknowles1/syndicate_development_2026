xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  @page_urls.each do |page_url|
    xml.url do
      xml.loc page_url
    end
  end
end
