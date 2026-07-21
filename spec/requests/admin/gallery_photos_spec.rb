require "rails_helper"

RSpec.describe "Admin::GalleryPhotos", type: :request do
  def sign_in_admin(admin)
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
  end

  describe "GET /admin/gallery_photos" do
    context "when authenticated and 2 GalleryPhoto rows exist" do
      it "returns HTTP 200 with a draggable grid, a Delete control per tile, and no Move Up/Down controls (AT12, AC-13)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        create(:gallery_photo, position: 0)
        create(:gallery_photo, position: 1)

        # Act
        get admin_gallery_photos_path

        # Assert
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2")
        document = Nokogiri::HTML(response.body)
        expect(document.css("[data-gallery-photo-id]").count).to eq(2)
        expect(document.css("a[data-turbo-method='delete']").count).to eq(2)
        expect(document.css("a[href*='move_up']")).to be_empty
        expect(document.css("a[href*='move_down']")).to be_empty
      end
    end

    context "when authenticated and 2 GalleryPhoto rows exist" do
      it "carries data-controller=gallery-sort on the grid and data-gallery-photo-id on each tile (AT35, AC-36)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        photo_a = create(:gallery_photo, position: 0)
        photo_b = create(:gallery_photo, position: 1)

        # Act
        get admin_gallery_photos_path

        # Assert
        document = Nokogiri::HTML(response.body)
        expect(document.css("[data-controller='gallery-sort']")).not_to be_empty
        tile_ids = document.css("[data-gallery-photo-id]").map { |node| node["data-gallery-photo-id"] }
        expect(tile_ids).to contain_exactly(photo_a.id.to_s, photo_b.id.to_s)
      end
    end

    context "when authenticated" do
      it "includes a file input named gallery_photo[image] and a submit button (AT13, AC-14)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)

        # Act
        get admin_gallery_photos_path

        # Assert
        expect(response.body).to include('name="gallery_photo[image]"')
        expect(response.body).to include(I18n.t("admin.gallery_photos.save"))
      end
    end

    context "when authenticated and zero GalleryPhoto rows exist" do
      it "returns HTTP 200 with the empty-state message (AT14, AC-15)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)

        # Act
        get admin_gallery_photos_path

        # Assert
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("admin.gallery_photos.empty_state"))
      end
    end

    context "when not authenticated" do
      it "redirects to login (AT27, AC-28)" do
        # Arrange — no session

        # Act
        get admin_gallery_photos_path

        # Assert
        expect(response).to redirect_to(admin_login_path)
      end
    end
  end

  describe "POST /admin/gallery_photos" do
    context "when authenticated and zero prior GalleryPhoto rows exist, with a valid JPEG" do
      it "creates a GalleryPhoto at position 0 and redirects with a flash (AT15, AC-16)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        file = fixture_file_upload("gallery_photo.jpg", "image/jpeg")

        # Act
        expect {
          post admin_gallery_photos_path, params: { gallery_photo: { image: file } }
        }.to change(GalleryPhoto, :count).by(1)

        # Assert
        expect(response).to redirect_to(admin_gallery_photos_path)
        expect(flash[:notice]).to eq(I18n.t("admin.gallery_photos.flash.uploaded"))
        expect(GalleryPhoto.last.position).to eq(0)
      end
    end

    context "when authenticated and one GalleryPhoto exists at position 0, with a second valid image" do
      it "assigns the new row position 1 (AT16, AC-17)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        create(:gallery_photo, position: 0)
        file = fixture_file_upload("gallery_photo.jpg", "image/jpeg")

        # Act
        post admin_gallery_photos_path, params: { gallery_photo: { image: file } }

        # Assert
        expect(GalleryPhoto.order(:position).last.position).to eq(1)
      end
    end

    context "when authenticated, with an image/svg+xml file" do
      it "returns HTTP 422 with a content-type validation error and no new row (AT17, AC-18, E2)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        file = fixture_file_upload("gallery_photo.svg", "image/svg+xml")

        # Act
        expect {
          post admin_gallery_photos_path, params: { gallery_photo: { image: file } }
        }.not_to change(GalleryPhoto, :count)

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include(I18n.t("activerecord.errors.messages.invalid_content_type"))
      end
    end

    context "when authenticated, with a file exceeding 15 MB" do
      it "returns HTTP 422 with a file-size validation error and no new row (AT18, AC-19, E3)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        file = fixture_file_upload("gallery_photo_oversized.jpg", "image/jpeg")

        # Act
        expect {
          post admin_gallery_photos_path, params: { gallery_photo: { image: file } }
        }.not_to change(GalleryPhoto, :count)

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include(I18n.t("activerecord.errors.messages.file_too_large"))
      end
    end

    context "when authenticated, with no file selected" do
      it "returns HTTP 422 with a presence validation error and no new row (AT19, AC-20, E4)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)

        # Act
        expect {
          post admin_gallery_photos_path, params: { gallery_photo: { image: "" } }
        }.not_to change(GalleryPhoto, :count)

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("can&#39;t be blank").or include("can't be blank")
      end
    end

    context "when not authenticated" do
      it "redirects to login and creates no GalleryPhoto (AT27, AC-28)" do
        # Arrange
        file = fixture_file_upload("gallery_photo.jpg", "image/jpeg")

        # Act
        expect {
          post admin_gallery_photos_path, params: { gallery_photo: { image: file } }
        }.not_to change(GalleryPhoto, :count)

        # Assert
        expect(response).to redirect_to(admin_login_path)
      end
    end
  end

  describe "DELETE /admin/gallery_photos/:id" do
    context "when authenticated and a GalleryPhoto with an attached image exists" do
      it "destroys the row, purges the blob, and redirects with a flash (AT20, AC-21)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        photo = create(:gallery_photo, position: 0)
        blob_id = photo.image.blob.id

        # Act
        expect {
          delete admin_gallery_photo_path(photo)
        }.to change(GalleryPhoto, :count).by(-1)

        # Assert
        expect(response).to redirect_to(admin_gallery_photos_path)
        expect(flash[:notice]).to eq(I18n.t("admin.gallery_photos.flash.deleted"))
        expect(ActiveStorage::Blob.find_by(id: blob_id)).to be_nil
      end
    end

    context "when not authenticated" do
      it "redirects to login and destroys no GalleryPhoto (AT27, AC-28)" do
        # Arrange
        photo = create(:gallery_photo, position: 0)

        # Act
        expect {
          delete admin_gallery_photo_path(photo)
        }.not_to change(GalleryPhoto, :count)

        # Assert
        expect(response).to redirect_to(admin_login_path)
      end
    end
  end

  describe "PATCH /admin/gallery_photos/reorder" do
    def reorder(photo_ids)
      patch reorder_admin_gallery_photos_path,
        params: { photo_ids: photo_ids }.to_json,
        headers: { "Content-Type" => "application/json" }
    end

    context "when authenticated and 3 rows exist at positions 0, 1, 2" do
      it "reassigns every position to match the submitted order and returns an empty 200 (AT21, AC-22)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        photo_a = create(:gallery_photo, position: 0)
        photo_b = create(:gallery_photo, position: 1)
        photo_c = create(:gallery_photo, position: 2)

        # Act
        reorder([ photo_c.id, photo_a.id, photo_b.id ])

        # Assert
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_empty
        expect(photo_c.reload.position).to eq(0)
        expect(photo_a.reload.position).to eq(1)
        expect(photo_b.reload.position).to eq(2)
      end
    end

    context "when authenticated and the submitted order matches the current order" do
      it "succeeds and leaves every position unchanged" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        photo_a = create(:gallery_photo, position: 0)
        photo_b = create(:gallery_photo, position: 1)
        photo_c = create(:gallery_photo, position: 2)

        # Act
        reorder([ photo_a.id, photo_b.id, photo_c.id ])

        # Assert
        expect(response).to have_http_status(:ok)
        expect(photo_a.reload.position).to eq(0)
        expect(photo_b.reload.position).to eq(1)
        expect(photo_c.reload.position).to eq(2)
      end
    end

    context "when authenticated and photo_ids contains an id that does not belong to any existing GalleryPhoto" do
      it "returns HTTP 422 and changes no position (AT22, AC-23, E6)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        photo_a = create(:gallery_photo, position: 0)
        photo_b = create(:gallery_photo, position: 1)
        create(:gallery_photo, position: 2)
        foreign_id = GalleryPhoto.maximum(:id).to_i + 1000

        # Act
        reorder([ foreign_id, photo_a.id, photo_b.id ])

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(photo_a.reload.position).to eq(0)
        expect(photo_b.reload.position).to eq(1)
      end
    end

    context "when authenticated and photo_ids omits an existing GalleryPhoto" do
      it "returns HTTP 422 and changes no position (AT22, AC-23, E6)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        photo_a = create(:gallery_photo, position: 0)
        photo_b = create(:gallery_photo, position: 1)
        create(:gallery_photo, position: 2)

        # Act
        reorder([ photo_b.id, photo_a.id ])

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(photo_a.reload.position).to eq(0)
        expect(photo_b.reload.position).to eq(1)
      end
    end

    context "when authenticated and photo_ids contains a duplicate id" do
      it "returns HTTP 422 and changes no position (AT22, AC-23, E6)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        photo_a = create(:gallery_photo, position: 0)
        photo_b = create(:gallery_photo, position: 1)
        photo_c = create(:gallery_photo, position: 2)

        # Act
        reorder([ photo_a.id, photo_a.id, photo_b.id ])

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(photo_a.reload.position).to eq(0)
        expect(photo_b.reload.position).to eq(1)
        expect(photo_c.reload.position).to eq(2)
      end
    end

    context "when authenticated and photo_ids is an empty array" do
      it "returns HTTP 422 and changes no position (AT23, AC-24, E7)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        photo_a = create(:gallery_photo, position: 0)
        create(:gallery_photo, position: 1)
        create(:gallery_photo, position: 2)

        # Act
        reorder([])

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(photo_a.reload.position).to eq(0)
      end
    end

    context "when authenticated and photo_ids is absent entirely" do
      it "returns HTTP 422 and changes no position (AT23, AC-24, E7)" do
        # Arrange
        admin = create(:admin_user)
        sign_in_admin(admin)
        photo_a = create(:gallery_photo, position: 0)
        create(:gallery_photo, position: 1)

        # Act
        patch reorder_admin_gallery_photos_path,
          params: {}.to_json,
          headers: { "Content-Type" => "application/json" }

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(photo_a.reload.position).to eq(0)
      end
    end

    context "when not authenticated" do
      it "redirects to login and changes no position (AT27, AC-28)" do
        # Arrange
        photo_a = create(:gallery_photo, position: 0)
        photo_b = create(:gallery_photo, position: 1)

        # Act
        reorder([ photo_b.id, photo_a.id ])

        # Assert
        expect(response).to redirect_to(admin_login_path)
        expect(photo_a.reload.position).to eq(0)
        expect(photo_b.reload.position).to eq(1)
      end
    end
  end

  describe "GET /admin" do
    it "includes an href linking to admin_gallery_photos_path (AT24, AC-25)" do
      # Arrange
      admin = create(:admin_user)
      sign_in_admin(admin)

      # Act
      get admin_root_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(href="#{admin_gallery_photos_path}"))
    end
  end
end
