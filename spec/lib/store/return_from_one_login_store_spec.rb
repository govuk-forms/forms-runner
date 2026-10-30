require "rails_helper"

RSpec.describe Store::ReturnFromOneLoginStore do
  subject(:return_from_one_login_store) { described_class.new(store) }

  let(:store) { {} }
  let(:form) { build(:form) }
  let(:mode) { Mode.new("form") }
  let(:locale) { :en }
  let(:return_to) { "a_form_path" }

  describe "#store_return_params" do
    it "stores the path params" do
      return_from_one_login_store.store_return_params(form:, mode:, locale:, return_to:)

      expect(store["return_from_one_login"]).to eq({
        "last_mode" => mode.to_s,
        "last_form_id" => form.id,
        "last_form_slug" => form.form_slug,
        "last_locale" => locale,
        "return_to" => return_to,
      })
    end

    context "when returning to signed out page" do
      let(:return_to) do
        Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:signed_out]
      end

      it "does not store the form path params" do
        return_from_one_login_store.store_return_params(form:, mode:, locale:, return_to:)

        expect(store["return_from_one_login"]).to eq({
          "last_locale" => locale,
          "return_to" => return_to,
        })
      end
    end
  end

  describe "#return_to" do
    let(:return_to) do
      Store::ReturnFromOneLoginStore::RETURN_TO_VALUES.values.sample
    end

    it "returns the return to value" do
      return_from_one_login_store.store_return_params(form:, mode:, locale:, return_to:)

      expect(return_from_one_login_store.return_to).to eq return_to
    end
  end

  describe "#form_path_params" do
    it "returns the path params" do
      return_from_one_login_store.store_return_params(form:, mode:, locale:, return_to:)

      expect(return_from_one_login_store.form_path_params).to eq({
        mode: mode.to_s,
        form_id: form.id,
        form_slug: form.form_slug,
        locale: locale,
      })
    end

    it "raises an error if the return params have not been stored" do
      expect { return_from_one_login_store.form_path_params }.to raise_error(Store::ReturnFromOneLoginStore::MissingReturnParamsError)
    end
  end

  describe "#clear_return_from_one_login" do
    it "clears the return to value and the form path params" do
      return_from_one_login_store.store_return_params(form:, mode:, locale:, return_to:)

      return_from_one_login_store.clear_return_from_one_login

      expect(store).not_to have_key(Store::ReturnFromOneLoginStore::RETURN_FROM_ONE_LOGIN_KEY)
      expect(return_from_one_login_store.return_to).to be_nil
      expect { return_from_one_login_store.form_path_params }.to raise_error(Store::ReturnFromOneLoginStore::MissingReturnParamsError)
    end

    it "does nothing if the return params have not been stored" do
      expect { return_from_one_login_store.clear_return_from_one_login }.not_to raise_error
    end
  end

  describe "#form_id" do
    it "returns the stored form id" do
      return_from_one_login_store.store_return_params(form:, mode:, locale:, return_to:)

      expect(return_from_one_login_store.form_id).to eq form.id
    end

    it "raises an error if the return params have not been stored" do
      expect { return_from_one_login_store.form_id }.to raise_error(Store::ReturnFromOneLoginStore::MissingReturnParamsError)
    end
  end

  describe "#last_locale" do
    it "returns the stored locale" do
      return_from_one_login_store.store_return_params(form:, mode:, locale: "cy", return_to:)

      expect(return_from_one_login_store.last_locale).to eq "cy"
    end

    it "raises an error if the return params have not been stored" do
      expect { return_from_one_login_store.last_locale }.to raise_error(Store::ReturnFromOneLoginStore::MissingReturnParamsError)
    end
  end
end
