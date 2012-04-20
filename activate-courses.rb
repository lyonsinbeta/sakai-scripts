# .csv MUST include headers in the order of
# siteid, userid of instructor

require 'savon'
require 'csv'

host           = ''
soap_user      = ''
soap_pwd       = '' 
activation_csv = ARGV[0] || 'single.csv'

login_wsdl     = "#{host}/sakai-axis/SakaiLogin.jws?wsdl"
script_wsdl    = "#{host}/sakai-axis/SakaiScript.jws?wsdl"

courses_to_activate = []

CSV.foreach(activation_csv, {:headers => true}) do |row|
  courses_to_activate << row
end

if courses_to_activate.empty?
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

courses_to_activate.each do |course|

  response = soapClient.request(:add_member_to_site_with_role) do
    soap.body = { :sessionid => session[:login_response][:login_return],
                  :siteid    => course[0],
                  :eid       => course[1],
                  :roleid    => 'Instructor' }
  end
    
  if response[:add_member_to_site_with_role_response][:add_member_to_site_with_role_return] =~ /null/
    course << "Returned error"
  end
end

time = Time.now  
t = time.strftime("%Y-%m-%d %H%M%S")
  
CSV.open("Courses activated #{t}.csv", 'w') { |csv| csv << ['siteid', 'instructor id'] }
CSV.open("Courses activated #{t}.csv", 'a') do |csv| 
  courses_to_activate.each { |course| csv << course } 
end