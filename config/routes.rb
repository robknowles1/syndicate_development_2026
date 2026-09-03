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

  get "/sitemap.xml", to: "sitemaps#show", as: :sitemap, defaults: { format: :xml }
  get "/robots.txt",  to: "robots#show",   as: :robots,  defaults: { format: :text }

  namespace :admin do
    get    "login",  to: "sessions#new",     as: :login
    post   "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    # Unauthenticated by necessity: the whole point is that the admin cannot sign in.
    # The token is the credential, so the emailed #claim URL is the only place it appears.
    # It is moved into the session there and the form itself is tokenless, keeping the
    # credential out of later log lines, form actions, and Referer headers.
    #
    # A query parameter rather than a path segment because config.filter_parameters
    # redacts the query string of the logged request path and never a path segment, and
    # this one request is the only one that carries the token.
    resource :password_reset, only: [ :new, :create ]
    get "password_reset/claim", to: "password_resets#claim", as: :claim_password_reset
    get "password_reset/edit", to: "password_resets#edit", as: :edit_password_reset
    patch "password_reset", to: "password_resets#update", as: :password_reset_update

    # Also unauthenticated: an invited admin has no working password yet.
    get "invitation/claim", to: "invitations#claim", as: :claim_invitation
    get "invitation/edit", to: "invitations#edit", as: :edit_invitation
    patch "invitation", to: "invitations#update", as: :invitation_update

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
    resources :faqs, only: [ :index, :new, :create, :edit, :update, :destroy ] do
      member do
        patch :move_up
        patch :move_down
      end
    end
    resources :social_media_links, only: [ :index, :new, :create, :edit, :update, :destroy ] do
      member do
        patch :move_up
        patch :move_down
      end
    end
    resource :business_hours, only: [ :show, :update ]
  end
end
