module HasUploadedFileKeys
  extend ActiveSupport::Concern

  def uploaded_file_keys
    answers.to_h.values.filter_map do |answer|
      answer["uploaded_file_key"].presence if answer.is_a?(Hash)
    end
  end
end
