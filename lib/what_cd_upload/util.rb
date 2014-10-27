require 'net/http'
require 'uri'
require 'zip'

module WhatCDUpload
  class Util
    def self.fetch_from_remote_zip(remote_zip, target_directory)
      zipfilename = File.join(target_directory, 'archive.zip')
      download(remote_zip, zipfilename)
      unzip(zipfilename, target_directory)
      File.delete(zipfilename)
    end

    def self.make_torrent(tracker_url, directory, torrent_filename)
      system("transmission-create -p -o \"#{torrent_filename.gsub('"', '\"')}\" -t #{tracker_url} \"#{directory}\"")
    end

    def self.bandcamp_format_to_what_cd_format_info(bandcamp_format)
      return case bandcamp_format
      when 'FLAC'
        {
          format: 'FLAC'
        }
      when 'MP3 V0'
        {
          format: 'MP3',
          bitrate: 'V0 (VBR)'
        }
      when 'MP3 320'
        {
          format: 'MP3',
          bitrate: '320'
        }
      end
    end

    private
      def self.download(remote_uri, target_file)
        uri = URI.parse(remote_uri)
        File.open(target_file, 'wb') do |file|
          Net::HTTP.start(uri.host) do |http|
            http.request_get(URI.parse(remote_uri)) do |resp|
              resp.read_body do |segment|
                file.write(segment)
              end
            end
          end
        end
      end

      def self.unzip(zipfilename, target_directory)
        Zip::File.open(zipfilename) do |zipfile|
          zipfile.each do |file|
            file.extract(File.join(target_directory, file.name.force_encoding('utf-8')))
          end
        end
      end
  end
end