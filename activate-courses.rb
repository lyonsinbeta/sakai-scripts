# activate.csv MUST include headers: site_id, id, role
# training.csv (if used) must include a header for username

require 'optparse'
require 'savon'
require 'csv'

options = {}
OptionParser.new do |opts|
  opts.banner = "\nThanks for supporting open source software."
  opts.on('-t', '--trained', "Adds instructor as Teaching Assistant if untrained") do |t|
    options[:trained] = t
  end
  opts.on('-v', '--verify', "Verifies instructor belongs in course") do |v|
    options[:verify] = v
    require 'mysql2'
  end
  opts.on('-h', '--help', 'Displays help') do
    puts opts
	exit
  end
end.parse!

require './config.rb'

course_list = []

if options[:trained]
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
  if sakai_trained && !sakai_trained.include?(row[:id].downcase)
    row[:role] = "Teaching Assistant"
  end
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

if options[:verify]
  sql_client = Mysql2::Client.new(
    host:     SQL_HOST,
    database: SQL_DB,
    username: SQL_USER,
    password: SQL_PWD)

  instructors = []
  course_list.each { |course| instructors << course[:id] }
  verify_list = Hash[instructors.collect { |id| [id, []] }]

  verify_list.each do |id, arr|
    sql_client.query(
      "SELECT SAKAI_SITE.SITE_ID,SAKAI_SITE.TITLE, SAKAI_REALM_RL_GR.ACTIVE, SAKAI_USER_ID_MAP.EID 
      FROM SAKAI_USER_ID_MAP
      JOIN SAKAI_REALM_RL_GR ON SAKAI_USER_ID_MAP.USER_ID=SAKAI_REALM_RL_GR.USER_ID
      JOIN SAKAI_REALM ON SAKAI_REALM_RL_GR.REALM_KEY=SAKAI_REALM.REALM_KEY
      JOIN SAKAI_SITE ON SAKAI_REALM.REALM_ID=CONCAT('/site/',SAKAI_SITE.SITE_ID)
      WHERE SAKAI_USER_ID_MAP.EID='#{id}'
      AND SITE_ID IN(SELECT SITE_ID FROM SAKAI_SITE 
      WHERE SAKAI_SITE.SITE_ID IN (SELECT SITE_ID 
      FROM SAKAI_SITE_PROPERTY WHERE (#{SQL_TERMS})));").each do |row|
        arr << row["SITE_ID"]
    end
  end
end

course_list.each do |course|
  if options[:verify]
    if verify_list[course[:id]].include?(course[:site_id])
      response = soapClient.request(:add_member_to_site_with_role) do
        soap.body = { :sessionid => session[:login_response][:login_return],
                      :siteid    => course[:site_id],
                      :eid       => course[:id],
                      :roleid    => course[:role] }
      end
    else
      course << 'Not listed as instructor in PeopleSoft'
    end
  else
    response = soapClient.request(:add_member_to_site_with_role) do
      soap.body = { :sessionid => session[:login_response][:login_return],
                    :siteid    => course[:site_id],
                    :eid       => course[:id],
                    :roleid    => course[:role] }
    end

    if response[:add_member_to_site_with_role_response][:add_member_to_site_with_role_return] =~ /null/
    course << 'site_id does not exist'
    end
  end
end

time = Time.now  
t = time.strftime("%Y-%m-%d %H%M%S")
  
CSV.open("Courses activated #{t}.csv", 'w') { |csv| csv << ['site_id', 'instructor'] }
CSV.open("Courses activated #{t}.csv", 'a') do |csv| 
  course_list.each { |course| csv << course } 
end

