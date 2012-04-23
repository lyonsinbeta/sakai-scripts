# single.csv MUST include headers in the order of
# siteid, userid of instructor
# training.csv (if used) must include a header for userid

require 'optparse'
require 'savon'
require 'csv'

options = {}
OptionParser.new do |opts|
  opts.banner = "\nThanks for supporting open source software."
  opts.on('-v', '--verify', "Verifies an instructor has completed training before activating") do |v|
    options[:verify] = v
  end
  opts.on('-h', '--help', 'Displays help') do
    puts opts
	exit
  end
end.parse!

host           = ''
soap_user      = ''
soap_pwd       = '' 
activation_csv = ARGV[0] || 'single.csv'
training_csv   = 'training.csv'

login_wsdl     = "#{host}/sakai-axis/SakaiLogin.jws?wsdl"
script_wsdl    = "#{host}/sakai-axis/SakaiScript.jws?wsdl"
longsight_wsdl = "#{host}/sakai-axis/WSLongsight.jws?wsdl"

course_list = []

if options[:verify]
  begin
    sakai_trained = []
    CSV.foreach(training_csv, {:headers => true}) do |trained|
      sakai_trained << trained[0].to_s.downcase
    end
  rescue
    abort 'Error opening training.csv'
  end
  abort 'The training.csv appears to be empty.' if sakai_trained.empty? 
end 
 
CSV.foreach(activation_csv, {:headers => true}) do |row|
  row << 'Untrained' if sakai_trained && !sakai_trained.include?(row[1].downcase)
  course_list << row
end

if course_list.empty?
  abort 'Input csv appears to be empty.'
end

login = Savon::Client.new(login_wsdl)
login.http.auth.ssl.verify_mode = :none

begin
  session = login.request(:login) do
    soap.body = { :id => soap_user, :pw => soap_pwd }
  end
rescue
  abort 'Login failed.'
end

soapClient   = Savon::Client.new(script_wsdl)
  soapClient.http.auth.ssl.verify_mode = :none
soapLSClient = Savon::Client.new(longsight_wsdl) 
  soapLSClient.http.auth.ssl.verify_mode = :none

course_list.each do |course|
  unless course.fields.include?('Untrained')
    response = soapClient.request(:add_member_to_site_with_role) do
      soap.body = { :sessionid => session[:login_response][:login_return],
                    :siteid    => course[0],
                    :eid       => course[1],
                    :roleid    => 'Instructor' }
    end
    
    if response[:add_member_to_site_with_role_response][:add_member_to_site_with_role_return] =~ /null/
      course << 'Returned error'
    end
  end
end

time = Time.now  
t = time.strftime("%Y-%m-%d %H%M%S")
  
CSV.open("Courses activated #{t}.csv", 'w') { |csv| csv << ['siteid', 'instructor id'] }
CSV.open("Courses activated #{t}.csv", 'a') do |csv| 
  course_list.each { |course| csv << course } 
end