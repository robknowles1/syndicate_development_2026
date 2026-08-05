require "rails_helper"

RSpec.describe "Admin::BusinessHours", type: :request do
  def sign_in_admin
    admin = create(:admin_user)
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
    admin
  end

  describe "GET /admin/business_hours" do
    context "when unauthenticated" do
      it "redirects to the login page (R20)" do
        # Act
        get admin_business_hours_path

        # Assert
        expect(response).to redirect_to(admin_login_path)
      end
    end

    context "without a persisted row" do
      it "renders a blank opens/closes pair for all seven days (AT49, R18)" do
        # Arrange
        sign_in_admin

        # Act
        get admin_business_hours_path
        form = Nokogiri::HTML(response.body)

        # Assert
        expect(response).to have_http_status(:ok)
        BusinessHours::DAYS.each do |day|
          expect(form.at_css("#business_hours_#{day}_opens_at")[:value]).to be_nil
          expect(form.at_css("#business_hours_#{day}_closes_at")[:value]).to be_nil
          expect(form.text).to include(I18n.t("admin.business_hours.day_#{day}"))
        end
      end

      it "gives the time inputs full width and the save button a large tap target (AT49, AC-58)" do
        # Arrange
        sign_in_admin

        # Act
        get admin_business_hours_path
        form = Nokogiri::HTML(response.body)

        # Assert
        expect(form.at_css("#business_hours_monday_opens_at")[:class]).to include("w-full")
        expect(form.at_css("#business_hours_sunday_closes_at")[:class]).to include("w-full")
        expect(form.at_css("input[type=submit]")[:class]).to include("py-3")
      end
    end

    context "with hours already saved" do
      it "pre-populates the saved times" do
        # Arrange
        sign_in_admin
        BusinessHours.create!(friday_opens_at: "09:00", friday_closes_at: "17:00")

        # Act
        get admin_business_hours_path
        form = Nokogiri::HTML(response.body)

        # Assert
        expect(form.at_css("#business_hours_friday_opens_at")[:value]).to eq("09:00")
        expect(form.at_css("#business_hours_friday_closes_at")[:value]).to eq("17:00")
      end
    end
  end

  describe "PATCH /admin/business_hours" do
    context "with a complete, forward-running day" do
      it "persists the hours and redirects with a notice (AT18, AC-20)" do
        # Arrange
        sign_in_admin

        # Act
        patch admin_business_hours_path,
          params: { business_hours: { friday_opens_at: "09:00", friday_closes_at: "17:00" } }

        # Assert
        expect(response).to redirect_to(admin_business_hours_path)
        expect(flash[:notice]).to eq(I18n.t("admin.business_hours.update_notice"))
        expect(BusinessHours.sole.friday_opens_at.strftime("%H:%M")).to eq("09:00")
        expect(BusinessHours.sole.friday_closes_at.strftime("%H:%M")).to eq("17:00")
      end
    end

    context "with a half-filled day" do
      it "returns 422, re-renders the form with the error, and persists nothing (AT19, AC-21, E5)" do
        # Arrange
        sign_in_admin

        # Act
        patch admin_business_hours_path,
          params: { business_hours: { saturday_opens_at: "09:00", saturday_closes_at: "" } }

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include(I18n.t("admin.business_hours.save"))
        expect(response.body).to include(
          I18n.t("activerecord.errors.models.business_hours.missing_closing_time")
        )
        expect(BusinessHours.count).to eq(0)
      end
    end

    context "with a day that closes before it opens" do
      it "returns 422 and leaves the saved hours untouched (AC-21, E9)" do
        # Arrange
        sign_in_admin
        BusinessHours.create!(monday_opens_at: "08:00", monday_closes_at: "17:00")

        # Act
        patch admin_business_hours_path,
          params: { business_hours: { monday_opens_at: "18:00", monday_closes_at: "09:00" } }

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(BusinessHours.sole.monday_opens_at.strftime("%H:%M")).to eq("08:00")
      end
    end

    context "with every day cleared" do
      it "accepts the blank week and keeps a single row (AC-18)" do
        # Arrange
        sign_in_admin
        BusinessHours.create!(monday_opens_at: "08:00", monday_closes_at: "17:00")

        # Act
        patch admin_business_hours_path,
          params: { business_hours: { monday_opens_at: "", monday_closes_at: "" } }

        # Assert
        expect(response).to redirect_to(admin_business_hours_path)
        expect(BusinessHours.sole.monday_opens_at).to be_nil
        expect(BusinessHours.count).to eq(1)
      end
    end
  end
end
