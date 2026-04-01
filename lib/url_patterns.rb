module UrlPatterns
  # If we make changes to these regexes, update the WAF rules first
  FORM_ID_REGEX = /\d+/
  FORM_SLUG_REGEX = /[\w-]+/
  PAGE_ID_REGEX_FOR_ROUTES = /(?:[a-zA-Z0-9]{8}|\d+)/
  PAGE_ID_REGEX = /\A#{PAGE_ID_REGEX_FOR_ROUTES}\z/
end
