require 'optparse'
require 'pry-byebug'
require './player-stats'

options = {
  format: :ap,
  o: :stdout
}

OptionParser.new do |opts|
  opts.banner = "Usage: run.rb [options] player"

  opts.on("-y", "--year=YYYY", "Select year (default: current year)") { |v| options[:year] = v.to_i }
  opts.on("-f", "--format=FILETYPE", "Output format (options: json, yaml, xml, ap; default: ap)") { |v| options[:format] = v.to_sym }
  opts.on("-o", "--output-to=PATH", "Output target (default: stdout)") { |v| options[:o] = v.to_sym }
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

options[:player] = ARGV.pop
raise "Need to specify a player" unless options[:player]

ps = PlayerStats.new(player: options[:player])
puts "Retrieving…"
stats = ps.stats

case options[:format]
when :yaml, :yml
  require 'yaml'
  stats = stats.to_yaml
when :xml
  require 'xml-simple'
  stats = XmlSimple.xml_out(stats)
when :json
  require 'json'
  stats = JSON.pretty_generate(stats)
else
  require 'awesome_print'
  stats = stats.ai
end

if options[:o].downcase == :stdout
  puts stats
else
  raise 'Cannot write to existing file' if File.exist?(options[:o])
  File.open(options[:o], 'w') { |f| f.write(stats) }
  puts "Written to #{options[:o]}"
end

