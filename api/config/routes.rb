Rails.application.routes.draw do
  # Load-balancer / uptime liveness (boots-with-no-exceptions check).
  get "up" => "rails/health#show", as: :rails_health_check

  # OmniAuth browser-redirect flow. The request phase (POST /auth/:provider) is
  # handled by the OmniAuth middleware; the provider redirects back here.
  match "/auth/:provider/callback", to: "api/v1/sessions#create", via: %i[get post]
  match "/auth/failure",            to: "api/v1/sessions#failure", via: %i[get post]

  namespace :api do
    namespace :v1 do
      get    "health",  to: "health#show"
      get    "me",      to: "me#show"
      delete "session", to: "sessions#destroy"

      # Agencies & partner logins (spec §4, §12 M2). org_admin-gated via Pundit.
      resources :agencies, only: %i[index create] do
        resources :agency_users, only: %i[create]
      end

      # Inspection intake + triage (spec §8.2, §8.7, M3).
      resources :inspection_type_configs, only: %i[index]
      resources :inspection_requests, only: %i[index create] do
        member do
          post :accept
          post :decline
        end
      end
      resources :inspections, only: %i[index show]
    end
  end
end
