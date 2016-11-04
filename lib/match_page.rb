require 'nokogiri'
require 'date'

class MatchPage
  def initialize(url, player)
    @doc = Nokogiri::HTML(retrieve_boxscore_html(url))
    @player = player
    raise 'No team sheet table' unless team_sheet_table.any?
    raise 'Not in 18' unless starting? || subbing? || unused_sub?
  end

  def data
    {
      date: timestamp,
      opponent: opponent,
      home: home?,
      stats: player_stats,
      teammates: teammates,
      subs: subs,
      goals_for: home? ? home_goals : away_goals,
      goals_against: home? ? away_goals : home_goals
    }
  end

  def player_stats
    return {} if unused_sub?
    Hash[
      (subbing? ? subbing_stats : starting_stats).children.map.with_index { |td, i|
        [
          team_sheet_table_headers[i],
          parse_potential_num(td.text)
        ]
      }
    ]
  end

  def starting?
    starting_stats.any?
  end

  def subbing?
    subbing_stats.any? && !unused_sub?
  end

  def unused_sub?
    subbing_stats.any? && subbing_stats[0].xpath("td[contains(., '#{@player}')][i[contains(@class,'fa-chevron-up')]]").empty?
  end

  def timestamp
    DateTime.parse(@doc.xpath('//div[contains(@class, "sb-match-datetime")]').children.map(&:text).join(' '))
  end

  def teammates
    list_players(team_sheet_table.xpath('.//tbody//tr[position() <= 10]'))
  end

  def subs
    list_players(team_sheet_table.xpath('.//tbody//tr[position() >= 11][td[i[contains(@class, "fa-chevron-up")]]]'))
  end

  def home_info
    @doc.xpath('//div[contains(@class, "sb-home")]')
  end

  def away_info
    @doc.xpath('//div[contains(@class, "sb-away")]')
  end

  def home?
    home_info.xpath('.//span[contains(@class, "sb-club-name-full")]').text.strip.casecmp('new england').zero?
  end

  def away?
    !home?
  end

  def opponent
    (home? ? away_info : home_info).xpath('.//span[contains(@class, "sb-club-name-full")]').text.strip.to_sym
  end

  def home_goals
    home_info.xpath('.//div[contains(@class, "sb-score")]').text.to_i
  end

  def away_goals
    away_info.xpath('.//div[contains(@class, "sb-score")]').text.to_i
  end

  private

  def team_sheet_table
    @doc.xpath("//table[contains(@class, 'ps-table')][.//tr[td[contains(., '#{@player}')]]]")
  end

  def team_sheet_table_headers
    team_sheet_table.xpath('thead/tr')[0].children.map { |td| td['title'].to_sym }
  end

  def starting_stats
    team_sheet_table.xpath(".//tbody//tr[position() <= 10][td[contains(., '#{@player}')]]")
  end

  def subbing_stats
    team_sheet_table.xpath(".//tbody//tr[position() >= 11][td[contains(., '#{@player}')]]")
  end

  def list_players(trs)
    trs.map { |tr| tr.xpath('./td')[team_sheet_table_headers.index(:Name)].text }
       .reject { |name| name.include? @player }
  end

  def parse_potential_num(str)
    return str.to_i if str =~ /^\s*\d+\s*$/
    return str.to_f if str =~ /^\s*\d*\.\d+\s*$/
    str
  end

  def retrieve_boxscore_html(url)
    uri = URI(url)
    uri.path = uri.path.sub(/\/$/, '') + '/boxscore'
    Net::HTTP.get(uri)
  end
end
