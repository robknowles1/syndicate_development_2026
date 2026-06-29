FactoryBot.define do
  factory :admin_user do
    email { "admin@syndicate-development.com" }
    password { "securepassword123" }
    password_confirmation { "securepassword123" }
  end
end
