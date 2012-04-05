# .csv MUST include headers in the order of 
# siteid, Site Title, userid of instructor

require 'savon'
require 'csv'

host = ''
usr  = ''
pwd  = ''
term = ''
data = ARGV[0] || '.csv' 

default_tools = { 'Syllabus'        => 'sakai.syllabus',
                  'Calendar'        => 'sakai.summary.calendar', 
                  'Announcements'   => 'sakai.announcements', 
                  'Lesson Builder'  => 'sakai.lessonbuildertool', 
                  'Assignment2'     => 'sakai.assignment2', 
                  'Tests & Quizzes' => 'sakai.samigo', 
                  'Forums'          => 'sakai.forums', 
                  'Messages'        => 'sakai.messages', 
                  'Gradebook'       => 'sakai.gradebook.tool', 
                  'Roster'          => 'sakai.site.roster', 
                  'Statistics'      => 'sakai.sitestats', 
                  'User Activity'   => 'seminole.useractivity', 
                  'Section Info'    => 'sakai.sections', 
                  'Site Info'       => 'sakai.siteinfo' }

### Do not edit below this line! ###

login_wsdl 	= "#{host}/sakai-axis/SakaiLogin.jws?wsdl"
script_wsdl 	= "#{host}/sakai-axis/SakaiScript.jws?wsdl"
longsight_wsdl	= "#{host}/sakai-axis/WSLongsight.jws?wsdl"

login = Savon::Client.new(login_wsdl)

session = login.request(:login) do
  soap.body = { :id => usr, :pw => pwd }
end

soapClient 	= Savon::Client.new(script_wsdl)
soapLSClient 	= Savon::Client.new(longsight_wsdl) 

CSV.foreach(data, {:headers => true}) do |row|
  response = soapClient.request(:add_new_site) do
	soap.body = { :sessionid   => session[:login_response][:login_return],
                   :siteid      => row[0],
                   :title       => row[1],
                   :description => '',
                   :shortdesc   => '',
                   :iconurl     => '',
                   :infourl     => '',
                   :joinable    => false,
                   :joinerrole  => 'Student',
                   :published   => false,
                   :publicview  => false,
                   :skin        => '',
                   :type        => 'course' }
  end

  req = soapClient.request(:set_site_property) do
	soap.body = { :sessionid => session[:login_response][:login_return],
                   :siteid    => row[0],
                   :propname  => 'term',
                   :propvalue => term }
  end

# Loop to add default tools

  default_tools.each_pair do |tool_name, tool_id|
  	req = soapClient.request(:add_new_page_to_site) do
		soap.body = { :sessionid  => session[:login_response][:login_return],
                        :siteid     => row[0],
                        :pagetitle  => tool_name,
                        :pagelayout => 2 }
	end

  	req = soapClient.request(:add_new_tool_to_page) do
		soap.body = { :sessionid   => session[:login_response][:login_return],
                        :siteid      => row[0],
                        :pagetitle   => tool_name,
                        :tooltitle   => tool_name,
                        :toolid      => tool_id,
                        :layouthints => '0,0' }
	end
  end

# Home begin
# This whole part is to setup the complicated, multi-tooled 'Home'

  req = soapClient.request(:add_new_page_to_site) do
	  soap.body = { :sessionid  => session[:login_response][:login_return],
                     :siteid     => row[0],
                     :pagetitle  => 'Home',
                     :pagelayout => 1 }
  end

  req = soapLSClient.request(:add_config_property_to_page) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                     :siteid    => row[0],
                     :pagetitle => 'Home',
                     :propname  => 'is_home_page',
                     :propvalue => 'true' }
  end

  req = soapClient.request(:add_new_tool_to_page) do
	  soap.body = { :sessionid   => session[:login_response][:login_return],
                     :siteid      => row[0],
                     :pagetitle   => 'Home',
                     :tooltitle   => 'Site Information Display',
                     :toolid      => 'sakai.iframe.site',
                     :layouthints => '0,0' }
  end

  req = soapClient.request(:add_config_property_to_tool) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                     :siteid    => row[0],
                     :pagetitle => 'Home',
                     :tooltitle => 'Worksite Information',
                     :propname  => 'special',
                     :propvalue => 'worksite' }
  end

  req = soapClient.request(:add_new_tool_to_page) do
	  soap.body = { :sessionid   => session[:login_response][:login_return],
                     :siteid      => row[0],
                     :pagetitle   => 'Home',
                     :tooltitle   => 'Recent Announcements',
                     :toolid      => 'sakai.synoptic.announcement',
                     :layouthints => '0,1' }
  end

# Remove creator of site and add correct instructor

  req = soapClient.request(:remove_member_from_site) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                     :siteid    => row[0],
                     :userid    => usr }
  end

  req = soapLSClient.request(:add_inactive_member_to_site_with_role) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                     :siteid    => row[0],
                     :eid       => row[2],
                     :roleid    => 'Instructor' }
  end

  req = soapLSClient.request(:set_member_status) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                     :siteid    => row[0],
                     :eid       => row[2],
                     :active    => true }
  end
end
