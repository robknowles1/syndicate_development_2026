require "rails_helper"

RSpec.describe "Admin::Invitations", type: :request do
  def invite!(email: "invitee@example.com")
    admin = AdminUser.new(email: email, invited_at: Time.current)
    admin.password = SecureRandom.base58(32)
    admin.save!
    admin
  end

  # The emailed link only stashes the token and redirects; the form lives at a tokenless
  # URL, so every spec that reaches the form has to follow that redirect.
  def claim_invitation(token)
    get admin_claim_invitation_path(token: token)
    follow_redirect!
  end

  describe "GET /admin/invitation/:token/edit" do
    it "renders the password form for a pending invitation" do
      # Arrange
      admin = invite!

      # Act
      claim_invitation(admin.generate_token_for(:invitation))

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin.email)
    end

    it "keeps the token out of the URL that renders the form" do
      # Arrange — a token in the path is logged on every request and leaks via Referer
      admin = invite!
      token = admin.generate_token_for(:invitation)

      # Act
      get admin_claim_invitation_path(token: token)

      # Assert
      expect(response).to redirect_to(admin_edit_invitation_path)
      expect(admin_edit_invitation_path).not_to include(token)

      follow_redirect!
      expect(response.body).not_to include(token)
    end

    it "rejects a garbage token" do
      # Act
      get admin_claim_invitation_path(token: "not-a-real-token")

      # Assert
      expect(response).to redirect_to(admin_login_path)
      expect(flash[:alert]).to eq(I18n.t("admin.invitation.invalid_token"))
    end

    it "rejects a token for an already-accepted invitation" do
      # Arrange — acceptance rotates the password salt the token derives from
      admin = invite!
      token = admin.generate_token_for(:invitation)
      admin.accept_invitation(password: "brandnewpassword", password_confirmation: "brandnewpassword")

      # Act
      get admin_claim_invitation_path(token: token)

      # Assert
      expect(response).to redirect_to(admin_login_path)
    end

    it "rejects an expired token" do
      # Arrange
      admin = invite!
      token = admin.generate_token_for(:invitation)

      # Act
      travel 8.days do
        get admin_claim_invitation_path(token: token)
      end

      # Assert
      expect(response).to redirect_to(admin_login_path)
    end

    it "does not put an unresolvable token into the visitor's session" do
      # Arrange — this is an unauthenticated GET any visitor can be sent to, and the session
      # rides in a cookie: stashing the path segment unread lets a stranger choose several
      # kilobytes of it, which overflows the 4KB cookie and 500s the request
      oversized_token = "a" * 5_000

      # Act
      get admin_claim_invitation_path(token: oversized_token)

      # Assert
      expect(response).to redirect_to(admin_login_path)
      expect(session[:invitation_token]).to be_nil
    end

    it "refuses a token minted for an admin who was never invited" do
      # Arrange — the token resolves on its own, so only the pending check separates it
      # from a password reset that never asks for the current password
      admin = create(:admin_user, email: "established@example.com")

      # Act
      get admin_claim_invitation_path(token: admin.generate_token_for(:invitation))

      # Assert
      expect(response).to redirect_to(admin_login_path)
      expect(flash[:alert]).to eq(I18n.t("admin.invitation.invalid_token"))
    end

    it "does not let a token minted for an established admin set a password" do
      # Arrange
      admin = create(:admin_user, email: "established@example.com")

      # Act
      get admin_claim_invitation_path(token: admin.generate_token_for(:invitation))
      patch admin_invitation_update_path, params: {
        admin_user: { password: "attacker-chosen-pw", password_confirmation: "attacker-chosen-pw" }
      }

      # Assert
      expect(admin.reload.authenticate("attacker-chosen-pw")).to be_falsey
      expect(admin.authenticate("securepassword123")).to be_truthy
    end

    it "keeps the token out of the path written to the log" do
      # Arrange — filter_parameters redacts the query string but never a path segment
      admin = invite!
      token = admin.generate_token_for(:invitation)

      # Act
      get admin_claim_invitation_path(token: token)

      # Assert
      expect(request.filtered_path).not_to include(token)
    end

    it "discards a signed-in session rather than stashing the token into it" do
      # Arrange
      victim = create(:admin_user, email: "victim@example.com")
      invited = invite!
      post admin_login_path, params: { email: victim.email, password: "securepassword123" }

      # Act
      get admin_claim_invitation_path(token: invited.generate_token_for(:invitation))

      # Assert
      expect(session[:admin_user_id]).to be_nil
    end

    it "refuses to render the form without a claimed token" do
      # Act
      get admin_edit_invitation_path

      # Assert
      expect(response).to redirect_to(admin_login_path)
    end
  end

  describe "PATCH /admin/invitation" do
    it "sets the password, marks the invitation accepted, and signs the admin in" do
      # Arrange
      admin = invite!
      claim_invitation(admin.generate_token_for(:invitation))

      # Act
      patch admin_invitation_update_path, params: {
        admin_user: { password: "brandnewpassword", password_confirmation: "brandnewpassword" }
      }

      # Assert
      expect(response).to redirect_to(admin_root_path)
      admin.reload
      expect(admin.invitation_accepted_at).to be_present
      expect(admin.invitation_pending?).to be(false)
      expect(admin.authenticate("brandnewpassword")).to be_truthy

      # The session really is authenticated, not just redirected
      get admin_root_path
      expect(response).to have_http_status(:ok)
    end

    it "re-renders when the confirmation does not match" do
      # Arrange
      admin = invite!
      claim_invitation(admin.generate_token_for(:invitation))

      # Act
      patch admin_invitation_update_path, params: {
        admin_user: { password: "brandnewpassword", password_confirmation: "different-entirely" }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(admin.reload.invitation_pending?).to be(true)
    end

    it "re-renders when the password is below the minimum length" do
      # Arrange
      admin = invite!
      claim_invitation(admin.generate_token_for(:invitation))

      # Act
      patch admin_invitation_update_path, params: {
        admin_user: { password: "short", password_confirmation: "short" }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(admin.reload.invitation_pending?).to be(true)
    end

    it "rejects a blank password instead of accepting the invitation" do
      # Arrange — has_secure_password ignores a blank assignment, so the placeholder
      # password would survive while the invitation was marked accepted and the link spent
      admin = invite!
      placeholder_digest = admin.password_digest
      claim_invitation(admin.generate_token_for(:invitation))

      # Act
      patch admin_invitation_update_path, params: {
        admin_user: { password: "", password_confirmation: "" }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      admin.reload
      expect(admin.invitation_pending?).to be(true)
      expect(admin.password_digest).to eq(placeholder_digest)
    end

    it "sets the password when the confirmation field is not submitted at all" do
      # Arrange — permitted params drop keys the form did not send, and has_secure_password
      # skips the confirmation check when the confirmation is nil rather than merely blank
      admin = invite!
      claim_invitation(admin.generate_token_for(:invitation))

      # Act
      patch admin_invitation_update_path, params: {
        admin_user: { password: "brandnewpassword" }
      }

      # Assert
      expect(response).to redirect_to(admin_root_path)
      expect(admin.reload.authenticate("brandnewpassword")).to be_truthy
    end

    it "rejects a payload with no password key instead of accepting the invitation" do
      # Arrange — with the key absent, password= is never called at all, so nothing records
      # a blank attempt: the update succeeds, the invitation is marked accepted, and the
      # placeholder digest nobody knows stays in place while the link is spent
      admin = invite!
      placeholder_digest = admin.password_digest
      token = admin.generate_token_for(:invitation)
      claim_invitation(token)

      # Act
      patch admin_invitation_update_path, params: { admin_user: { unrelated: "x" } }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      admin.reload
      expect(admin.invitation_pending?).to be(true)
      expect(admin.password_digest).to eq(placeholder_digest)
      expect(AdminUser.find_by_token_for(:invitation, token)).to eq(admin)
    end

    it "refuses to update without a claimed token" do
      # Arrange
      admin = invite!

      # Act
      patch admin_invitation_update_path, params: {
        admin_user: { password: "brandnewpassword", password_confirmation: "brandnewpassword" }
      }

      # Assert
      expect(response).to redirect_to(admin_login_path)
      expect(admin.reload.invitation_pending?).to be(true)
    end

    it "rejects an all-whitespace password" do
      # Arrange — the length minimum is satisfiable with no entropy at all
      admin = invite!
      whitespace = " " * 14
      claim_invitation(admin.generate_token_for(:invitation))

      # Act
      patch admin_invitation_update_path, params: {
        admin_user: { password: whitespace, password_confirmation: whitespace }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(admin.reload.invitation_pending?).to be(true)
    end

    it "answers a scalar where the payload should be nested instead of raising" do
      # Arrange — permit assumes a nested hash and blows up on anything else
      admin = invite!
      claim_invitation(admin.generate_token_for(:invitation))

      # Act
      patch admin_invitation_update_path, params: { admin_user: "not-a-hash" }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(admin.reload.invitation_pending?).to be(true)
    end
  end

  describe "an invited admin who has not accepted" do
    it "cannot sign in with the placeholder password even if it were guessed" do
      # Arrange
      admin = AdminUser.new(email: "pending@example.com", invited_at: Time.current)
      placeholder = SecureRandom.base58(32)
      admin.password = placeholder
      admin.save!

      # Act
      post admin_login_path, params: { email: admin.email, password: placeholder }

      # Assert — credentials are correct, but the account is not active
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash.now[:alert]).to eq(I18n.t("admin.login.invalid_credentials"))
    end
  end
end
