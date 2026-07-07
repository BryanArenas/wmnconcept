module Api
  module V1
    # Public liveness/readiness probe (spec Appendix C: uptime monitoring).
    class HealthController < ApplicationController
      def show
        render json: {
          status: "ok",
          service: "wmn-api",
          time: Time.current.iso8601
        }
      end
    end
  end
end
