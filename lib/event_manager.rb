require "csv"
require "google/apis/civicinfo_v2"
require "erb"

def csv_contents
  CSV.open(
    "event_attendees.csv",
    headers: true,
    header_converters: :symbol
  )
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def clean_phone_number(phone)
  phone = phone.to_s.delete("^0-9")
  if phone.length <= 11 && phone.chr == "1"
    phone = phone[1..]
  elsif phone.length < 10
    return nil
  end
  if phone.length == 10
    phone
  end
end

def registration_hour
  hour_with_most_registers = []
  csv_contents.each do |row|
    date = row[:regdate]
    datetime = Time.strptime(date, "%m/%d/%y %k:%M").strftime("%H")
    hour_with_most_registers << datetime
  end
  peak_hour = hour_with_most_registers
    .group_by(&:itself)
    .max_by { |hour, count| count.size }[0]

  print "#{peak_hour}:00 is the peak registration hour\n"
end
registration_hour

def registration_day
  day_with_most_registers = []
  csv_contents.each do |row|
    date = row[:regdate]
    datetime = Date.strptime(date, "%m/%d/%y %k:%M").strftime("%A")
    day_with_most_registers << datetime
  end
  peak_day = day_with_most_registers
    .group_by(&:itself)
    .max_by { |hour, count| count.size }[0]

  print "#{peak_day} is the peak registration day\n"
end
registration_day

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = "AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw"

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: "country",
      roles: ["legislatorUpperBody", "legislatorLowerBody"]
    ).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir("output") unless Dir.exist?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename, "w") do |file|
    file.puts form_letter
  end
end

puts "EventManager Initialized"

template_letter = File.read("form_letter.erb")
erb_template = ERB.new template_letter

csv_contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  homephone = clean_phone_number(row[:homephone])
  next if homephone.nil?

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end
