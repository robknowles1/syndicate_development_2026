require "rails_helper"

RSpec.describe "GET / (home page FAQ section — SPEC-012 T3)", type: :request do
  def faq_page_node(body)
    Nokogiri::HTML(body)
      .css("script[type='application/ld+json']")
      .map { |script| JSON.parse(script.text) }
      .find { |node| node["@type"] == "FAQPage" }
  end

  def details_elements(body)
    Nokogiri::HTML(body).css("details")
  end

  describe "when FAQs exist" do
    it "renders one <details> per FAQ in position order (AT8, R6, AC-8)" do
      # Arrange
      create(:faq, position: 1, question: "Second question?", answer: "Second answer.")
      create(:faq, position: 0, question: "First question?", answer: "First answer.")
      create(:faq, position: 2, question: "Third question?", answer: "Third answer.")

      # Act
      get root_path

      # Assert
      details = details_elements(response.body)
      expect(details.size).to eq(3)
      expect(details.map { |element| element.at_css("summary").text.strip }).to eq(
        [ "First question?", "Second question?", "Third question?" ]
      )
      expect(details.map { |element| element.at_css("p").text.strip }).to eq(
        [ "First answer.", "Second answer.", "Third answer." ]
      )
    end

    it "renders the FAQ heading from i18n (R6)" do
      # Arrange
      create(:faq)

      # Act
      get root_path

      # Assert
      expect(response.body).to include(I18n.t("pages.home.faq_heading"))
    end

    it "places the section between the mission and CTA blocks (R6)" do
      # Arrange
      create(:faq)

      # Act
      get root_path

      # Assert
      body = response.body
      expect(body.index(I18n.t("pages.home.mission_heading")))
        .to be < body.index(I18n.t("pages.home.faq_heading"))
      expect(body.index(I18n.t("pages.home.faq_heading")))
        .to be < body.index(I18n.t("pages.home.cta_heading"))
    end

    it "mirrors the visible list in the FAQPage JSON-LD, in the same order (AT10, R7, R8, AC-10)" do
      # Arrange
      create(:faq, position: 0, question: "First question?", answer: "First answer.")
      create(:faq, position: 1, question: "Second question?", answer: "Second answer.")
      create(:faq, position: 2, question: "Third question?", answer: "Third answer.")

      # Act
      get root_path

      # Assert
      main_entity = faq_page_node(response.body)["mainEntity"]
      expect(main_entity).to eq([
        { "@type" => "Question", "name" => "First question?",
          "acceptedAnswer" => { "@type" => "Answer", "text" => "First answer." } },
        { "@type" => "Question", "name" => "Second question?",
          "acceptedAnswer" => { "@type" => "Answer", "text" => "Second answer." } },
        { "@type" => "Question", "name" => "Third question?",
          "acceptedAnswer" => { "@type" => "Answer", "text" => "Third answer." } }
      ])
    end

    it "declares the schema.org context on the FAQPage node (R8)" do
      # Arrange
      create(:faq)

      # Act
      get root_path

      # Assert
      expect(faq_page_node(response.body)["@context"]).to eq("https://schema.org")
    end

    it "renders the JSON-LD immediately after the visible section (R7)" do
      # Arrange
      create(:faq, question: "Only question?")

      # Act
      get root_path

      # Assert
      body = response.body
      expect(body.index("</details>")).to be < body.index('type="application/ld+json"', body.index("</details>"))
      expect(body.index(I18n.t("pages.home.cta_heading")))
        .to be > body.index('type="application/ld+json"', body.index("</details>"))
    end
  end

  describe "when no FAQs exist (E1)" do
    it "omits the heading, the <details> list and the FAQPage script (AT9, R6, R7, AC-9)" do
      # Act
      get root_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(I18n.t("pages.home.faq_heading"))
      expect(details_elements(response.body)).to be_empty
      expect(faq_page_node(response.body)).to be_nil
    end
  end

  describe "when an answer carries markup that could close the script (E4)" do
    it "renders the page intact and round-trips the exact text through the JSON-LD (AT11, R32, AC-11)" do
      # Arrange
      hostile_answer = "Safe </script><script>alert(1)</script> text"
      create(:faq, position: 0, question: "Is this escaped?", answer: hostile_answer)
      create(:faq, position: 1, question: "Does markup after it survive?", answer: "Yes.")

      # Act
      get root_path

      # Assert
      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(details_elements(response.body).size).to eq(2)
      expect(response.body).to include(I18n.t("pages.home.cta_heading"))
      expect(faq_page_node(response.body)["mainEntity"].first["acceptedAnswer"]["text"])
        .to eq(hostile_answer)
    end
  end
end
