module GovukOneLogin::ServiceHeaderComponent
  class View < ApplicationComponent
    attr_reader :homepage_url,
                :one_login_url,
                :sign_out_form_action,
                :sign_out_link_href,
                :sign_out_text

    def initialize(homepage_url: nil,
                   one_login_url: nil,
                   sign_out_form_action: nil,
                   sign_out_link_href: nil,
                   sign_out_text: nil)
      lng_query_string = I18n.locale.to_sym == :cy ? "?lng=cy" : ""
      @homepage_url = homepage_url || "https://www.gov.uk"
      @one_login_url = one_login_url || "https://home.account.gov.uk#{lng_query_string}"
      @sign_out_form_action = sign_out_form_action
      @sign_out_link_href = sign_out_link_href || "https://home.account.gov.uk/sign-out#{lng_query_string}"
      @sign_out_text = sign_out_text

      super()
    end

  private

    def one_login_icon(modifier = :default)
      classes = class_names(
        "cross-service-header__logo",
        "cross-service-header__logo--nav" => (modifier == :nav),
      )

      <<~HTML.html_safe
        <svg focusable="false" xmlns="http://www.w3.org/2000/svg" width="15" height="30" viewBox="150 150 250 250" fill="currentcolor" class="#{classes}" aria-hidden="true">
          <path d="M300.002 312.261C249.445 312.261 208.346 271.165 208.346 220.608C208.346 170.051 249.445 128.954 300.002 128.954C350.559 128.954 391.655 170.051 391.655 220.608C391.655 271.165 350.559 312.261 300.002 312.261ZM300.002 170.892C272.673 170.892 250.389 193.175 250.389 220.504C250.389 247.83 272.673 270.113 300.002 270.113C327.33 270.113 349.611 247.83 349.611 220.504C349.611 193.175 327.33 170.892 300.002 170.892Z" />
          <path d="M221.275 471.046H179.231V365.202H420.769V407.246H221.275V471.046Z"/>
        </svg>
      HTML
    end
  end
end
