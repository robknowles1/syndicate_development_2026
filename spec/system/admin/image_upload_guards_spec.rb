require "rails_helper"

RSpec.describe "Admin image upload guards", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  def sign_in_admin(admin)
    visit admin_login_path
    fill_in I18n.t("admin.login.email_label"), with: admin.email
    fill_in I18n.t("admin.login.password_label"), with: "securepassword123"
    click_button I18n.t("admin.login.submit")
    expect(page).to have_current_path(admin_root_path)
  end

  def signed_in_admin
    admin = create(:admin_user, password: "securepassword123", password_confirmation: "securepassword123")
    sign_in_admin(admin)
    admin
  end

  def oversized_alert(namespace)
    I18n.t("admin.#{namespace}.oversized_image_alert",
      max_mb: ImageAttachmentValidatable::MAX_IMAGE_SIZE / 1.megabyte)
  end

  def invalid_type_alert(namespace)
    I18n.t("admin.#{namespace}.invalid_image_type_alert")
  end

  # One round trip reporting what the form would actually submit alongside what the admin
  # can read, so a passing example cannot mean "the message rendered but the file is still
  # attached" or the reverse.
  def guard_state(field_name)
    page.evaluate_script(<<~JS).symbolize_keys
      (() => {
        const input = document.querySelector("input[type=file][name='#{field_name}']");
        const message = input.closest("[data-controller~='image-upload-guard']")
          .querySelector("[data-image-upload-guard-target='message']");
        return {
          attachedFileCount: input.files.length,
          messageText: message.textContent,
          messageVisible: !message.classList.contains("hidden")
        };
      })()
    JS
  end

  describe "an oversized file (AT6, AT7, AT8, AT10, R8, R9, AC-5, AC-6, AC-7, AC-9, E2)" do
    it "clears the Gallery photo field and names the cap" do
      # Arrange
      signed_in_admin
      visit admin_gallery_photos_path

      # Act
      attach_file I18n.t("admin.gallery_photos.image_label"),
        padded_jpeg_path(ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1)

      # Assert
      expect(page).to have_text(oversized_alert("gallery_photos"))
      expect(page).to have_text("30 MB")
      expect(guard_state("gallery_photo[image]")).to include(attachedFileCount: 0, messageVisible: true)
    end

    it "clears an About slideshow field and names the cap" do
      # Arrange
      signed_in_admin
      visit admin_about_page_content_path

      # Act
      attach_file I18n.t("admin.about_page_content.slideshow_image_1_label"),
        padded_jpeg_path(ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1)

      # Assert
      expect(page).to have_text(oversized_alert("about_page_content"))
      expect(guard_state("about_page_content[slideshow_image_1]"))
        .to include(attachedFileCount: 0, messageVisible: true)
    end

    it "clears the Home hero field and names the cap" do
      # Arrange
      signed_in_admin
      visit admin_home_page_content_path

      # Act
      attach_file I18n.t("admin.home_page_content.hero_image_label"),
        padded_jpeg_path(ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1)

      # Assert
      expect(page).to have_text(oversized_alert("home_page_content"))
      expect(guard_state("home_page_content[hero_image]"))
        .to include(attachedFileCount: 0, messageVisible: true)
    end

    it "clears the Home CTA field and names the cap" do
      # Arrange
      signed_in_admin
      visit admin_home_page_content_path

      # Act
      attach_file I18n.t("admin.home_page_content.cta_image_label"),
        padded_jpeg_path(ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1)

      # Assert
      expect(page).to have_text(oversized_alert("home_page_content"))
      expect(guard_state("home_page_content[cta_image]"))
        .to include(attachedFileCount: 0, messageVisible: true)
    end
  end

  describe "the size boundary (AT9, R8, AC-8, E1)" do
    it "keeps a file sitting exactly on the cap, silently" do
      # Arrange
      signed_in_admin
      visit admin_gallery_photos_path

      # Act
      attach_file I18n.t("admin.gallery_photos.image_label"),
        padded_jpeg_path(ImageAttachmentValidatable::MAX_IMAGE_SIZE)

      # Assert
      expect(guard_state("gallery_photo[image]"))
        .to include(attachedFileCount: 1, messageVisible: false, messageText: "")
      expect(page).to have_no_text(oversized_alert("gallery_photos"))
    end

    it "rejects the same file one byte heavier" do
      # Arrange
      signed_in_admin
      visit admin_gallery_photos_path

      # Act
      attach_file I18n.t("admin.gallery_photos.image_label"),
        padded_jpeg_path(ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1)

      # Assert
      expect(page).to have_text(oversized_alert("gallery_photos"))
      expect(guard_state("gallery_photo[image]")).to include(attachedFileCount: 0)
    end
  end

  describe "a disallowed file type (AT11, AT13, R7, R9, AC-10, AC-12, E4)" do
    it "names the wrong kind rather than the size when a video is picked" do
      # Arrange
      signed_in_admin
      visit admin_gallery_photos_path

      # Act
      attach_file I18n.t("admin.gallery_photos.image_label"), browser_upload_path("holiday_clip.mp4")

      # Assert
      expect(page).to have_text(invalid_type_alert("gallery_photos"))
      expect(page).to have_no_text(oversized_alert("gallery_photos"))
      expect(guard_state("gallery_photo[image]")).to include(attachedFileCount: 0, messageVisible: true)
    end

    it "still names the wrong kind when the video is also over the cap" do
      # Arrange
      signed_in_admin
      visit admin_gallery_photos_path
      oversized_video = browser_upload_path(
        "long_holiday_clip.mp4", byte_size: ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1
      )

      # Act
      attach_file I18n.t("admin.gallery_photos.image_label"), oversized_video

      # Assert
      expect(page).to have_text(invalid_type_alert("gallery_photos"))
      expect(page).to have_no_text(oversized_alert("gallery_photos"))
    end
  end

  describe "a file the browser cannot type (AT12, R12, AC-11, E5)" do
    it "lets an under-cap file through untouched rather than guessing" do
      # Arrange
      signed_in_admin
      visit admin_gallery_photos_path

      # Act
      attach_file I18n.t("admin.gallery_photos.image_label"), browser_upload_path("scan_without_extension")

      # Assert
      expect(guard_state("gallery_photo[image]"))
        .to include(attachedFileCount: 1, messageVisible: false)
      expect(page).to have_no_text(invalid_type_alert("gallery_photos"))
    end

    it "still measures that file against the cap" do
      # Arrange
      signed_in_admin
      visit admin_gallery_photos_path
      untyped_and_oversized = browser_upload_path(
        "large_scan_without_extension", byte_size: ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1
      )

      # Act
      attach_file I18n.t("admin.gallery_photos.image_label"), untyped_and_oversized

      # Assert
      expect(page).to have_text(oversized_alert("gallery_photos"))
      expect(page).to have_no_text(invalid_type_alert("gallery_photos"))
      expect(guard_state("gallery_photo[image]")).to include(attachedFileCount: 0)
    end
  end

  describe "unsaved work elsewhere on the form (AT14, R13, AC-13, E8)" do
    it "leaves every other About field exactly as the admin typed it" do
      # Arrange
      signed_in_admin
      visit admin_about_page_content_path
      fill_in I18n.t("admin.about_page_content.bio_heading_label"), with: "Doug, mid-sentence"
      fill_in I18n.t("admin.about_page_content.bio_body_label"), with: "Half a paragraph he has not saved."
      fill_in I18n.t("admin.about_page_content.slideshow_alt_2_label"), with: "A caption in progress"

      # Act
      attach_file I18n.t("admin.about_page_content.slideshow_image_1_label"),
        padded_jpeg_path(ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1)

      # Assert
      expect(page).to have_text(oversized_alert("about_page_content"))
      expect(find_field(I18n.t("admin.about_page_content.bio_heading_label")).value)
        .to eq("Doug, mid-sentence")
      expect(find_field(I18n.t("admin.about_page_content.bio_body_label")).value)
        .to eq("Half a paragraph he has not saved.")
      expect(find_field(I18n.t("admin.about_page_content.slideshow_alt_2_label")).value)
        .to eq("A caption in progress")
      expect(page).to have_current_path(admin_about_page_content_path)
    end

    it "leaves a second file input's valid selection attached" do
      # Arrange
      signed_in_admin
      visit admin_home_page_content_path
      attach_file I18n.t("admin.home_page_content.cta_image_label"),
        Rails.root.join("spec/fixtures/files/gallery_photo.jpg").to_s

      # Act
      attach_file I18n.t("admin.home_page_content.hero_image_label"),
        padded_jpeg_path(ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1)

      # Assert
      expect(page).to have_text(oversized_alert("home_page_content"))
      expect(guard_state("home_page_content[hero_image]")).to include(attachedFileCount: 0)
      expect(guard_state("home_page_content[cta_image]")).to include(attachedFileCount: 1)
    end
  end

  describe "recovering from a rejection (AT15, R10, AC-14, E6)" do
    it "hides the message and keeps the replacement once a valid file is picked" do
      # Arrange
      signed_in_admin
      visit admin_gallery_photos_path
      attach_file I18n.t("admin.gallery_photos.image_label"),
        padded_jpeg_path(ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1)
      expect(page).to have_text(oversized_alert("gallery_photos"))

      # Act
      attach_file I18n.t("admin.gallery_photos.image_label"),
        Rails.root.join("spec/fixtures/files/gallery_photo.jpg").to_s

      # Assert
      expect(page).to have_no_text(oversized_alert("gallery_photos"))
      expect(guard_state("gallery_photo[image]"))
        .to include(attachedFileCount: 1, messageVisible: false, messageText: "")
    end
  end

  describe "submitting after a rejection (AT16, AT17, R11, AC-15, AC-16, E7)" do
    it "saves the About form and leaves the existing slideshow image in place" do
      # Arrange
      signed_in_admin
      content = create(:about_page_content, :with_slideshow_image_2)
      existing_blob_id = content.slideshow_image_2.blob.id
      visit admin_about_page_content_path
      attach_file I18n.t("admin.about_page_content.slideshow_image_2_label"),
        padded_jpeg_path(ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1)
      expect(page).to have_text(oversized_alert("about_page_content"))

      # Act
      fill_in I18n.t("admin.about_page_content.bio_heading_label"), with: "Saved anyway"
      click_button I18n.t("admin.about_page_content.save")

      # Assert
      expect(page).to have_text(I18n.t("admin.about_page_content.update_notice"))
      expect(content.reload.bio_heading).to eq("Saved anyway")
      expect(content.slideshow_image_2.blob.id).to eq(existing_blob_id)
    end

    it "creates no photo and shows the Gallery admin the presence error" do
      # Arrange
      signed_in_admin
      blank_image_error = GalleryPhoto.new.tap(&:validate).errors.full_messages_for(:image).first
      visit admin_gallery_photos_path
      attach_file I18n.t("admin.gallery_photos.image_label"),
        padded_jpeg_path(ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1)
      expect(page).to have_text(oversized_alert("gallery_photos"))

      # Act
      click_button I18n.t("admin.gallery_photos.save")

      # Assert
      expect(page).to have_css("form li", text: blank_image_error)
      expect(page).to have_no_text(I18n.t("admin.gallery_photos.flash.uploaded"))
      expect(page).to have_text(I18n.t("admin.gallery_photos.empty_state"))
      expect(guard_state("gallery_photo[image]")).to include(attachedFileCount: 0)
      expect(GalleryPhoto.count).to eq(0)
    end
  end

  describe "the message at phone width (AT21, R14, AC-21)" do
    it "adds no horizontal scroll to any of the three forms, hidden or visible" do
      # Arrange
      signed_in_admin
      emulate_viewport(width: 375, height: 812)
      forms = {
        admin_gallery_photos_path => [ I18n.t("admin.gallery_photos.image_label"), "gallery_photos" ],
        admin_about_page_content_path => [ I18n.t("admin.about_page_content.slideshow_image_1_label"), "about_page_content" ],
        admin_home_page_content_path => [ I18n.t("admin.home_page_content.hero_image_label"), "home_page_content" ]
      }

      # Act
      overflow_readings = forms.map { |path, (field_label, namespace)|
        visit path
        before_overflow = horizontal_overflow?
        attach_file field_label, padded_jpeg_path(ImageAttachmentValidatable::MAX_IMAGE_SIZE + 1)
        expect(page).to have_text(oversized_alert(namespace))
        [ before_overflow, horizontal_overflow? ]
      }

      # Assert
      expect(actual_viewport_width).to eq(375)
      expect(overflow_readings.flatten).to all(be(false))
    end
  end
end
