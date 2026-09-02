Rails.application.routes.draw do
  resource :session
  # The emailed link is a GET that renders and a POST that redeems, and they are separate actions
  # on their own resource because a mail scanner following the link must reach one that cannot
  # sign anybody in. The token rides the query string, never a path segment, since `filtered_path`
  # filters only the query string - both decisions are ADR 0004's.
  resource :sign_in, only: %i[ show create ]
  # Two singular resources mirroring the sign-in pair, and split for the same reason: asking for a
  # link and redeeming one are different actions with different guards. `resource :sign_up` is the
  # counterpart of `resource :session`, and `resource :sign_up_confirmation` of `resource :sign_in`.
  resource :sign_up, only: %i[ new create ]
  resource :sign_up_confirmation, only: %i[ show create ]
  # An address exists only as a detail of the group or event that points at it: both build one
  # through `accepts_nested_attributes_for :address`, and `EventsController` picks an existing one
  # out of `group.addresses`. So there is nothing to create standalone - an address pointed at by
  # nothing appears in no picker and is reachable by nobody, its own author included - and nothing
  # to destroy, since every address a member can reach is held by an ON DELETE RESTRICT reference.
  # What is left is reading them and correcting them. Settled on #172; the reuse flow the event
  # form gestures at is #187.
  resources :addresses, only: %i[ index show edit update ]

  # No `new` and no `create`: signing up and being invited are the two ways to become a user, and
  # neither of them is a signed-in visitor asking for a second account.
  resource :user, only: %i[ show edit update destroy ] do
    resource :profile, controller: "user_profiles", only: %i[ show edit update ]
  end
  resolve("User")        { [ :user         ] }
  resolve("UserProfile") { [ :user_profile ] }
  # A singular resource, so polymorphic routing has no plural path to build for a new record.
  resolve("SignUp")      { [ :sign_up      ] }


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
