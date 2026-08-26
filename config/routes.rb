Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # No destroy: an address is only reachable because a group or an event points at it, and
  # both of those references are ON DELETE RESTRICT, so every address a member can reach is
  # one the database refuses to delete. Deleting is not a thing users do here - correcting an
  # address is what `edit` is for. Settled on #172.
  resources :addresses, except: :destroy

  resource :user do
    resource :profile, controller: "user_profiles", only: %i[ show edit update ]
  end
  resolve("User")        { [ :user         ] }
  resolve("UserProfile") { [ :user_profile ] }


  resources :groups do
    resources :members
    resources :events do
      get "duplicate", on: :member
      resources :registrations
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "groups#index"
end
