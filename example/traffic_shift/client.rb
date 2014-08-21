require 'consul/client'
require 'base64'
require 'json'
require 'resolv'

dns = Resolv::DNS.new(nameserver_port: [['localhost', 8600]])

service_name = 'testdrive'
s = Consul::Client.v1.http
data = JSON.parse(Base64.decode64(s.get("/kv/#{service_name}/spec")[0]["Value"])).to_a

n = rand
sum = 0
i = data.find_index {|(version, ratio)|
  sum += ratio
  n <= sum
}
entry = data.delete_at(i)[0]

ip = begin
  dns.getaddress("#{entry}.testdrive.service.consul")
rescue Resolv::ResolvError
  puts "no primary service, just fall back to any valid"
  begin
    dns.getaddress("testdrive.service.consul")
  rescue Resolv::ResolvError
    raise "No available services!"
  end
end

puts "#{entry} @ #{ip}"
