Rails.application.routes.draw do
  # Admin-only dashboards. Non-admins get a 404 — the routes simply do not exist for them.
  constraints AdminConstraint do
    mount Flipper::UI.app(Flipper) => "/flipper", as: :flipper
    mount Blazer::Engine => "/blazer"
  end

  # The admin dashboard itself is a normal controller, gated by AdminPolicy
  # rather than the routing constraint above -- the constraint exists because
  # mounted engines run outside the controller stack.
  get "admin" => "admin#index", as: :admin

  # The game. A birb is a photo; a guess is one pin on it, and you get one.
  # `resource :guess`, singular, because a player has at most one per birb.
  resources :birbs, only: %i[ index show new create ] do
    resource :guess, only: :create
  end

  # Passwordless sign-in. Requesting a code also creates the account, so this is
  # both the sign-up and the sign-in flow.
  get    "login"          => "logins#new",      as: :new_login
  post   "login"          => "logins#create",   as: :login
  get    "login/verify"   => "logins#verify",   as: :verify_login
  post   "login/verify"   => "logins#complete", as: :complete_login
  # The magic link. Last, so it cannot shadow /login/verify above.
  get    "login/:token"   => "logins#show",     as: :login_link
  delete "logout"         => "sessions#destroy", as: :logout
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
