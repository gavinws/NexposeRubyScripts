# This script generates a comma delimited report to help with scan planning
# The report shows the following information for every site:
#   Site Name
#   Last Scan Start
#   Last Scan Status
#   Last Scan Live Nodes
#   Last Scan Duration
#   Scan Template
#   Scan Engine
#   Next Scan Start  (Not implemented yet)
#   Schedule         (Not implemented yet)
 
# March 6, 2012
# misterpaul
 
require 'nexpose'
require 'time'
require 'highline/import'
include Nexpose
 
# Defaults: Change to suit your environment.
default_host = 'your-host'
default_port = 3780
default_name = 'your-nexpose-id'
default_file = 'ScanPlan_' + DateTime.now.strftime('%Y-%m-%d--%H%M') + '.csv'
 
host = ask('Enter the server name (host) for Nexpose: ') { |q| q.default = default_host }
port = ask('Enter the port for Nexpose: ') { |q| q.default = default_port.to_s }
user = ask('Enter your username:  ') { |q| q.default = default_name }
pass = ask('Enter your password:  ') { |q| q.echo = '*' }
file = ask('Enter the filename to save the results into: ') { |q| q.default = default_file }
 
begin
  @nsc = Connection.new(host, user, pass, port)
  @nsc.login
 
  sites = @nsc.site_listing || []
 
  # Get a list of the scanners and make a hash, indexed by id
  engine_list = {}
  EngineListing.new(@nsc).engines.each do |engine|
    engine_list[engine.id] = "#{engine.name} (#{engine.status})"
  end
 
  if sites.empty?
    puts 'There are currently no active sites on this Nexpose instance.'
  else
    File.open(file, 'w') do |file|
      file.puts 'Site Name,Last Scan Start,Last Scan Status,Last Scan Live Nodes,Last Scan Duration,Scan Template,Scan Engine,Next Scan Start,Schedule'
      sites.each do |s|
        site = Site.new(@nsc, s[:site_id])
        puts "site: ##{s[:site_id]}\tname: #{s[:name]}"
        config = site.site_config
        template = config.scanConfig.name
        history = site.site_scan_history.scan_summaries
        if history.empty?
          # No scans found.
          start_time = ''
          status = ''
          active = ''
          duration = ''
          engine_name = ''
        else
          latest = history.sort_by { |summary| summary.startTime }.last
          start_time = Time.parse(latest.startTime)
          status = latest.status
          active = latest.nodes_live
          engine_name = engine_list[latest.engine_id.to_s]
          if latest.endTime.empty?
            duration = ''
          else
            duration_sec = Time.parse(latest.endTime) - Time.parse(latest.startTime)
            hours = (duration_sec / 3600).to_i
            minutes = (duration_sec / 60 - hours * 60).to_i
            seconds = (duration_sec - (minutes * 60 + hours * 3600))
            duration = sprintf('%dh %02dm %02ds', hours, minutes, seconds)
          end
        end
        file.puts "#{config.site_name},#{start_time},#{status},#{active},#{duration},#{template}, #{engine_name},NEXT SCAN,SCHEDULE"
      end   
    end
  end
rescue ::Nexpose::APIError => e
  $stderr.puts "Failure: #{e.reason}"
  exit(1)
end