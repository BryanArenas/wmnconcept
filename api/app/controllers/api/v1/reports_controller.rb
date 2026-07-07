module Api
  module V1
    # The generated report + its signed download (spec §4, §8.4). Read access is
    # scoped through the inspection: agency(own) can retrieve/download the
    # delivered report; staff org-wide; inspector own assignments.
    class ReportsController < BaseController
      after_action :verify_authorized

      # GET /inspections/:inspection_id/report — report metadata + signed URL.
      def show
        inspection = find_scoped_inspection
        authorize inspection, :report?
        report = inspection.report
        return render_no_report unless report

        url = ReportStorageService.signed_url(report.s3_key, inspection_id: inspection.id)
        render json: { data: ReportSerializer.call(report, download_url: url) }
      end

      # GET /inspections/:inspection_id/report/download — streams the PDF. Used by
      # the local-storage fallback; with S3 the signed URL points straight at S3.
      def download
        inspection = find_scoped_inspection
        authorize inspection, :download?
        report = inspection.report
        return render_no_report unless report

        bytes = ReportStorageService.read(report.s3_key)
        return render_no_report unless bytes

        send_data bytes,
                  filename: File.basename(report.s3_key),
                  type: "application/pdf",
                  disposition: "inline"
      end

      private

      def find_scoped_inspection
        policy_scope(Inspection).find(params[:inspection_id])
      end

      def render_no_report
        render_error(
          code: "report_not_ready",
          message: "The report has not been generated yet.",
          status: :not_found
        )
      end
    end
  end
end
