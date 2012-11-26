# single.csv MUST include headers: site_id, id, role
# training.csv (if used) must include a header for username

require 'optparse'
require 'savon'
require 'csv'

options = {}
OptionParser.new do |opts|
  opts.banner = "\nThanks for supporting open source software."
  opts.on('-v', '--verify', "Verifies instructor belongs in course") do |v|
    options[:verify] = v
    require 'mysql2'
  end
  opts.on('-t', '--training', "Adds untrained insstructors as TA.") do |t|
    options[:training] = t
  end
  opts.on('-h', '--help', 'Displays help') do
    puts opts
	exit
  end
end.parse!

require './config.rb'

course_list = []

if options[:training]
  begin
    sakai_trained = []
    CSV.foreach(TRAINING_CSV, {:headers => true, :header_converters => :symbol}) do |trained|
      sakai_trained << trained[:username].downcase
    end
  rescue
    abort 'Error opening training.csv'
  end
  abort 'training.csv appears to be empty.' if sakai_trained.empty? 
end 
 
CSV.foreach(ACTIVATION_CSV, {:headers => true, :header_converters => :symbol}) do |row|
  row[:role] = 'Teaching Assistant' if sakai_trained && !sakai_trained.include?(row[:id].downcase)
  course_list << row
end

if course_list.empty?
  abort 'activate.csv appears to be empty.'
end

login = Savon::Client.new(LOGIN_WSDL)
  login.http.auth.ssl.verify_mode = :none

begin
  session = login.request(:login) do
    soap.body = { :id => SOAP_USER, :pw => SOAP_PWD }
  end
rescue
  abort 'Login failed.'
end

soapClient   = Savon::Client.new(SCRIPT_WSDL)
  soapClient.http.auth.ssl.verify_mode = :none
soapLSClient = Savon::Client.new(LONGSIGHT_WSDL) 
  soapLSClient.http.auth.ssl.verify_mode = :none

course_list.each do |course|
  response = soapClient.request(:add_member_to_site_with_role) do
    soap.body = { :sessionid => session[:login_response][:login_return],
                  :siteid    => course[:site_id],
                  :eid       => course[:id],
                  :roleid    => course[:role] }
  end
    
  if response[:add_member_to_site_with_role_response][:add_member_to_site_with_role_return] =~ /null/
    course << 'Returned error'
  end
end

time = Time.now  
t = time.strftime("%Y-%m-%d %H%M%S")
  
CSV.open("Courses activated #{t}.csv", 'w') { |csv| csv << ['site_id', 'instructor'] }
CSV.open("Courses activated #{t}.csv", 'a') do |csv| 
  course_list.each { |course| csv << course } 
end
