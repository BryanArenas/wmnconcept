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
      get    "dashboard", to: "dashboard#show"
      post   "session", to: "sessions#login"
      delete "session", to: "sessions#destroy"

      # Public invitation accept flow (email-confirmed account activation).
      get  "invitations",        to: "invitations#show"
      post "invitations/accept", to: "invitations#accept"

      # Public placeholder pay page reached from the invoice link (spec §11).
      get  "pay/:id",         to: "payments#show"
      post "pay/:id/confirm", to: "payments#confirm"

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
      resources :inspections, only: %i[index show] do
        member do
          post   :assign
          post   :schedule
          post   :start
          post   :cancel
          post   :submit
          # Review → delivery (M6)
          post   :approve
          post   :reject
          get    :evidence
          # Field capture (M5)
          get    :form_template
          get    :photos, to: "inspections#photos_index"
          post   :photos, to: "inspections#photos_create"
          patch  "photos/:photo_id/confirm", to: "inspections#confirm_photo"
          put    :form_response
        end
        # Generated report + signed download (M6, spec §8.4)
        get "report", to: "reports#show"
        get "report/download", to: "reports#download"
      end

      # Company settings (admin).
      resource :organization, only: %i[show update], controller: "organization"

      # Inspector availability blocks (Settings → Availability).
      resources :availability_blocks, only: %i[index create destroy]

      # Staff roster for dispatch inspector dropdown (spec §8.8, M4) + staff
      # provisioning (create invites a member) + permissions management (update).
      resources :users, only: %i[index create update]

      # Billing surface (spec §4, §8.5, M7).
      resources :invoices, only: %i[index show] do
        member { post :send, action: :send_invoice }
      end

      # Inbound Stripe webhooks — public, signature-verified (spec §4, §9).
      post "webhooks/stripe", to: "webhooks/stripe#create"
    end
  end
end
