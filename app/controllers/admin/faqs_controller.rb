module Admin
  class FaqsController < BaseController
    before_action :set_faq, only: [ :edit, :update, :destroy, :move_up, :move_down ]

    def index
      @faqs = Faq.order(:position)
    end

    def new
      @faq = Faq.new
    end

    def create
      @faq = Faq.new(faq_params)
      @faq.position = (Faq.maximum(:position) || -1) + 1

      if @faq.save
        flash[:notice] = I18n.t("admin.faqs.flash.created")
        redirect_to admin_faqs_path
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @faq.update(faq_params)
        flash[:notice] = I18n.t("admin.faqs.flash.updated")
        redirect_to admin_faqs_path
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @faq.destroy
      flash[:notice] = I18n.t("admin.faqs.flash.destroyed")
      redirect_to admin_faqs_path
    end

    def move_up
      swap_position_with(Faq.where("position < ?", @faq.position).order(position: :desc).first)
      flash[:notice] = I18n.t("admin.faqs.flash.moved")
      redirect_to admin_faqs_path
    end

    def move_down
      swap_position_with(Faq.where("position > ?", @faq.position).order(position: :asc).first)
      flash[:notice] = I18n.t("admin.faqs.flash.moved")
      redirect_to admin_faqs_path
    end

    private

    def swap_position_with(neighbour)
      return unless neighbour

      original_position = @faq.position
      ActiveRecord::Base.transaction do
        @faq.update_column(:position, neighbour.position)
        neighbour.update_column(:position, original_position)
      end
    end

    def set_faq
      @faq = Faq.find(params[:id])
    end

    def faq_params
      params.require(:faq).permit(:question, :answer)
    end
  end
end
