require "rails_helper"

RSpec.describe "Admin image upload guards", type: :request do
  def sign_in_admin(admin)
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
  end

  def signed_in_admin
    admin = create(:admin_user, password: "securepassword123", password_confirmation: "securepassword123")
    sign_in_admin(admin)
    admin
  end

  def file_input(document, name)
    document.at_css("input[type='file'][name='#{name}']")
  end

  def guard_wrapper(document, name)
    file_input(document, name).ancestors("[data-controller~='image-upload-guard']").first
  end

  describe "Guard 1 — the picker filter" do
    it "puts the derived accept value on all three About slideshow inputs (AT3, R3, AC-3)" do
      # Arrange
      signed_in_admin

      # Act
      get admin_about_page_content_path
      document = Nokogiri::HTML(response.body)

      # Assert
      accepts = (1..3).map { |index|
        file_input(document, "about_page_content[slideshow_image_#{index}]")["accept"]
      }
      expect(accepts).to all(eq(ImageAttachmentValidatable.accept_attribute_value))
    end

    it "puts the derived accept value on the Gallery upload input (AT4, R3, AC-3)" do
      # Arrange
      signed_in_admin

      # Act
      get admin_gallery_photos_path
      document = Nokogiri::HTML(response.body)

      # Assert
      expect(file_input(document, "gallery_photo[image]")["accept"])
        .to eq(ImageAttachmentValidatable.accept_attribute_value)
    end

    it "puts the derived accept value on the Home hero and CTA inputs (AT5, R3, R19, AC-4)" do
      # Arrange
      signed_in_admin

      # Act
      get admin_home_page_content_path
      document = Nokogiri::HTML(response.body)

      # Assert
      accepts = %w[hero_image cta_image].map { |field|
        file_input(document, "home_page_content[#{field}]")["accept"]
      }
      expect(accepts).to all(eq(ImageAttachmentValidatable.accept_attribute_value))
    end
  end

  describe "the guards' single source of truth (AT2, R3, R15, AC-2)" do
    it "re-renders all six inputs from the constants, not from a copy of today's values" do
      # Arrange — a literal in a view would match the constants as they stand today, so
      # only moving the constants can tell a derived value from a hardcoded one.
      signed_in_admin
      stub_const(
        "ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES",
        ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES + [ "image/avif" ]
      )
      stub_const("ImageAttachmentValidatable::MAX_IMAGE_SIZE", 7.megabytes)
      pages = {
        admin_home_page_content_path => %w[home_page_content[hero_image] home_page_content[cta_image]],
        admin_about_page_content_path => (1..3).map { |i| "about_page_content[slideshow_image_#{i}]" },
        admin_gallery_photos_path => %w[gallery_photo[image]]
      }

      # Act
      rendered_guards = pages.flat_map { |path, names|
        get path
        document = Nokogiri::HTML(response.body)
        names.map { |name|
          wrapper = guard_wrapper(document, name)
          {
            accept: file_input(document, name)["accept"],
            max_bytes: wrapper["data-image-upload-guard-max-bytes-value"],
            allowed_types: wrapper["data-image-upload-guard-allowed-types-value"],
            oversized_message: wrapper["data-image-upload-guard-oversized-message-value"]
          }
        }
      }

      # Assert
      expect(rendered_guards.length).to eq(6)
      expect(rendered_guards.map { |guard| guard[:accept] })
        .to all(eq("image/jpeg,image/png,image/webp,image/avif,.jpg,.jpeg,.png,.webp"))
      expect(rendered_guards.map { |guard| guard[:allowed_types] })
        .to all(eq("image/jpeg,image/png,image/webp,image/avif"))
      expect(rendered_guards.map { |guard| guard[:max_bytes] }).to all(eq(7.megabytes.to_s))
      expect(rendered_guards.map { |guard| guard[:oversized_message] }).to all(include("7 MB"))
    end
  end

  describe "Guard 2 — the values handed to the Stimulus controller (R15)" do
    it "renders the size cap and type list from the server constants on the Gallery input" do
      # Arrange
      signed_in_admin

      # Act
      get admin_gallery_photos_path
      wrapper = guard_wrapper(Nokogiri::HTML(response.body), "gallery_photo[image]")

      # Assert
      expect(wrapper["data-image-upload-guard-max-bytes-value"])
        .to eq(ImageAttachmentValidatable::MAX_IMAGE_SIZE.to_s)
      expect(wrapper["data-image-upload-guard-allowed-types-value"])
        .to eq(ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES.join(","))
    end

    it "renders the cap into the oversized message rather than a hardcoded number (R16, AC-18)" do
      # Arrange
      signed_in_admin

      # Act
      get admin_gallery_photos_path
      wrapper = guard_wrapper(Nokogiri::HTML(response.body), "gallery_photo[image]")

      # Assert
      expect(wrapper["data-image-upload-guard-oversized-message-value"])
        .to include((ImageAttachmentValidatable::MAX_IMAGE_SIZE / 1.megabyte).to_s)
    end

    it "wires every one of the six inputs to the controller's validate action (R5, R14)" do
      # Arrange
      signed_in_admin
      pages = {
        admin_home_page_content_path => %w[home_page_content[hero_image] home_page_content[cta_image]],
        admin_about_page_content_path => (1..3).map { |i| "about_page_content[slideshow_image_#{i}]" },
        admin_gallery_photos_path => %w[gallery_photo[image]]
      }

      # Act
      wired_inputs = pages.flat_map { |path, names|
        get path
        document = Nokogiri::HTML(response.body)
        names.map { |name|
          input = file_input(document, name)
          message = guard_wrapper(document, name).at_css("p[data-image-upload-guard-target='message']")
          {
            action: input["data-action"],
            target: input["data-image-upload-guard-target"],
            message_role: message["role"],
            message_classes: message["class"].split.sort,
            message_text: message.text
          }
        }
      }

      # Assert
      expect(wired_inputs.length).to eq(6)
      expect(wired_inputs).to all(
        eq(
          action: "change->image-upload-guard#validate",
          target: "input",
          message_role: "alert",
          message_classes: %w[hidden mt-1 text-red-600 text-sm],
          message_text: ""
        )
      )
    end
  end

  describe "the server's authority when both guards are defeated (AT20, R18, AC-20, E10)" do
    it "still rejects an oversized upload posted straight past the browser" do
      # Arrange
      signed_in_admin
      get admin_gallery_photos_path
      guarded_input = file_input(Nokogiri::HTML(response.body), "gallery_photo[image]")
      wrapper = guard_wrapper(Nokogiri::HTML(response.body), "gallery_photo[image]")
      over_cap_bytes = ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1
      posted_file = Rack::Test::UploadedFile.new(
        padded_jpeg_path(over_cap_bytes), "image/jpeg", original_filename: "holiday_clip.mp4"
      )

      # Act
      expect {
        post admin_gallery_photos_path, params: { gallery_photo: { image: posted_file } }
      }.not_to change(GalleryPhoto, :count)

      # Assert — this exact file is one both live guards would have stopped
      expect(guarded_input["accept"].split(",")).not_to include(".mp4")
      expect(over_cap_bytes).to be > wrapper["data-image-upload-guard-max-bytes-value"].to_i

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("activerecord.errors.messages.file_too_large"))
    end

    it "still rejects a disallowed content type posted straight past the browser" do
      # Arrange
      signed_in_admin
      disallowed_file = fixture_file_upload("gallery_photo.svg", "image/svg+xml")

      # Act
      expect {
        post admin_gallery_photos_path, params: { gallery_photo: { image: disallowed_file } }
      }.not_to change(GalleryPhoto, :count)

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("activerecord.errors.messages.invalid_content_type"))
    end
  end
end
