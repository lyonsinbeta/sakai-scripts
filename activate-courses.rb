require 'savon'
require 'csv'

host	= ''
usr 	= ''
pwd 	= '' 
data = ARGV[0] || 'data.rb'

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
  response = soapLSClient.request(:add_inactive_member_to_site_with_role) do
	soap.body = { :sessionid	=> session[:login_response][:login_return],
                   :siteid    => row[0],
                   :eid       => row[1],
                   :roleid    => 'Instructor' }
  end

  response = soapLSClient.request(:set_member_status) do
	soap.body = { :sessionid => session[:login_response][:login_return],
                   :siteid    => row[0],
                   :eid       => row[1],
                   :active    => true }
  end
end
