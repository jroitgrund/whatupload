require 'capybara'
require 'capybara-webkit'
require 'gazelle'

module WhatCDUpload
  class WhatCDSession
    attr_reader :tracker_url
    attr_reader :success

    LOGIN_FORM_POST = 'https://what.cd/login.php'
    USERNAME_FIELD = 'username'
    PASSWORD_FIELD = 'password'
    LOG_IN_BUTTON = 'Log in'
    UPLOAD_LINK = 'Upload'
    TRACKER_URL_FIELD = 'input[readonly]'
    JSON_RESULTS_KEY = 'results'
    ARTIST_FIELD = 'artist'
    TITLE_FIELD = 'title'
    YEAR_FIELD = 'year'
    ALBUM_OPTION = 'Album'
    WEB_OPTION = 'WEB'
    DESCRIPTION_FIELD = 'album_desc'
    FLAC_OPTION = 'FLAC'
    MP3_OPTION = 'MP3'
    V0_OPTION = 'V0 (VBR)'
    B320_OPTION = '320'
    MAIN_FILE_FIELD = 'file_input'
    ADD_FORMAT_BUTTON = '+'
    EXTRA_FILE_1_FIELD = 'extra_file_1'
    EXTRA_FILE_2_FIELD = 'extra_file_2'
    FORMAT_1_FIELD = 'format_1'
    BITRATE_1_FIELD = 'bitrate_1'
    FORMAT_2_FIELD = 'format_2'
    BITRATE_2_FIELD = 'bitrate_2'
    UPLOAD_BUTTON = 'Upload torrent'

    def initialize(username, password)
      @username = username
      @password = password
      @success = log_in
    end

    def uploaded?(artist, album)
      session = RubyGazelle::Gazelle.connect username: @username, password: @password
      response = session.search(:torrents, artistname: artist, groupname: album)
      not response[WhatCDSession::JSON_RESULTS_KEY].empty?
    end

    def upload_torrent(upload_info, torrents)
      unless torrents.empty?
        @session.visit("https://what.cd/upload.php")

        2.times do
          begin
            @session.fill_in(WhatCDSession::ARTIST_FIELD, with: upload_info[:artist])
            break
          rescue
            log_in
          end
        end
        @session.fill_in(WhatCDSession::TITLE_FIELD, with: upload_info[:album])
        @session.fill_in(WhatCDSession::YEAR_FIELD, with: upload_info[:year])
        @session.select(WhatCDSession::ALBUM_OPTION)
        @session.select(WhatCDSession::WEB_OPTION)
        begin
          @session.select(upload_info[:genre])
        rescue
          @session.select('rock')
        end
        @session.fill_in(WhatCDSession::DESCRIPTION_FIELD, with: WhatCDSession.description_for_album(upload_info[:artist], upload_info[:album]))

        torrents.each_with_index do |torrent, index|
          @session.click_button(ADD_FORMAT_BUTTON) unless index == 0
          fields = WhatCDSession.upload_fields_for_file_number(index)
          @session.attach_file(fields[:file_input], File.absolute_path(torrent[:filename]))
          @session.select(torrent[:format], from: fields[:format])
          @session.select(torrent[:bitrate], from: fields[:bitrate]) if torrent[:bitrate]
        end

        @session.click_button('Upload torrent')
      end
    end

    private
      def log_in
        @session = Capybara::Session.new(:selenium)
        @session.visit(WhatCDSession::LOGIN_FORM_POST)
        @session.fill_in(WhatCDSession::USERNAME_FIELD, with: @username)
        @session.fill_in(WhatCDSession::PASSWORD_FIELD, with: @password)
        @session.click_button(WhatCDSession::LOG_IN_BUTTON)
        @session.click_link(WhatCDSession::UPLOAD_LINK)
        @tracker_url = @session.find(WhatCDSession::TRACKER_URL_FIELD).value
        true
        rescue
          false
      end

      def self.upload_fields_for_file_number(file_number)
        return {
          file_input: file_number == 0 ? "file_input" : "extra_file_#{file_number}",
          format: file_number == 0 ? "format" : "format_#{file_number}",
          bitrate: file_number == 0 ? "bitrate" : "bitrate_#{file_number}"
        }
      end

      def self.description_for_album(artist, album)
        return "Artist: #{artist}\nAlbum: #{album}"
      end
  end
end
