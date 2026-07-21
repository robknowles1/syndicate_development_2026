module Admin
  class GalleryPhotosController < BaseController
    before_action :set_gallery_photo, only: [ :destroy ]

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
      @photos = GalleryPhoto.with_attached_image.order(:position)
      @gallery_photo = GalleryPhoto.new
    end

    def reorder
      photo_ids = params[:photo_ids]

      unless valid_reorder_ids?(photo_ids)
        head :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        photo_ids.each_with_index do |id, index|
          GalleryPhoto.where(id: id).update_all(position: index)
        end
      end

      head :ok
    end

    private

    def valid_reorder_ids?(photo_ids)
      return false unless photo_ids.is_a?(Array)
      return false if photo_ids.empty?
      return false if photo_ids.uniq.length != photo_ids.length

      photo_ids.map(&:to_i).to_set == GalleryPhoto.pluck(:id).to_set
    end

    def set_gallery_photo
      @gallery_photo = GalleryPhoto.find(params[:id])
    end

    def gallery_photo_params
      params.require(:gallery_photo).permit(:image)
    end
  end
end
