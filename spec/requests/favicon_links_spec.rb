require "rails_helper"

RSpec.describe "Favicon links in the public layout (SPEC-012 Part H)", type: :request do
  def icon_links(body)
    Nokogiri::HTML(body).css("head link[rel='icon'], head link[rel='apple-touch-icon']")
  end

  describe "when a visitor loads a public page" do
    it "declares each lion crop at the size the browser should pick it for (AT36, R46, AC-46)" do
      # Act
      get root_path

      # Assert
      declarations = icon_links(response.body).map { |link|
        [ link[:rel], link[:href], link[:type], link[:sizes] ]
      }
      expect(declarations).to eq([
        [ "icon", "/icon-32.png", "image/png", "32x32" ],
        [ "icon", "/icon.png", "image/png", "512x512" ],
        [ "apple-touch-icon", "/apple-touch-icon.png", nil, "180x180" ]
      ])
    end

    it "no longer links the stock Rails vector icon (AT36, R44, R46, AC-46)" do
      # Act
      get root_path

      # Assert — Chrome and Firefox prefer a declared SVG over any PNG, so a surviving
      # icon.svg link would keep the stock red circle in the tab whatever the PNGs hold
      expect(Nokogiri::HTML(response.body).css("head link[href$='.svg']")).to be_empty
    end
  end
end
