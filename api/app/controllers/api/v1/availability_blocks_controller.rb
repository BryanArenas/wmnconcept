module Api
  module V1
    # An inspector's blocked-out times (Settings → Availability). Scoped to the
    # caller's own rows; only inspectors create/destroy their blocks.
    class AvailabilityBlocksController < BaseController
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      def index
        authorize AvailabilityBlock
        blocks = policy_scope(AvailabilityBlock).upcoming.chronological
        render json: { data: blocks.map { |b| AvailabilityBlockSerializer.call(b) } }
      end

      def create
        authorize AvailabilityBlock
        block = current_user.availability_blocks.build(
          organization: current_organization, **block_params.to_h.symbolize_keys
        )
        block.save!
        render json: { data: AvailabilityBlockSerializer.call(block) }, status: :created
      end

      def destroy
        block = policy_scope(AvailabilityBlock).find(params[:id])
        authorize block
        block.destroy!
        head :no_content
      end

      private

      def block_params
        params.require(:availability_block).permit(:starts_at, :ends_at, :all_day, :reason)
      end
    end
  end
end
