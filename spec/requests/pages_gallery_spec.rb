require "rails_helper"

RSpec.describe "GET /gallery (SPEC-008 gallery photo management)", type: :request do
  describe "when 3 GalleryPhoto rows exist in position order (AT1)" do
    it "returns HTTP 200 and renders the 3 images in position order (AT1, R11, R12, AC-1)" do
      # Arrange
      create(:gallery_photo, position: 2)
      create(:gallery_photo, position: 0)
      create(:gallery_photo, position: 1)

      # Act
      get gallery_path

      # Assert
      expect(response).to have_http_status(:ok)
      grid_images = Nokogiri::HTML(response.body).css("div.grid img")
      expect(grid_images.count).to eq(3)
    end

    it "renders photos ordered by position, not creation order (AT1, R11, AC-1)" do
      # Arrange
      last_photo = create(:gallery_photo, position: 2)
      first_photo = create(:gallery_photo, position: 0)
      create(:gallery_photo, position: 1)

      # Act
      get gallery_path

      # Assert
      grid_image_srcs = Nokogiri::HTML(response.body).css("div.grid img").map { |img| img["src"] }
      first_signed_blob_id = first_photo.image.blob.signed_id
      last_signed_blob_id = last_photo.image.blob.signed_id
      first_index = grid_image_srcs.index { |src| src.include?(first_signed_blob_id) }
      last_index = grid_image_srcs.index { |src| src.include?(last_signed_blob_id) }
      expect(first_index).to be < last_index
    end
  end

  describe "when a GalleryPhoto has an attached image (AT2, AT3)" do
    it "renders the img src as a display-variant representation path, not the raw blob path (AT2, R4, R10, R12, AC-2)" do
      # Arrange
      create(:gallery_photo, position: 0)

      # Act
      get gallery_path

      # Assert
      img_src = Nokogiri::HTML(response.body).css("div.grid img").first["src"]
      expect(img_src).to match(%r{/rails/active_storage/representations/})
      expect(img_src).not_to match(%r{/rails/active_storage/blobs/})
    end

    it "wraps the img in a lightbox-trigger button carrying the same display-variant URL as a param, not a navigable <a> href (AT3, R10, R12, AC-3)" do
      # Arrange
      photo = create(:gallery_photo, position: 0)

      # Act
      get gallery_path

      # Assert
      document = Nokogiri::HTML(response.body)
      expect(document.css("div.grid a")).to be_empty
      trigger = document.css("div.grid button").first
      expect(trigger["data-action"]).to include("gallery-lightbox#open")
      expect(URI(trigger["data-gallery-lightbox-src-param"]).path).to eq(URI(trigger.at_css("img")["src"]).path)
      expect(trigger["data-gallery-lightbox-src-param"]).to match(%r{/rails/active_storage/representations/})
      expect(trigger["data-gallery-lightbox-src-param"]).to include(photo.image.blob.signed_id)
    end

    it "renders a lightbox overlay with a close button, hidden by default" do
      # Arrange
      create(:gallery_photo, position: 0)

      # Act
      get gallery_path

      # Assert
      document = Nokogiri::HTML(response.body)
      overlay = document.css("[data-gallery-lightbox-target='overlay']").first
      expect(overlay["class"]).to include("hidden")
      expect(overlay.css("button[data-action*='gallery-lightbox#close']")).not_to be_empty
      expect(overlay["role"]).to eq("dialog")
    end
  end

  describe "when zero GalleryPhoto rows exist (AT4)" do
    it "returns HTTP 200 with zero images and no error (AT4, R11, AC-4)" do
      # Arrange — table empty by default in a clean test

      # Act
      get gallery_path

      # Assert
      expect(response).to have_http_status(:ok)
      grid_images = Nokogiri::HTML(response.body).css("div.grid img")
      expect(grid_images.count).to eq(0)
    end
  end

  describe "photo alt text (AT5)" do
    it "renders the generic photo_alt string for every photo (AT5, R12, AC-5)" do
      # Arrange
      create(:gallery_photo, position: 0)
      create(:gallery_photo, position: 1)

      # Act
      get gallery_path

      # Assert
      grid_images = Nokogiri::HTML(response.body).css("div.grid img")
      expect(grid_images.map { |img| img["alt"] }).to all(eq(I18n.t("pages.gallery.photo_alt")))
    end
  end
end
