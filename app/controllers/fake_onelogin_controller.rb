class FakeOneloginController < ApplicationController
  def show
  end

  def create
    redirect_to auth_callback_path(mode: "preview-draft", form_id: 14, form_slug: "testing-none-of-the-above")
  end
end
