Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#home"
  get "/about", to: "pages#about"
  get "/gallery", to: "pages#gallery"
  get "/services", to: "pages#services"
  post "/contact", to: "contacts#create", as: :contact

  namespace :admin do
    get    "login",  to: "sessions#new",     as: :login
    post   "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    # Unauthenticated by necessity: the whole point is that the admin cannot sign in.
    # The token in the path is the credential.
    resource :password_reset, only: [ :new, :create ]
    get   "password_reset/:token/edit", to: "password_resets#edit",   as: :edit_password_reset
    patch "password_reset/:token",      to: "password_resets#update", as: :password_reset_update

    # Also unauthenticated: an invited admin has no working password yet.
    get   "invitation/:token/edit", to: "invitations#edit",   as: :edit_invitation
    patch "invitation/:token",      to: "invitations#update", as: :invitation_update

    resources :users, only: [ :index, :new, :create, :destroy ]
    resource  :account, only: [ :edit, :update ]

    root to: "dashboard#index"
    resource :home_page_content, only: [ :show, :update ] do
      patch :restore_defaults
    end
    resource :about_page_content, only: [ :show, :update ] do
      patch :restore_defaults
    end
    resource  :services_page,    only: [ :show, :update ]
    resources :service_sections, only: [ :new, :create, :edit, :update, :destroy ] do
      member do
        patch :move_up
        patch :move_down
      end
    end
    resources :gallery_photos, only: [ :index, :create, :destroy ] do
      collection do
        patch :reorder
      end
    end
  end
end
