require "rails_helper"

RSpec.describe "Admin::PasswordResets", type: :request do
  include ActiveJob::TestHelper

  before { ActionMailer::Base.deliveries.clear }

  # The emailed link only stashes the token and redirects; the form lives at a tokenless
  # URL, so every spec that reaches the form has to follow that redirect.
  def claim_reset(token)
    get admin_claim_password_reset_path(token: token)
    follow_redirect!
  end

  describe "POST /admin/password_reset" do
    it "emails a reset link to a known address" do
      # Arrange
      admin = create(:admin_user, email: "known@example.com")

      # Act
      perform_enqueued_jobs { post admin_password_reset_path, params: { email: admin.email } }

      # Assert
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq([ admin.email ])
    end

    it "gives an identical response for an unknown address, without sending mail" do
      # Arrange
      create(:admin_user, email: "known@example.com")

      # Act
      perform_enqueued_jobs { post admin_password_reset_path, params: { email: "stranger@example.com" } }

      # Assert — the response must not reveal whether the account exists
      expect(response).to redirect_to(admin_login_path)
      expect(flash[:notice]).to eq(I18n.t("admin.password_reset.sent"))
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "finds the account regardless of the case typed" do
      # Arrange
      admin = create(:admin_user, email: "known@example.com")

      # Act
      perform_enqueued_jobs { post admin_password_reset_path, params: { email: "KNOWN@Example.COM" } }

      # Assert
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq([ admin.email ])
    end

    it "does not send to an admin with an unaccepted invitation" do
      # Arrange
      admin = create(:admin_user, :pending_invitation, email: "pending@example.com")

      # Act
      perform_enqueued_jobs { post admin_password_reset_path, params: { email: admin.email } }

      # Assert
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "answers a delivery failure exactly as it answers an unknown address" do
      # Arrange — a 500 here would mark the address as one that has an account
      create(:admin_user, email: "known@example.com")
      mailer = double(:mail)
      allow(mailer).to receive(:deliver_later).and_raise(Net::SMTPServerBusy, "mailbox unavailable")
      allow(AdminMailer).to receive(:password_reset).and_return(mailer)

      # Act
      post admin_password_reset_path, params: { email: "known@example.com" }

      # Assert
      expect(response).to redirect_to(admin_login_path)
      expect(flash[:notice]).to eq(I18n.t("admin.password_reset.sent"))
    end

    it "does not spend the delivery on the request that asks for it" do
      # Arrange — delivering inline costs an SMTP round trip for addresses that have an
      # account and nothing for those that do not, which times the two apart
      create(:admin_user, email: "known@example.com")

      # Act
      post admin_password_reset_path, params: { email: "known@example.com" }

      # Assert
      expect(ActionMailer::Base.deliveries).to be_empty
      expect(enqueued_jobs.size).to eq(1)
    end
  end

  describe "GET /admin/password_reset/:token/edit" do
    it "keeps the token out of the URL that renders the form" do
      # Arrange — a token in the path is logged on every request and leaks via Referer
      admin = create(:admin_user)
      token = admin.generate_token_for(:password_reset)

      # Act
      get admin_claim_password_reset_path(token: token)

      # Assert
      expect(response).to redirect_to(admin_edit_password_reset_path)
      expect(admin_edit_password_reset_path).not_to include(token)

      follow_redirect!
      expect(response.body).not_to include(token)
    end

    it "keeps the token out of the path written to the log" do
      # Arrange — filter_parameters redacts the query string but never a path segment, and
      # this one request carries a credential good for full admin takeover
      admin = create(:admin_user)
      token = admin.generate_token_for(:password_reset)

      # Act
      get admin_claim_password_reset_path(token: token)

      # Assert
      expect(request.filtered_path).not_to include(token)
    end

    it "discards a signed-in session rather than stashing the token into it" do
      # Arrange — this is a GET, so an admin can be walked onto it from a link; carrying
      # the claim into their session hands them the other account on submit
      victim = create(:admin_user, email: "victim@example.com")
      attacker = create(:admin_user, email: "attacker@example.com")
      post admin_login_path, params: { email: victim.email, password: "securepassword123" }

      # Act
      get admin_claim_password_reset_path(token: attacker.generate_token_for(:password_reset))

      # Assert
      expect(session[:admin_user_id]).to be_nil
    end

    it "refuses to render the form without a claimed token" do
      # Act
      get admin_edit_password_reset_path

      # Assert
      expect(response).to redirect_to(new_admin_password_reset_path)
    end

    it "does not put an unresolvable token into the visitor's session" do
      # Arrange — this is an unauthenticated GET any visitor can be sent to, and the session
      # rides in a cookie: stashing the path segment unread lets a stranger choose several
      # kilobytes of it, which overflows the 4KB cookie and 500s the request
      oversized_token = "a" * 5_000

      # Act
      get admin_claim_password_reset_path(token: oversized_token)

      # Assert
      expect(response).to redirect_to(new_admin_password_reset_path)
      expect(session[:password_reset_token]).to be_nil
    end
  end

  describe "PATCH /admin/password_reset" do
    it "updates the password and signs the admin in" do
      # Arrange
      admin = create(:admin_user)
      claim_reset(admin.generate_token_for(:password_reset))

      # Act
      patch admin_password_reset_update_path, params: {
        admin_user: { password: "a-brand-new-password", password_confirmation: "a-brand-new-password" }
      }

      # Assert
      expect(response).to redirect_to(admin_root_path)
      expect(admin.reload.authenticate("a-brand-new-password")).to be_truthy

      get admin_root_path
      expect(response).to have_http_status(:ok)
    end

    it "refuses a token that has already been used" do
      # Arrange — the first reset rotates the salt the token derives from
      admin = create(:admin_user)
      token = admin.generate_token_for(:password_reset)
      claim_reset(token)
      patch admin_password_reset_update_path, params: {
        admin_user: { password: "a-brand-new-password", password_confirmation: "a-brand-new-password" }
      }

      # Act
      claim_reset(token)
      patch admin_password_reset_update_path, params: {
        admin_user: { password: "yet-another-password", password_confirmation: "yet-another-password" }
      }

      # Assert
      expect(response).to redirect_to(new_admin_password_reset_path)
      expect(admin.reload.authenticate("yet-another-password")).to be_falsey
    end

    it "refuses a token older than its 2 hour lifetime" do
      # Arrange
      admin = create(:admin_user)
      token = admin.generate_token_for(:password_reset)

      # Act
      travel 3.hours do
        claim_reset(token)
        patch admin_password_reset_update_path, params: {
          admin_user: { password: "a-brand-new-password", password_confirmation: "a-brand-new-password" }
        }
      end

      # Assert
      expect(response).to redirect_to(new_admin_password_reset_path)
      expect(admin.reload.authenticate("a-brand-new-password")).to be_falsey
    end

    it "re-renders when the password is too short" do
      # Arrange
      admin = create(:admin_user)
      claim_reset(admin.generate_token_for(:password_reset))

      # Act
      patch admin_password_reset_update_path, params: {
        admin_user: { password: "short", password_confirmation: "short" }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a blank password instead of reporting success" do
      # Arrange — has_secure_password ignores a blank assignment, leaving the old digest
      admin = create(:admin_user)
      claim_reset(admin.generate_token_for(:password_reset))

      # Act
      patch admin_password_reset_update_path, params: {
        admin_user: { password: "", password_confirmation: "" }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:notice]).to be_nil
      expect(admin.reload.authenticate("securepassword123")).to be_truthy
    end

    it "rejects a payload with no password key instead of reporting success" do
      # Arrange — with the key absent, password= is never called at all, so nothing records
      # a blank attempt: the update succeeds against the existing digest, the caller is
      # signed in, and the link stays resolvable for the rest of its two hours
      admin = create(:admin_user)
      claim_reset(admin.generate_token_for(:password_reset))

      # Act
      patch admin_password_reset_update_path, params: { admin_user: { unrelated: "x" } }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:notice]).to be_nil
      expect(admin.reload.authenticate("securepassword123")).to be_truthy

      get admin_root_path
      expect(response).to redirect_to(admin_login_path)
    end

    it "settles a still-pending invitation rather than signing in an inactive account" do
      # Arrange — every path that grants a session must leave the account able to log in
      admin = create(:admin_user, :pending_invitation, email: "pending@example.com")
      claim_reset(admin.generate_token_for(:password_reset))

      # Act
      patch admin_password_reset_update_path, params: {
        admin_user: { password: "a-brand-new-password", password_confirmation: "a-brand-new-password" }
      }

      # Assert
      admin.reload
      expect(admin.invitation_accepted_at).to be_present
      expect(admin.active?).to be(true)
    end

    it "refuses to update without a claimed token" do
      # Arrange
      admin = create(:admin_user)

      # Act
      patch admin_password_reset_update_path, params: {
        admin_user: { password: "a-brand-new-password", password_confirmation: "a-brand-new-password" }
      }

      # Assert
      expect(response).to redirect_to(new_admin_password_reset_path)
      expect(admin.reload.authenticate("a-brand-new-password")).to be_falsey
    end

    it "rejects an all-whitespace password" do
      # Arrange — the length minimum is satisfiable with no entropy at all
      admin = create(:admin_user)
      whitespace = "\t\n" * 7
      claim_reset(admin.generate_token_for(:password_reset))

      # Act
      patch admin_password_reset_update_path, params: {
        admin_user: { password: whitespace, password_confirmation: whitespace }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(admin.reload.authenticate(whitespace)).to be_falsey
      expect(admin.authenticate("securepassword123")).to be_truthy
    end

    it "answers a scalar where the payload should be nested instead of raising" do
      # Arrange — permit and dig both assume a nested hash and blow up on anything else
      admin = create(:admin_user)
      claim_reset(admin.generate_token_for(:password_reset))

      # Act
      patch admin_password_reset_update_path, params: { admin_user: "not-a-hash" }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(admin.reload.authenticate("securepassword123")).to be_truthy
    end
  end

  describe "rate limiting" do
    it "throttles repeated reset requests for one address" do
      # Arrange
      create(:admin_user, email: "known@example.com")

      # Act — the limit is 5 within 15 minutes
      6.times { post admin_password_reset_path, params: { email: "known@example.com" } }

      # Assert
      expect(response).to redirect_to(new_admin_password_reset_path)
      expect(flash[:alert]).to eq(I18n.t("admin.password_reset.too_many_requests"))
    end

    it "throttles an address regardless of the case it is typed in" do
      # Arrange — keying on the raw string would let case variants multiply the allowance
      create(:admin_user, email: "known@example.com")

      # Act
      3.times { post admin_password_reset_path, params: { email: "known@example.com" } }
      3.times { post admin_password_reset_path, params: { email: "KNOWN@EXAMPLE.COM" } }

      # Assert
      expect(flash[:alert]).to eq(I18n.t("admin.password_reset.too_many_requests"))
    end
  end
end
