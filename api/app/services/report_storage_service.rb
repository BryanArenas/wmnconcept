# Stores generated report PDFs and hands back a download URL. S3 when configured
# (presigned GET); a local filesystem fallback in dev/test so the whole pipeline
# — generate → persist → deliver → download — is exercisable without AWS.
#
# The local fallback writes under tmp/report_storage and signs a URL pointing at
# the API's report download action (ReportsController#download).
class ReportStorageService
  BUCKET = ENV["S3_BUCKET"]
  REGION = ENV.fetch("AWS_REGION", "us-east-1")
  URL_EXPIRY = 15.minutes

  class << self
    def store(key:, content:, content_type: "application/pdf")
      if s3_configured?
        put_s3(key, content, content_type)
      else
        put_local(key, content)
      end
      key
    end

    def read(key)
      if s3_configured?
        get_s3(key)
      else
        path = local_path(key)
        File.exist?(path) ? File.binread(path) : nil
      end
    end

    # Returns a download URL. For S3, a presigned GET; otherwise an app-relative
    # path the API serves via ReportsController#download.
    def signed_url(key, inspection_id:)
      return presigned_get(key) if s3_configured?

      "/api/v1/inspections/#{inspection_id}/report/download"
    end

    def s3_configured?
      BUCKET.present? && ENV["AWS_ACCESS_KEY_ID"].present?
    end

    private

    def client
      require "aws-sdk-s3"
      @client ||= Aws::S3::Client.new(region: REGION)
    end

    def put_s3(key, content, content_type)
      client.put_object(bucket: BUCKET, key:, body: content, content_type:)
    end

    def get_s3(key)
      client.get_object(bucket: BUCKET, key:).body.read
    rescue Aws::S3::Errors::NoSuchKey
      nil
    end

    def presigned_get(key)
      require "aws-sdk-s3"
      Aws::S3::Presigner.new(client:)
                        .presigned_url(:get_object, bucket: BUCKET, key:, expires_in: URL_EXPIRY.to_i)
    end

    def put_local(key, content)
      path = local_path(key)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, content)
    end

    def local_path(key)
      Rails.root.join("tmp", "report_storage", key).to_s
    end
  end
end
