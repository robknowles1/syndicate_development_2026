module Admin
  class BusinessHoursController < BaseController
    def show
      @business_hours = BusinessHours.first_or_initialize
    end

    def update
      @business_hours = BusinessHours.first_or_initialize

      if @business_hours.update(business_hours_params)
        flash[:notice] = I18n.t("admin.business_hours.update_notice")
        redirect_to admin_business_hours_path
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def business_hours_params
      params.require(:business_hours).permit(
        *BusinessHours::DAYS.flat_map { |day| [ :"#{day}_opens_at", :"#{day}_closes_at" ] }
      )
    end
  end
end
