module Api
  module V1
    # Inspection read + dispatch transitions (spec §8.8, M4).
    # Read scope: agency→own, inspector→own assignments, staff→all.
    # Transitions (assign/schedule/start/cancel): coordinator-gated via Pundit.
    # AASM::InvalidTransition is rescued globally by ErrorEnvelope.
    class InspectionsController < BaseController
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      def index
        authorize Inspection
        scope = policy_scope(Inspection)
                  .includes(:agency, :property, :homeowner, :assigned_inspector, :report, :invoice)
        scope = scope.where(status: params[:status]) if params[:status].present?
        inspections, next_cursor = paginate(scope)
        render json: {
          data: inspections.map { |i| InspectionSerializer.call(i) },
          meta: { next_cursor: }
        }
      end

      def show
        inspection = find_scoped_inspection
        authorize inspection
        render json: { data: InspectionSerializer.call(inspection) }
      end

      # Assign an inspector (unassigned → assigned). Body: { inspection: { inspector_id } }
      def assign
        inspection = find_scoped_inspection
        authorize inspection, :assign?
        inspector = current_organization.users.active.find(inspection_params[:inspector_id])
        inspection.assign_to!(inspector, actor: current_user)
        render json: { data: InspectionSerializer.call(inspection.reload) }
      end

      # Set scheduled_at (assigned → scheduled). Body: { inspection: { scheduled_at } }
      # Enqueues T-24h InspectionReminderJob automatically (spec §9).
      def schedule
        inspection = find_scoped_inspection
        authorize inspection, :schedule?
        time = parse_scheduled_at!(inspection_params[:scheduled_at])
        inspection.schedule_for!(time, actor: current_user)
        render json: { data: InspectionSerializer.call(inspection.reload) }
      end

      # Inspector marks arrival (scheduled → in_progress).
      def start
        inspection = find_scoped_inspection
        authorize inspection, :start?
        inspection.start_by!(actor: current_principal)
        render json: { data: InspectionSerializer.call(inspection.reload) }
      end

      # Coordinator voids an in-flight inspection (spec §6 cancel guard).
      def cancel
        inspection = find_scoped_inspection
        authorize inspection, :cancel?
        inspection.cancel_by!(actor: current_principal)
        render json: { data: InspectionSerializer.call(inspection.reload) }
      end

      # Inspector submits completed evidence (in_progress → submitted_for_review).
      # Guard: ready_for_review? (≥1 uploaded photo + required form fields).
      def submit
        inspection = find_scoped_inspection
        authorize inspection, :submit?
        inspection.submit_by!(actor: current_principal)
        render json: { data: InspectionSerializer.call(inspection.reload) }
      end

      # --- Review → delivery (M6, spec §8.13) -----------------------------------

      # Manager approves (submitted_for_review → approved). Enqueues the report
      # pipeline; does NOT deliver (spec §6 invariant — delivery needs a PDF).
      def approve
        inspection = find_scoped_inspection
        authorize inspection, :approve?
        inspection.approve_by!(actor: current_user)
        render json: { data: InspectionSerializer.call(inspection.reload) }
      end

      # Manager sends back (submitted_for_review → in_progress). Body:
      # { inspection: { rejection_note } } — note required (spec §6 guard).
      def reject
        inspection = find_scoped_inspection
        authorize inspection, :reject?
        inspection.reject_with_note!(review_params[:rejection_note], actor: current_user)
        render json: { data: InspectionSerializer.call(inspection.reload) }
      end

      # GET captured evidence for the review pane: the form fields + saved
      # answers + uploaded photos, in one payload so a reviewer can actually see
      # what they're approving (spec §8.13). Photos carry a short-lived view URL
      # when S3 is configured; otherwise the filename (no bytes exist locally).
      def evidence
        inspection = find_scoped_inspection
        authorize inspection, :evidence?
        template = current_organization.inspection_form_templates
                                       .active
                                       .find_by(inspection_type: inspection.inspection_type)
        response = inspection.inspection_form_response

        render json: {
          inspection_id: inspection.id,
          inspection_type: inspection.inspection_type,
          form: {
            fields: template&.schema&.dig("fields") || [],
            responses: response&.responses || {}
          },
          photos: inspection.inspection_photos.uploaded.order(:created_at).map do |p|
            InspectionPhotoSerializer.call(p).merge(view_url: PhotoUploadService.view_url(p))
          end
        }
      end

      # --- Field capture (M5) ---------------------------------------------------

      # GET all photos for an inspection (field app resume after restart).
      def photos_index
        inspection = find_scoped_inspection
        authorize inspection, :show?
        render json: {
          data: inspection.inspection_photos.order(:created_at).map do |p|
            InspectionPhotoSerializer.call(p)
          end
        }
      end

      # GET form template for this inspection type; 404 if none configured yet.
      def form_template
        inspection = find_scoped_inspection
        authorize inspection, :show_form?
        template = current_organization.inspection_form_templates
                                       .active
                                       .find_by!(inspection_type: inspection.inspection_type)
        render json: { data: InspectionFormTemplateSerializer.call(template) }
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "No form template configured for this inspection type",
                     status: :not_found)
      end

      # POST a new photo: returns the InspectionPhoto + presigned S3 PUT URL.
      # Body: { photo: { filename, content_type } }
      def photos_create
        inspection = find_scoped_inspection
        authorize inspection, :upload_photo?
        result = PhotoUploadService.presign(
          inspection:,
          filename: photo_params[:filename],
          content_type: photo_params[:content_type]
        )
        render json: {
          data: InspectionPhotoSerializer.call(result[:photo]),
          presigned_url: result[:presigned_url]
        }, status: :created
      end

      # PATCH confirm: client calls this after the S3 PUT completes.
      def confirm_photo
        inspection = find_scoped_inspection
        authorize inspection, :confirm_photo?
        photo = inspection.inspection_photos.find(params[:photo_id])
        photo.confirm!
        render json: { data: InspectionPhotoSerializer.call(photo) }
      end

      # PUT form_response: upsert the inspector's form answers.
      # Body: { form_response: { responses: { key => value } } }
      def form_response
        inspection = find_scoped_inspection
        authorize inspection, :save_form?
        resp = inspection.inspection_form_response ||
               inspection.build_inspection_form_response(organization: current_organization)
        resp.update!(responses: form_response_params[:responses] || {})
        render json: { data: InspectionFormResponseSerializer.call(resp) }
      end

      private

      def find_scoped_inspection
        policy_scope(Inspection).find(params[:id])
      end

      def inspection_params
        params.require(:inspection).permit(:inspector_id, :scheduled_at)
      end

      def photo_params
        params.require(:photo).permit(:filename, :content_type)
      end

      def form_response_params
        params.require(:form_response).permit(responses: {})
      end

      def review_params
        params.require(:inspection).permit(:rejection_note)
      end

      def parse_scheduled_at!(str)
        raise ActionController::ParameterMissing.new(:scheduled_at) if str.blank?

        parsed = Time.zone.parse(str.to_s)
        render_error(
          code: "invalid_date",
          message: "scheduled_at is not a valid datetime",
          status: :unprocessable_content
        ) and return if parsed.nil?
        parsed
      end
    end
  end
end
