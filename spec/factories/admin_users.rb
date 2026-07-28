FactoryBot.define do
  factory :admin_user do
    email { "admin@syndicate-development.com" }
    password { "securepassword123" }
    password_confirmation { "securepassword123" }
    # Directly created admins are active. Without this they look like pending invitations
    # and cannot sign in, which would break every spec that logs in.
    invitation_accepted_at { Time.current }

    trait :pending_invitation do
      invited_at { Time.current }
      invitation_accepted_at { nil }
    end
  end
end
