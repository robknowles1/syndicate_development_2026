module Admin
  class ServiceSectionsController < BaseController
    before_action :set_section, only: [ :edit, :update, :destroy, :move_up, :move_down ]

    def new
      @section = ServiceSection.new
      @section.service_bullets.build(position: 0)
    end

    def create
      @section = ServiceSection.new(section_params)
      @section.position = (ServiceSection.maximum(:position) || -1) + 1

      if @section.save
        flash[:notice] = I18n.t("admin.service_sections.flash.created")
        redirect_to admin_services_page_path
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @section.update(section_params)
        flash[:notice] = I18n.t("admin.service_sections.flash.updated")
        redirect_to admin_services_page_path
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @section.destroy
      flash[:notice] = I18n.t("admin.service_sections.flash.destroyed")
      redirect_to admin_services_page_path
    end

    def move_up
      neighbour = ServiceSection.where("position < ?", @section.position)
                                .order(position: :desc)
                                .first
      if neighbour
        original_position = @section.position
        ActiveRecord::Base.transaction do
          @section.update_column(:position, neighbour.position)
          neighbour.update_column(:position, original_position)
        end
      end
      flash[:notice] = I18n.t("admin.service_sections.flash.moved")
      redirect_to admin_services_page_path
    end

    def move_down
      neighbour = ServiceSection.where("position > ?", @section.position)
                                .order(position: :asc)
                                .first
      if neighbour
        original_position = @section.position
        ActiveRecord::Base.transaction do
          @section.update_column(:position, neighbour.position)
          neighbour.update_column(:position, original_position)
        end
      end
      flash[:notice] = I18n.t("admin.service_sections.flash.moved")
      redirect_to admin_services_page_path
    end

    private

    def set_section
      @section = ServiceSection.includes(:service_bullets).find(params[:id])
    end

    def section_params
      params.require(:service_section).permit(
        :heading,
        :icon_key,
        service_bullets_attributes: [ :id, :body, :position, :_destroy ]
      )
    end
  end
end
