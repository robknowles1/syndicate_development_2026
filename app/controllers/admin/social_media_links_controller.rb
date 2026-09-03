module Admin
  class SocialMediaLinksController < BaseController
    before_action :set_social_media_link, only: [ :edit, :update, :destroy, :move_up, :move_down ]

    def index
      @social_media_links = SocialMediaLink.order(:position, :id)
    end

    def new
      @social_media_link = SocialMediaLink.new
    end

    def create
      @social_media_link = SocialMediaLink.new(social_media_link_params)
      @social_media_link.position = (SocialMediaLink.maximum(:position) || -1) + 1

      if @social_media_link.save
        flash[:notice] = I18n.t("admin.social_media_links.flash.created")
        redirect_to admin_social_media_links_path
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @social_media_link.update(social_media_link_params)
        flash[:notice] = I18n.t("admin.social_media_links.flash.updated")
        redirect_to admin_social_media_links_path
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @social_media_link.destroy
      flash[:notice] = I18n.t("admin.social_media_links.flash.destroyed")
      redirect_to admin_social_media_links_path
    end

    def move_up
      swap_position_with(
        SocialMediaLink.where("position < ?", @social_media_link.position).order(position: :desc).first
      )
      flash[:notice] = I18n.t("admin.social_media_links.flash.moved")
      redirect_to admin_social_media_links_path
    end

    def move_down
      swap_position_with(
        SocialMediaLink.where("position > ?", @social_media_link.position).order(position: :asc).first
      )
      flash[:notice] = I18n.t("admin.social_media_links.flash.moved")
      redirect_to admin_social_media_links_path
    end

    private

    def swap_position_with(neighbour)
      return unless neighbour

      original_position = @social_media_link.position
      ActiveRecord::Base.transaction do
        @social_media_link.update_column(:position, neighbour.position)
        neighbour.update_column(:position, original_position)
      end
    end

    def set_social_media_link
      @social_media_link = SocialMediaLink.find(params[:id])
    end

    def social_media_link_params
      params.require(:social_media_link).permit(:platform, :url, :active)
    end
  end
end
