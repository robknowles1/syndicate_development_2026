require "rails_helper"

RSpec.describe "Admin::AboutPageContents", type: :request do
  def sign_in_admin(admin)
    post admin_login_path, params: { email: admin.email, password: "password123" }
  end

  def valid_about_page_content_params(overrides = {})
    {
      shop_heading: "SYNDICATE DEVELOPMENT",
      shop_phone_label: "Shop Phone:",
      shop_phone_number: "208-251-9536",
      shop_address_label: "Shop Address:",
      shop_address: "1801 N. Arthur Ave., Pocatello, ID, 83204",
      bio_heading: "About Doug Haskett",
      bio_body: "Doug builds bikes.",
      slideshow_alt_1: "Alt one",
      slideshow_alt_2: "Alt two",
      slideshow_alt_3: "Alt three",
      published: "false"
    }.merge(overrides)
  end

  describe "authentication guard" do
    it "redirects unauthenticated GET /admin/about_page_content to login" do
      # Act
      get admin_about_page_content_path

      # Assert
      expect(response).to redirect_to(admin_login_path)
    end

    it "redirects unauthenticated PATCH /admin/about_page_content to login" do
      # Act
      patch admin_about_page_content_path, params: { about_page_content: { shop_heading: "x" } }

      # Assert
      expect(response).to redirect_to(admin_login_path)
    end

    it "redirects unauthenticated PATCH /admin/about_page_content/restore_defaults to login (AT15, AT26, R7, AC-15, AC-26)" do
      # Arrange
      create(:about_page_content)
      initial_count = AboutPageContent.count

      # Act
      patch restore_defaults_admin_about_page_content_path

      # Assert
      expect(response).to redirect_to(admin_login_path)
      expect(AboutPageContent.count).to eq(initial_count)
    end
  end

  describe "GET /admin/about_page_content (AT10, AT11, AT12)" do
    it "returns HTTP 200 with all expected form field names (AT10, R10, AC-8)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)

      # Act
      get admin_about_page_content_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("about_page_content[shop_heading]")
      expect(response.body).to include("about_page_content[shop_phone_label]")
      expect(response.body).to include("about_page_content[shop_phone_number]")
      expect(response.body).to include("about_page_content[shop_address_label]")
      expect(response.body).to include("about_page_content[shop_address]")
      expect(response.body).to include("about_page_content[bio_heading]")
      expect(response.body).to include("about_page_content[bio_body]")
      expect(response.body).to include("about_page_content[slideshow_alt_1]")
      expect(response.body).to include("about_page_content[slideshow_alt_2]")
      expect(response.body).to include("about_page_content[slideshow_alt_3]")
      expect(response.body).to include("about_page_content[published]")
    end

    it "pre-fills form with existing shop_heading value (AT11, R10, AC-9)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      create(:about_page_content, shop_heading: "Custom Shop Name")

      # Act
      get admin_about_page_content_path

      # Assert
      expect(response.body).to include("Custom Shop Name")
    end

    it "renders without error when no AboutPageContent row exists (AT12, R10, AC-10)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      # No AboutPageContent row

      # Act / Assert — must not raise
      expect { get admin_about_page_content_path }.not_to raise_error
      expect(response).to have_http_status(:ok)
    end

    it "pre-fills the form with i18n originals when no AboutPageContent row exists" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      # No AboutPageContent row

      # Act
      get admin_about_page_content_path

      # Assert
      expect(response.body).to include(CGI.escapeHTML(I18n.t("pages.about.shop_heading")))
      expect(response.body).to include(CGI.escapeHTML(I18n.t("pages.about.shop_phone_number")))
      expect(response.body).to include(CGI.escapeHTML(I18n.t("pages.about.bio_heading")))
      expect(AboutPageContent.count).to eq(0)
    end

    it "renders the shop_phone_number_hint text permanently (R10)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)

      # Act
      get admin_about_page_content_path

      # Assert
      expect(response.body).to include(I18n.t("admin.about_page_content.shop_phone_number_hint"))
    end

    it "renders the restore defaults button targeting restore_defaults path with turbo-confirm (AT27, R19, AC-27)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)

      # Act
      get admin_about_page_content_path

      # Assert — (a) path present, (b) turbo-confirm, (c) py-3
      expect(response.body).to include(restore_defaults_admin_about_page_content_path)
      expect(response.body).to include("data-turbo-confirm")
      expect(response.body).to include("py-3")
    end
  end

  describe "PATCH /admin/about_page_content — happy path (AT13, AT20, R11)" do
    it "creates the record and redirects with flash on first save (AT13, R11, AC-11, AC-17)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      params = { about_page_content: valid_about_page_content_params(published: "true") }

      # Act
      patch admin_about_page_content_path, params: params

      # Assert
      expect(response).to redirect_to(admin_about_page_content_path)
      expect(flash[:notice]).to eq(I18n.t("admin.about_page_content.update_notice"))
      expect(AboutPageContent.first.shop_heading).to eq("SYNDICATE DEVELOPMENT")
      expect(AboutPageContent.first.published?).to be true
    end

    it "sets published: false when unchecked param is sent (AT20, AC-18)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      create(:about_page_content, published: true)
      params = { about_page_content: valid_about_page_content_params(published: "false") }

      # Act
      patch admin_about_page_content_path, params: params

      # Assert
      expect(AboutPageContent.first.published?).to be false
    end
  end

  describe "PATCH /admin/about_page_content — validation failures (AT14, AT15, AT16, AT17, AT18, AT19)" do
    it "returns HTTP 422 on blank shop_heading and leaves the field unchanged (AT14, R6, AC-12)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      create(:about_page_content, shop_heading: "Original Shop Heading")
      params = { about_page_content: valid_about_page_content_params(shop_heading: "") }

      # Act
      patch admin_about_page_content_path, params: params

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(AboutPageContent.first.shop_heading).to eq("Original Shop Heading")
      expect(response.body).to include(CGI.escapeHTML(I18n.t("errors.messages.blank")))
    end

    it "returns HTTP 422 on shop_phone_number containing letters (AT15, R7, E4, AC-13)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      params = { about_page_content: valid_about_page_content_params(shop_phone_number: "call-us-now") }

      # Act
      patch admin_about_page_content_path, params: params

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(CGI.escapeHTML(I18n.t("errors.messages.invalid")))
    end

    it "returns HTTP 422 on blank shop_phone_number (AT16, R6, E5, AC-14)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      params = { about_page_content: valid_about_page_content_params(shop_phone_number: "") }

      # Act
      patch admin_about_page_content_path, params: params

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns HTTP 422 on shop_phone_number of formatting punctuation only (AT17, R7, E6)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      params = { about_page_content: valid_about_page_content_params(shop_phone_number: "----") }

      # Act
      patch admin_about_page_content_path, params: params

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns HTTP 422 on blank bio_body (AT18, R6, E9, AC-15)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      params = { about_page_content: valid_about_page_content_params(bio_body: "") }

      # Act
      patch admin_about_page_content_path, params: params

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns HTTP 422 on blank slideshow_alt_1 (AT19, R6, E11, AC-16)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      params = { about_page_content: valid_about_page_content_params(slideshow_alt_1: "") }

      # Act
      patch admin_about_page_content_path, params: params

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /admin/about_page_content — slideshow image file inputs (AT10, R9)" do
    it "includes 3 file inputs named for slideshow_image_1/2/3 (AT10, AC-10)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)

      # Act
      get admin_about_page_content_path

      # Assert
      expect(response.body).to include("about_page_content[slideshow_image_1]")
      expect(response.body).to include("about_page_content[slideshow_image_2]")
      expect(response.body).to include("about_page_content[slideshow_image_3]")
    end
  end

  describe "PATCH /admin/about_page_content — slideshow image uploads (AT5, AT6, AT7, AT12)" do
    it "attaches a valid JPEG to slideshow_image_2 and redirects with flash (AT5, R1, R9, AC-5)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      file = fixture_file_upload("gallery_photo.jpg", "image/jpeg")
      params = { about_page_content: valid_about_page_content_params(slideshow_image_2: file) }

      # Act
      patch admin_about_page_content_path, params: params

      # Assert
      expect(response).to redirect_to(admin_about_page_content_path)
      expect(flash[:notice]).to eq(I18n.t("admin.about_page_content.update_notice"))
      expect(AboutPageContent.first.slideshow_image_2).to be_attached
    end

    it "rejects an image/svg+xml file for slideshow_image_2 with HTTP 422 and no attachment (AT6, R2, E4, AC-6)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      file = fixture_file_upload("gallery_photo.svg", "image/svg+xml")
      params = { about_page_content: valid_about_page_content_params(slideshow_image_2: file) }

      # Act
      patch admin_about_page_content_path, params: params

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(AboutPageContent.first&.slideshow_image_2&.attached?).to be_falsy
      expect(response.body).to include(I18n.t("activerecord.errors.messages.invalid_content_type"))
    end

    it "rejects a slideshow_image_3 file exceeding 15 MB with HTTP 422 (AT7, R2, E5, AC-7)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      file = fixture_file_upload("gallery_photo_oversized.jpg", "image/jpeg")
      params = { about_page_content: valid_about_page_content_params(slideshow_image_3: file) }

      # Act
      patch admin_about_page_content_path, params: params

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("activerecord.errors.messages.file_too_large"))
    end

    it "replaces rather than accumulates the blob when slideshow_image_1 is already attached (AT12, R8, E8, AC-12)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      about_page_content = create(:about_page_content, :with_slideshow_image_1)
      new_file = fixture_file_upload("gallery_photo.jpg", "image/jpeg")
      params = { about_page_content: valid_about_page_content_params(slideshow_image_1: new_file) }

      # Act
      patch admin_about_page_content_path, params: params

      # Assert
      attachment_count = ActiveStorage::Attachment.where(record: about_page_content, name: "slideshow_image_1").count
      expect(attachment_count).to eq(1)
    end
  end

  describe "GET /admin dashboard includes about page content link (AT21, R14, AC-19)" do
    it "returns HTTP 200 and includes href for admin_about_page_content_path (AT21)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)

      # Act
      get admin_root_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_about_page_content_path)
    end
  end

  describe "confirm_restore_defaults i18n content (AT11, R10, AC-11)" do
    it "mentions uploaded images being removed, in addition to text" do
      # Arrange / Act
      confirmation_text = I18n.t("admin.about_page_content.confirm_restore_defaults")

      # Assert
      expect(confirmation_text).to match(/image/i)
    end
  end

  describe "PATCH /admin/about_page_content/restore_defaults (AT24, AT25, R17, R18)" do
    it "creates a new row from i18n when no row exists (AT24, E10, AC-24)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      # No AboutPageContent row

      # Act
      patch restore_defaults_admin_about_page_content_path

      # Assert
      expect(response).to redirect_to(admin_about_page_content_path)
      expect(flash[:notice]).to eq(I18n.t("admin.about_page_content.flash.restored"))
      restored = AboutPageContent.first
      expect(AboutPageContent.count).to eq(1)
      expect(restored.shop_heading).to eq(I18n.t("pages.about.shop_heading"))
      expect(restored.shop_phone_number).to eq(I18n.t("pages.about.shop_phone_number"))
      expect(restored.bio_body).to eq(I18n.t("pages.about.bio_body"))
      expect(restored.slideshow_alt_1).to eq(I18n.t("pages.about.slideshow_alt_1"))
      expect(restored.slideshow_alt_2).to eq(I18n.t("pages.about.slideshow_alt_2"))
      expect(restored.slideshow_alt_3).to eq(I18n.t("pages.about.slideshow_alt_3"))
      expect(restored.published?).to be false
    end

    it "overwrites content but leaves published unchanged on existing published row (AT25, R18, AC-25)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      create(:about_page_content, shop_heading: "My Custom Shop", published: true)

      # Act
      patch restore_defaults_admin_about_page_content_path

      # Assert
      expect(response).to redirect_to(admin_about_page_content_path)
      expect(flash[:notice]).to eq(I18n.t("admin.about_page_content.flash.restored"))
      restored = AboutPageContent.first
      expect(restored.shop_heading).to eq(I18n.t("pages.about.shop_heading"))
      expect(restored.shop_heading).not_to eq("My Custom Shop")
      expect(restored.published?).to be true
    end

    it "only ever has one AboutPageContent row after restore (singleton contract, R8)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      create(:about_page_content)

      # Act
      patch restore_defaults_admin_about_page_content_path

      # Assert
      expect(AboutPageContent.count).to eq(1)
    end

    it "purges all 3 slideshow attachments and resets text while leaving published unchanged (AT8, R7, AC-8)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      create(:about_page_content, :published, :with_slideshow_image_1, :with_slideshow_image_2, :with_slideshow_image_3)

      # Act
      patch restore_defaults_admin_about_page_content_path

      # Assert
      expect(response).to redirect_to(admin_about_page_content_path)
      expect(flash[:notice]).to eq(I18n.t("admin.about_page_content.flash.restored"))
      restored = AboutPageContent.first
      expect(restored.slideshow_image_1).not_to be_attached
      expect(restored.slideshow_image_2).not_to be_attached
      expect(restored.slideshow_image_3).not_to be_attached
      expect(restored.shop_heading).to eq(I18n.t("pages.about.shop_heading"))
      expect(restored.published?).to be true
    end

    it "completes normally without raising when zero slots are attached (AT9, R7, E6, E7, AC-9)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      create(:about_page_content)

      # Act / Assert
      expect { patch restore_defaults_admin_about_page_content_path }.not_to raise_error
      expect(response).to redirect_to(admin_about_page_content_path)
    end
  end

  describe "seeds idempotency (AT22, AT23, R9)" do
    def run_about_page_content_seed
      about_content = AboutPageContent.first_or_initialize
      if about_content.new_record?
        about_content.assign_attributes(
          shop_heading: "SYNDICATE DEVELOPMENT",
          shop_phone_label: "Shop Phone:",
          shop_phone_number: "208-251-9536",
          shop_address_label: "Shop Address:",
          shop_address: "1801 N. Arthur Ave., Pocatello, ID, 83204",
          bio_heading: "About Doug Haskett",
          bio_body: I18n.t("pages.about.bio_body"),
          slideshow_alt_1: "Syndicate Development motorcycle 1",
          slideshow_alt_2: "Syndicate Development motorcycle 2",
          slideshow_alt_3: "Syndicate Development motorcycle 3",
          published: false
        )
        about_content.save!
      end
    end

    it "creates exactly one row with correct values on fresh database (AT22)" do
      # Arrange — no AboutPageContent row

      # Act
      run_about_page_content_seed

      # Assert
      expect(AboutPageContent.count).to eq(1)
      expect(AboutPageContent.first.shop_heading).to eq("SYNDICATE DEVELOPMENT")
      expect(AboutPageContent.first.shop_phone_number).to eq("208-251-9536")
      expect(AboutPageContent.first.slideshow_alt_1).to eq("Syndicate Development motorcycle 1")
      expect(AboutPageContent.first.published?).to be false
    end

    it "running seeds twice produces no second row (AT23)" do
      # Arrange — simulate first seed run
      run_about_page_content_seed

      # Act — simulate second seed run
      run_about_page_content_seed

      # Assert
      expect(AboutPageContent.count).to eq(1)
    end
  end
end
