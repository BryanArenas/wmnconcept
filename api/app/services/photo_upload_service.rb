# Generates a presigned S3 PUT URL for direct browser-to-S3 upload.
# Returns { photo: InspectionPhoto, presigned_url: String }.
#
# In dev/test (no S3 env vars), returns a stub URL so the flow stays exercisable
# without real AWS credentials.
class PhotoUploadService
  BUCKET = ENV["S3_BUCKET"]
  REGION = ENV.fetch("AWS_REGION", "us-east-1")
  URL_EXPIRY = 15.minutes

  class << self
    def presign(inspection:, filename:, content_type:)
      s3_key = build_key(inspection, filename)

      photo = inspection.inspection_photos.create!(
        organization: inspection.organization,
        s3_key:,
        filename:,
        content_type:,
        upload_state: "pending"
      )

      url = presigned_url(s3_key, content_type)
      { photo:, presigned_url: url }
    end

    # Short-lived presigned GET so a reviewer can view an uploaded photo inline.
    # Returns nil when S3 is not configured (dev/test) — the reviewer sees the
    # filename chip instead, since no real bytes were ever uploaded locally.
    def view_url(photo)
      return nil unless s3_configured?

      require "aws-sdk-s3"
      client = Aws::S3::Client.new(region: REGION)
      signer = Aws::S3::Presigner.new(client:)
      signer.presigned_url(:get_object, bucket: BUCKET, key: photo.s3_key, expires_in: URL_EXPIRY.to_i)
    end

    private

    def build_key(inspection, filename)
      ext  = File.extname(filename.to_s).downcase.presence || ".jpg"
      slug = SecureRandom.uuid
      "inspections/#{inspection.id}/photos/#{slug}#{ext}"
    end

    def presigned_url(s3_key, content_type)
      return stub_url(s3_key) unless s3_configured?

      require "aws-sdk-s3"
      client = Aws::S3::Client.new(region: REGION)
      signer = Aws::S3::Presigner.new(client:)
      signer.presigned_url(
        :put_object,
        bucket: BUCKET,
        key: s3_key,
        expires_in: URL_EXPIRY.to_i,
        content_type:
      )
    end

    def s3_configured?
      BUCKET.present? && ENV["AWS_ACCESS_KEY_ID"].present?
    end

    def stub_url(s3_key)
      "/dev/stub-upload/#{s3_key}"
    end
  end
end
