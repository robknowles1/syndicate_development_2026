require "rails_helper"

RSpec.describe "SPEC-012 static file inspection" do
  def repository_path(relative_path)
    Rails.root.join(relative_path)
  end

  def png_dimensions(relative_path)
    IO.binread(repository_path(relative_path), 24).unpack("x16N2")
  end

  describe "files under public/ that would shadow a dynamic route" do
    it "ships no static robots.txt (AT31, R35, AC-40, E17)" do
      # Assert
      expect(repository_path("public/robots.txt")).not_to exist
    end

    it "ships no static sitemap.xml (AT28, R38)" do
      # Assert
      expect(repository_path("public/sitemap.xml")).not_to exist
    end
  end

  describe "favicon assets" do
    it "keeps icon.png at its full 512x512 size (AT37, R44, AC-47)" do
      # Assert
      expect(png_dimensions("public/icon.png")).to eq([ 512, 512 ])
    end

    it "adds a 32x32 tab icon (AT37, R44, AC-47)" do
      # Assert
      expect(png_dimensions("public/icon-32.png")).to eq([ 32, 32 ])
    end

    it "adds a 180x180 apple touch icon (AT37, R44, AC-47)" do
      # Assert
      expect(png_dimensions("public/apple-touch-icon.png")).to eq([ 180, 180 ])
    end

    it "drops the stock Rails vector icon (AT31, R44, AC-47)" do
      # Assert
      expect(repository_path("public/icon.svg")).not_to exist
    end

    it "keeps the 822x540 crop source alongside the icons it produced (AT37, R45, AC-47)" do
      # Assert
      expect(png_dimensions("docs/assets/favicon/moto-original-822x540.png")).to eq([ 822, 540 ])
    end
  end

  describe "app/views/layouts/admin.html.erb" do
    it "adds no favicon link tags to the admin layout (AT51, R47, AC-60)" do
      # Arrange
      layout_source = File.read(repository_path("app/views/layouts/admin.html.erb"))

      # Act
      icon_links = Nokogiri::HTML(layout_source).css("link[rel*='icon']")

      # Assert
      expect(icon_links).to be_empty
    end
  end
end
