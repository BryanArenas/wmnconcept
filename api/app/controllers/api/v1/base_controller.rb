module Api
  module V1
    # Authenticated base for API endpoints. Anything under it requires a signed-in
    # user; tenancy is available via current_organization. Public endpoints
    # (health, session callback) inherit ApplicationController directly instead.
    class BaseController < ApplicationController
      before_action :authenticate_user!
    end
  end
end
