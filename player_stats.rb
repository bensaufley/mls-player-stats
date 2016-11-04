require 'net/http'
require 'nokogiri'

class PlayerStats
  attr_accessor :year, :player

  def initialize(options)
    @year = options[:year] || Time.new.year
    @player = options[:player]
  end

  def match_links
    @match_links ||= get_match_links
  end

  def stats
    @stats ||= get_stats
  end

  private

  def reset_stats
    {
      starts: [],
      subs: [],
      unused_subs: []
    }
  end

  def get_stats
    @stats = reset_stats
    match_links.each do |url|
      parse_matchcenter(url)
    end
    @stats
  end
    
  def parse_matchcenter(url)
    uri = URI(url)
    uri.path = uri.path.sub(/\/$/,'') + '/boxscore'
    response = Net::HTTP.get(uri)
    body = Nokogiri::HTML(response)

    table = body.xpath("//table[contains(@class, 'ps-table')][.//tr[td[contains(., '#{@player}')]]]")
    return unless table.any?
    stats = table.xpath(".//tbody//tr[position() <= 10][td[contains(., '#{@player}')]]")
    starting = stats.any?
    timestamp = DateTime.parse(body.xpath("//div[contains(@class, 'sb-match-datetime')]").children.map(&:text).join(" "))
    unless starting
      stats = table.xpath(".//tbody//tr[position() >= 11][td[contains(., '#{@player}')]]")
      return unless stats.any?
      @stats[:unused_subs] = (@stats[:unused_subs] + [timestamp]).uniq and return if stats[0].xpath("td[contains(., '#{@player}')][i[contains(@class,'fa-chevron-up')]]").empty?
    end

    stat_key = table.xpath("thead/tr")[0]
    headers = stat_key.children.map { |td| td['title'].to_sym }
    home_info = body.xpath('//div[contains(@class, "sb-home")]') 
    away_info = body.xpath('//div[contains(@class, "sb-away")]')
    is_home = home_info.xpath(".//span[contains(@class, 'sb-club-name-full')]").text.strip.downcase == 'new england'
    teammates = list_players(table.xpath('.//tbody//tr[position() <= 10]'), headers)
    subs = list_players(table.xpath('.//tbody//tr[position() >= 11][td[i[contains(@class, "fa-chevron-up")]]]'), headers)
    opponent = (is_home ? away_info : home_info).xpath('.//span[contains(@class, "sb-club-name-full")]').text.strip.to_sym
    home_goals = home_info.xpath('.//div[contains(@class, "sb-score")]').text.to_i
    away_goals = away_info.xpath('.//div[contains(@class, "sb-score")]').text.to_i
    game = {
      date: timestamp,
      opponent: opponent,
      home: is_home,
      stats: Hash[stats.children.map.with_index { |td, i| [headers[i], parse_potential_num(td.text)] }],
      teammates: teammates,
      subs: subs, 
      goals_for: is_home ? home_goals : away_goals,
      goals_against: is_home ? away_goals : home_goals
     }
    @stats[starting ? :starts : :subs] << game
  end

  def list_players(trs, headers)
    trs.map { |tr| tr.xpath('./td')[headers.index(:Name)].text }.reject { |name| name.include? @player }
  end

  def get_match_links
    match_list_url = "http://www.mlssoccer.com/schedule?month=all&year=#{@year}&club=189"
    uri = URI(match_list_url)
    response = Net::HTTP.get(uri)
    body = Nokogiri::HTML(response)
    links = body.css('.field-item:first-child:last-child a[href*=matchcenter]')
    links.map { |link| link[:href] }
  end

  def parse_potential_num(str)
    return str.to_i if str =~ /^\s*\d+\s*$/
    return str.to_f if str =~ /^\s*\d*\.\d+\s*$/
    str
  end
end
