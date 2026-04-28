require "rails_helper"

RSpec.describe Store::ReturnFromOneLoginStore do
  subject(:return_from_one_login_store) { described_class.new(store) }

  let(:store) { {} }
  let(:form) { build(:form) }
  let(:mode) { Mode.new("form") }
  let(:locale) { :en }

  describe "#get_path_params" do
    it "stores and return the path params" do
      return_from_one_login_store.store_return_params(form:, mode:, locale:)

      expect(return_from_one_login_store.get_path_params).to eq({
        mode: mode.to_s,
        form_id: form.id,
        form_slug: form.form_slug,
        locale: locale,
      })
    end

    it "raises an error if the return params have not been stored" do
      expect { return_from_one_login_store.get_path_params }.to raise_error(Store::ReturnFromOneLoginStore::MissingReturnParamsError)
    end
  end

  describe "#form_id" do
    it "stores the params and uses them to return the form id" do
      return_from_one_login_store.store_return_params(form:, mode:, locale:)

      expect(return_from_one_login_store.form_id).to eq form.id
    end

    it "raises an error if the return params have not been stored" do
      expect { return_from_one_login_store.form_id }.to raise_error(Store::ReturnFromOneLoginStore::MissingReturnParamsError)
    end
  end
end
