module Admin
  class GalleryPhotosController < BaseController
    before_action :set_gallery_photo, only: [ :destroy, :move_up, :move_down ]

    def create
      @gallery_photo = GalleryPhoto.new(gallery_photo_params)
      @gallery_photo.position = (GalleryPhoto.maximum(:position) || -1) + 1

      if @gallery_photo.save
        @gallery_photo.display_variant.processed
        flash[:notice] = I18n.t("admin.gallery_photos.flash.uploaded")
        redirect_to admin_gallery_photos_path
      else
        @photos = GalleryPhoto.with_attached_image.order(:position)
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      @gallery_photo.image.purge
      @gallery_photo.destroy
      flash[:notice] = I18n.t("admin.gallery_photos.flash.deleted")
      redirect_to admin_gallery_photos_path
    end

    def index
      @photos = GalleryPhoto.order(:position)
      @gallery_photo = GalleryPhoto.new
    end

    def move_down
      neighbour = GalleryPhoto.where("position > ?", @gallery_photo.position)
                              .order(position: :asc)
                              .first
      if neighbour
        original_position = @gallery_photo.position
        ActiveRecord::Base.transaction do
          @gallery_photo.update_column(:position, neighbour.position)
          neighbour.update_column(:position, original_position)
        end
      end
      flash[:notice] = I18n.t("admin.gallery_photos.flash.moved")
      redirect_to admin_gallery_photos_path
    end

    def move_up
      neighbour = GalleryPhoto.where("position < ?", @gallery_photo.position)
                              .order(position: :desc)
                              .first
      if neighbour
        original_position = @gallery_photo.position
        ActiveRecord::Base.transaction do
          @gallery_photo.update_column(:position, neighbour.position)
          neighbour.update_column(:position, original_position)
        end
      end
      flash[:notice] = I18n.t("admin.gallery_photos.flash.moved")
      redirect_to admin_gallery_photos_path
    end

    private

    def set_gallery_photo
      @gallery_photo = GalleryPhoto.find(params[:id])
    end

    def gallery_photo_params
      params.require(:gallery_photo).permit(:image)
    end
  end
end
