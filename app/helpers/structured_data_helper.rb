module StructuredDataHelper
  BUSINESS_NAME = "Syndicate Development".freeze
  ADDRESS_LOCALITY = "Pocatello".freeze
  ADDRESS_REGION = "ID".freeze
  POSTAL_CODE = "83204".freeze
  ADDRESS_COUNTRY = "US".freeze
  GEO_LATITUDE = 42.8739291
  GEO_LONGITUDE = -112.4668151
  AREA_SERVED = [
    { "@type" => "City", "name" => "Pocatello" },
    { "@type" => "City", "name" => "Idaho Falls" },
    { "@type" => "City", "name" => "Boise" },
    { "@type" => "State", "name" => "Idaho" },
    { "@type" => "State", "name" => "Utah" }
  ].freeze
  BUSINESS_IMAGE = "gallery/m45a2849.jpg".freeze

  def local_business_schema
    content = AboutPageContent.first
    content = nil unless content&.published?

    schema = {
      "@context" => "https://schema.org",
      "@type" => "MotorcycleRepair",
      "@id" => "#{root_url}#business",
      "name" => BUSINESS_NAME,
      "url" => root_url,
      "image" => image_url(BUSINESS_IMAGE),
      "telephone" => content&.shop_phone_number || t("pages.about.shop_phone_number"),
      "address" => {
        "@type" => "PostalAddress",
        "streetAddress" => content&.shop_address || t("pages.about.shop_address"),
        "addressLocality" => ADDRESS_LOCALITY,
        "addressRegion" => ADDRESS_REGION,
        "postalCode" => POSTAL_CODE,
        "addressCountry" => ADDRESS_COUNTRY
      },
      "geo" => {
        "@type" => "GeoCoordinates",
        "latitude" => GEO_LATITUDE,
        "longitude" => GEO_LONGITUDE
      },
      "areaServed" => AREA_SERVED
    }

    opening_hours = BusinessHours.first&.opening_hours_specification
    schema["openingHoursSpecification"] = opening_hours if opening_hours

    schema
  end

  def faq_page_schema(faqs)
    {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => faqs.map { |faq|
        {
          "@type" => "Question",
          "name" => faq.question,
          "acceptedAnswer" => { "@type" => "Answer", "text" => faq.answer }
        }
      }
    }
  end

  # `raw` here is load-bearing, not an oversight. json_escape has already neutralised the
  # `<`, `>` and `&` that admin-authored text could use to close this <script>; escaping
  # again would only reach the quotes, and HTML entities are not decoded inside a script
  # element, so the JSON parser would receive a literal `&quot;` and fail.
  def json_ld_script_tag(schema)
    tag.script(raw(json_escape(schema.to_json)), type: "application/ld+json")
  end
end
