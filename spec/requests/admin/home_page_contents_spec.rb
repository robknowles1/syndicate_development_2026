require "rails_helper"

RSpec.describe "Admin::HomePageContents", type: :request do
  def sign_in_admin(admin)
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
  end

  def valid_home_page_content_params(overrides = {})
    {
      hero_tagline: "Valid tagline",
      mission_heading: "HEADING",
      mission_subheading: "SUB",
      mission_body: "Body.",
      published: "false"
    }.merge(overrides)
  end

  describe "authentication guard" do
    it "redirects unauthenticated GET /admin/home_page_content to login" do
      # Act
      get admin_home_page_content_path

      # Assert
      expect(response).to redirect_to(admin_login_path)
    end

    it "redirects unauthenticated PATCH /admin/home_page_content to login" do
      # Act
      patch admin_home_page_content_path, params: { home_page_content: { hero_tagline: "x" } }

      # Assert
      expect(response).to redirect_to(admin_login_path)
    end

    it "redirects unauthenticated PATCH /admin/home_page_content/restore_defaults to login (AT20, AC-22)" do
      # Arrange
      create(:home_page_content)
      initial_count = HomePageContent.count

      # Act
      patch restore_defaults_admin_home_page_content_path

      # Assert
      expect(response).to redirect_to(admin_login_path)
      expect(HomePageContent.count).to eq(initial_count)
    end
  end

  describe "GET /admin/home_page_content (AT7, AT8, AT9, AC-7, AC-8, AC-9)" do
    it "returns HTTP 200 with all expected form field names (AT7, R12, AC-7)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)

      # Act
      get admin_home_page_content_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("home_page_content[hero_tagline]")
      expect(response.body).to include("home_page_content[mission_heading]")
      expect(response.body).to include("home_page_content[mission_subheading]")
      expect(response.body).to include("home_page_content[mission_body]")
      expect(response.body).to include("home_page_content[published]")
    end

    it "pre-fills form with existing hero_tagline value (AT8, AC-8)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content, hero_tagline: "Test Tagline")

      # Act
      get admin_home_page_content_path

      # Assert
      expect(response.body).to include("Test Tagline")
    end

    it "renders without error when no HomePageContent row exists (AC-9)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      # No HomePageContent row

      # Act / Assert — must not raise
      expect { get admin_home_page_content_path }.not_to raise_error
      expect(response).to have_http_status(:ok)
    end

    it "pre-fills the form with i18n originals when no HomePageContent row exists" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      # No HomePageContent row

      # Act
      get admin_home_page_content_path

      # Assert
      expect(response.body).to include(CGI.escapeHTML(I18n.t("pages.home.hero_tagline")))
      expect(response.body).to include(CGI.escapeHTML(I18n.t("pages.home.mission_heading")))
      expect(HomePageContent.count).to eq(0)
    end

    it "renders the hero_tagline_hint text permanently (R17)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)

      # Act
      get admin_home_page_content_path

      # Assert
      expect(response.body).to include(I18n.t("admin.home_page_content.hero_tagline_hint"))
    end

    it "renders the restore defaults button targeting restore_defaults path with turbo-confirm (AT21, R21, AC-23)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)

      # Act
      get admin_home_page_content_path

      # Assert — (a) path present, (b) turbo-confirm, (c) py-3
      expect(response.body).to include(restore_defaults_admin_home_page_content_path)
      expect(response.body).to include("data-turbo-confirm")
      expect(response.body).to include("py-3")
    end
  end

  describe "PATCH /admin/home_page_content — happy path (AT9, AT12, AT13, R13)" do
    it "creates the record and redirects with flash on first save (AT9, R13, AC-10, AC-13)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      valid_params = {
        home_page_content: {
          hero_tagline: "Precision. Power.",
          mission_heading: "DREAM IT.",
          mission_subheading: "CUSTOM BIKES.",
          mission_body: "We build.",
          published: "true"
        }
      }

      # Act
      patch admin_home_page_content_path, params: valid_params

      # Assert
      expect(response).to redirect_to(admin_home_page_content_path)
      expect(flash[:notice]).to eq(I18n.t("admin.home_page_content.update_notice"))
      expect(HomePageContent.first.hero_tagline).to eq("Precision. Power.")
      expect(HomePageContent.first.published?).to be true
    end

    it "accepts exactly 50-character hero_tagline (AT12, R6, E3)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      tagline_50 = "A" * 50
      valid_params = {
        home_page_content: {
          hero_tagline: tagline_50,
          mission_heading: "HEADING",
          mission_subheading: "SUBHEADING",
          mission_body: "Body text.",
          published: "false"
        }
      }

      # Act
      patch admin_home_page_content_path, params: valid_params

      # Assert
      expect(response).to have_http_status(:redirect)
      expect(HomePageContent.first.hero_tagline).to eq(tagline_50)
    end

    it "sets published: false when unchecked param is sent (AC-14)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content, published: true)
      params_with_false = {
        home_page_content: {
          hero_tagline: "Updated.",
          mission_heading: "HEADING",
          mission_subheading: "SUB",
          mission_body: "Body.",
          published: "false"
        }
      }

      # Act
      patch admin_home_page_content_path, params: params_with_false

      # Assert
      expect(HomePageContent.first.published?).to be false
    end
  end

  describe "PATCH /admin/home_page_content — validation failures (AT10, AT11, AT13, AT14, R14)" do
    it "returns HTTP 422 on blank hero_tagline (AT10, R6, AC-11)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content, hero_tagline: "Original tagline")
      blank_tagline_params = {
        home_page_content: {
          hero_tagline: "",
          mission_heading: "HEADING",
          mission_subheading: "SUB",
          mission_body: "Body.",
          published: "false"
        }
      }

      # Act
      patch admin_home_page_content_path, params: blank_tagline_params

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(HomePageContent.first.hero_tagline).to eq("Original tagline")
    end

    it "returns HTTP 422 on 51-character hero_tagline (AT11, R6, E4, AC-12)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      long_tagline_params = {
        home_page_content: {
          hero_tagline: "A" * 51,
          mission_heading: "HEADING",
          mission_subheading: "SUB",
          mission_body: "Body.",
          published: "false"
        }
      }

      # Act
      patch admin_home_page_content_path, params: long_tagline_params

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Hero tagline")
    end

    it "returns HTTP 422 on blank mission_heading (AT13, R7)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      blank_heading_params = {
        home_page_content: {
          hero_tagline: "Valid tagline",
          mission_heading: "",
          mission_subheading: "SUB",
          mission_body: "Body.",
          published: "false"
        }
      }

      # Act
      patch admin_home_page_content_path, params: blank_heading_params

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns HTTP 422 on blank mission_body (AT14, R8, E7)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      blank_body_params = {
        home_page_content: {
          hero_tagline: "Valid tagline",
          mission_heading: "HEADING",
          mission_subheading: "SUB",
          mission_body: "",
          published: "false"
        }
      }

      # Act
      patch admin_home_page_content_path, params: blank_body_params

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /admin dashboard includes home page content link (AT15, R16, AC-15)" do
    it "returns HTTP 200 and includes href for admin_home_page_content_path (AT15)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)

      # Act
      get admin_root_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_home_page_content_path)
    end
  end

  describe "PATCH /admin/home_page_content/restore_defaults (AT18, AT19, AT20, R19, R20)" do
    it "creates a new row from i18n when no row exists (AT18, E8, AC-20)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      # No HomePageContent row

      # Act
      patch restore_defaults_admin_home_page_content_path

      # Assert
      expect(response).to redirect_to(admin_home_page_content_path)
      expect(flash[:notice]).to eq(I18n.t("admin.home_page_content.flash.restored"))
      restored = HomePageContent.first
      expect(HomePageContent.count).to eq(1)
      expect(restored.hero_tagline).to eq(I18n.t("pages.home.hero_tagline"))
      expect(restored.mission_heading).to eq(I18n.t("pages.home.mission_heading"))
      expect(restored.mission_subheading).to eq(I18n.t("pages.home.mission_subheading"))
      expect(restored.mission_body).to eq(I18n.t("pages.home.mission_body"))
      expect(restored.published?).to be false
    end

    it "overwrites content but leaves published unchanged on existing published row (AT19, R20, AC-21)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content, hero_tagline: "My Custom Line", published: true)

      # Act
      patch restore_defaults_admin_home_page_content_path

      # Assert
      expect(response).to redirect_to(admin_home_page_content_path)
      expect(flash[:notice]).to eq(I18n.t("admin.home_page_content.flash.restored"))
      restored = HomePageContent.first
      expect(restored.hero_tagline).to eq(I18n.t("pages.home.hero_tagline"))
      expect(restored.hero_tagline).not_to eq("My Custom Line")
      expect(restored.published?).to be true  # unchanged
    end

    it "only ever has one HomePageContent row after restore (singleton contract, R10)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content)

      # Act
      patch restore_defaults_admin_home_page_content_path

      # Assert
      expect(HomePageContent.count).to eq(1)
    end
  end

  describe "GET /admin/home_page_content — hero and CTA image controls (AT19, R14, R16, AC-20)" do
    it "includes both file inputs and both removal checkboxes" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)

      # Act
      get admin_home_page_content_path

      # Assert
      expect(response.body).to include("home_page_content[hero_image]")
      expect(response.body).to include("home_page_content[cta_image]")
      expect(response.body).to include("home_page_content[remove_hero_image]")
      expect(response.body).to include("home_page_content[remove_cta_image]")
    end

    it "states the 30 MB limit in visible copy beside the file inputs (R10, AC-23)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)

      # Act
      get admin_home_page_content_path

      # Assert
      expect(response.body).to include(I18n.t("admin.home_page_content.image_hint"))
      expect(I18n.t("admin.home_page_content.image_hint")).to include("30 MB")
    end

    it "indicates the bundled default is in use when a slot is unattached (R14)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content)

      # Act
      get admin_home_page_content_path

      # Assert
      expect(response.body).to include(I18n.t("admin.home_page_content.using_default_image"))
    end

    it "shows a thumbnail of the current image instead of the default notice once attached (R14)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content, :with_hero_image, :with_cta_image)

      # Act
      get admin_home_page_content_path

      # Assert
      expect(response.body).to include("/rails/active_storage/representations/")
      expect(response.body).not_to include(I18n.t("admin.home_page_content.using_default_image"))
    end
  end

  describe "PATCH /admin/home_page_content — image uploads (AT10, AT11, AT12, AT13, AT20)" do
    it "attaches a valid hero_image and redirects with a flash (AT10, R1, R16, AC-11)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      file = fixture_file_upload("gallery_photo.jpg", "image/jpeg")

      # Act
      patch admin_home_page_content_path, params: { home_page_content: valid_home_page_content_params(hero_image: file) }

      # Assert
      expect(response).to redirect_to(admin_home_page_content_path)
      expect(flash[:notice]).to eq(I18n.t("admin.home_page_content.update_notice"))
      expect(HomePageContent.first.hero_image).to be_attached
    end

    it "rejects an image/svg+xml cta_image with HTTP 422 and no attachment (AT11, R2, AC-12, E5)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      file = fixture_file_upload("gallery_photo.svg", "image/svg+xml")

      # Act
      patch admin_home_page_content_path, params: { home_page_content: valid_home_page_content_params(cta_image: file) }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(HomePageContent.first&.cta_image&.attached?).to be_falsy
      expect(response.body).to include(I18n.t("activerecord.errors.messages.invalid_content_type"))
    end

    it "rejects a hero_image over 30 MB and says so in the response (AT12, R8, R9, AC-13, E6)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      file = padded_jpeg_upload(31.megabytes)

      # Act
      patch admin_home_page_content_path, params: { home_page_content: valid_home_page_content_params(hero_image: file) }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("activerecord.errors.messages.file_too_large"))
      expect(response.body).to include("30 MB")
    end

    it "accepts a 29 MB hero_image that the old 15 MB cap would have rejected (AT13, R8, AC-14)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      file = padded_jpeg_upload(29.megabytes)

      # Act
      patch admin_home_page_content_path, params: { home_page_content: valid_home_page_content_params(hero_image: file) }

      # Assert
      expect(response).to redirect_to(admin_home_page_content_path)
      expect(HomePageContent.first.hero_image).to be_attached
      expect(HomePageContent.first.hero_image.blob.byte_size).to eq(29.megabytes)
    end

    it "replaces rather than accumulates the blob when hero_image is already attached (AT20, R15, AC-21, E9)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      home_page_content = create(:home_page_content, :with_hero_image)
      new_file = fixture_file_upload("gallery_photo_large.jpg", "image/jpeg")

      # Act
      patch admin_home_page_content_path, params: { home_page_content: valid_home_page_content_params(hero_image: new_file) }

      # Assert
      attachment_count = ActiveStorage::Attachment.where(record: home_page_content, name: "hero_image").count
      expect(attachment_count).to eq(1)
      expect(home_page_content.reload.hero_image.blob.filename.to_s).to eq("gallery_photo_large.jpg")
    end
  end

  describe "PATCH /admin/home_page_content — removal checkboxes (AT15, AT16, R15)" do
    it "purges a slot when its removal box is checked with no new file (AT15, AC-16, E11)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content, :with_hero_image)

      # Act
      patch admin_home_page_content_path,
            params: { home_page_content: valid_home_page_content_params(remove_hero_image: "1") }

      # Assert
      expect(response).to redirect_to(admin_home_page_content_path)
      expect(HomePageContent.first.hero_image.attached?).to be false
    end

    it "leaves the other slot attached when only one removal box is checked (R6, R15)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content, :with_hero_image, :with_cta_image)

      # Act
      patch admin_home_page_content_path,
            params: { home_page_content: valid_home_page_content_params(remove_hero_image: "1") }

      # Assert
      expect(HomePageContent.first.hero_image.attached?).to be false
      expect(HomePageContent.first.cta_image.attached?).to be true
    end

    it "lets a simultaneous upload win over a checked removal box (AT16, R15, AC-17, E10)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content, :with_hero_image)
      replacement = fixture_file_upload("gallery_photo_large.jpg", "image/jpeg")

      # Act
      patch admin_home_page_content_path,
            params: { home_page_content: valid_home_page_content_params(hero_image: replacement, remove_hero_image: "1") }

      # Assert
      expect(HomePageContent.first.hero_image.attached?).to be true
      expect(HomePageContent.first.hero_image.blob.filename.to_s).to eq("gallery_photo_large.jpg")
    end

    it "keeps the saved image when the removal box is checked with no new file and the save fails (R15, AC-16, E5)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content, :with_hero_image)

      # Act
      patch admin_home_page_content_path,
            params: { home_page_content: valid_home_page_content_params(hero_tagline: "", remove_hero_image: "1") }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(HomePageContent.first.hero_image.attached?).to be true
      expect(HomePageContent.first.hero_image.blob.filename.to_s).to eq("gallery_photo.jpg")
    end

    it "keeps the saved image when a checked box and a new file arrive together but the save fails (R15, AC-17)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content, :with_hero_image)
      replacement = fixture_file_upload("gallery_photo_large.jpg", "image/jpeg")

      # Act
      patch admin_home_page_content_path,
            params: { home_page_content: valid_home_page_content_params(hero_tagline: "", hero_image: replacement, remove_hero_image: "1") }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(HomePageContent.first.hero_image.attached?).to be true
      expect(HomePageContent.first.hero_image.blob.filename.to_s).to eq("gallery_photo.jpg")
    end

    it "leaves an attached slot alone when its removal box is unchecked (R15)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content, :with_hero_image)

      # Act
      patch admin_home_page_content_path,
            params: { home_page_content: valid_home_page_content_params(remove_hero_image: "0") }

      # Assert
      expect(HomePageContent.first.hero_image.attached?).to be true
    end
  end

  describe "PATCH /admin/home_page_content — synchronous variant processing (AT25, R20, AC-26)" do
    it "processes the hero display and social share variants before responding" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      file = fixture_file_upload("gallery_photo_large.jpg", "image/jpeg")

      # Act
      patch admin_home_page_content_path, params: { home_page_content: valid_home_page_content_params(hero_image: file) }

      # Assert
      blob = HomePageContent.first.hero_image.blob
      expect(ActiveStorage::VariantRecord.where(blob_id: blob.id).count).to eq(2)
    end

    it "processes the CTA display variant before responding" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      file = fixture_file_upload("gallery_photo_large.jpg", "image/jpeg")

      # Act
      patch admin_home_page_content_path, params: { home_page_content: valid_home_page_content_params(cta_image: file) }

      # Assert
      blob = HomePageContent.first.cta_image.blob
      expect(ActiveStorage::VariantRecord.where(blob_id: blob.id).count).to eq(1)
    end
  end

  describe "PATCH /admin/home_page_content/restore_defaults — image purge (AT17, AT18, R17)" do
    it "purges both slots while leaving published untouched (AT17, AC-18, E7)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content, :with_hero_image, :with_cta_image, hero_tagline: "My Custom Line", published: true)

      # Act
      patch restore_defaults_admin_home_page_content_path

      # Assert
      restored = HomePageContent.first
      expect(response).to redirect_to(admin_home_page_content_path)
      expect(flash[:notice]).to eq(I18n.t("admin.home_page_content.flash.restored"))
      expect(restored.hero_image.attached?).to be false
      expect(restored.cta_image.attached?).to be false
      expect(restored.hero_tagline).to eq(I18n.t("pages.home.hero_tagline"))
      expect(restored.mission_heading).to eq(I18n.t("pages.home.mission_heading"))
      expect(restored.mission_subheading).to eq(I18n.t("pages.home.mission_subheading"))
      expect(restored.mission_body).to eq(I18n.t("pages.home.mission_body"))
      expect(restored.published?).to be true
    end

    it "completes normally when no slot is attached (AT18, AC-19, E8)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123")
      sign_in_admin(admin)
      create(:home_page_content)

      # Act / Assert
      expect { patch restore_defaults_admin_home_page_content_path }.not_to raise_error
      expect(response).to redirect_to(admin_home_page_content_path)
    end

    it "leaves an unauthenticated caller's attachments intact (AT21, AC-22)" do
      # Arrange
      create(:home_page_content, :with_hero_image, hero_tagline: "My Custom Line")

      # Act
      patch restore_defaults_admin_home_page_content_path

      # Assert
      expect(response).to redirect_to(admin_login_path)
      expect(HomePageContent.first.hero_image.attached?).to be true
      expect(HomePageContent.first.hero_tagline).to eq("My Custom Line")
    end
  end

  describe "seeds idempotency (AT16, AT17, R11)" do
    it "creates exactly one row with correct values on fresh database (AT16)" do
      # Arrange — no HomePageContent row

      # Act — simulate what seeds.rb does
      home_content = HomePageContent.first_or_initialize
      if home_content.new_record?
        home_content.assign_attributes(
          hero_tagline: "Performance, Passion, Precision.",
          mission_heading: "DREAM IT. BUILD IT. RIDE IT. LOVE IT.",
          mission_subheading: "SPECIALIZING IN CUSTOM PERFORMANCE MOTOCROSS AND SUPERCROSS MOTORCYCLES",
          mission_body: I18n.t("pages.home.mission_body"),
          published: false
        )
        home_content.save!
      end

      # Assert
      expect(HomePageContent.count).to eq(1)
      expect(HomePageContent.first.hero_tagline).to eq("Performance, Passion, Precision.")
      expect(HomePageContent.first.published?).to be false
    end

    it "running seeds twice produces no second row (AT17, R10, R11)" do
      # Arrange — simulate first seed run
      home_content = HomePageContent.first_or_initialize
      if home_content.new_record?
        home_content.assign_attributes(
          hero_tagline: "Performance, Passion, Precision.",
          mission_heading: "DREAM IT. BUILD IT. RIDE IT. LOVE IT.",
          mission_subheading: "SPECIALIZING IN CUSTOM PERFORMANCE MOTOCROSS AND SUPERCROSS MOTORCYCLES",
          mission_body: I18n.t("pages.home.mission_body"),
          published: false
        )
        home_content.save!
      end

      # Act — simulate second seed run
      home_content2 = HomePageContent.first_or_initialize
      if home_content2.new_record?
        home_content2.assign_attributes(
          hero_tagline: "Performance, Passion, Precision.",
          mission_heading: "DREAM IT. BUILD IT. RIDE IT. LOVE IT.",
          mission_subheading: "SPECIALIZING IN CUSTOM PERFORMANCE MOTOCROSS AND SUPERCROSS MOTORCYCLES",
          mission_body: I18n.t("pages.home.mission_body"),
          published: false
        )
        home_content2.save!
      end

      # Assert
      expect(HomePageContent.count).to eq(1)
    end
  end
end
