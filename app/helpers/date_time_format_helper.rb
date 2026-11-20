module DateTimeFormatHelper
  def format_date(datetime)
    I18n.l(datetime, format: "%-d %B %Y")
  end

  def format_time(datetime)
    datetime.strftime("%l:%M%P").strip
  end
end
