require "rails_helper"

RSpec.describe "Contact form spam fields", type: :request do
  describe "GET /about" do
    it "keeps the honeypot out of the accessibility tree and the tab order (AT45, AC-55, R51)" do
      # Act
      get about_path

      # Assert
      honeypot = Nokogiri::HTML(response.body).at_css("input[name='website']")
      wrapper = honeypot.parent
      expect(wrapper["aria-hidden"]).to eq("true")
      expect(wrapper.at_css("label[for='website']")).to be_present
      expect(honeypot["tabindex"]).to eq("-1")
      expect(honeypot["autocomplete"]).to eq("off")
    end

    it "moves the honeypot off screen rather than hiding it from bots (AT45, AC-55, R51)" do
      # Act
      get about_path

      # Assert
      wrapper_classes = Nokogiri::HTML(response.body).at_css("input[name='website']").parent["class"].split
      expect(wrapper_classes).to include("absolute", "-left-[9999px]", "-top-[9999px]")
      expect(wrapper_classes).not_to include("hidden")
      expect(wrapper_classes).not_to include("invisible")
    end

    it "renders a timing token this app can verify (AT45, R54)" do
      # Act
      get about_path

      # Assert
      token = Nokogiri::HTML(response.body).at_css("input[name='rendered_at']")
      expect(token["type"]).to eq("hidden")
      expect(Rails.application.message_verifier(:contact_form).verify(token["value"]))
        .to be_within(5).of(Time.current.to_i)
    end

    it "signs a fresh timing token on every render (R54)" do
      # Act
      get about_path
      first_token = Nokogiri::HTML(response.body).at_css("input[name='rendered_at']")["value"]
      travel 1.minute
      get about_path
      second_token = Nokogiri::HTML(response.body).at_css("input[name='rendered_at']")["value"]

      # Assert
      expect(second_token).not_to eq(first_token)
    end
  end
end
