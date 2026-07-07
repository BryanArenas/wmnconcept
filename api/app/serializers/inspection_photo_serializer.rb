module InspectionPhotoSerializer
  module_function

  def call(photo)
    {
      id: photo.id,
      inspection_id: photo.inspection_id,
      s3_key: photo.s3_key,
      upload_state: photo.upload_state,
      filename: photo.filename,
      content_type: photo.content_type,
      created_at: photo.created_at
    }
  end
end
