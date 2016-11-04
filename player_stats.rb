require 'net/http'
require 'nokogiri'
require './lib/match_page'

class PlayerStats
  attr_accessor :year, :player

  def initialize(options)
    @year = options[:year] || Time.new.year
    @player = options[:player]
  end

  def match_links
    @match_links ||= retrieve_match_links
  end

  def stats
    @stats ||= retrieve_stats
  end

  private

  def reset_stats
    {
      starts: [],
      subs: [],
      unused_subs: []
    }
  end

  def retrieve_stats
    @stats = reset_stats
    match_links.each do |url|
      parse_matchcenter(url)
    end
    @stats
  end

  def parse_matchcenter(url)
    match = MatchPage.new(url, @player)

    if match.unused_sub?
      (@stats[:unused_subs] << match.timestamp).uniq!
    elsif match.subbing?
      @stats[:subs] << match.data
    else
      @stats[:starts] << match.data
    end
  rescue => e
    puts e
  end

  def retrieve_match_links
    match_list_url = "http://www.mlssoccer.com/schedule?month=all&year=#{@year}&club=189"
    uri = URI(match_list_url)
    response = Net::HTTP.get(uri)
    body = Nokogiri::HTML(response)
    links = body.css('.field-item:first-child:last-child a[href*=matchcenter]')
    links.map { |link| link[:href] }
  end
end
