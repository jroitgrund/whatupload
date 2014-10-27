require 'capybara'
require 'capybara-webkit'

module WhatCDUpload
  class BandcampDownloadInfo
    ARTIST_INDEX_URL = 'http://bandcamp.com/artist_index?page='
    BUY_NOW_BUTTON = 'Buy Now'
    USER_PRICE_FIELD = 'userPrice'
    DOWNLOAD_NOW_BUTTON = 'Download Now'
    FREE_DOWNLOAD_BUTTON = 'Free Download'
    DIGITAL_ALBUM_REGEX = /\ADigital Album\z/
    NAME_YOUR_PRICE_REGEX = /\Aname your price\z/
    FREE_DOWNLOAD_REGEX = /\AFree Download\z/
    ARTIST_ELEM = 'span[itemprop=byArtist]'
    TAG_ELEM = 'a.tag'
    ALBUM_TITLE_ELEM = 'h2.trackTitle'
    YEAR_REGEX = /released [0-9]* [a-zA-Z]* ([0-9]{4})/
    YEAR_ELEM = '.tralbumData.tralbum-credits'
    FORMATS = [
      "FLAC",
      "MP3 V0",
      "MP3 320"
    ]
    DOWNLOAD_FORMAT_DROPDOWN = 'downloadFormatMenu0'
    DOWNLOAD_REGEX = /\ADownload\z/

    class PricingModel
      FREE_DOWNLOAD = 1
      NAME_YOUR_PRICE = 2
      NOT_A_FREE_ALBUM = 3
    end

    attr_reader :album_info
    attr_reader :urls

    def self.get_newest_urls(num_urls)
      session = Capybara::Session.new(:webkit)
      page = 0
      urls = []
      while urls.length < num_urls
        session.visit("#{ARTIST_INDEX_URL}#{++page}")
        urls += session.all(:xpath, "/html/body/div/div/div/div/div/ul[@id='bandlist']/li/a")[0, num_urls - urls.length].map { |link| link[:href] }
      end
      return urls
    end

    def initialize(url)
      @session = Capybara::Session.new(:webkit)
      @session.visit(url)
      get_pricing_model
      if downloadable?
        get_album_info
        get_download_urls
      end
    end

    def downloadable?
      @pricing_model != PricingModel::NOT_A_FREE_ALBUM
    end

    private
      def get_pricing_model
        @pricing_model = PricingModel::NOT_A_FREE_ALBUM
        if @session.first('span', text: DIGITAL_ALBUM_REGEX)
          if @session.first('span', text: NAME_YOUR_PRICE_REGEX)
            @pricing_model = PricingModel::NAME_YOUR_PRICE
          elsif @session.first('button', text: FREE_DOWNLOAD_REGEX)
            @pricing_model = PricingModel::FREE_DOWNLOAD
          end
        end
      end

      def get_album_info
        @album_info = {
          artist: @session.find(ARTIST_ELEM).text.strip,
          genre: @session.first(TAG_ELEM).text.strip,
          album: @session.find(ALBUM_TITLE_ELEM).text.strip,
          year: YEAR_REGEX.match(@session.find(YEAR_ELEM).text)[1]
        }
      end

      def get_download_urls
        begin
          new_session = Capybara::Session.new(:webkit)
          new_session.visit(@session.current_url)
          case @pricing_model
          when PricingModel::FREE_DOWNLOAD
            new_session.click_button(FREE_DOWNLOAD_BUTTON)
          when PricingModel::NAME_YOUR_PRICE
            new_session.click_button(BUY_NOW_BUTTON)
            new_session.fill_in(USER_PRICE_FIELD, with: '0')
            new_session.click_button(DOWNLOAD_NOW_BUTTON)
          end
          @urls = Hash[FORMATS.map do |format|
            new_session.click_link(DOWNLOAD_FORMAT_DROPDOWN)
            new_session.click_link(format)
            [format, new_session.find('a', text: DOWNLOAD_REGEX, wait: 120)[:href]]
          end]
        rescue
          @urls = {}
        end
      end
  end
end
