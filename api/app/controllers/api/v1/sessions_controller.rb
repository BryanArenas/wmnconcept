module Api
  module V1
    # OmniAuth callback + logout. The browser initiates login on the Next side
    # (POST /auth/:provider), the provider redirects back to
    # GET /auth/:provider/callback → #create, and we set the shared-cookie
    # session then redirect the browser back into the app (spec §10).
    class SessionsController < ApplicationController
      # The OAuth callback is protected by OmniAuth's own state parameter, and
      # #failure is provider-driven — neither carries our CSRF token.
      skip_forgery_protection only: %i[create failure]

      # GET/POST /auth/:provider/callback
      def create
        auth = request.env["omniauth.auth"]
        return redirect_to_login(error: "auth_failed") if auth.blank?

        organization = resolve_organization
        # Staff and agency identities live in separate tables (spec §2); resolve
        # staff first, then partner logins.
        principal = User.from_omniauth(auth, organization: organization) ||
                    AgencyUser.from_omniauth(auth, organization: organization)

        if principal
          sign_in(principal)
          redirect_to frontend_url(home_path_for(principal)), allow_other_host: true
        else
          # Authenticated with the provider, but not a provisioned WMN account.
          redirect_to_login(error: "not_authorized")
        end
      end

      # DELETE /api/v1/session — idempotent logout.
      def destroy
        sign_out
        head :no_content
      end

      # OmniAuth on_failure target (bad config, denied consent, etc.).
      def failure
        redirect_to_login(error: params[:message].presence || "auth_failed")
      end

      private

      def redirect_to_login(error:)
        redirect_to frontend_url("/login?error=#{error}"), allow_other_host: true
      end

      # Route each principal to its surface: agency users to the partner portal,
      # inspectors to the field shell, other staff to the staff shell.
      def home_path_for(principal)
        return "/agency/dashboard" if principal.agency?

        principal.inspector? ? "/today" : "/dashboard"
      end

      def frontend_url(path = "")
        base = ENV.fetch("FRONTEND_URL", "http://localhost:3000").chomp("/")
        "#{base}#{path}"
      end
    end
  end
end
