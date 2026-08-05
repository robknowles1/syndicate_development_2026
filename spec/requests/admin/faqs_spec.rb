require "rails_helper"

RSpec.describe "Admin::Faqs", type: :request do
  def sign_in_admin
    admin = create(:admin_user)
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
    admin
  end

  describe "GET /admin/faqs" do
    context "when unauthenticated" do
      it "redirects to the login page" do
        # Act
        get admin_faqs_path

        # Assert
        expect(response).to redirect_to(admin_login_path)
      end
    end

    context "without any faqs" do
      it "returns 200 and shows the empty state (AT7, AC-7)" do
        # Arrange
        sign_in_admin

        # Act
        get admin_faqs_path

        # Assert
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("admin.faqs.empty_state"))
        expect(response.body).to include(I18n.t("admin.faqs.add_first"))
      end
    end

    context "with faqs out of insertion order" do
      it "lists them in position order (R5)" do
        # Arrange
        sign_in_admin
        create(:faq, question: "Asked second", position: 1)
        create(:faq, question: "Asked first", position: 0)

        # Act
        get admin_faqs_path

        # Assert
        expect(response.body.index("Asked first")).to be < response.body.index("Asked second")
      end
    end
  end

  describe "GET /admin/faqs/new" do
    context "without any faqs" do
      it "gives the inputs full width and the save button a large tap target (AT48, AC-14)" do
        # Arrange
        sign_in_admin

        # Act
        get new_admin_faq_path
        form = Nokogiri::HTML(response.body)

        # Assert
        expect(form.at_css("#faq_question")[:class]).to include("w-full")
        expect(form.at_css("#faq_answer")[:class]).to include("w-full")
        expect(form.at_css("input[type=submit]")[:class]).to include("py-3")
      end
    end
  end

  describe "POST /admin/faqs" do
    context "without any existing faqs" do
      it "creates the first faq at position 0 (AT3, AC-3)" do
        # Arrange
        sign_in_admin

        # Act
        post admin_faqs_path, params: { faq: { question: "Do you tune ECUs?", answer: "Yes." } }

        # Assert
        expect(response).to redirect_to(admin_faqs_path)
        expect(flash[:notice]).to eq(I18n.t("admin.faqs.flash.created"))
        expect(Faq.sole.position).to eq(0)
      end
    end

    context "with a faq already at position 0" do
      it "creates the next faq at position 1 (AT4, AC-4)" do
        # Arrange
        sign_in_admin
        create(:faq, position: 0)

        # Act
        post admin_faqs_path, params: { faq: { question: "Second?", answer: "Yes." } }

        # Assert
        expect(Faq.find_by(question: "Second?").position).to eq(1)
      end
    end

    context "with a blank answer" do
      it "returns 422 and persists nothing (AT2, AC-2, E2)" do
        # Arrange
        sign_in_admin

        # Act
        post admin_faqs_path, params: { faq: { question: "Half a FAQ?", answer: "" } }

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(Faq.count).to eq(0)
      end
    end
  end

  describe "GET /admin/faqs/:id/edit" do
    context "with an existing faq" do
      it "pre-populates the question and answer" do
        # Arrange
        sign_in_admin
        faq = create(:faq, question: "Existing question?", answer: "Existing answer.")

        # Act
        get edit_admin_faq_path(faq)

        # Assert
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Existing question?", "Existing answer.")
      end
    end
  end

  describe "PATCH /admin/faqs/:id" do
    context "with a valid change" do
      it "updates the row and redirects with a notice" do
        # Arrange
        sign_in_admin
        faq = create(:faq, question: "Before?", answer: "Before.")

        # Act
        patch admin_faq_path(faq), params: { faq: { question: "After?", answer: "After." } }

        # Assert
        expect(response).to redirect_to(admin_faqs_path)
        expect(flash[:notice]).to eq(I18n.t("admin.faqs.flash.updated"))
        expect(faq.reload).to have_attributes(question: "After?", answer: "After.")
      end
    end

    context "with a blank question" do
      it "returns 422 and leaves the row unchanged" do
        # Arrange
        sign_in_admin
        faq = create(:faq, question: "Before?")

        # Act
        patch admin_faq_path(faq), params: { faq: { question: "", answer: "Still here." } }

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(faq.reload.question).to eq("Before?")
      end
    end
  end

  describe "DELETE /admin/faqs/:id" do
    context "with an existing faq" do
      it "removes the row and redirects with a notice (AT6, AC-6)" do
        # Arrange
        sign_in_admin
        faq = create(:faq)

        # Act
        delete admin_faq_path(faq)

        # Assert
        expect(response).to redirect_to(admin_faqs_path)
        expect(flash[:notice]).to eq(I18n.t("admin.faqs.flash.destroyed"))
        expect(Faq.find_by(id: faq.id)).to be_nil
      end
    end
  end

  describe "PATCH /admin/faqs/:id/move_up" do
    context "with a lower-positioned neighbour" do
      it "swaps the two positions (AT5, AC-5)" do
        # Arrange
        sign_in_admin
        first = create(:faq, position: 0)
        second = create(:faq, position: 1)

        # Act
        patch move_up_admin_faq_path(second)

        # Assert
        expect(response).to redirect_to(admin_faqs_path)
        expect(first.reload.position).to eq(1)
        expect(second.reload.position).to eq(0)
      end
    end

    context "with a gap between neighbouring positions" do
      it "swaps with the nearest lower neighbour rather than decrementing (R4)" do
        # Arrange
        sign_in_admin
        first = create(:faq, position: 0)
        second = create(:faq, position: 5)

        # Act
        patch move_up_admin_faq_path(second)

        # Assert
        expect(first.reload.position).to eq(5)
        expect(second.reload.position).to eq(0)
      end
    end

    context "without a lower-positioned neighbour" do
      it "is a no-op (AT5, AC-5, E3)" do
        # Arrange
        sign_in_admin
        lowest = create(:faq, position: 0)

        # Act
        patch move_up_admin_faq_path(lowest)

        # Assert
        expect(response).to redirect_to(admin_faqs_path)
        expect(lowest.reload.position).to eq(0)
      end
    end
  end

  describe "PATCH /admin/faqs/:id/move_down" do
    context "with a higher-positioned neighbour" do
      it "swaps the two positions (R4)" do
        # Arrange
        sign_in_admin
        first = create(:faq, position: 0)
        second = create(:faq, position: 1)

        # Act
        patch move_down_admin_faq_path(first)

        # Assert
        expect(first.reload.position).to eq(1)
        expect(second.reload.position).to eq(0)
      end
    end

    context "without a higher-positioned neighbour" do
      it "is a no-op (R4, E3)" do
        # Arrange
        sign_in_admin
        highest = create(:faq, position: 0)

        # Act
        patch move_down_admin_faq_path(highest)

        # Assert
        expect(highest.reload.position).to eq(0)
      end
    end
  end
end
