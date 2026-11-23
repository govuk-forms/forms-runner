module HasUploadedFileKeys
  extend ActiveSupport::Concern

  def uploaded_file_keys
    answers.to_h.values.filter_map { |answer| Question::File.uploaded_file_key_from(answer) }
  end
end
